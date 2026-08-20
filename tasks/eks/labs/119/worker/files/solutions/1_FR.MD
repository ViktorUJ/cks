[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 119 - solution de référence (troubleshooting: le nœud n'atteint pas Ready)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà
configuré pour le cluster, l'`aws` CLI est configuré pour le même compte et la même
région.

D'abord, enregistrez le nom du cluster dans une variable - presque toutes les commandes
en auront besoin :

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## Tâche 1. Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## Tâche 2. Inventaire : une managed node group saine comme norme

La lab a déjà une managed node group en cours d'exécution (séparée de Karpenter) - c'est
l'échantillon sain auquel est comparée l'instance self-managed cassée des tâches
suivantes.

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (norme - liste vide) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

Si `health.issues` n'est pas une liste vide - c'est exactement le `NodeCreationFailure`
du chapitre 45, et ce ne serait plus un échantillon sain pour la comparaison. Normalement,
un node de la managed node group est visible dans `kubectl get nodes` avec le statut
`Ready`.

## Tâche 3. Rôle IAM de test pour l'instance self-managed

Le rôle du node doit obtenir `AmazonEKSWorkerNodePolicy`,
`AmazonEC2ContainerRegistryReadOnly` et `AmazonEKS_CNI_Policy` (chapitre 45.2) - le même
ensemble que le rôle de la managed node group saine. La troisième politique ici n'est pas
une formalité : l'addon `vpc-cni` fonctionne sans son propre rôle IRSA, donc `aws-node`
prend ses identifiants depuis le rôle du node, et sans `AmazonEKS_CNI_Policy` le node
reste `NotReady` pour toujours avec `cni plugin not initialized`. Exactement une chose
doit être cassée dans cette lab - l'access entry manquant. Le nom du rôle doit contenir
`-test-`, sinon le worker ne pourra pas le gérer.

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

L'instance profile est créé immédiatement : c'est de lui, et non du rôle directement,
que l'instance a besoin. Laissez 10-15 secondes au profil pour se propager avant de
lancer l'instance.

## Tâche 4. Instance EC2 self-managed sur AL2023 sans access entry

Nous prenons la même AMI, le même subnet privé et le même security group de nodes que
les nodes habituels du cluster, mais ne créons PAS d'access entry - c'est la
configuration délibérément incomplète.

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

Construisons le user data : un document MIME avec un `NodeConfig` pour `nodeadm`
(chapitre 10.5 et chapitre 45.4).

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

Lançons l'instance avec l'instance profile de test et la même AMI/subnet/SG que les nodes
en production. Le tag `Name` avec `-test-` est nécessaire pour les permissions du worker,
et il doit être fourni dans les deux sections `--tag-specifications` à la fois - à la
fois pour `instance` et pour `volume`. La politique du worker autorise `RunInstances` sur
`instance/*` et `volume/*` uniquement sous la condition
`aws:RequestTag/Name = *-test-*`, et `RunInstances` crée aussi un volume racine en même
temps que l'instance. Sans tag sur le volume, AWS répond avec
`UnauthorizedOperation ... on resource: .../volume/*`, même si l'instance elle-même est
correctement taguée :

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

## Tâche 5. Symptôme : `running` dans EC2, mais absent de `kubectl get nodes`

Laissez à l'instance 3-5 minutes pour démarrer et bootstrapper, puis comparez les deux
sources de vérité.

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

L'instance est `running`, et pourtant elle est absente de la liste des nodes -
exactement le symptôme qui ouvre le chapitre 45.

## Tâche 6. Diagnostic : ce qui manque au rôle

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

L'ARN du rôle `eks-task119-test-node` est absent de la liste. Le rôle a des managed
policies (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`), mais aucune
autorisation à l'intérieur du cluster - sans access entry de type `EC2_LINUX`, kubelet ne
passe pas l'autorisation.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
L'instance $INSTANCE_ID est en running dans EC2, mais n'est pas apparue dans kubectl get
nodes. La raison est que le rôle $ROLE_ARN a des managed policies
(AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnly), mais aucun access entry
dans le cluster. Les permissions IAM du rôle et l'autorisation du rôle dans le cluster
sont deux choses différentes (chapitre 45.2). aws eks list-access-entries pour $CLUSTER
ne montre pas ce rôle. Une managed node group crée une telle entrée automatiquement,
tandis que pour les nodes self-managed un access entry de type EC2_LINUX doit être créé
manuellement avec aws eks create-access-entry.
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## Tâche 7. Correction : un access entry de type `EC2_LINUX`

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

Laissons au node le temps de s'enregistrer et de passer à `Ready` (généralement 1-2
minutes après la création de l'access entry, puisque kubelet était déjà en cours
d'exécution et attendait l'autorisation) :

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

L'identifiant du node dans le cluster est le private DNS name de l'instance, pas
l'`INSTANCE_ID` lui-même ; pour trouver la ligne correspondant à l'instance spécifique,
comparez-la avec `PrivateDnsName` :

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

Attendez le véritable `Ready`, pas seulement l'apparition du node dans la liste : juste
après l'enregistrement il reste `NotReady` pendant quelques dizaines de secondes tandis
que `aws-node` démarre. Puis capturons la preuve - après la tâche 9, ni le node ni son
private DNS name n'existeront plus :

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

## Tâche 8. Vérification : le node accepte réellement des pods

`Ready` n'est pas encore une preuve que le node est fonctionnel. Planifions un pod
spécifiquement sur lui :

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

Capturons la preuve de la même manière que dans la tâche 7 : le pod vit sur ce node et
disparaîtra avec lui une fois l'instance terminée dans la tâche 9.

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## Tâche 9. Nettoyage : terminer l'instance self-managed

Cette instance EC2 ne fait pas partie de l'état terraform de la lab : `make
delete_eks_task` n'y touchera pas. Terminez-la vous-même avant de clore la lab :

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

L'access entry, le rôle de test et l'instance profile valent aussi la peine d'être
supprimés : ils ne coûtent rien, mais leurs noms sont statiques, donc ils resteront dans
le compte même après `make delete_eks_task`. L'ordre compte - d'abord l'access entry,
puis le rôle :

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

## Vérification rapide

```bash
check_result
```
