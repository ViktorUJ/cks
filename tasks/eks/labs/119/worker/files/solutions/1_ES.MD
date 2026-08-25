[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 - solución de referencia (troubleshooting: el node no alcanza Ready)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster, la CLI de `aws` está configurada para la misma cuenta y región.

Primero, guarda el nombre del cluster en una variable - casi todos los comandos la
necesitarán:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Tarea 1. Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## Tarea 2. Inventario: un managed node group healthy como norma

La lab ya tiene un managed node group en ejecución (separado de Karpenter) - este es el
ejemplo healthy con el que se compara la instancia self-managed rota de las tareas
siguientes.

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (norma - lista vacía) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

Si `health.issues` no es una lista vacía - esto es exactamente el `NodeCreationFailure`
del capítulo 45, y ya no sería un ejemplo healthy para comparar. Normalmente, un node
del managed node group es visible en `kubectl get nodes` con estado `Ready`.

## Tarea 3. Rol IAM de prueba para la instancia self-managed

El rol del node debe recibir `AmazonEKSWorkerNodePolicy`,
`AmazonEC2ContainerRegistryReadOnly` y `AmazonEKS_CNI_Policy` (capítulo 45.2) - el mismo
conjunto que el rol del managed node group healthy. La tercera política aquí no es una
formalidad: el addon `vpc-cni` se ejecuta sin su propio rol IRSA, así que `aws-node` toma
las credenciales del rol del node, y sin `AmazonEKS_CNI_Policy` el node permanece
`NotReady` para siempre con `cni plugin not initialized`. Exactamente una cosa debe estar
rota en esta lab - el access entry ausente. El nombre del rol debe contener `-test-`, de
lo contrario el worker no podrá gestionarlo.

```bash
ROLE_NAME="eks-task119-test-node"
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam create-instance-profile --instance-profile-name "$ROLE_NAME"
aws iam add-role-to-instance-profile --instance-profile-name "$ROLE_NAME" --role-name "$ROLE_NAME"

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
mkdir -p /var/work/tests/artifacts/3
echo "$ROLE_ARN" > /var/work/tests/artifacts/3/test_role_arn.txt
cat /var/work/tests/artifacts/3/test_role_arn.txt
```

El instance profile se crea de inmediato: la instancia necesita exactamente eso, no el
rol directamente. Da al perfil 10-15 segundos para propagarse antes de lanzar la
instancia.

## Tarea 4. Instancia EC2 self-managed en AL2023 sin access entry

Tomamos la misma AMI, la misma subred privada y el mismo security group de los nodes que
los nodes normales del cluster, pero NO creamos un access entry - esta es la
configuración deliberadamente incompleta.

```bash
AMI_ID=$(aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.36/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query 'Parameter.Value' --output text)

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  "Name=tag:kubernetes.io/cluster/$CLUSTER,Values=owned" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[0].SubnetId' --output text)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=tag:karpenter.sh/discovery,Values=$CLUSTER" \
  --query 'SecurityGroups[0].GroupId' --output text)

API_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.endpoint' --output text)
CA_DATA=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.certificateAuthority.data' --output text)
SERVICE_CIDR=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.kubernetesNetworkConfig.serviceIpv4Cidr' --output text)
```

Construimos el user data: un documento MIME con un `NodeConfig` para `nodeadm`
(capítulo 10.5 y capítulo 45.4).

```bash
cat > /tmp/user-data.yaml <<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${CLUSTER}
    apiServerEndpoint: ${API_ENDPOINT}
    certificateAuthority: ${CA_DATA}
    cidr: ${SERVICE_CIDR}

--BOUNDARY--
EOF
```

Lanzamos la instancia con el instance profile de prueba y la misma AMI/subred/SG que los
nodes de producción. La etiqueta `Name` con `-test-` es necesaria para los permisos del
worker, y debe proporcionarse en las dos secciones `--tag-specifications` a la vez - tanto
para `instance` como para `volume`. La política del worker permite `RunInstances` en
`instance/*` y `volume/*` solo bajo la condición `aws:RequestTag/Name = *-test-*`, y
`RunInstances` también crea un volumen raíz junto con la instancia. Sin una etiqueta en el
volumen, AWS responde con `UnauthorizedOperation ... on resource: .../volume/*`, aunque la
instancia misma esté etiquetada correctamente:

```bash
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.medium \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --iam-instance-profile "Name=eks-task119-test-node" \
  --user-data file:///tmp/user-data.yaml \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=eks-task119-test-node}]' \
    'ResourceType=volume,Tags=[{Key=Name,Value=eks-task119-test-node}]' \
  --query 'Instances[0].InstanceId' --output text)

mkdir -p /var/work/tests/artifacts/4
echo "$INSTANCE_ID" > /var/work/tests/artifacts/4/instance_id.txt
cat /var/work/tests/artifacts/4/instance_id.txt
```

## Tarea 5. Síntoma: `running` en EC2, pero no en `kubectl get nodes`

Da a la instancia 3-5 minutos para arrancar y hacer bootstrap, luego compara las dos
fuentes de verdad.

```bash
sleep 240
STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' --output text)
NODES=$(kubectl get nodes -o wide)

mkdir -p /var/work/tests/artifacts/5
{
  echo "instance $INSTANCE_ID state: $STATE"
  echo "=== kubectl get nodes ==="
  echo "$NODES"
} > /var/work/tests/artifacts/5/no_join_symptom.txt
cat /var/work/tests/artifacts/5/no_join_symptom.txt
```

La instancia está `running`, pero está ausente de la lista de nodes - exactamente el
síntoma que abre el capítulo 45.

## Tarea 6. Diagnóstico: qué le falta al rol

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

El ARN del rol `eks-task119-test-node` está ausente de la lista. El rol tiene políticas
administradas (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`), pero
no tiene autorización dentro del cluster - sin un access entry de tipo `EC2_LINUX`,
kubelet no pasa la autorización.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
La instancia $INSTANCE_ID está running en EC2, pero no apareció en kubectl get nodes. La
razón es que el rol $ROLE_ARN tiene políticas administradas (AmazonEKSWorkerNodePolicy,
AmazonEC2ContainerRegistryReadOnly), pero no tiene access entry en el cluster. Los
permisos IAM del rol y la autorización del rol en el cluster son dos cosas distintas
(capítulo 45.2). aws eks list-access-entries para $CLUSTER no muestra este rol. Un
managed node group crea dicha entrada automáticamente, mientras que para los nodes
self-managed un access entry de tipo EC2_LINUX debe crearse manualmente con aws eks
create-access-entry.
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## Tarea 7. Arreglo: un access entry de tipo `EC2_LINUX`

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

Da al node tiempo para registrarse y pasar a `Ready` (generalmente 1-2 minutos después de
crear el access entry, ya que kubelet ya estaba en ejecución esperando la autorización):

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

El identificador del node en el cluster es el private DNS name de la instancia, no el
propio `INSTANCE_ID`; para encontrar la línea de la instancia específica, compárala con
`PrivateDnsName`:

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

Espera el `Ready` real, no solo que el node aparezca en la lista: justo después del
registro permanece `NotReady` durante unas cuantas decenas de segundos mientras
`aws-node` se levanta. Luego captura la evidencia - después de la tarea 9, ni el node ni
su private DNS name existirán más:

```bash
for i in $(seq 1 20); do
  STATUS=$(kubectl get node "$NODE_NAME" --no-headers | awk '{print $2}')
  echo "node status=$STATUS"
  [[ "$STATUS" == "Ready" ]] && break
  sleep 15
done

mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/node_ready.txt <<EOF
node_name=$NODE_NAME
node_status=$STATUS
EOF
cat /var/work/tests/artifacts/7/node_ready.txt
```

## Tarea 8. Verificación: el node realmente acepta pods

`Ready` todavía no es prueba de que el node sea funcional. Programamos un pod
específicamente en él:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: eks-119
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_NAME}
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl wait --for=condition=Ready pod/probe -n eks-119 --timeout=240s
kubectl get pod probe -n eks-119 -o wide
```

Capturamos la evidencia igual que en la tarea 7: el pod vive en este node y desaparecerá
junto con él una vez que la instancia sea terminada en la tarea 9.

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## Tarea 9. Limpieza: terminar la instancia self-managed

Esta instancia EC2 no forma parte del estado terraform de la lab: `make delete_eks_task`
no la tocará. Termínala tú mismo antes de cerrar la lab:

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

El access entry, el rol de prueba y el instance profile también conviene eliminarlos: no
cuestan dinero, pero sus nombres son estáticos, así que permanecerán en la cuenta incluso
después de `make delete_eks_task`. El orden importa - primero el access entry, luego el
rol:

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$ROLE_ARN"
aws iam remove-role-from-instance-profile --instance-profile-name eks-task119-test-node \
  --role-name eks-task119-test-node
aws iam delete-instance-profile --instance-profile-name eks-task119-test-node
for p in AmazonEKSWorkerNodePolicy AmazonEC2ContainerRegistryReadOnly AmazonEKS_CNI_Policy; do
  aws iam detach-role-policy --role-name eks-task119-test-node \
    --policy-arn arn:aws:iam::aws:policy/$p
done
aws iam delete-role --role-name eks-task119-test-node
```

## Verificación rápida

```bash
check_result
```
