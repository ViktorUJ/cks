[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 120 - solución de referencia (fallos de red, targets no saludables en el load balancer)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster. Terraform ya creó el security group "roto" (componente
`eks_network_break_demo`) y un rol IRSA para el AWS Load Balancer Controller
(`eks_lbc_irsa`) - los nombres e ids están en `~/lab120_hints.txt`.

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## Tarea 1. Namespace y la carga de trabajo de la lab

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## Tarea 2. Conectividad base y diagnóstico de SG

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

La conectividad aquí funciona bien: el SG del node permite el tráfico entre pods del
cluster, y los SG son stateful, así que la respuesta a esta petición pasa por sí sola
(capítulo 46.3). Veamos qué SGs están realmente asignados al ENI del pod `api`:

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

Importa qué filtro usas para encontrar el ENI. Con VPC CNI, la IP del pod es una
dirección **secundaria** en el ENI del node, así que el filtro `private-ip-address`
(que mira la dirección primaria de la interfaz) devolverá `null`. Necesitas
`addresses.private-ip-address`, que busca entre todas las direcciones de la interfaz:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## Tarea 3. Instalación del AWS Load Balancer Controller

```bash
LBC_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER}-lbc-irsa" \
  --query 'Role.Arn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

Un detalle importante de este entorno: el namespace `kube-system` cae bajo el perfil
Fargate, así que los pods del controller se ejecutan en Fargate, y Fargate **no tiene
IMDS**. Sin IMDS el controller no puede determinar la región y la VPC por sí mismo y
falla con `failed to get VPC ID: ... ec2imds ... context deadline exceeded`. Así que
`region` y `vpcId` se establecen de forma explícita:

```bash
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## Tarea 4. Síntoma: NLB con targets no saludables

Establecemos el SG "roto" como el SG propio del balancer. En el momento en que se
especifica un SG explícitamente vía la anotación, el LBC deja de añadir la regla
inbound faltante en el SG del node por nosotros - ese es precisamente el fallo
(capítulo 46.6):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  namespace: eks-120
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${SG_ID}
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl get svc api-lb -n eks-120 -w
```

Esperamos la dirección externa, encontramos el target group y verificamos la salud de
los targets:

```bash
HOSTNAME=$(kubectl get svc api-lb -n eks-120 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table > /var/work/tests/artifacts/4/unhealthy.txt
cat /var/work/tests/artifacts/4/unhealthy.txt
```

Todos los targets están `unhealthy` - el SG del balancer no deja pasar el health check
hacia el SG del node, y por lo tanto tampoco llega nunca al pod `api`.

## Tarea 5. Diagnóstico: qué SG está bloqueando el health check

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

La lista vacía lo confirma: el SG del balancer no tiene una sola regla inbound.

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
El security group del balancer (${SG_ID}) está asignado a api-lb vía la anotación
aws-load-balancer-security-groups y no contiene reglas inbound. El health check del
NLB llega como una nueva conexión TCP desde el security group del balancer hacia el
security group del node (${NODE_SG}) en el puerto 8080 de la aplicación. El security
group del node no permite tráfico inbound desde el security group del balancer en este
puerto, así que el health check falla y los targets permanecen unhealthy (capítulo
46.6).
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## Tarea 6. Arreglo: authorize-security-group-ingress, targets healthy

Dos reglas: permitir el health check y el tráfico de la aplicación desde el SG del
balancer hacia el SG del node, y abrir el listener del NLB para los clientes en el
puerto 80:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$NODE_SG" \
  --protocol tcp --port 8080 \
  --source-group "$SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0
```

Esperamos hasta que los targets se vuelvan `healthy` (generalmente 1-2 minutos) y
verificamos con curl:

```bash
sleep 90

mkdir -p /var/work/tests/artifacts/6
{
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
  echo
  curl -s --max-time 5 "http://${HOSTNAME}"
} > /var/work/tests/artifacts/6/healthy.txt
cat /var/work/tests/artifacts/6/healthy.txt
```

## Tarea 7. El DNS funciona: una verificación contrastante

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

Consultamos el nombre interno por su FQDN completo. El nombre corto `kubernetes.default`
mediante `nslookup` desde busybox devuelve `NXDOMAIN`: este resolver no añade los search
domains de `/etc/resolv.conf` como lo hace un cliente normal, y esa respuesta se confunde
fácilmente con un fallo de DNS que en realidad no existe.

Ambos nombres resuelven bien (`kubernetes.default.svc.cluster.local` a la dirección del
service `kubernetes`, `example.com` a direcciones externas) - el DNS no es el origen del
problema en esta lab (capítulos 46.5, 46.7), a diferencia del security group de las
tareas 4-6.

## Tarea 8. Checklist final: síntoma - causa probable - qué verificar

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
Síntoma: los targets en el target group del NLB están unhealthy, el service api-lb
devuelve 503.
Causa probable: el security group del balancer no permite tráfico inbound hacia el SG
del node en el puerto del health check (capítulo 46.6).
Qué verificar: aws elbv2 describe-target-health --target-group-arn <arn> mostrará
TargetHealth.Reason=Target.FailedHealthChecks, y aws ec2 describe-security-groups
confirmará que el SG del balancer no tiene ninguna regla inbound.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Verificación rápida

```bash
check_result
```
