[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 122 - Referenzlösung (AWS Backup für EKS: composite recovery point,
Wiederherstellung eines namespace)

Alle Befehle werden auf der Worker-Maschine über SSH ausgeführt. kubectl und die aws CLI
sind bereits für den Cluster und die Region des Labs konfiguriert. Terraform hat die IAM
role für AWS Backup und den backup vault bereits erstellt (Komponente `eks_backup_iam`,
Modul `eks_v2_backup_iam`) - deren ARNs und Namen stehen in der Hinweisdatei
`~/lab122_hints.txt`.

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## Aufgabe 1. Namespace `eks-122`, Last auf einem EBS-Volume und Marker

Namespace, Deployment, PVC auf der Klasse `gp3` (das Addon `aws-ebs-csi-driver` ist bereits
von der Komponente `eks_addon_ebs_irsa` installiert) und eine ConfigMap mit einem Marker,
der später bestätigt, dass das wiederhergestellte Objekt wirklich aus dem Backup kam:

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

`volumeBindingMode: WaitForFirstConsumer` verzögert die Erstellung des Volumes, bis der Pod
geplant ist (Kapitel 23) - das PVC wechselt erst dann auf `Bound`, wenn der Pod `web`
tatsächlich geplant wurde. Der Marker im Artefakt wird später beweisen, dass die
wiederhergestellte ConfigMap aus dem Backup kam und nicht von Hand neu erstellt wurde.

## Aufgabe 2. Opt-in für Amazon EKS in AWS Backup für die Region

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

Ohne diesen opt-in sieht AWS Backup den EKS-Cluster nicht als schützbare Ressource, und
`start-backup-job` für den Cluster schlägt fehl (Kapitel 41, Abschnitt 41.4).

## Aufgabe 3. On-demand Backup des Clusters

Der Cluster wurde bereits mit explizitem `authentication_mode = "API_AND_CONFIG_MAP"`
erstellt (Modul `eks_v2_control_plane`), damit ist die Anforderung von AWS Backup an den
Autorisierungsmodus schon im Vorfeld erfüllt - der Service erstellt beim ersten backup job
seine eigene access entry.

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

Der EBS-Snapshot des Volumes `data` kann länger brauchen als der Clusterzustand, deshalb
warten wir auf einen Endstatus und nicht speziell auf `COMPLETED`: `PARTIAL` (Kapitel 41,
Abschnitt 41.4) bedeutet ebenfalls, dass der backup job beendet ist und ein recovery point
erstellt wurde, nur dass eventuell einer der verschachtelten Punkte nicht zustande kam.
Speichern wir das Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## Aufgabe 4. Diagnose des composite recovery point

`RECOVERY_POINT_ARN` aus Aufgabe 3 ist ein composite recovery point: der übergeordnete
Punkt gruppiert den child recovery point des Clusterzustands und den child recovery point
des Volumes `data` als eine konsistente Einheit (Kapitel 41, Abschnitt 41.4). Sehen wir uns
diesen Punkt und die verschachtelten Punkte an:

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

Speichern wir die Erklärung des Unterschieds zwischen composite und child Punkten im
Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
Ein composite recovery point ist ein zusammengesetzter Wiederherstellungspunkt für einen
EKS-Cluster: er gruppiert mehrere verschachtelte (nested/child) Punkte unter sich als eine
konsistente Einheit. Für dieses Lab bedeutet das den child recovery point des
Clusterzustands (die Manifeste der Kubernetes-Objekte des namespace eks-122) und den child
recovery point des Volumes data (einen EBS-Snapshot hinter dem PVC).

Der composite Punkt hat keinen eigenen ParentRecoveryPointArn - er ist die oberste Ebene.
In jedem child Punkt verweist das Feld ParentRecoveryPointArn auf den ARN des composite
Punktes, und IsParent=true ist genau am composite gesetzt. Das child des Clusterzustands
hat eine 1:1-Bindung an seinen Parent: es kann nicht einzeln kopiert, gelöscht oder
abgetrennt werden. Der child Punkt des Volumes kann dagegen getrennt vom composite kopiert,
gelöscht und wiederhergestellt werden.

Genau deshalb kann der composite Punkt nicht gelöscht werden, solange er verschachtelte
Punkte enthält - zuerst müssen die nested Punkte gelöscht oder abgetrennt werden, und erst
danach der composite Punkt selbst.
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## Aufgabe 5. Namespace restore (non-destructive)

Wir starten einen restore des composite recovery point und geben den namespace `eks-122`
an, in denselben (laufenden) Cluster:

`namespaceLevelRestore` allein genügt hier nicht. Der composite Punkt enthält zusätzlich
einen EBS-Snapshot, und für dessen Wiederherstellung **verlangt AWS Backup zwingend eine
Availability Zone**, in der das Volume erstellt wird. Fehlt sie, scheitert der child restore
job des Volumes mit `Restore Job failed as no restore metadata was provided`, und der
übergeordnete mit `All PV restore jobs failed to restore`. Das wird über den Parameter
`nestedRestoreJobs` übergeben: eine Map `ARN des verschachtelten Punktes -> dessen
Metadaten`. Die Zone wird von einem vorhandenen Node genommen, sonst würde das Volume dort
entstehen, wo es niemand einbinden kann.

Achten Sie auf die verschachtelte Kodierung: der Wert von `nestedRestoreJobs` ist ein
JSON-String, in dem eine Map steckt, und der Wert jedes Map-Elements ist selbst wieder ein
JSON-String. Eine zusätzliche Ebene Anführungszeichen führt zum Fehler
`Invalid JSON format in NestedRestoreMetadata`, deshalb bauen wir ihn mit `jq` (beachten
Sie das `-r` im ersten Aufruf - es entfernt die zusätzliche Ebene):

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

Wir prüfen, dass das Deployment `web` und die ConfigMap `marker` nicht dupliziert wurden
und dass der Marker mit dem in Aufgabe 1 gespeicherten übereinstimmt - das beweist das
non-destructive Verhalten des restore (Kapitel 42, Abschnitt 42.2): Objekte, die im Cluster
schon unter demselben Namen existieren, werden nicht überschrieben, sondern nur
übersprungen, sodass ein restore über einen laufenden namespace keine zweite Kopie anlegt.

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

Speichern wir ein Artefakt mit der Erklärung:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
Ein restore in AWS Backup ist immer non-destructive: Kubernetes-Objekte, die im
Ziel-namespace bereits existieren, werden nicht überschrieben, sondern nur übersprungen.
Das Deployment web und die ConfigMap marker existierten zum Zeitpunkt des restore schon in
eks-122 mit demselben Inhalt, daher hat der restore keine Duplikate davon erzeugt und den
Wert des Markers nicht verändert - die Objekte stimmten einfach überein und wurden
übersprungen.
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## Aufgabe 6. Warum ein rollback der Clusterversion `kubectl delete namespace` nicht rückgängig macht

Das motivierende Beispiel aus Abschnitt 41.1 von Kapitel 41: ein Ingenieur führt
versehentlich `kubectl delete namespace prod` gegen den falschen Cluster aus, und der erste
Gedanke ist „machen wir ein rollback". Aber es gibt nichts zurückzurollen.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
Ein rollback der Clusterversion (Kapitel 39) arbeitet mit dem control plane und seiner
Kubernetes-Version - es speichert und liefert weder Kubernetes-Objekte noch den Inhalt der
Volumes zurück. Die Objekte, die kubectl delete namespace entfernt hat, leben in etcd, und
in EKS ist etcd managed: es gibt keinen direkten Zugriff darauf, und man kann keinen
etcd-Dump nehmen und ihn von Hand wiederherstellen wie in einem selbst verwalteten Cluster.
Es gibt für ein managed control plane auch keinen Befehl "stelle es so her wie gestern".

Genau deshalb ist der einzige funktionierende Weg, einen gelöschten namespace
zurückzuholen, ein im Vorfeld mit AWS Backup erstelltes Backup des Clusterzustands
(Aufgaben 3-4) mit anschließendem restore (Aufgabe 5), und kein rollback der Version des
control plane.
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## Schnelle Prüfung

```bash
check_result
```
