[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 - solución de referencia (acceso al clúster: IAM, RBAC, access entries)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster. El rol worker tiene `eks:*` (suficiente para todos los
comandos de access entry/access policy) y permisos puntuales
`iam:CreateRole/GetRole/DeleteRole/PutRolePolicy` más `sts:AssumeRole`, limitados a roles
con un nombre del tipo `*-test-*` - esto es suficiente para crear el rol de prueba y
realmente hacer assume-role sobre él, sin tocar los permisos de otros laboratorios.

## Elección del segundo principal

El clúster ya se crea con el módulo `eks_v2_control_plane` en modo
`authenticationMode = API` (v21 de `terraform-aws-modules/eks/aws` con
`enable_cluster_creator_admin_permissions = true`). El rol worker ya tiene su propia access
entry con `AmazonEKSClusterAdminPolicy` (`terraform/modules/eks_v2_work_pc/iam.tf`) - esto
confirma que las access entries de la API están habilitadas y funcionando en el clúster.

Para las tareas de este laboratorio se necesita un **segundo** principal de IAM, que
todavía no tenga acceso al clúster. El rol del nodo de Karpenter no sirve para esto: el
submódulo `terraform-aws-modules/eks/aws//modules/karpenter` crea automáticamente para él
una access entry de tipo `EC2_LINUX` (`create_access_entry = true` por defecto), y un mismo
principal de IAM no puede estar en dos access entries a la vez. Por eso el laboratorio crea
un rol de prueba independiente mediante la AWS CLI directamente desde worker, con confianza
únicamente hacia el propio rol worker (`sts:AssumeRole` permitido exclusivamente al ARN del
rol worker, a nadie más).

## Tarea 1. Inventario: authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

La salida esperada se parece a:

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` es igual a `API` - en el clúster no hay ConfigMap `aws-auth`, todos los
mapeos de principales pasan por access entries.

## Tarea 2. Rol IAM de prueba como segundo principal

Averiguamos el ARN y el account id del rol worker (a él le permitiremos assumir el rol de
prueba):

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

`get-caller-identity` para una instancia con perfil de EC2 muestra el ARN de la **sesión**
(`assumed-role/.../i-...`), no el ARN del propio rol. Para la trust policy y la access entry
se necesita el ARN del rol, así que lo reconstruimos a partir de la sesión:

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

Creamos el rol de prueba. El nombre debe contener obligatoriamente `-test-`, de lo
contrario worker no podrá ni crearlo ni assumirlo (su política de IAM está limitada por esa
subcadena):

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

El rol no necesita ningún permiso de IAM interno más allá del assume - todos sus permisos
reales los define el clúster mediante la access entry y la access policy/RBAC, no IAM.

## Tarea 3. Access entry para el rol de prueba, grupo viewers

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

No indicamos `username` - EKS lo asignará automáticamente, tal como recomienda la
documentación. Ahora el clúster conoce al principal y este entra en el grupo de Kubernetes
`viewers`, pero todavía sin ningún permiso: la entrada por sí sola no otorga permisos, solo
proporciona el sujeto para RBAC.

## Tarea 4. ClusterRole y ClusterRoleBinding sobre el grupo viewers

RBAC clásico encima de la access entry, sin access policy:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

El grupo `viewers` ahora puede leer pods en todos los namespaces, y nada más.

## Tarea 5. Comprobación manual de permisos mediante assume-role

Este es un paso que el estudiante ejecuta manualmente - el autotest solo verifica el
artefacto con el resultado, no el propio assume-role (no se necesitan credenciales
temporales dentro de `tests.bats`).

Obtenemos credenciales temporales del rol de prueba y un kubeconfig aparte con alias:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

Resultado esperado: `get pods -A` funciona (RBAC solo permite lectura mediante el binding
sobre el grupo `viewers`), y `create namespace test` falla con `Forbidden` - el RBAC del
grupo `viewers` no contiene permisos sobre `namespaces`. Volvemos a los permisos de worker:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

Guardamos el resultado de la comprobación manual en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> funcionó: el binding RBAC viewers-pod-reader otorga get/list sobre pods.

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden: el grupo viewers no tiene permisos para crear namespaces,
     la access entry dio el sujeto, pero RBAC no permitió esta acción.
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## Tarea 6. Access policy AmazonEKSViewPolicy sobre la access entry

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

Ahora el rol de prueba tiene dos fuentes de permisos independientes: el grupo RBAC
`viewers` (get/list de pods) y la access policy `AmazonEKSViewPolicy` (lectura de la
mayoría de los recursos del clúster, sin secretos). Ten en cuenta:
`kubectl --kubeconfig /tmp/test-viewer.kubeconfig auth can-i --list` no mostrará los
permisos de la access policy - no está expresada mediante objetos RBAC, la única forma de
verla es `list-associated-access-policies`.

## Tarea 7. Diagnóstico: Unauthorized frente a Forbidden

Mostramos la diferencia con comandos reales. Creamos otro rol **sin** access entry - será
desconocido para el clúster:

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

Comparamos con el intento de crear un namespace con el mismo rol de prueba de la tarea 5
(`test-viewer.kubeconfig`) - ahí el clúster conoce al principal, pero RBAC no permite la
acción, es decir, `Forbidden`. La diferencia es una sola: `Unauthorized` significa que el
clúster no encontró una access entry para ese ARN (`aws eks list-access-entries` no
mostrará ese ARN en absoluto), `Forbidden` significa que la access entry existe, pero
RBAC/access policy no permiten esa acción.

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

Guardamos la explicación en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401): el rol eks-task102-test-nobody no tiene access entry en el clúster.
kubectl get pods -A con su kubeconfig responde "You must be logged in to the server
(Unauthorized)" - no se llegó a RBAC, la autenticación no pasó. Verificación:
aws eks list-access-entries --cluster-name <cluster> no contiene su ARN.

Forbidden (403): el rol eks-task102-test-viewer tiene access entry (grupo viewers) y
puede leer pods, pero kubectl create namespace test con el mismo rol responde Forbidden -
el clúster reconoció al principal, pero el RBAC del grupo viewers no permite crear namespaces.
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## Tarea 8. Eliminación de la access entry y restauración

Retiramos la access entry y confirmamos que el acceso desapareció, luego creamos la
entrada de nuevo (el clúster queda en estado funcional para la verificación):

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` elimina junto con la entrada todas sus asociaciones de access
policy - la policy de la tarea 6 (`AmazonEKSViewPolicy`) no se restaura sola tras eliminar
la entrada. La devolvemos de forma explícita, para que el entorno quede en el estado
alcanzado en la tarea 6:

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

Guardamos el resultado del ciclo eliminación/restauración en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized): la access entry eliminada
     hizo que el principal fuera desconocido para el clúster de inmediato.

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> acceso restaurado, el binding RBAC sobre el grupo viewers no cambió y vuelve a funcionar.
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## Comprobación rápida

```bash
check_result
```
