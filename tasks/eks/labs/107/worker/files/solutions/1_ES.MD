[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - solución de referencia (EFS CSI: ReadWriteMany entre AZ)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el clúster. El driver `aws-efs-csi-driver` (provisioner `efs.csi.aws.com`) ya está
instalado como addon gestionado con un rol mediante IRSA (componente
`eks_addon_efs_irsa`), el sistema de archivos EFS y el mount target en cada AZ ya están
creados por terraform - no es necesario crearlos de nuevo.

## Tarea 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## Tarea 2. StorageClass `efs-sc` apuntando al `fileSystemId` real

El sistema de archivos fue creado previamente por terraform, el driver solo trabaja sobre
él. Encontramos su ID mediante AWS CLI (la etiqueta `Name` se construye a partir del
`prefix` del laboratorio):

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

`provisioningMode: efs-ap` significa aprovisionamiento dinámico: para cada PVC el driver
crea un access point independiente dentro de este sistema de archivos, en lugar de
entregar el sistema de archivos completo.

## Tarea 3. PVC `shared-data` (`ReadWriteMany`, `5Gi`)

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

EFS es un sistema regional, así que el PVC pasa a `Bound` independientemente de en qué
zona acaben aterrizando los pods más adelante: el mount target es accesible desde
cualquier AZ donde esté creado.

## Tarea 4. Deployment `writer` (3 réplicas, distintas AZ, PVC compartido)

`topologySpreadConstraints` en la clave `topology.kubernetes.io/zone` hace que el
scheduler distribuya las réplicas entre distintas zonas:

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

Comprueba que las réplicas aterrizaron en distintas AZ:

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

Las 3 réplicas están `Running` al mismo tiempo y montan el mismo PVC `shared-data`, aunque
estén en distintas AZ. Con EBS esto es imposible (`ReadWriteOnce`, error
`Multi-Attach error`), porque EBS es un volumen de bloques zonal, mientras que EFS es un
sistema NFS regional con un mount target en cada zona.

## Tarea 5. Acceso compartido: escribir desde una réplica, leer desde otra

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

La línea escrita por el pod `$WRITER_POD` en una AZ es leída por el pod `$READER_POD` en
otra AZ - esto confirma que realmente es un volumen de red compartido sobre NFS, no una
copia local en el disco del nodo.

## Tarea 6. Comprobación de la ausencia de un `nodeAffinity` zonal

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
El PV creado por efs.csi.aws.com no tiene sección spec.nodeAffinity (a diferencia de EBS,
capítulo 23, donde nodeAffinity fija una AZ concreta mediante la clave
topology.ebs.csi.aws.com/zone). La razón es que EFS es un sistema de archivos regional con
un mount target en cada AZ, así que un pod que usa este volumen puede recrearse en
cualquier otra zona del clúster y seguirá viendo los mismos datos a través del mount
target de su nueva zona. El scheduler no necesita fijar el pod a un nodo o zona concretos
por culpa del volumen, como sí ocurre con EBS.
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

El comando `grep -A3 nodeAffinity` no encuentra nada (salida vacía, código de salida `1`) -
eso es la confirmación de que la sección está ausente. Compara con el `pv.yaml` del
laboratorio 106 (EBS), donde `spec.nodeAffinity.required.nodeSelectorTerms` fija
rígidamente la zona del volumen.

## Tarea 7. Diagnóstico: SG del mount target y puerto 2049 (solo lectura)

Romper infraestructura real es arriesgado, así que esta tarea solo confirma el estado
actual mediante AWS CLI y explica las consecuencias de que falte la regla.

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

Comprueba que la salida tiene una regla `FromPort/ToPort: 2049`, `IpProtocol: tcp`, y que
el origen (`UserIdGroupPairs`) es el security group de los nodos del clúster, no un CIDR.
Guarda el diagnóstico de causas y efectos:

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
El security group del mount target permite entrada TCP 2049 (NFS) desde el security group
de los nodos del clúster - esto lo confirma la salida de aws ec2 describe-security-groups
(sg-rule.txt). La regla es obligatoria para cada mount target: sin ella, el driver
efs.csi.aws.com todavía puede crear el punto de montaje a nivel de API, pero el proceso de
montaje real en el nodo no podrá establecer una conexión NFS con el mount target.

Si se elimina esta regla, el montaje no fallará de inmediato con un error explícito: los
paquetes TCP hacia el puerto 2049 serán descartados por el security group, y el kernel del
nodo esperará la respuesta del servidor NFS hasta que expire el timeout. El pod se quedará
en Pending/ContainerCreating, y kubectl describe pod mostrará un evento FailedMount con un
texto como "Unable to mount... connection timed out" - visualmente parecido a una red
lenta en lugar de una denegación de acceso explícita, y sin diagnosticar el security group
es fácil confundir la causa con un problema del propio servidor NFS o de la subred.
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## Comprobación rápida

```bash
check_result
```
