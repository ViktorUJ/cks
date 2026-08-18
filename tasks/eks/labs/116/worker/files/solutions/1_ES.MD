[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 116 - solución de referencia (IMDSv2 hop limit, Pod Security Admission, endpoint privado)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster (el kubeconfig se generó con `aws eks update-kubeconfig` al arrancar la
máquina).

## Tarea 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## Tarea 2. Síntoma: IMDS no es accesible desde el pod

El NodePool `hardened` (el único en esta lab) establece `httpPutResponseHopLimit=1` en
todos sus nodos mediante `metadataOptions` del EC2NodeClass. Un paquete de un proceso en
el host llega a IMDS en un solo hop, mientras que un paquete desde un pod hace un hop
adicional (el network namespace del contenedor) - y no entra dentro del límite. Creamos
un Deployment con un contenedor dormido para poder entrar con exec:

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

Petición IMDSv2 desde el pod (primero el token, luego los datos), con límite de tiempo:

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

Con hop limit `1`, `curl` no recibe respuesta dentro de los `5` segundos asignados, y en
el archivo queda una línea sobre el timeout (`curl` imprime `curl: (28) ... timeout` con
`-v`, y sin token el propio script añade la nota `timed out`).

## Tarea 3. Verificación vía AWS API: hop limit e IMDSv2 en el nodo

Averiguamos en qué nodo vive `probe`, obtenemos su `providerID` y extraemos el id de la
instancia:

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID con formato aws:///eu-central-1a/i-0abc123def456789
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

En la salida debe aparecer `"HttpTokens": "required"` y `"HttpPutResponseHopLimit": 1` -
exactamente lo que definió `vng.metadataOptions` en
`eks_karpenter_hardened_vng/terragrunt.hcl` y lo que el EC2NodeClass pasó al launch
template del nodo.

## Tarea 4. Pod Security Admission: rechazo de un pod privilegiado

Activamos restricted en el namespace mediante etiquetas (PSA viene integrado en EKS,
pero por defecto un namespace sin etiquetas se comporta como `privileged` - no restringe
nada):

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

Probamos un pod privilegiado - admission debe rechazar la creación:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

Salida esperada, similar a:

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

El pod no se crea (`kubectl get pod priv-test` devuelve `NotFound`), y el mensaje
contiene las palabras `privileged` y `restricted`/`violates` - que es exactamente lo que
piden los criterios de aceptación.

## Tarea 5. La vía permitida: un pod compatible con restricted

Construimos un pod con todos los campos que exige el perfil `restricted`.
`runAsNonRoot: true` solo prohíbe ejecutar como root - la imagen `busybox:latest` no
declara un usuario non-root por defecto, así que sin un `runAsUser` explícito (cualquier
UID distinto de cero) kubelet bloquea el arranque del contenedor con un error aparte,
`container has runAsNonRoot and image will run as root`, ya después de que admission
dejó pasar el pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

El pod pasa admission y llega a `Running` - el mismo namespace, el mismo perfil
`restricted`, pero los requisitos se cumplen por completo: `runAsNonRoot` con
`runAsUser` explícito, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`,
`seccompProfile` `RuntimeDefault`.

## Tarea 6. Acceso privado al control plane y VPC endpoints

Comprobamos el `resourcesVpcConfig` del cluster - el módulo `eks_v2_control_plane` ya
activa ambos flags (`endpoint_public_access = true`, `endpoint_private_access = true`):

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

En la salida aparece `"endpointPrivateAccess": true`. Completamos el archivo con una
explicación:

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

Para un cluster totalmente privado (nodos sin salida a internet) se necesitan VPC
endpoints: ecr.api y ecr.dkr (para descargar imágenes de contenedores), el s3 gateway
endpoint (las capas de las imágenes de ECR residen físicamente en S3, así que sin él la
imagen no se descargará aunque ecr.api y ecr.dkr estén presentes), sts (intercambiar el
token de IRSA por credenciales temporales), ec2 (registro del nodo y nombre DNS), logs
(envío de logs a CloudWatch) y eks (acceso a la API de EKS desde la VPC). El acceso
privado al control plane (ya activado en este cluster) es obligatorio por separado de la
lista de endpoints - sin él los nodos no podrían registrarse en el API server desde una
subred privada.
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## Verificación rápida

```bash
check_result
```
