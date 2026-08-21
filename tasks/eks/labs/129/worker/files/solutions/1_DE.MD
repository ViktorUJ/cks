[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 129 - Musterlösung (Mountpoint for S3: Dateisemantik und Backup)

Alle Befehle laufen auf der Worker-Maschine per SSH. kubectl ist dort bereits auf dem
Cluster konfiguriert. Der Driver `aws-mountpoint-s3-csi-driver` (Provisioner
`s3.csi.aws.com`) ist bereits als verwalteter Addon mit einer Rolle via IRSA installiert
(Komponente `eks_addon_s3_csi_irsa`), und ein Bucket mit aktiviertem Versioning und einem
Testobjekt `readme.txt` wurde bereits von terraform erstellt.

## Aufgabe 1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## Aufgabe 2. Statisches PV/PVC auf einem echten Bucket

Wir suchen den Namen des echten Buckets:

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpoint unterstützt nur statisches Provisioning: das PV wird händisch geschrieben und
verweist auf einen bereits existierenden Bucket.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  claimRef:
    namespace: eks-129
    name: s3-pvc
  mountOptions:
    - region eu-central-1
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-demo-volume
    volumeAttributes:
      bucketName: $BUCKET
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
  namespace: eks-129
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  resources:
    requests:
      storage: 1200Gi
  volumeName: s3-pv
EOF

kubectl get pv s3-pv
kubectl get pvc s3-pvc -n eks-129
```

`capacity`/`requests.storage` sind Platzhalterwerte - das Schema verlangt sie, aber
Mountpoint ignoriert sie: die tatsächliche Größe wird durch den Inhalt des Buckets
bestimmt.

## Aufgabe 3. Erfolgreiche Operationen: neue Datei und Lesen

Wir starten einen Pod mit diesem PVC:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mountpoint-app
  namespace: eks-129
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mountpoint-app
  template:
    metadata:
      labels:
        app: mountpoint-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        volumeMounts:
        - name: s3
          mountPath: /data
      volumes:
      - name: s3
        persistentVolumeClaim:
          claimName: s3-pvc
EOF

kubectl rollout status deployment/mountpoint-app -n eks-129
POD=$(kubectl get po -n eks-129 -l app=mountpoint-app -o jsonpath='{.items[0].metadata.name}')
```

Das Image hier ist gezielt `busybox` und nicht die Anwendung aus anderen Kurslabs: in
`viktoruj/ping_pong` gibt es weder `sh` noch `cat`, und `kubectl exec` darin antwortet mit
`exec: "sh": executable file not found in $PATH` (geprüft). Dieses ganze Lab dreht sich um
Dateisystemoperationen innerhalb des Pods, daher braucht es ein Image mit Shell, `mv` und
`dd`. Der Pod muss nur am Leben bleiben, daher das `command` mit `sleep`.

Das Erstellen einer neuen Datei ist ein sequentielles Schreiben von Anfang an, was zum
`PutObject`-Modell eines ganzen Objekts passt, deshalb funktioniert es:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

Das Lesen, auch das vorhandenen Bucket-Objekts `readme.txt`, funktioniert ebenfalls - das
ist ein `GetObject`:

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## Aufgabe 4. Symptom: `rename` schlägt fehl

Umbenennen ist auf Objektspeicher keine billige Operation, und Mountpoint lehnt sie auf
normalen Buckets ehrlich ab:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

Die Ausgabe ist `mv: can't rename '/data/newfile.txt': Function not implemented` (auf dem
Stand geprüft, Driver v1.15.0-eksbuild.1, busybox 1.36). Achten Sie auf die errno: das ist
`ENOSYS`, Mountpoint implementiert den Systemaufruf `rename` überhaupt nicht. In Aufgabe 5
gibt es einen anderen Fehlertyp - `EPERM`, `Operation not permitted`: dort ist die
Operation implementiert, aber durch Mount-Einstellungen verboten. Im Ernstfall ist es
nützlich, das zu unterscheiden: `ENOSYS` bedeutet "das gibt es im Driver nicht und wird es
nie geben", während `EPERM` bedeutet "könnte mit anderen Mount-Optionen funktionieren".

Die Datei `newfile.txt` bleibt dabei an ihrem Platz, und `renamed.txt` erscheint nicht: die
Operation hat nicht begonnen und den Bucket nicht in einen Zwischenzustand gebracht. Das
lässt sich von der AWS-Seite prüfen:

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## Aufgabe 5. Symptom: Append und Schreiben in die Mitte schlagen fehl

Beide Fälle sind Versuche einer teilweisen Änderung eines bereits existierenden Objekts,
und ein S3-Objekt ist unveränderlich - es wird nur als Ganzes aktualisiert, über ein neues
`PutObject`:

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append (echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== Schreiben in die Mitte der Datei (dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== Überschreiben einer vorhandenen Datei (braucht allow-overwrite) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== Löschen einer Datei (braucht allow-delete) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "Erklärung: ein S3-Objekt ist unveränderlich. Das Aktualisieren eines Schlüssels"
  echo "ist ein neues PutObject des gesamten Objekts, deshalb kann Mountpoint nicht an das"
  echo "Ende anhängen (append) oder Bytes in der Mitte einer bereits hochgeladenen Datei"
  echo "ändern - beide Operationen schlagen explizit mit Operation not permitted fehl,"
  echo "statt die Daten still zu beschädigen. Aus dem gleichen Grund sind Überschreiben"
  echo "und Löschen standardmäßig verboten: sie werden über die Mount-Optionen"
  echo "allow-overwrite und allow-delete aktiviert, und das sollte bewusst geschehen."
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

Die vier obigen Fehler sind alle dasselbe `EPERM`, und alle vier lassen sich über
Mount-Einstellungen ein- oder ausschalten, im Gegensatz zum `rename` aus Aufgabe 4. Ein
nützlicher Kontrast: `mkdir /data/sub` geht STILLSCHWEIGEND und ohne Fehler durch, weil ein
Verzeichnis in S3 virtuell ist - dafür wird kein Objekt erstellt, und
`aws s3api list-objects-v2` zeigt keinen neuen Key. Das Schreiben in ein nicht
existierendes verschachteltes Präfix (`echo x > /data/sub2/nested.txt`) schlägt dagegen mit
`nonexistent directory` fehl: zuerst braucht man ein `mkdir`. Das ist genau das "fast ein
Dateisystem", vor dem Kapitel 25 warnt.

## Aufgabe 6. Warum es kein Backup über AWS Backup gibt, aber Versioning

AWS Backup für EKS (Kapitel 41-42) schützt Daten über CSI-Snapshots von EBS-Volumes. Ein
Mountpoint-Volume hat überhaupt kein EBS unter der Haube: die Dateien in `/data` sind
Objekte in einem S3-Bucket, keine Blöcke auf einer Festplatte, daher hat der PVC `s3-pvc`
keinen Snapshot in dem Sinne, wie ein `gp3`-Volume einen hat (Kapitel 23). Was die Daten
hier schützt, ist S3 selbst - vor allem das Versioning des Buckets, das terraform im
Voraus aktiviert hat (`aws_s3_bucket_versioning`):

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "Erklärung: der PVC s3-pvc ist über Mountpoint S3 CSI gemountet, nicht über EBS"
  echo "CSI. Die Daten liegen bereits als Objekte in S3, nicht auf einem Blockgerät,"
  echo "daher hat dieses Volume keinen Snapshot über AWS Backup for EKS (dieser"
  echo "Mechanismus funktioniert über EBS VolumeSnapshot, Kapitel 41). Der Schutz gegen"
  echo "versehentliches Überschreiben oder Löschen von Objekten auf so einem Bucket ist"
  echo "das Versioning (von terraform aktiviert) und die Lifecycle-Richtlinien von S3"
  echo "selbst, kein Backup des gesamten Volumes."
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## Schnelle Prüfung

```bash
check_result
```
