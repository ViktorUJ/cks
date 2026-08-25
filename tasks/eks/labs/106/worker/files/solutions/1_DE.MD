[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - Referenzlösung (EBS CSI: gp3, Bindung an AZ, Erweiterung, Snapshot)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für den
Cluster konfiguriert. Der Driver `aws-ebs-csi-driver` (Provisioner `ebs.csi.aws.com`) ist
bereits als Managed Addon mit einer Rolle über IRSA installiert (Komponente
`eks_addon_ebs_irsa`) - die Rolle muss nicht neu erstellt werden.

## Aufgabe 1. Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## Aufgabe 2. StorageClass `gp3-immediate` (defekte Konfiguration)

Absichtlich wird `volumeBindingMode: Immediate` verwendet - genau er fängt das Volume in
einer zufälligen Zone ein:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
```

## Aufgabe 3. StatefulSet `db` auf `gp3-immediate`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-106
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3-immediate
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl get pvc -n eks-106
kubectl get po db-0 -n eks-106 -o wide
```

Der Cluster dieses Labs ist in zwei AZ (`eu-central-1a` und `eu-central-1b`) aufgesetzt. Mit
`Immediate` erstellt der Driver das Volume sofort nach dem Erscheinen des PVC, ohne
abzuwarten, wohin der Scheduler den Pod stellt, daher wird die Zone des Volumes unabhängig
davon gewählt, wo Karpenter den Node tatsächlich hochfährt. In zwei AZ tritt der Konflikt
`volume node affinity conflict` real auf, aber nicht garantiert bei jedem Durchlauf: Das
Volume kann zufällig in derselben Zone landen, in der bereits ein passender Node existiert.
Genau deshalb ist die Diagnose in Aufgabe 4 unabhängig vom Ausgang verpflichtend.

## Aufgabe 4. Diagnose: Symptom Immediate versus Bindung an die Zone

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

Wir schauen, wo der Pod tatsächlich gelandet ist und ob die Zone des Volumes mit der Zone
des Nodes übereinstimmt:

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

Wir speichern die Erklärung im Artefakt. Die Formulierung muss in beiden Fällen
funktionieren - sowohl wenn der Pod in `Pending` hängt, als auch wenn er zufällig Glück
hatte:

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
Die StorageClass gp3-immediate verwendet volumeBindingMode: Immediate. Das bedeutet, dass
der CSI-Driver ebs.csi.aws.com das EBS-Volume sofort nach dem Erscheinen des PVC erstellt,
bevor der Scheduler einen Node fuer den Pod ausgewaehlt hat. Die Zone des Volumes wird im
PV ueber spec.nodeAffinity.required.nodeSelectorTerms[].matchExpressions[].key fixiert:
topology.ebs.csi.aws.com/zone, und der Scheduler muss diese Bindung respektieren.

Wenn der Pod db-0 in Pending ist, zeigt kubectl describe pod das Ereignis
"0/N nodes are available: N node(s) had volume node affinity conflict" - das Volume wurde
in einer Zone erstellt, in der es keinen passenden Node gibt.

Wenn der Pod db-0 in Running ist, bedeutet das nicht, dass die Konfiguration korrekt ist:
Der Cluster hat nur zwei AZ (eu-central-1a, eu-central-1b), und mit Immediate ist das
Volume rein zufaellig in einer Zone gelandet, in der bereits ein Node existierte. Bei einem
anderen Durchlauf, bei einer Karpenter-Consolidation oder bei mehr AZ liefert dieselbe
StorageClass wieder einen volume node affinity conflict. Garantiert korrekt funktioniert
nur WaitForFirstConsumer, bei dem die Zone des Volumes immer gleich der Zone des bereits
gewaehlten Nodes ist - das ist Aufgabe 5.
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## Aufgabe 5. Behebung: StorageClass `gp3` mit `WaitForFirstConsumer`

Ein PVC bindet sich einmalig an seine StorageClass, die Klasse eines bestehenden PVC lässt
sich nicht ändern, daher behebt man das Problem nicht mit einem Patch auf `gp3-immediate`,
sondern mit einer neuen Klasse und einem neuen StatefulSet:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-fixed
  namespace: eks-106
spec:
  serviceName: db-fixed
  replicas: 1
  selector:
    matchLabels:
      app: db-fixed
  template:
    metadata:
      labels:
        app: db-fixed
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl rollout status statefulset/db-fixed -n eks-106
```

Mit `WaitForFirstConsumer` wird das Provisioning des Volumes verzögert, bis der Scheduler
einen Node für `db-fixed-0` ausgewählt hat. Erst danach erstellt der Driver das Volume in
der Zone dieses Nodes, und der `nodeAffinity`-Konflikt wird konstruktionsbedingt
unmöglich. Wir prüfen, dass die Zone des Volumes mit der Zone des Nodes übereinstimmt:

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

Die Werte `node_zone` und `pv_zone` müssen übereinstimmen - das ist das Zeichen für
korrekte, nicht zufällige Funktionsweise. Zusätzlich lässt sich die Menge der Zonen
explizit über `allowedTopologies` in der StorageClass einschränken (Schlüssel
`topology.ebs.csi.aws.com/zone`), falls eine bestimmte AZ vom Volume-Provisioning
ausgeschlossen werden soll.

## Aufgabe 6. Erweiterung des Volumes `data-db-fixed-0` von 5Gi auf 10Gi

`allowVolumeExpansion: true` in `gp3` erlaubt die Erweiterung im laufenden Betrieb, ohne
den Pod neu zu erstellen:

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# warten, bis der CSI-Driver die Modifikation des Volumes und des Dateisystems abschliesst
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

Ein Volume verkleinern geht nicht - nur vergrößern, und nicht öfter, als es das Limit für
EBS-Modifikationen erlaubt.

## Aufgabe 7. Snapshot des Volumes und Wiederherstellung (Best Effort)

Der Snapshot funktioniert über drei Objekte: `VolumeSnapshotClass`, `VolumeSnapshot` und
den automatisch erstellten `VolumeSnapshotContent`. Der Snapshot-Controller und die CRDs im
Cluster sind bereits über das Managed Addon `snapshot-controller` installiert (Komponente
`eks_addons`):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snap
  namespace: eks-106
spec:
  volumeSnapshotClassName: ebs-snapclass
  source:
    persistentVolumeClaimName: data-db-fixed-0
EOF

kubectl get volumesnapshot db-snap -n eks-106
```

Wir warten, bis der Snapshot bereit ist (`readyToUse: true`), und stellen ihn in einem neuen
PVC wieder her. Der EBS-Snapshot ist ein regionales Objekt, aber das daraus
wiederhergestellte Volume ist wieder zonal, daher ist auch hier eine Klasse mit
`WaitForFirstConsumer` erforderlich:

```bash
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/db-snap -n eks-106 --timeout=180s

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-restored
  namespace: eks-106
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  dataSource:
    kind: VolumeSnapshot
    name: db-snap
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 10Gi
EOF

kubectl get pvc data-restored -n eks-106
```

`data-restored` bleibt in `Pending`, bis ein Pod darauf zugreift (Klasse `gp3` -
`WaitForFirstConsumer`), das ist erwartet: Das Provisioning des wiederhergestellten Volumes
wird ebenfalls bis zur Planung verzögert. Falls im Cluster aus irgendeinem Grund kein
Snapshot-Controller oder keine CRD vorhanden ist, blockiert diese Aufgabe nicht das übrige
Lab - es ist ein separater, nicht verpflichtender Prüfschritt.

## Schnelle Prüfung

```bash
check_result
```
