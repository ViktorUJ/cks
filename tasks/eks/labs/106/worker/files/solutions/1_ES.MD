[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - solución de referencia (EBS CSI: gp3, vinculación a AZ, expansión, snapshot)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster. El driver `aws-ebs-csi-driver` (provisioner `ebs.csi.aws.com`)
ya está instalado como managed addon con un rol mediante IRSA (componente
`eks_addon_ebs_irsa`) - no hace falta crear el rol de nuevo.

## Tarea 1. Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## Tarea 2. StorageClass `gp3-immediate` (configuración rota)

Elegimos deliberadamente `volumeBindingMode: Immediate` - es justo el que atrapa el volumen
en una zona aleatoria:

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

## Tarea 3. StatefulSet `db` sobre `gp3-immediate`

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

El clúster del laboratorio está levantado en dos AZ (`eu-central-1a` y `eu-central-1b`). Con
`Immediate` el driver crea el volumen justo después de que aparece el PVC, sin esperar a
dónde el planificador colocará el pod, así que la zona del volumen se elige de forma
independiente a dónde Karpenter realmente levante el nodo. En dos AZ el conflicto
`volume node affinity conflict` surge de verdad, pero no está garantizado en cada ejecución:
el volumen puede caer por azar en la misma zona donde ya hay un nodo adecuado. Por eso en la
tarea 4 el diagnóstico es obligatorio sin importar el resultado.

## Tarea 4. Diagnóstico: el síntoma de Immediate frente a la vinculación a la zona

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

Comprobamos dónde acabó realmente el pod y si la zona del volumen coincide con la zona del
nodo:

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

Guardamos la explicación como artefacto. La formulación debe ser válida en ambos casos - ya
sea que el pod se haya quedado colgado en `Pending`, o que haya tenido suerte:

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
El StorageClass gp3-immediate usa volumeBindingMode: Immediate. Esto significa que el driver
CSI ebs.csi.aws.com crea el volumen EBS justo después de que aparece el PVC, antes de que el
planificador haya elegido un nodo para el pod. La zona del volumen queda fijada en el PV
mediante spec.nodeAffinity.required.nodeSelectorTerms[].matchExpressions[].key:
topology.ebs.csi.aws.com/zone, y el planificador está obligado a respetar esa vinculación.

Si el pod db-0 está en Pending, kubectl describe pod muestra el evento
"0/N nodes are available: N node(s) had volume node affinity conflict" - el volumen se creó
en una zona donde no hay ningún nodo adecuado.

Si el pod db-0 está en Running, eso no significa que la configuración sea correcta: en el
clúster solo hay dos AZ (eu-central-1a, eu-central-1b), y con Immediate el volumen cayó por
azar en una zona donde ya había un nodo. En otra ejecución, con una consolidación de
Karpenter o al escalar a más AZ, el mismo StorageClass volvería a producir un volume node
affinity conflict. Lo único que funciona de forma garantizada es WaitForFirstConsumer, donde
la zona del volumen siempre es igual a la zona del nodo ya elegido - eso es la tarea 5.
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## Tarea 5. Corrección: StorageClass `gp3` con `WaitForFirstConsumer`

El PVC se vincula a su StorageClass una sola vez, no se puede cambiar la clase en un PVC
existente, así que la corrección no se hace con un patch sobre `gp3-immediate`, sino con una
clase nueva y un StatefulSet nuevo:

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

Con `WaitForFirstConsumer` el aprovisionamiento del volumen se posterga hasta que el
planificador elige un nodo para `db-fixed-0`. Solo después de eso el driver crea el volumen
en la zona de ese nodo, y el conflicto de `nodeAffinity` se vuelve imposible por
construcción. Comprobamos que la zona del volumen coincide con la zona del nodo:

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

Los valores `node_zone` y `pv_zone` deben coincidir - esa es la señal de que funciona de
forma correcta, y no por azar. Además, se puede restringir explícitamente el conjunto de
zonas mediante `allowedTopologies` en el StorageClass (clave
`topology.ebs.csi.aws.com/zone`), si es necesario excluir una AZ concreta del
aprovisionamiento de volúmenes.

## Tarea 6. Expansión del volumen `data-db-fixed-0` de 5Gi a 10Gi

`allowVolumeExpansion: true` en `gp3` permite la expansión en caliente, sin recrear el pod:

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# esperamos a que el driver CSI termine de modificar el volumen y el sistema de archivos
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

No se puede reducir el volumen - solo aumentarlo, y no con más frecuencia de la que permite
el límite de modificaciones de EBS.

## Tarea 7. Snapshot del volumen y restauración (best effort)

El snapshot funciona mediante tres objetos: `VolumeSnapshotClass`, `VolumeSnapshot` y el
`VolumeSnapshotContent` creado automáticamente. El snapshot-controller y las CRD ya están
instalados en el clúster como managed addon `snapshot-controller` (componente
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

Esperamos a que el snapshot esté listo (`readyToUse: true`), y lo restauramos en un nuevo
PVC. El snapshot de EBS es un objeto regional, pero el volumen restaurado a partir de él
vuelve a ser zonal, así que aquí también hace falta la clase con `WaitForFirstConsumer`:

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

`data-restored` se quedará en `Pending` hasta que un pod lo reclame (la clase `gp3` es
`WaitForFirstConsumer`), y eso es lo esperado: el aprovisionamiento del volumen restaurado
también se posterga hasta la planificación. Si por algún motivo en el clúster no hay
snapshot-controller ni CRD, esta tarea en sí no bloquea el resto del laboratorio - es un
paso de verificación adicional y opcional.

## Verificación rápida

```bash
check_result
```
