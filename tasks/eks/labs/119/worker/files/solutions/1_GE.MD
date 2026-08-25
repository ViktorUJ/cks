[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 119 - ეტალონური გადაწყვეტა (troubleshooting: node არ აღწევს Ready-ს)

ყველა ბრძანება მუშავდება worker მანქანაზე SSH-ით. kubectl უკვე კონფიგურირებულია
კლასტერზე, `aws` CLI კონფიგურირებულია იმავე აკაუნტზე და რეგიონზე.

პირველად შევინახოთ კლასტერის სახელი ცვლადში - თითქმის ყველა ბრძანებას ეს დაჭირდება:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## დავალება 1. Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## დავალება 2. ინვენტარიზაცია: ჯანსაღი managed node group როგორც ნორმა

ლაბაში უკვე დგახარია managed node group (ცალკე Karpenter-ისგან) - ეს არის ჯანსაღი
ნიმუში, რომელთანაც შედარდება დამტვრეული self-managed ინსტანსი შემდეგ დავალებებში.

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (ნორმა - ცარიელი სია) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

თუ `health.issues` ცარიელი სია არ არის - ეს ზუსტად `NodeCreationFailure`-ია თავი
45-იდან, და ის უკვე არ იქნება ჯანსაღი ნიმუში შედარებისთვის. ჩვეულებრივ, managed
node group-ის node ხილვადია `kubectl get nodes`-ში სტატუსით `Ready`.

## დავალება 3. ტესტური IAM role self-managed ინსტანსისთვის

Node-ის role-მა უნდა მიიღოს `AmazonEKSWorkerNodePolicy`,
`AmazonEC2ContainerRegistryReadOnly` და `AmazonEKS_CNI_Policy` (თავი 45.2) - იმავე
ნაკრები, რაც ჯანსაღი managed node group-ის role-ს აქვს. მესამე policy აქ არ არის
ფორმალობა: `vpc-cni` add-on მუშაობს საკუთარი IRSA role-ის გარეშე, ამიტომ `aws-node`
credentials-ს იღებს node-ის role-იდან, და `AmazonEKS_CNI_Policy`-ის გარეშე node-ი
სამუდამოდ რჩება `NotReady`-ში `cni plugin not initialized`-ით. ამ ლაბაში ზუსტად ერთი
რამ უნდა იყოს დამტვრეული - access entry-ის არარსებობა. Role-ის სახელი უნდა შეიცავდეს
`-test-`-ს, სხვანაირად worker-ს არ შეეძლება მისი მართვა.

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

Instance profile იქმნება მაშინვე: ინსტანსს ზუსტად ის ჰყოფნის, არა role პირდაპირ.
მიეცით profile-ს 10-15 წამი გავრცელებისთვის ინსტანსის გაშვების წინ.

## დავალება 4. Self-managed EC2-ინსტანსი AL2023-ზე access entry-ის გარეშე

ვიღებთ იმავე AMI-ს, იმავე პრივატულ subnet-ს და იმავე node-ების security group-ს, რაც
კლასტერის ჩვეულ node-ებს აქვს, მაგრამ ᲐᲠ ვქმნით access entry-ს - ეს არის განზრახ
არასრული კონფიგურაცია.

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

ვაწყობთ user data-ს: MIME-დოკუმენტს `NodeConfig`-ით `nodeadm`-ისთვის (თავი 10.5 და
თავი 45.4).

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

ვუშვებთ ინსტანსს ტესტური instance profile-ით და იმავე AMI/subnet/SG-ით, რაც საბრძოლო
node-ებს. ტეგი `Name` `-test-`-ით საჭიროა worker-ის უფლებებისთვის, და მისი
მითითება საჭირო ორ `--tag-specifications` სექციაში ერთდროულად - როგორც
`instance`-ისთვის, ისე `volume`-ისთვის. Worker-ის policy უშვებს `RunInstances`-ს
`instance/*`-ზე და `volume/*`-ზე მხოლოდ პირობით `aws:RequestTag/Name = *-test-*`,
ხოლო `RunInstances` ინსტანსთან ერთად ქმნის root ტომსაც. ტომზე ტეგის გარეშე AWS
პასუხობს `UnauthorizedOperation ... on resource: .../volume/*`-ით, მიუხედავად იმისა,
რომ თავად ინსტანსი სწორად არის მონიშნული:

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

## დავალება 5. სიმპტომი: `running` EC2-ში, მაგრამ არ არის `kubectl get nodes`-ში

მიეცით ინსტანსს 3-5 წუთი ჩასატანად და bootstrap-ისთვის, შემდეგ შეადარეთ ორი წყარო.

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

ინსტანსი `running`-ია, მაგრამ node-ების სიაში ის არ არსებობს - ზუსტად ის სიმპტომი,
რომელიც თავი 45-ს ხსნის.

## დავალება 6. დიაგნოსტიკა: რას არ ჰყოფნის role-ს

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

Role-ის `eks-task119-test-node` ARN სიაში არ არსებობს. Role-ს ჰყავს managed
policy-ები (`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`),
მაგრამ არ აქვს ავტორიზაცია კლასტერის შიგნით - access entry ტიპის `EC2_LINUX`-ის
გარეშე kubelet არ გადის ავტორიზაციას.

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
Instance $INSTANCE_ID is running EC2-ში, მაგრამ არ გამოჩნდა kubectl get nodes-ში.
მიზეზი - role $ROLE_ARN-ს ჰყავს managed policy-ები (AmazonEKSWorkerNodePolicy,
AmazonEC2ContainerRegistryReadOnly), მაგრამ არ აქვს access entry კლასტერში. Role-ის
IAM უფლებები და role-ის ავტორიზაცია კლასტერში - ორი სხვადასხვა რამ არის (თავი 45.2).
aws eks list-access-entries $CLUSTER-ისთვის ამ role-ს არ აჩვენებს. Managed node group
ასეთ ჩანაწერს ავტომატურად ქმნის, ხოლო self-managed node-ებისთვის access entry ტიპის
EC2_LINUX უნდა შეიქმნას ხელით ბრძანებით aws eks create-access-entry.
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## დავალება 7. ჩასწორება: access entry ტიპით `EC2_LINUX`

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

მივცემთ node-ს დროს დარეგისტრირდეს და გადავალს `Ready`-ში (ჩვეულებრივ 1-2 წუთი access
entry-ის შექმნის შემდეგ, kubelet უკვე გაშვებული იყო და ავტორიზაციას ელოდებოდა):

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

Node-ის იდენტიფიკატორი კლასტერში - ინსტანსის private DNS name-ია, არა თავად
`INSTANCE_ID`; კონკრეტულ ინსტანსზე სტრიქონის საპოვნელად შეადარეთ ის
`PrivateDnsName`-ს:

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

დაელოდეთ ზუსტად `Ready`-ს, არა უბრალოდ node-ის გამოჩენას სიაში: რეგისტრაციის
შემდეგ ის რამდენიმე ათეული წამი `NotReady`-ში დგება, სანამ `aws-node` ამოდის.
შემდეგ ვფიქსირებთ მტკიცებულებას - დავალება 9-ის შემდეგ ვერც node და ვერც მისი
private DNS name უკვე არ იარსებებს:

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

## დავალება 8. გადამოწმება: node-ი რეალურად იღებს pod-ებს

`Ready` ჯერ არ არის მტკიცებულება იმისა, რომ node-ი მუშაა. ვგანვსახლებთ pod-ს ზუსტად
მასზე:

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

ვფიქსირებთ მტკიცებულებას ისევე, როგორც დავალება 7-ში: pod ცხოვრობს ამ node-ზე და
გაქრება მასთან ერთად, როცა დავალება 9-ში ინსტანსი terminate-ული იქნება.

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## დავალება 9. დასუფთავება: self-managed ინსტანსის terminate

ეს EC2-ინსტანსი არ შედის ლაბის terraform state-ში: `make delete_eks_task` მას არ
ეხება. Terminate-ე ის თავად, ლაბის დახურვის წინ:

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

Access entry, ტესტური role და instance profile-იც ღირს მოშორება: ფულს ისინი არ
ხარჯავენ, მაგრამ მათი სახელები სტატიკურია, ამიტომ ისინი აკაუნტში დარჩებიან
`make delete_eks_task`-ის შემდეგაც. თანმიმდევრობა მნიშვნელოვანია - ჯერ access entry,
შემდეგ role:

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

## სწრაფი შემოწმება

```bash
check_result
```
