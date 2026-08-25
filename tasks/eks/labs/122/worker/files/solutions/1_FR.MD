[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 122 - solution de référence (AWS Backup pour EKS : composite recovery point,
restauration de namespace)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl et la CLI aws sont
déjà configurés pour le cluster et la région du lab. Terraform a déjà créé l'IAM role pour
AWS Backup et le backup vault (composant `eks_backup_iam`, module `eks_v2_backup_iam`) -
leurs ARN et leurs noms sont dans le fichier d'indices `~/lab122_hints.txt`.

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## Tâche 1. Namespace `eks-122`, charge sur un volume EBS et marqueur

Namespace, Deployment, PVC sur la classe `gp3` (l'addon `aws-ebs-csi-driver` est déjà
installé par le composant `eks_addon_ebs_irsa`) et un ConfigMap avec un marqueur qui
confirmera plus tard que l'objet restauré vient réellement du backup :

```bash
kubectl create namespace eks-122

cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: eks-122
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-122
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data
EOF

kubectl rollout status deployment/web -n eks-122

MARKER="MARKER_LAB122_$(tr -dc a-z0-9 </dev/urandom | head -c 8)"
kubectl create configmap marker -n eks-122 --from-literal=marker="$MARKER"

mkdir -p /var/work/tests/artifacts/1
echo -n "$MARKER" > /var/work/tests/artifacts/1/marker.txt
cat /var/work/tests/artifacts/1/marker.txt
```

`volumeBindingMode: WaitForFirstConsumer` retarde la création du volume jusqu'à ce que le
pod soit planifié (chapitre 23) - le PVC ne passe à `Bound` qu'après que le pod `web` est
réellement planifié. Le marqueur dans l'artefact prouvera plus tard que le ConfigMap
restauré vient du backup et n'a pas été recréé à la main.

## Tâche 2. Opt-in Amazon EKS dans AWS Backup pour la région

```bash
mkdir -p /var/work/tests/artifacts/2
BEFORE=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "before=$BEFORE" > /var/work/tests/artifacts/2/optin.txt

if [[ "$BEFORE" != "True" ]]; then
  aws backup update-region-settings \
    --resource-type-opt-in-preference '{"EKS":true}'
fi

AFTER=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "after=$AFTER" >> /var/work/tests/artifacts/2/optin.txt
cat /var/work/tests/artifacts/2/optin.txt
```

Sans cet opt-in, AWS Backup ne voit pas le cluster EKS comme une ressource protégeable, et
`start-backup-job` sur le cluster échoue (chapitre 41, section 41.4).

## Tâche 3. Backup on-demand du cluster

Le cluster a déjà été créé avec un `authentication_mode = "API_AND_CONFIG_MAP"` explicite
(module `eks_v2_control_plane`), donc l'exigence d'AWS Backup sur le mode d'autorisation
est déjà satisfaite d'avance - le service créera sa propre access entry lors du premier
backup job.

```bash
BACKUP_JOB_ID=$(aws backup start-backup-job \
  --backup-vault-name "$VAULT_NAME" \
  --resource-arn "$CLUSTER_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --query 'BackupJobId' --output text)

echo "backup_job_id=$BACKUP_JOB_ID"

while true; do
  STATE=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
    --query 'State' --output text)
  echo "backup job state: $STATE"
  case "$STATE" in
    COMPLETED|PARTIAL|FAILED|ABORTED|EXPIRED) break ;;
  esac
  sleep 15
done

RECOVERY_POINT_ARN=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
  --query 'RecoveryPointArn' --output text)
```

Le snapshot EBS du volume `data` peut prendre plus de temps à se constituer que l'état du
cluster, c'est pourquoi nous attendons un statut terminal et pas spécifiquement
`COMPLETED` : `PARTIAL` (chapitre 41, section 41.4) signifie aussi que le backup job est
terminé et qu'un recovery point a été créé, simplement l'un des points imbriqués n'a
peut-être pas abouti. Enregistrons l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## Tâche 4. Diagnostic du composite recovery point

`RECOVERY_POINT_ARN` de la tâche 3 est un composite recovery point : le point parent
regroupe le child recovery point de l'état du cluster et le child recovery point du volume
`data` comme une unité cohérente (chapitre 41, section 41.4). Regardons ce point et les
points imbriqués :

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

Enregistrons dans l'artefact l'explication de la différence entre points composite et
child :

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
Un composite recovery point est un point de restauration composé pour un cluster EKS : il
regroupe sous lui plusieurs points imbriqués (nested/child) comme une unité cohérente.
Pour ce lab, cela signifie le child recovery point de l'état du cluster (les manifestes
des objets Kubernetes du namespace eks-122) et le child recovery point du volume data (un
snapshot EBS derrière le PVC).

Le point composite n'a pas de ParentRecoveryPointArn propre - il est au niveau supérieur.
Dans chaque point child, le champ ParentRecoveryPointArn référence l'ARN du point
composite, et IsParent=true est marqué précisément sur le composite. Le child de l'état du
cluster a un lien 1:1 avec son parent : il ne peut pas être copié, supprimé ni détaché
séparément. Le point child du volume, en revanche, peut être copié, supprimé et restauré
séparément du composite.

