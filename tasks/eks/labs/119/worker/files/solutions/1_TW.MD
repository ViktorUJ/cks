[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 119 - 參考解答(troubleshooting:節點無法進入 Ready 狀態)

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經設定好指向叢集,`aws` CLI
也已經設定好對應同一個帳號和地區。

首先把叢集名稱存到一個變數裡 -幾乎每個指令都會用到它:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## 任務 1. Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## 任務 2. 盤點:作為正常基準的健康 managed node group

這個實驗中已經有一個在執行中的 managed node group(和 Karpenter 分開) - 這是
用來和後面任務中壞掉的 self-managed instance 做比較的健康樣本。

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (正常 - 空列表) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

如果 `health.issues` 不是空列表 - 那就是第 45 章裡的 `NodeCreationFailure`,這樣
它就不再是可以用來比較的健康樣本了。正常情況下,managed node group 裡的 node
應該能在 `kubectl get nodes` 中看到,狀態為 `Ready`。

## 任務 3. 給 self-managed instance 使用的測試 IAM role

node 的 role 必須取得 `AmazonEKSWorkerNodePolicy`、
`AmazonEC2ContainerRegistryReadOnly` 與 `AmazonEKS_CNI_Policy`(第 45.2 章) -
和健康的 managed node group 的 role 使用同一組 policy。第三個 policy 在這裡不
是形式上的東西:`vpc-cni` addon 沒有使用自己的 IRSA role,所以 `aws-node` 會從
node 的 role 取得憑證,如果沒有 `AmazonEKS_CNI_Policy`,node 就會永遠停在
`NotReady`,並顯示 `cni plugin not initialized`。這個實驗裡必須恰好只有一件事
被弄壞 - 缺少 access entry。role 名稱必須包含 `-test-`,否則 worker 就無法管理
它。

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

instance profile 馬上就建立好了:instance 需要的正是它,而不是直接使用 role。
在啟動 instance 之前,給這個 profile 10-15 秒的時間讓它傳播開來。

## 任務 4. 建立在 AL2023 上、沒有 access entry 的 self-managed EC2 instance

我們使用和叢集一般 node 相同的 AMI、相同的私有子網路,以及相同的 node security
group,但不建立 access entry - 這正是刻意設定不完整的地方。

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

組裝 user data:一份給 `nodeadm` 使用、帶有 `NodeConfig` 的 MIME 文件(第 10.5
章與第 45.4 章)。

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

使用測試用的 instance profile,以及和正式 node 相同的 AMI/子網路/SG 來啟動這個
instance。帶有 `-test-` 的 `Name` 標籤是 worker 權限所需要的,而且必須同時放在
兩個 `--tag-specifications` 區塊裡 - `instance` 和 `volume` 都要有。worker 的
policy 只在條件 `aws:RequestTag/Name = *-test-*` 成立時,才允許在 `instance/*`
和 `volume/*` 上執行 `RunInstances`,而 `RunInstances` 在建立 instance 的同時
也會建立一個 root volume。如果 volume 上沒有標籤,AWS 就會回覆
`UnauthorizedOperation ... on resource: .../volume/*`,即使 instance 本身的
標籤是正確的:

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

## 任務 5. 症狀:在 EC2 中是 `running`,但不在 `kubectl get nodes` 裡

給這個 instance 3-5 分鐘的時間開機並完成 bootstrap,然後比較這兩個真相來源。

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

instance 是 `running`,但它不在 node 列表裡 - 這正是開啟第 45 章的那個症狀。

## 任務 6. 診斷:這個 role 缺了什麼

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

role `eks-task119-test-node` 的 ARN 不在列表中。這個 role 有 managed policy
(`AmazonEKSWorkerNodePolicy`、`AmazonEC2ContainerRegistryReadOnly`),但在叢集
內部沒有授權 - 如果沒有 `EC2_LINUX` 類型的 access entry,kubelet 就無法通過
授權。

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
Instance $INSTANCE_ID is running in EC2, but did not appear in kubectl get nodes. The
reason is that role $ROLE_ARN has managed policies (AmazonEKSWorkerNodePolicy,
AmazonEC2ContainerRegistryReadOnly), but no access entry in the cluster. The role's IAM
permissions and the role's authorization in the cluster are two different things
(chapter 45.2). aws eks list-access-entries for $CLUSTER does not show this role. A
managed node group creates such an entry automatically, while for self-managed nodes an
access entry of type EC2_LINUX must be created manually with aws eks
create-access-entry.
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## 任務 7. 修復:一個 `EC2_LINUX` 類型的 access entry

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

給這個 node 一些時間去註冊並轉換到 `Ready`(通常在建立 access entry 之後
1-2 分鐘,因為 kubelet 已經在執行並等待授權):

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

這個 node 在叢集中的識別名稱是該 instance 的 private DNS name,而不是
`INSTANCE_ID` 本身;要找到對應特定 instance 的那一行,需要拿它去比對
`PrivateDnsName`:

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

要等到真正的 `Ready`,而不只是 node 出現在列表中:剛註冊完之後的幾十秒內它會
停在 `NotReady`,等待 `aws-node` 啟動。接著把這個證據記錄下來 - 任務 9 之後,
這個 node 和它的 private DNS name 都不會再存在了:

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

## 任務 8. 驗證:node 確實能接受 pod

`Ready` 還不足以證明這個 node 是可用的。把一個 pod 特別排程到它上面:

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

用和任務 7 相同的方式記錄證據:這個 pod 活在這個 node 上,一旦任務 9 中
instance 被終止,它也會一起消失。

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## 任務 9. 清理:終止 self-managed instance

這個 EC2 instance 不屬於這個實驗的 terraform state:`make delete_eks_task` 不會
動到它。在結束這個實驗之前,自己把它終止:

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

access entry、測試用的 role,以及 instance profile 也值得一併移除:它們不會
產生費用,但名稱是固定的,所以即使執行了 `make delete_eks_task`,它們也會留在
帳號中。順序很重要 - 先移除 access entry,再移除 role:

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

## 快速檢查

```bash
check_result
```
