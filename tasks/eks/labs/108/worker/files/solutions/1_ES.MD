[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - solución de referencia (AWS Load Balancer Controller: NLB para un Service)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl ya está
configurado para el clúster. Terraform ya creó el rol IAM para el controlador (componente
`eks_lbc_irsa`, módulo `eks_v2_lbc_irsa`) - solo queda tomar su ARN e instalar el
controlador en sí.

## Tarea 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## Tarea 2. ServiceAccount e instalación del AWS Load Balancer Controller

Buscamos el ARN del rol que creó terraform (nombre del rol `<cluster-name>-lbc-irsa`):

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

Creamos el ServiceAccount en `kube-system` con una anotación que apunta a ese rol. El LBC se
instala mediante Helm con `serviceAccount.create=false`, así que el ServiceAccount debe
existir de antemano:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
```

Instalamos el controlador desde el chart oficial:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "$VPC_ID"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

El controlador corre en Fargate (namespace `kube-system` bajo el perfil de Fargate), y en
Fargate no existe físicamente el instance metadata service (IMDS) de EC2 - sin `vpcId` y
`region` explícitos, el controlador intenta obtener el VPC ID a través de IMDS y termina en
`CrashLoopBackOff` con un error del tipo `failed to fetch VPC ID from instance metadata: ...
context deadline exceeded`. En nodos EC2 gestionados estos flags no son necesarios (IMDS
está disponible), pero en Fargate siempre hay que pasarlos de forma explícita.

Comprobamos que el controlador arrancó y ve el rol:

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## Tarea 3. Deployment `web` (viktoruj/ping_pong, 2 réplicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## Tarea 4. Service `web` de tipo LoadBalancer: NLB en vez de CLB

Por defecto el in-tree cloud provider crea un Classic Load Balancer obsoleto para un
Service de tipo LoadBalancer. La anotación `aws-load-balancer-type: external` transfiere la
reconciliación al AWS Load Balancer Controller, que crea un Network Load Balancer moderno:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: eks-108
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
EOF
```

Esperamos la dirección externa:

```bash
kubectl get svc web -n eks-108 -w
```

Confirmamos mediante AWS CLI que se creó un NLB (tipo `network`) y no un CLB, y que el
esquema es `internet-facing`:

```bash
HOSTNAME=$(kubectl get svc web -n eks-108 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/4/nlb.txt
cat /var/work/tests/artifacts/4/nlb.txt
```

En la salida, `Type` debe ser `network` (NLB), y `Scheme` debe ser `internet-facing`. Si no
existiera la anotación `aws-load-balancer-type`, el in-tree provider habría creado
`Type: classic` - ese es exactamente el síntoma «pedí un LoadBalancer y obtuve un CLB» del
capítulo 26.

## Tarea 5. Verificación de los targets: IP de los pods, no instance ID de los nodos

`target-type: ip` registra en el target group las direcciones de los pods entregadas por
VPC CNI, no los nodos por `InstanceId`. Lo comprobamos con `describe-target-groups` y
`describe-target-health`:

```bash
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/5
{
  aws elbv2 describe-target-groups --target-group-arns "$TG_ARN"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
} > /var/work/tests/artifacts/5/targets.txt

cat /var/work/tests/artifacts/5/targets.txt
```

En el archivo, `TargetType` debe ser `ip`, y el `Target.Id` de cada target debe ser una
dirección de `10.10.0.0/16` (la subred de la VPC de este laboratorio), no `i-...` (un
instance ID). Así es exactamente como se ve un target group de NLB con `target-type: ip`:
el controlador registra la IP del pod directamente, sin pasar por NodePort, lo que elimina
el salto extra a través de kube-proxy.

## Tarea 6. Diagnóstico: reconciliación exitosa frente a AccessDenied

Miramos el log del controlador para ver cómo se ve una reconciliación normal del Service -
debe aparecer el ARN del balanceador creado:

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

Si el ServiceAccount no tuviera un rol asociado (o el rol no tuviera los permisos
necesarios), el controlador no podría llamar a la API de ELBv2 y en el log aparecería un
mensaje como `AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer`, y el Service se quedaría en `<pending>` sin
dirección externa - porque la reconciliación falla en la primera llamada a la API, antes
de crear el NLB.

Guardamos ambas observaciones en un solo artefacto:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== Reconciliación exitosa (log real del controlador) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== Síntoma esperado sin permisos IAM (no reproducido con el rol activo) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "Con este error el Service web se queda en <pending>: EXTERNAL-IP nunca aparece," \
       "porque el controlador no pudo crear el NLB a través de la API de ELBv2."
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## Verificación rápida

```bash
check_result
```