C'est exactement pour cela que le composite ne peut pas être supprimé tant qu'il contient
des points imbriqués - il faut d'abord supprimer ou détacher les points nested, et
seulement ensuite le composite lui-même.
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## Tâche 5. Namespace restore (non-destructive)

Nous lançons un restore du composite recovery point, en indiquant le namespace `eks-122`,
dans le même cluster (en production) :

`namespaceLevelRestore` seul ne suffit pas ici. Le point composite contient aussi un
snapshot EBS, et pour le restaurer AWS Backup **exige obligatoirement une Availability
Zone** dans laquelle créer le volume. Si elle n'est pas indiquée, le restore job child du
volume échoue avec `Restore Job failed as no restore metadata was provided`, et le parent
échoue avec `All PV restore jobs failed to restore`. Cela se transmet via le paramètre
`nestedRestoreJobs` : une carte `ARN du point imbriqué -> ses métadonnées`. La zone est
prise d'un nœud existant, sinon le volume serait créé là où personne ne peut le monter.

Notez l'imbrication de l'encodage : la valeur de `nestedRestoreJobs` est une chaîne JSON,
à l'intérieur de laquelle il y a une carte, et la valeur de chaque élément de la carte est
elle-même une chaîne JSON. Un niveau de guillemets en trop produit l'erreur
`Invalid JSON format in NestedRestoreMetadata`, c'est pourquoi nous la construisons avec
`jq` (notez le `-r` du premier appel - c'est lui qui retire le niveau en trop) :

```bash
AZ=$(kubectl get nodes -l 'eks.amazonaws.com/compute-type notin (fargate)' \
  -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/zone}')

SNAP_ARN=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN" \
  --query 'RecoveryPoints[?ResourceType==`EBS`].RecoveryPointArn' --output text)

NESTED=$(jq -rn --arg s "$SNAP_ARN" --arg az "$AZ" \
  '{($s): ({AvailabilityZone: $az} | tostring)} | tostring')

METADATA=$(jq -cn --arg c "$CLUSTER_NAME" --arg n "$NESTED" \
  '{clusterName: $c, newCluster: "false", namespaceLevelRestore: "true",
    namespaces: "[\"eks-122\"]", nestedRestoreJobs: $n}')

RESTORE_JOB_ID=$(aws backup start-restore-job \
  --recovery-point-arn "$RECOVERY_POINT_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --resource-type EKS \
  --metadata "$METADATA" \
  --query 'RestoreJobId' --output text)

echo "restore_job_id=$RESTORE_JOB_ID"

while true; do
  STATUS=$(aws backup describe-restore-job --restore-job-id "$RESTORE_JOB_ID" \
    --query 'Status' --output text)
  echo "restore job status: $STATUS"
  case "$STATUS" in
    COMPLETED|FAILED|ABORTED) break ;;
  esac
  sleep 15
done
```

Nous vérifions que le Deployment `web` et le ConfigMap `marker` n'ont pas été dupliqués et
que le marqueur correspond à celui enregistré dans la tâche 1 - cela prouve le
comportement non-destructive du restore (chapitre 42, section 42.2) : les objets qui
existent déjà dans le cluster sous le même nom ne sont pas écrasés, ils sont simplement
ignorés, si bien qu'un restore par-dessus un namespace en production ne crée pas de
deuxième copie.

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

Enregistrons un artefact avec l'explication :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
Un restore dans AWS Backup est toujours non-destructive : les objets Kubernetes qui
existent déjà dans le namespace cible ne sont pas écrasés, ils sont simplement ignorés. Le
Deployment web et le ConfigMap marker existaient déjà dans eks-122 au moment du restore
avec le même contenu, donc le restore n'a pas créé de doublons et n'a pas changé la valeur
du marqueur - les objets ont simplement coïncidé et ont été ignorés.
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## Tâche 6. Pourquoi un rollback de la version du cluster n'annule pas `kubectl delete namespace`

L'exemple motivant de la section 41.1 du chapitre 41 : un ingénieur exécute par erreur
`kubectl delete namespace prod` sur le mauvais cluster, et la première pensée est
« faisons un rollback ». Mais il n'y a rien à annuler.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
Un rollback de la version du cluster (chapitre 39) travaille avec le control plane et sa
version de Kubernetes - il ne stocke ni ne restitue les objets Kubernetes ni le contenu
des volumes. Les objets que kubectl delete namespace a supprimés vivent dans etcd, et dans
EKS etcd est managed : il n'y a pas d'accès direct, et on ne peut pas prendre un dump
d'etcd et le restaurer à la main comme sur un cluster autogéré. Il n'existe pas non plus
de commande « remets-le comme hier » pour un control plane managed.

C'est exactement pour cela que la seule façon qui fonctionne pour ramener un namespace
supprimé est un backup de l'état du cluster fait à l'avance avec AWS Backup (tâches 3-4)
suivi d'un restore (tâche 5), et non un rollback de la version du control plane.
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## Vérification rapide

```bash
check_result
```
