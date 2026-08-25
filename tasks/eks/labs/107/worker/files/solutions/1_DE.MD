[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - Referenzlösung (EFS CSI: ReadWriteMany über AZ hinweg)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für
den Cluster konfiguriert. Der Driver `aws-efs-csi-driver` (Provisioner `efs.csi.aws.com`)
ist bereits als Managed Addon mit einer Rolle über IRSA installiert (Komponente
`eks_addon_efs_irsa`), das EFS-Dateisystem und das Mount Target in jeder AZ sind bereits
von Terraform erstellt worden - sie müssen nicht erneut erstellt werden.

## Aufgabe 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## Aufgabe 2. StorageClass `efs-sc` zeigt auf die reale `fileSystemId`

Das Dateisystem wurde vorab von Terraform erstellt, der Driver arbeitet nur darauf
aufbauend. Wir finden seine ID über die AWS CLI (das Tag `Name` wird aus dem `prefix` des
Labs gebildet):

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

`provisioningMode: efs-ap` bedeutet dynamisches Provisioning: für jede PVC erstellt der
Driver einen separaten Access Point innerhalb dieses Dateisystems, statt das gesamte
Dateisystem herauszugeben.

## Aufgabe 3. PVC `shared-data` (`ReadWriteMany`, `5Gi`)

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

EFS ist ein regionales System, daher geht die PVC in `Bound` über, unabhängig davon, in
welcher Zone die Pods später landen: das Mount Target ist aus jeder AZ erreichbar, in der
es erstellt wurde.

## Aufgabe 4. Deployment `writer` (3 Repliken, unterschiedliche AZ, gemeinsame PVC)

`topologySpreadConstraints` auf dem Key `topology.kubernetes.io/zone` bewirkt, dass der
Scheduler die Repliken über verschiedene Zonen verteilt:

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

Wir prüfen, dass die Repliken über verschiedene AZ verteilt gelandet sind:

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

Alle 3 Repliken sind gleichzeitig `Running` und mounten dieselbe PVC `shared-data`, obwohl
sie sich in unterschiedlichen AZ befinden. Mit EBS ist das unmöglich (`ReadWriteOnce`,
Fehler `Multi-Attach error`), weil EBS ein zonales Block-Volume ist, während EFS ein
regionales NFS-System mit einem Mount Target in jeder Zone ist.

## Aufgabe 5. Gemeinsamer Zugriff: Schreiben von einer Replik, Lesen von einer anderen

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

Die von Pod `$WRITER_POD` in einer AZ geschriebene Zeile wird von Pod `$READER_POD` in
einer anderen AZ gelesen - das bestätigt, dass es sich tatsächlich um ein gemeinsames
Netzwerk-Volume über NFS handelt, nicht um eine lokale Kopie auf der Festplatte des Nodes.

## Aufgabe 6. Prüfung auf das Fehlen einer zonalen `nodeAffinity`

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
Das von efs.csi.aws.com erstellte PV hat keinen Abschnitt spec.nodeAffinity (im
Unterschied zu EBS, Kapitel 23, wo nodeAffinity eine bestimmte AZ über den Key
topology.ebs.csi.aws.com/zone festlegt). Der Grund ist, dass EFS ein regionales
Dateisystem mit einem Mount Target in jeder AZ ist, sodass ein Pod, der dieses Volume
nutzt, in jeder anderen Zone des Clusters neu erstellt werden kann und weiterhin dieselben
Daten über das Mount Target seiner neuen Zone sieht. Der Scheduler muss den Pod wegen des
Volumes nicht an einen bestimmten Node oder eine Zone binden, wie er es bei EBS tut.
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

Der Befehl `grep -A3 nodeAffinity` findet nichts (leere Ausgabe, Exit-Code `1`) - das ist
die Bestätigung, dass der Abschnitt fehlt. Vergleichen Sie das mit der `pv.yaml` aus Lab
106 (EBS), wo `spec.nodeAffinity.required.nodeSelectorTerms` die Zone des Volumes starr
festlegt.

## Aufgabe 7. Diagnose: Security Group des Mount Targets und Port 2049 (nur lesend)

Reale Infrastruktur zu beschädigen ist riskant, daher bestätigt diese Aufgabe nur den
aktuellen Zustand über die AWS CLI und erklärt die Folgen, wenn die Regel fehlt.

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

Stellen Sie sicher, dass die Ausgabe eine Regel `FromPort/ToPort: 2049`, `IpProtocol: tcp`
enthält und dass die Quelle (`UserIdGroupPairs`) die Security Group der Cluster-Nodes ist,
nicht ein CIDR. Speichern Sie die Diagnose von Ursachen und Auswirkungen:

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
Die Security Group des Mount Targets erlaubt eingehendes TCP 2049 (NFS) von der Security
Group der Cluster-Nodes - das wird durch die Ausgabe von aws ec2 describe-security-groups
(sg-rule.txt) bestätigt. Die Regel ist für jedes Mount Target erforderlich: ohne sie kann
der efs.csi.aws.com-Driver den Mount Point auf API-Ebene zwar weiterhin erstellen, aber
der eigentliche Mount-Vorgang auf dem Node wird keine NFS-Verbindung zum Mount Target
aufbauen können.

Wird diese Regel entfernt, schlägt das Mounten nicht sofort mit einem expliziten Fehler
fehl: TCP-Pakete zu Port 2049 werden von der Security Group verworfen, und der Kernel auf
dem Node wartet auf die Antwort des NFS-Servers, bis das Timeout abläuft. Der Pod bleibt
in Pending/ContainerCreating, und kubectl describe pod zeigt ein FailedMount-Ereignis mit
einem Text wie "Unable to mount... connection timed out" - optisch ähnlich einem langsamen
Netzwerk statt einer expliziten Zugriffsverweigerung, und ohne Diagnose der Security Group
ist es leicht, die Ursache mit einem Problem des NFS-Servers selbst oder des Subnetzes zu
verwechseln.
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## Schnellprüfung

```bash
check_result
```
