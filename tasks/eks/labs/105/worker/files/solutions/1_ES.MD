[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - solución de referencia (secretos: KMS envelope encryption, External Secrets)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster, y terraform ya creó el secreto de Secrets Manager y el rol IRSA
para el controlador de ESO - sus nombres y ARN están en el archivo de pistas
`/home/ubuntu/lab105_hints.txt`.

```bash
cat ~/lab105_hints.txt
```

Variables del archivo de pistas para los siguientes comandos:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## Tarea 1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## Tarea 2. Capa 1: verificación del KMS envelope encryption

Desde Kubernetes 1.28, EKS cifra todos los objetos de la API (incluido `Secret`) con una
clave de AWS por defecto, sin necesidad de ninguna acción por tu parte. Comprobamos la
configuración de cifrado del clúster:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

En la salida, un elemento de la lista contiene `"resources": ["secrets"]` - esto confirma
que la capa 1 (envelope encryption de secretos en etcd) está habilitada. Si en lugar de la
AWS owned key se necesitara una customer managed key (CMK) propia, esto se hace con un
comando aparte, `aws eks associate-encryption-config` - pero se puede habilitar una CMK
propia, no se puede deshabilitar el cifrado (es una operación irreversible), así que aquí
nos quedamos con la clave por defecto de AWS.

## Tarea 3. Instalación de External Secrets Operator mediante Helm

El `role_arn` ya fue creado por terraform con una trust policy que confía exactamente en el
SA `external-secrets` del namespace `external-secrets` (capítulo 16, IRSA). Instalamos ESO
mediante Helm y vinculamos el rol de inmediato con una anotación en el ServiceAccount:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

Comprobamos que la anotación se aplicó al SA del controlador:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## Tarea 4. SecretStore y ExternalSecret

Creamos el `SecretStore` (con alcance de namespace - aislamiento por equipos, capítulo
18.5), y luego el `ExternalSecret`, que referencia el secreto de demostración de terraform:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

Esperamos la sincronización y comprobamos el `Secret` nativo:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

El valor debe coincidir con la contraseña que terraform colocó en Secrets Manager
(`S3cr3tPass123`). El `refreshInterval: 1m` se elige deliberadamente pequeño - en la tarea 6
necesitamos ver rápido la resincronización después de cambiar manualmente el secreto en AWS.

## Tarea 5. Pod con volumen: ruta de sincronización resistente

Montamos el `Secret` como volumen (volumeMount), y no mediante env - así lo recomienda el
capítulo 18.5 para valores que deben actualizarse sin recrear el pod (el propio kubelet
actualiza los archivos en el volumen cuando cambia el `Secret`):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

Leemos el valor desde el archivo en el volumen:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## Tarea 6. Pod con env: síntoma de valor obsoleto

Creamos un segundo pod, que lee el mismo `Secret`, pero mediante una variable de entorno:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Cambiamos el valor del secreto directamente en Secrets Manager (no mediante Kubernetes):

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

Esperamos el `refreshInterval` (en la tarea 4 se fijó en `1m`) más un margen, y comprobamos
que ESO resincronizó el `Secret` nativo:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

El valor en el `Secret` ya es el nuevo (`RotatedPass456`) - ESO hizo su trabajo. Ahora
miramos el pod con env, que se creó antes de la rotación:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

El pod todavía muestra el valor antiguo (`S3cr3tPass123`). El motivo: las variables de
entorno del contenedor se fijan al iniciar el proceso, por lo que la actualización del
`Secret` en etcd no las afecta - el pod debe recrearse (`kubectl rollout restart` para un
Deployment, o eliminación y creación manual para un Pod individual) para obtener el nuevo
valor mediante env. No es un bug de ESO, sino una particularidad del funcionamiento de env
en Kubernetes - a diferencia del volumen, que kubelet actualiza sin recrear el pod (tarea 5).

Registramos la observación en un artefacto:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
Después de put-secret-value en Secrets Manager y la resincronización del ExternalSecret, el
Secret nativo db-credentials en etcd se actualizó con el nuevo valor de la contraseña - ESO
funcionó correctamente.

El pod env-reader lee la contraseña mediante env (secretKeyRef), y las variables de entorno
del contenedor se fijan una sola vez al iniciar el proceso. El valor de env no se actualiza
tras cambiar el Secret sin recrear el pod - esto no es un fallo de ESO, sino una
particularidad de env en Kubernetes. El pod vol-reader (tarea 5) lee el mismo Secret
mediante volumeMount - ese volumen kubelet lo actualiza en disco automáticamente, sin
recrear el pod.

Nota breve en inglés: the env value is stale and does not update until the pod is recreated.
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## Comprobación rápida

```bash
check_result
```
