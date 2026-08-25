[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 122 - solución de referencia (AWS Backup para EKS: composite recovery point,
restauración de namespace)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl y la CLI de aws ya
están configurados para el cluster y la región del lab. Terraform ya creó el IAM role
para AWS Backup y el backup vault (componente `eks_backup_iam`, módulo
`eks_v2_backup_iam`) - sus ARN y nombres están en el archivo de pistas
`~/lab122_hints.txt`.

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## Tarea 1. Namespace `eks-122`, carga sobre un volumen EBS y marcador

Namespace, Deployment, PVC en la clase `gp3` (el addon `aws-ebs-csi-driver` ya está
instalado por el componente `eks_addon_ebs_irsa`) y un ConfigMap con un marcador que más
adelante confirmará que el objeto restaurado vino realmente del backup:

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

`volumeBindingMode: WaitForFirstConsumer` retrasa la creación del volumen hasta que el
pod es planificado (capítulo 23) - el PVC solo pasa a `Bound` después de que el pod
`web` realmente se planifique. El marcador en el artefacto demostrará más adelante que
el ConfigMap restaurado vino del backup y no fue creado de nuevo a mano.

## Tarea 2. Opt-in de Amazon EKS en AWS Backup para la región

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

Sin este opt-in, AWS Backup no ve el cluster EKS como un recurso protegible, y
`start-backup-job` para el cluster falla (capítulo 41, sección 41.4).

## Tarea 3. Backup on-demand del cluster

El cluster ya se creó con `authentication_mode = "API_AND_CONFIG_MAP"` explícito
(módulo `eks_v2_control_plane`), así que el requisito de AWS Backup sobre el modo de
autorización ya está cumplido de antemano - el servicio creará su propia access entry en
el primer backup job.

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

El snapshot EBS del volumen `data` puede tardar más en formarse que el estado del
cluster, por eso esperamos un estado terminal y no específicamente `COMPLETED`:
`PARTIAL` (capítulo 41, sección 41.4) también significa que el backup job terminó y se
creó un recovery point, solo que puede que alguno de los puntos anidados no se haya
formado. Guardamos el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## Tarea 4. Diagnóstico del composite recovery point

`RECOVERY_POINT_ARN` de la tarea 3 es un composite recovery point: el punto padre agrupa
el child recovery point del estado del cluster y el child recovery point del volumen
`data` como una unidad consistente (capítulo 41, sección 41.4). Miremos ese punto y los
puntos anidados:

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

Guardamos la explicación de la diferencia entre puntos composite y child en el
artefacto:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
Un composite recovery point es un punto de restauración compuesto para un cluster EKS:
agrupa bajo sí varios puntos anidados (nested/child) como una unidad consistente. Para
este lab eso significa el child recovery point del estado del cluster (los manifiestos
de los objetos de Kubernetes del namespace eks-122) y el child recovery point del
volumen data (un snapshot EBS detrás del PVC).

El punto composite no tiene su propio ParentRecoveryPointArn - es el nivel superior. En
cada punto child, el campo ParentRecoveryPointArn referencia el ARN del punto composite,
y IsParent=true se marca precisamente en el composite. El child del estado del cluster
tiene un vínculo 1:1 con su padre: no se puede copiar, eliminar ni desvincular por
separado. El punto child del volumen, en cambio, sí se puede copiar, eliminar y
restaurar por separado del composite.

Por eso exactamente el composite no se puede eliminar mientras tenga puntos anidados
dentro - primero hay que eliminar o desvincular los puntos nested, y solo después el
composite mismo.
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## Tarea 5. Namespace restore (non-destructive)

Lanzamos un restore del composite recovery point, indicando el namespace `eks-122`, en
el mismo cluster (en producción):

Con `namespaceLevelRestore` solo no basta aquí. El punto composite también contiene un
snapshot EBS, y para restaurarlo AWS Backup **exige obligatoriamente una Availability
Zone** donde crear el volumen. Si no se indica, el restore job child del volumen falla
con `Restore Job failed as no restore metadata was provided`, y el padre falla con
`All PV restore jobs failed to restore`. Esto se pasa mediante el parámetro
`nestedRestoreJobs`: un mapa de `ARN del punto anidado -> sus metadatos`. La zona se
toma de un nodo existente, de lo contrario el volumen se crearía donde nadie puede
montarlo.

Fíjese en el anidamiento de la codificación: el valor de `nestedRestoreJobs` es una
cadena JSON, dentro de la cual hay un mapa, y el valor de cada elemento del mapa es a su
vez una cadena JSON. Un nivel extra de comillas produce el error
`Invalid JSON format in NestedRestoreMetadata`, por eso lo construimos con `jq` (fíjese
en el `-r` de la primera llamada - es el que quita el nivel extra):

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

Comprobamos que el Deployment `web` y el ConfigMap `marker` no se duplicaron y que el
marcador coincide con el guardado en la tarea 1 - esto demuestra el comportamiento
non-destructive del restore (capítulo 42, sección 42.2): los objetos que ya existen en
el cluster con el mismo nombre no se sobrescriben, sino que se omiten, por lo que un
restore sobre un namespace en producción no crea una segunda copia.

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

Guardamos un artefacto con la explicación:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
Un restore en AWS Backup siempre es non-destructive: los objetos de Kubernetes que ya
existen en el namespace de destino no se sobrescriben, sino que se omiten. El Deployment
web y el ConfigMap marker ya existían en eks-122 en el momento del restore con el mismo
contenido, por lo que el restore no creó duplicados de ellos ni cambió el valor del
marcador - los objetos simplemente coincidieron y fueron omitidos.
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## Tarea 6. Por qué un rollback de la versión del cluster no revierte `kubectl delete namespace`

El ejemplo motivador de la sección 41.1 del capítulo 41: un ingeniero ejecuta por error
`kubectl delete namespace prod` en el cluster equivocado, y el primer pensamiento es
"hagamos un rollback". Pero no hay nada que revertir.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
Un rollback de la versión del cluster (capítulo 39) trabaja con el control plane y su
versión de Kubernetes - no almacena ni devuelve los objetos de Kubernetes ni el
contenido de los volúmenes. Los objetos que kubectl delete namespace eliminó viven en
etcd, y en EKS etcd es managed: no hay acceso directo a él, y no se puede tomar un dump
de etcd y restaurarlo a mano como en un cluster autogestionado. Tampoco existe ningún
comando "devuélvelo a como estaba ayer" para un control plane managed.

Por eso exactamente la única forma que funciona para recuperar un namespace eliminado es
un backup del estado del cluster hecho de antemano con AWS Backup (tareas 3-4) seguido
de un restore (tarea 5), y no un rollback de la versión del control plane.
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## Verificación rápida

```bash
check_result
```
