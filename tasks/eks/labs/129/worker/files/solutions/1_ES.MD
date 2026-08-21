[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 129 - solución de referencia (Mountpoint for S3: semántica de archivos y backup)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl ya está
configurado sobre el clúster. El driver `aws-mountpoint-s3-csi-driver` (provisioner
`s3.csi.aws.com`) ya está instalado como addon administrado con un rol vía IRSA
(componente `eks_addon_s3_csi_irsa`), y ya existe un bucket con versioning habilitado y un
objeto de prueba `readme.txt`, creado por terraform.

## Tarea 1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## Tarea 2. PV/PVC estático sobre un bucket real

Buscamos el nombre del bucket real:

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpoint solo soporta aprovisionamiento estático: el PV se escribe a mano y hace
referencia a un bucket que ya existe.

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

`capacity`/`requests.storage` son valores de relleno: el esquema los exige, pero Mountpoint
los ignora, el tamaño real lo determina el contenido del bucket.

## Tarea 3. Operaciones exitosas: archivo nuevo y lectura

Levantamos un pod con este PVC:

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

La imagen aquí es específicamente `busybox`, no la aplicación de otros laboratorios del
curso: en `viktoruj/ping_pong` no hay `sh` ni `cat`, y `kubectl exec` sobre ella responde
`exec: "sh": executable file not found in $PATH` (comprobado). Todo este laboratorio trata
sobre operaciones del sistema de archivos dentro del pod, así que se necesita una imagen
con shell, `mv` y `dd`. El pod solo tiene que seguir vivo, de ahí el `command` con `sleep`.

Crear un archivo nuevo es una escritura secuencial desde el principio, lo cual encaja con
el modelo `PutObject` de un objeto completo, por eso funciona:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

La lectura, incluida la del objeto existente del bucket `readme.txt`, también funciona: es
un `GetObject`:

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## Tarea 4. Síntoma: `rename` falla

Renombrar no es una operación barata en almacenamiento de objetos, y Mountpoint la rechaza
honestamente en buckets normales:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

La salida es `mv: can't rename '/data/newfile.txt': Function not implemented` (comprobado
en el stand, driver v1.15.0-eksbuild.1, busybox 1.36). Fíjate en el errno: es `ENOSYS`,
Mountpoint no implementa en absoluto la llamada al sistema `rename`. En la tarea 5 habrá un
fallo distinto: `EPERM`, `Operation not permitted` - ahí la operación está implementada
pero prohibida por la configuración del montaje. Es útil distinguirlos durante una guardia:
`ENOSYS` significa "esto no está en el driver y nunca lo estará", mientras que `EPERM`
significa "podría funcionar con otras opciones de montaje".

El archivo `newfile.txt` se queda en su lugar, y `renamed.txt` no aparece: la operación no
llegó a empezar y no dejó al bucket en un estado intermedio. Se puede verificar desde el
lado de AWS:

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## Tarea 5. Síntoma: el append y una escritura en medio del archivo fallan

Ambos casos son intentos de modificación parcial de un objeto ya existente, y un objeto de
S3 es inmutable: solo se actualiza entero, mediante un nuevo `PutObject`:

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append (echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== escritura en medio del archivo (dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== sobrescribir un archivo existente (necesita allow-overwrite) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== borrar un archivo (necesita allow-delete) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "Explicación: un objeto de S3 es inmutable. Actualizar una clave es un nuevo"
  echo "PutObject del objeto completo, así que Mountpoint no puede hacer append al final"
  echo "ni cambiar bytes en medio de un archivo ya subido - ambas operaciones fallan de"
  echo "forma explícita con Operation not permitted, en lugar de corromper los datos en"
  echo "silencio. Por la misma razón, sobrescribir y borrar están prohibidos por defecto:"
  echo "se habilitan con las mount options allow-overwrite y allow-delete, y hay que"
  echo "activarlas de forma consciente."
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

Los cuatro fallos anteriores son el mismo `EPERM`, y los cuatro se activan o desactivan con
la configuración del montaje, a diferencia del `rename` de la tarea 4. Un contraste útil:
`mkdir /data/sub` pasa EN SILENCIO y sin error, porque el directorio en S3 es virtual - no
se crea ningún objeto para él, y `aws s3api list-objects-v2` no mostrará una clave nueva.
En cambio, escribir en un prefijo anidado inexistente (`echo x > /data/sub2/nested.txt`)
falla con `nonexistent directory`: primero hace falta un `mkdir`. Esto es justo ese
"casi un sistema de archivos" del que advierte el capítulo 25.

## Tarea 6. Por qué no hay backup con AWS Backup, pero sí versioning

AWS Backup para EKS (capítulos 41-42) protege los datos mediante snapshots de volúmenes
EBS vía CSI. Un volumen Mountpoint no tiene EBS debajo en absoluto: los archivos en
`/data` son objetos de un bucket de S3, no bloques en un disco, así que el PVC `s3-pvc` no
tiene snapshot en el sentido en que sí lo tiene un volumen `gp3` (capítulo 23). Lo que
protege los datos aquí es el propio S3 - principalmente el versioning del bucket, que
terraform habilitó de antemano (`aws_s3_bucket_versioning`):

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "Explicación: el PVC s3-pvc está montado a través de Mountpoint S3 CSI, no de EBS"
  echo "CSI. Los datos ya están en S3 como objetos, no en un dispositivo de bloques, así"
  echo "que este volumen no tiene snapshot vía AWS Backup for EKS (ese mecanismo funciona"
  echo "a través de EBS VolumeSnapshot, capítulo 41). La protección contra sobrescritura o"
  echo "borrado accidental de objetos en un bucket así es el versioning (habilitado por"
  echo "terraform) y las políticas de lifecycle del propio S3, no un backup del volumen"
  echo "completo."
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## Verificación rápida

```bash
check_result
```
