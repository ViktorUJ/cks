[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 121 - solución de referencia (solución de problemas de acceso: access entries, IRSA, kubeconfig)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster, y terraform ya ha creado el bucket de S3 y el rol IRSA del componente
`eks_irsa_break_demo` - sus nombres y ARNs están en el archivo de pistas
`/home/ubuntu/lab121_hints.txt`.

```bash
cat ~/lab121_hints.txt
```

El resto de la solución usa variables de ese archivo:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

El lab cubre dos ejes de acceso independientes del capítulo 47: un humano/CI no puede entrar
al cluster (tareas 1-4), y un pod recibe `AccessDenied` en AWS (tareas 5-8).

## Tarea 1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## Tarea 2. Síntoma Unauthorized: un rol sin access entry

Creamos un rol IAM de prueba sin ningún access entry. El rol del worker solo permite
administrar roles con `-test-` en el nombre (ver `iam.tf` del módulo `eks_v2_work_pc`), así
que el nombre debe contener esa subcadena:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

El rol del worker lleva `sts:AssumeRole` específicamente para ARNs con `-test-` en el
nombre, así que podemos asumir este rol directamente:

Aquí el orden importa. Construimos el kubeconfig separado **con las credenciales del
worker, antes de** `assume-role`: `aws eks update-kubeconfig` llama a
`eks:DescribeCluster`, y el rol de prueba no tiene ninguna política IAM, así que bajo ese
rol el comando fallaría con `AccessDeniedException` y el archivo no se crearía. Este es, de
paso, el tercer tipo de fallo en esta cadena: `AccessDenied` desde IAM (sin permiso para la
API de AWS) es distinto tanto de `Unauthorized` (la identidad no está mapeada en el
cluster) como de `Forbidden` (RBAC). `kubectl` en sí obtiene entonces un token vía
`aws eks get-token`, y ese token vendrá de la identidad cuyas credenciales estén en las
variables de entorno:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

Comprobamos el acceso de esta identidad al cluster - sin ningún access entry no está
mapeada, así que esperamos `Unauthorized` (capítulo 47, sección 47.3):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

El archivo debería contener una línea con la palabra `Unauthorized` - el API server no pudo
hacer coincidir esta identidad IAM con ningún access entry ni registro de aws-auth.

Restauramos las credenciales del worker (las variables de sesión ya no son necesarias):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Tarea 3. Arreglando Unauthorized: access entry + AmazonEKSViewPolicy

Creamos un access entry para el rol de prueba y le otorgamos la política de acceso
`AmazonEKSViewPolicy` en el ámbito del cluster (capítulo 47, sección 47.4):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

Repetimos `assume-role` (la primera sesión ya caducó o terminó) y la misma solicitud con el
mismo kubeconfig temporal - ahora debería devolver la lista de pods, no `Unauthorized`:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

Ahora el archivo tiene líneas como `NAMESPACE ... POD ...` - el access entry eliminó el
error `Unauthorized`.

## Tarea 4. Síntoma Forbidden: el acceso de View no permite escribir

El rol solo tiene `AmazonEKSViewPolicy` (lectura). Intentamos crear un namespace con el
mismo kubeconfig temporal - RBAC debería denegarlo con `Forbidden` (capítulo 47, sección
47.3):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

Añadimos al mismo archivo una explicación de la diferencia entre la tarea 2
(`Unauthorized`) y la tarea 4 (`Forbidden`):

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

Difference: in task 2 the role wasn't mapped into the cluster at all - the API server
couldn't prove the identity, that's Unauthorized (an authentication failure, the authn
layer). In task 4 the identity is already proven and mapped via an access entry, but RBAC
(AmazonEKSViewPolicy only grants read) doesn't allow create namespace - that's Forbidden
(an authorization failure, the authz layer). The fixes differ: Unauthorized is fixed in the
mapping (access entry / aws-auth), Forbidden is fixed in RBAC (Role, ClusterRole, policy
binding).
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Tarea 5. Un ServiceAccount con la anotación IRSA correcta

El rol `eks_irsa_break_demo` ya fue creado por terraform con una trust policy que confía
exactamente en `system:serviceaccount:eks-121:demo-reader` (capítulo 16, capítulo 47
sección 47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

Comprobamos la identidad y leemos el objeto desde S3:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

`Arn` en la salida debería parecerse a `assumed-role/<prefix>-irsa-role/...`, y el segundo
bloque debería ser la línea `hello from s3` (el objeto que terraform colocó ahí).

## Tarea 6. Síntoma AccessDenied: una anotación rota en otro namespace

Creamos una segunda SA con la MISMA anotación sobre el mismo rol, pero en el namespace
`default`. La trust policy del rol espera
`sub = system:serviceaccount:eks-121:demo-reader`, mientras que el `sub` de esta SA será
`system:serviceaccount:default:demo-reader-broken` - la condición no coincidirá (capítulo
47, sección 47.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

El comando debería fallar con un error de intercambio de token: `AccessDenied` o
`WebIdentityErr` (el mensaje exacto varía según la versión del SDK/CLI, pero el punto es el
mismo - STS rechazó `sts:AssumeRoleWithWebIdentity` porque el `sub` en el token no coincidía
con la condición de la trust policy).

## Tarea 7. Diagnóstico: comparando anotaciones y la causa raíz del `sub`

Comparamos la anotación de la SA en ambos namespaces y explicamos la causa:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
Both annotations point at the same IRSA role, but the role's trust policy checks the sub
condition on the STS token: system:serviceaccount:<namespace>:<serviceaccount>. For
demo-reader that's system:serviceaccount:eks-121:demo-reader - it matches the role's
condition, so the exchange is allowed. For demo-reader-broken the token carries
sub=system:serviceaccount:default:demo-reader-broken - a different namespace and a
different SA name, so the StringEquals condition doesn't match, and
sts:AssumeRoleWithWebIdentity is rejected regardless of the fact that the role ARN in the
annotation is the same.
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## Tarea 8. Resumen: los dos ejes de acceso

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
The human axis (tasks 2-4) lives in the chain kubectl - IAM - EKS authenticator - RBAC:
Unauthorized means the IAM identity couldn't be proven or mapped into the cluster at all
(fixed via an access entry or aws-auth), while Forbidden means the identity is already
known, but RBAC didn't allow that specific action (fixed via Role/ClusterRoleBinding). The
pod axis (tasks 5-7) lives in the chain pod - ServiceAccount - STS - IAM role: AccessDenied
or WebIdentityErr means the role's trust policy didn't match the ServiceAccount token's sub
(fixed by editing the sub condition in the trust policy or the SA annotation). The key
difference: on the first axis the fix is RBAC inside the cluster, on the second axis the fix
is the IAM role's trust policy in AWS, and the two must not be confused.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Verificación rápida

```bash
check_result
```
