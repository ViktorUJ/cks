[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 104 - solución de referencia (workload identity: IRSA y Pod Identity)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el clúster, y terraform ya creó el bucket de S3, el secreto de Secrets Manager y
ambos roles IAM - sus nombres y ARN están en el archivo de pistas
`/home/ubuntu/lab104_hints.txt`.

```bash
cat ~/lab104_hints.txt
```

A continuación, los ejemplos usan variables de ese archivo - sustituye tus propios
valores o expórtalas al principio de la sesión:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## Tarea 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## Tarea 2. ServiceAccount con una anotación IRSA

El rol `irsa_role_arn` ya fue creado por terraform con una trust policy que confía
exactamente en este `ServiceAccount` (`system:serviceaccount:eks-104:s3-reader-irsa` -
capítulo 16). Creamos el SA con la anotación:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## Tarea 3. Pod con IRSA: verificación de identidad

Creamos un pod que usa este SA. El Pod Identity Webhook inyectará las variables
`AWS_ROLE_ARN` y `AWS_WEB_IDENTITY_TOKEN_FILE` (capítulo 16) al arrancar el pod:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

Comprobamos que el SDK dentro del pod obtuvo las credenciales mediante web identity, y no
el rol de la nodo:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

En la salida, `Arn` debe tener la forma
`arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...` - esto demuestra que el pod
actúa bajo el rol IRSA, y no bajo el rol de la nodo.

## Tarea 4. Lectura de un objeto de S3 mediante IRSA

El rol `irsa` lleva únicamente `s3:ListBucket` y `s3:GetObject` sobre este bucket concreto
(capítulo 16, principio de mínimo privilegio). Leemos el objeto que terraform colocó en el
bucket:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

El archivo debe contener la línea `hello from s3` - el contenido del objeto colocado por
el módulo `eks_v2_workload_identity_demo`.

## Tarea 5. Asociación de Pod Identity

A diferencia de IRSA, para Pod Identity no se necesita anotación en el SA - el vínculo
`namespace + SA -> rol` vive en la API de EKS, no en Kubernetes (capítulo 17). Creamos el
SA y la asociación:

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## Tarea 6. Pod con Pod Identity: secreto en lugar del rol de la nodo

Creamos un pod con el SA `secret-reader-podid`. El agente `eks-pod-identity-agent` (ya
instalado como managed addon en este laboratorio) le entregará las credenciales del rol
`pod_identity_role_arn` a través del endpoint local `169.254.170.23` (capítulo 17):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

Leemos el secreto y verificamos la identidad con un solo comando:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

El `Arn` de `get-caller-identity` mostrará `assumed-role/<prefix>-pod-identity-role/...`, y
el valor del secreto será un JSON con los campos `username`/`password`
(`demo`/`demo123`) que terraform colocó en Secrets Manager.

## Tarea 7. Síntoma: el rol de la nodo no tiene acceso al bucket

Creamos un pod **sin** vínculo a IRSA ni a Pod Identity - heredará solo los permisos del
rol de la nodo (capítulo 16, sección 16.1: «dieron un rol a la nodo y los permisos se
filtraron a todos los pods» funciona también en sentido inverso, el rol de la nodo no
lleva ningún permiso de aplicación):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

El comando debe terminar con el error `AccessDenied` (o `is not authorized to perform`) -
el rol de la nodo no lleva `s3:*` sobre este bucket, solo tiene los permisos de los
componentes de sistema (pull desde ECR, funcionamiento del CNI). Esto muestra claramente
la diferencia: sin IRSA ni Pod Identity, el pod obtiene solo lo que tiene el rol de la
nodo, y no «todo lo que esté configurado en algún lugar de la cuenta».

## Verificación rápida

```bash
check_result
```
