[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - solución de referencia (cluster como código: acceso, cómputo, red, AMI)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster (el kubeconfig se genera mediante `aws eks update-kubeconfig`
al arrancar la máquina).

## Tarea 1. Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## Tarea 2. Deployment `web` (viktoruj/ping_pong, 3 réplicas) en nodos EC2

Los pods de sistema (kube-system, karpenter) van a Fargate, mientras que cualquier pod en un
namespace normal se planifica en un nodo EC2 que Karpenter levanta. Por eso el Deployment en
`eks-101` cae en EC2 automáticamente:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

Comprobación de que los pods no están en Fargate (el nombre del nodo empieza por `ip-`, no
por `fargate-`):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

Por qué es así: Fargate solo ejecuta un pod si el namespace del pod coincide con un perfil de
Fargate. En este laboratorio el perfil está configurado para `kube-system` y `karpenter`, y
no hay ninguno para `eks-101`, así que Karpenter (EC2) se encarga de la carga de `eks-101`.
Esta explicación la registrarás en la tarea 7.

## Tarea 3. Artefacto: separación entre nodos de sistema y de trabajo

Guardamos la lista de nodos indicando cuáles son Fargate y cuáles EC2:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

El archivo debe contener tanto nodos `fargate-...` (pods de sistema) como nodos `ip-...`
(nodos de trabajo de Karpenter). Esta es la separación de cómputo del capítulo 9.

## Tarea 4. Artefacto: IP de un pod dentro del CIDR de la VPC

VPC CNI entrega a los pods direcciones enrutables de la subred del nodo (`10.10.15.0/24` o
`10.10.16.0/24`), es decir, de la VPC `10.10.0.0/16`:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

Para entender mejor VPC CNI, compara la dirección del pod con el CIDR de las subredes
privadas (el pod recibió una IP de la subred de su propio nodo):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## Tarea 5. Artefacto: AMI del nodo de trabajo (AL2023)

Miramos la imagen del sistema operativo de cualquier nodo de trabajo (EC2). El NodePool por
defecto está construido sobre `al2023@latest`, así que es Amazon Linux 2023:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## Tarea 6. Deployment `batch` (6 réplicas con petición de CPU) - escala vía Karpenter

Una carga con requests explícitos hace que Karpenter añada recursos de cómputo. Creamos el
deployment con una petición de CPU y esperamos a que todas las réplicas estén listas:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

Para observar cómo Karpenter levanta nodos:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## Tarea 7. Frontera de responsabilidad: síntoma y explicación

Pedimos Fargate deliberadamente donde no existe. El pod debe quedarse colgado en `Pending`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# eventos de todo el namespace por orden temporal - una habilidad de diagnóstico SRE para fallos de planificación
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

El pod se queda en `Pending`: no hay perfil de Fargate para `eks-101`, así que EKS no lo
programa en Fargate, y Karpenter tampoco crea un nodo EC2, porque sus nodos no llevan la
label `eks.amazonaws.com/compute-type: fargate`. Nadie puede satisfacer este requisito.

Guardamos la explicación como artefacto:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
Los pods web y batch fueron a nodos EC2 de Karpenter, no a Fargate: Fargate solo ejecuta un
pod si el namespace del pod coincide con un profile de Fargate. En el clúster hay profile
para kube-system y karpenter, pero no hay ninguno para eks-101.

fg-probe se quedó colgado en Pending porque pide Fargate explícitamente (nodeSelector
eks.amazonaws.com/compute-type: fargate), pero no hay profile para eks-101, y los nodos EC2
de Karpenter no tienen esa label. Ni Fargate ni Karpenter pueden satisfacer el requisito.
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

La frontera de responsabilidad queda clara: qué namespaces van a Fargate depende de ti (a
través de los profiles de Fargate, capítulo 9), no algo que EKS decida "por su cuenta".

## Verificación rápida

```bash
check_result
```
