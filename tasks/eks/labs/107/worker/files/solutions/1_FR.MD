[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - solution de référence (EFS CSI : ReadWriteMany entre AZ)

Toutes les commandes s'exécutent sur la worker machine via SSH. kubectl est déjà configuré
pour le cluster. Le driver `aws-efs-csi-driver` (provisioner `efs.csi.aws.com`) est déjà
installé comme addon managé avec un rôle via IRSA (composant `eks_addon_efs_irsa`), le
système de fichiers EFS et le mount target dans chaque AZ sont déjà créés par terraform - pas
besoin de les recréer.

## Tâche 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## Tâche 2. StorageClass `efs-sc` pointant vers le vrai `fileSystemId`

Le système de fichiers a été créé au préalable par terraform, le driver fonctionne seulement
au-dessus. On trouve son ID via AWS CLI (le tag `Name` est construit à partir du `prefix` du
lab) :

```bash
FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)
echo "$FS_ID"

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${FS_ID}
  directoryPerms: "755"
  uid: "1000"
  gid: "1000"
  basePath: "/dynamic"
mountOptions: ["tls"]
EOF
```

`provisioningMode: efs-ap` signifie un provisionnement dynamique : pour chaque PVC, le driver
crée un access point séparé à l'intérieur de ce système de fichiers, au lieu de fournir tout
le système de fichiers.

## Tâche 3. PVC `shared-data` (`ReadWriteMany`, `5Gi`)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
  namespace: eks-107
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
EOF

kubectl get pvc shared-data -n eks-107
```

EFS est un système régional, donc le PVC passe à `Bound` quelle que soit la zone dans laquelle
les pods atterriront plus tard : le mount target est accessible depuis n'importe quelle AZ où
il est créé.

## Tâche 4. Deployment `writer` (3 répliques, AZ différentes, PVC partagé)

`topologySpreadConstraints` sur la clé `topology.kubernetes.io/zone` fait que le scheduler
répartit les répliques sur des zones différentes :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writer
  namespace: eks-107
spec:
  replicas: 3
  selector:
    matchLabels:
      app: writer
  template:
    metadata:
      labels:
        app: writer
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: writer
      containers:
      - name: app
        image: viktoruj/ping_pong:alpine
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: shared-data
EOF

kubectl rollout status deployment/writer -n eks-107
kubectl get po -n eks-107 -l app=writer -o wide
```

Vérifiez que les répliques ont atterri dans des AZ différentes :

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

Les 3 répliques sont `Running` en même temps et montent le même PVC `shared-data`, même
si elles sont dans des AZ différentes. Avec EBS, cela est impossible (`ReadWriteOnce`, erreur
`Multi-Attach error`), car EBS est un volume bloc zonal, tandis qu'EFS est un système NFS
régional avec un mount target dans chaque zone.

## Tâche 5. Accès partagé : écrire depuis une réplique, lire depuis une autre

```bash
PODS=($(kubectl get po -n eks-107 -l app=writer -o jsonpath='{.items[*].metadata.name}'))
WRITER_POD=${PODS[0]}
READER_POD=${PODS[1]}

kubectl exec -n eks-107 "$WRITER_POD" -- sh -c \
  'echo "efs-rwx-test from $(hostname)" >> /data/shared.txt'

mkdir -p /var/work/tests/artifacts/5
kubectl exec -n eks-107 "$READER_POD" -- cat /data/shared.txt \
  > /var/work/tests/artifacts/5/readback.txt
cat /var/work/tests/artifacts/5/readback.txt
```

La ligne écrite par le pod `$WRITER_POD` dans une AZ est lue par le pod `$READER_POD` dans
une autre AZ - cela confirme qu'il s'agit vraiment d'un volume réseau partagé via NFS, pas
d'une copie locale sur le disque du nœud.

## Tâche 6. Vérification de l'absence de `nodeAffinity` zonale

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
Le PV créé par efs.csi.aws.com n'a pas de section spec.nodeAffinity (contrairement à EBS,
chapitre 23, où nodeAffinity ancre une AZ précise via la clé topology.ebs.csi.aws.com/zone).
La raison est qu'EFS est un système de fichiers régional avec un mount target dans chaque
AZ, donc un pod utilisant ce volume peut être recréé dans n'importe quelle autre zone du
cluster et continuera à voir les mêmes données via le mount target de sa nouvelle zone. Le
scheduler n'a pas besoin d'ancrer le pod à un nœud ou une zone précise à cause du volume,
comme il le fait avec EBS.
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

La commande `grep -A3 nodeAffinity` ne trouve rien (sortie vide, code de sortie `1`) - c'est
la confirmation que la section est absente. Comparez avec le `pv.yaml` du lab 106 (EBS), où
`spec.nodeAffinity.required.nodeSelectorTerms` ancre rigidement la zone du volume.

## Tâche 7. Diagnostic : SG du mount target et port 2049 (lecture seule)

Casser de l'infrastructure réelle est risqué, donc cette tâche se limite à confirmer l'état
actuel via AWS CLI et à expliquer les conséquences de l'absence de la règle.

```bash
mkdir -p /var/work/tests/artifacts/7

FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)

MT_SG=$(aws efs describe-mount-targets --region eu-central-1 --file-system-id "$FS_ID" \
  --query 'MountTargets[0].MountTargetId' --output text | \
  xargs -I{} aws efs describe-mount-target-security-groups --region eu-central-1 \
  --mount-target-id {} --query 'SecurityGroups[0]' --output text)

aws ec2 describe-security-groups --region eu-central-1 --group-ids "$MT_SG" \
  --query 'SecurityGroups[0].IpPermissions[?ToPort==`2049`]' \
  > /var/work/tests/artifacts/7/sg-rule.txt
cat /var/work/tests/artifacts/7/sg-rule.txt
```

Assurez-vous que la sortie contient une règle `FromPort/ToPort: 2049`, `IpProtocol: tcp`, et
que la source (`UserIdGroupPairs`) est le security group des nœuds du cluster, pas un CIDR.
Enregistrez le diagnostic des causes et effets :

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
Le security group du mount target autorise le TCP entrant sur le port 2049 (NFS) depuis le
security group des nœuds du cluster - ceci est confirmé par la sortie de aws ec2
describe-security-groups (sg-rule.txt). Cette règle est nécessaire pour chaque mount
target : sans elle, le driver efs.csi.aws.com peut toujours créer le point de montage au
niveau de l'API, mais le processus de montage réel sur le nœud ne pourra pas établir de
connexion NFS vers le mount target.

Si cette règle est retirée, le montage n'échouera pas immédiatement avec une erreur
explicite : les paquets TCP vers le port 2049 seront rejetés par le security group, et le
noyau du nœud attendra la réponse du serveur NFS jusqu'à expiration du timeout. Le pod
restera en Pending/ContainerCreating, et kubectl describe pod affichera un événement
FailedMount avec un texte du type "Unable to mount... connection timed out" - visuellement
proche d'un réseau lent plutôt que d'un refus d'accès explicite, et sans diagnostiquer le
security group, il est facile de confondre la cause avec un problème du serveur NFS
lui-même ou du sous-réseau.
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## Vérification rapide

```bash
check_result
```
