[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 119 - 参考解答(トラブルシューティング:ノードが Ready に到達しない)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl はすでにクラスタ用
に設定されており、`aws` CLI も同じアカウントとリージョン用に設定されています。

まず、クラスタ名を変数に保存します - ほぼすべてのコマンドがこれを必要とします:

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "$CLUSTER"
```

## タスク 1。Namespace `eks-119`

```bash
kubectl create namespace eks-119
```

## タスク 2。インベントリ:正常としての健全な managed node group

このラボにはすでに(Karpenter とは別に)managed node group が稼働しています - これが、
続くタスクで壊れた self-managed インスタンスと比較する際の健全なサンプルです。

```bash
mkdir -p /var/work/tests/artifacts/2
NODEGROUP=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query 'nodegroups[0]' --output text)
{
  echo "=== aws eks describe-nodegroup health.issues (正常 - 空のリスト) ==="
  aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" \
    --query 'nodegroup.health.issues'
  echo "=== kubectl get nodes -o wide ==="
  kubectl get nodes -o wide
} > /var/work/tests/artifacts/2/nodegroup_health.txt
cat /var/work/tests/artifacts/2/nodegroup_health.txt
```

`health.issues` が空のリストでなければ、それはまさに第 45 章の `NodeCreationFailure`
であり、比較用の健全なサンプルとしてはもはや成立しません。正常な状態では、managed
node group のノードは `kubectl get nodes` に `Ready` ステータスで見えます。

## タスク 3。self-managed インスタンス用のテスト IAM ロール

ノードのロールは `AmazonEKSWorkerNodePolicy`、`AmazonEC2ContainerRegistryReadOnly`、
`AmazonEKS_CNI_Policy`(第 45.2 章)を得る必要があります - これは健全な managed node
group のロールと同じセットです。3 つ目のポリシーはここでは形式的なものではありません:
`vpc-cni` アドオンは自分専用の IRSA ロールなしで動作しているため、`aws-node` はノード
のロールから credentials を取得します。`AmazonEKS_CNI_Policy` がなければ、ノードは
`cni plugin not initialized` とともに永久に `NotReady` のままになります。このラボで壊
れているべきものはちょうど 1 つ - access entry の欠落だけです。ロール名には `-test-`
を含める必要があります、そうでなければ worker はそれを管理できません。

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

instance profile はすぐに作成します:インスタンスに必要なのはロール自体ではなく、まさ
にこの instance profile です。インスタンスを起動する前に、プロファイルが伝播するまで
10-15 秒ほど待ってください。

## タスク 4。access entry のない AL2023 上の self-managed EC2 インスタンス

クラスタの通常のノードと同じ AMI、同じプライベート subnet、同じノードの security
group を使いますが、access entry は作成しません - これがあえて用意した不完全な設定で
す。

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

user data を組み立てます:`nodeadm`(第 10.5 章と第 45.4 章)用の `NodeConfig` を含む
MIME ドキュメントです。

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

テスト用の instance profile と、本番ノードと同じ AMI/subnet/SG でインスタンスを起動し
ます。`-test-` を含む `Name` タグは worker の権限のために必要で、`--tag-specifications`
の 2 つのセクション - `instance` と `volume` の両方 - に一度に指定する必要がありま
す。worker のポリシーは `aws:RequestTag/Name = *-test-*` の条件でのみ `instance/*` と
`volume/*` への `RunInstances` を許可し、`RunInstances` はインスタンスと一緒にルート
ボリュームも作成します。ボリュームにタグがなければ、インスタンス自体は正しくタグ付け
されていても、AWS は `UnauthorizedOperation ... on resource: .../volume/*` を返しま
す:

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

## タスク 5。症状:EC2 では `running` だが `kubectl get nodes` にはない

インスタンスの起動後、ブートと bootstrap のために 3-5 分待ち、それから 2 つの真実の
ソースを比較します。

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

インスタンスは `running` ですが、ノードの一覧には存在しません - これがまさに第 45 章
を開く症状です。

## タスク 6。診断:ロールに何が欠けているか

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

ロール `eks-task119-test-node` の ARN は一覧に存在しません。このロールには managed
policy(`AmazonEKSWorkerNodePolicy`、`AmazonEC2ContainerRegistryReadOnly`)がありま
すが、クラスタ内の認可がありません - `EC2_LINUX` 型の access entry がなければ、
kubelet は認可を通過できません。

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/why_no_access_entry.txt <<EOF
Instance $INSTANCE_ID は EC2 で running ですが、kubectl get nodes には現れませんでし
た。理由は、ロール $ROLE_ARN には managed policy(AmazonEKSWorkerNodePolicy、
AmazonEC2ContainerRegistryReadOnly)があるものの、クラスタ内に access entry がないこと
です。ロールの IAM 権限と、クラスタ内でのロールの認可は別のものです(chapter 45.2)。
$CLUSTER に対する aws eks list-access-entries はこのロールを表示しません。managed
node group はそのようなエントリを自動的に作成しますが、self-managed ノードの場合は
EC2_LINUX 型の access entry を aws eks create-access-entry で手動で作成する必要があ
ります。
EOF
cat /var/work/tests/artifacts/6/why_no_access_entry.txt
```

## タスク 7。修復:`EC2_LINUX` 型の access entry

```bash
aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$ROLE_ARN" --type EC2_LINUX
```

ノードが登録され `Ready` に遷移するまで時間を与えます(access entry の作成後、通常
1-2 分。kubelet はすでに起動していて認可を待っていたため):

```bash
for i in $(seq 1 20); do
  kubectl get nodes -o wide | grep -q "$INSTANCE_ID" && break
  sleep 15
done
kubectl get nodes -o wide
```

クラスタ内でのノードの識別子は、`INSTANCE_ID` そのものではなく、インスタンスのプライ
ベート DNS 名です。特定のインスタンスに関する行を見つけるには、`PrivateDnsName` と照
合します:

```bash
NODE_NAME=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PrivateDnsName' --output text)
kubectl get node "$NODE_NAME"
```

ノードが一覧に現れることだけでなく、実際に `Ready` になるまで待ちます:登録直後は
`aws-node` が立ち上がる間、数十秒 `NotReady` のままです。それから証拠を記録します -
タスク 9 の後には、ノードもそのプライベート DNS 名もすでに存在しなくなります:

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

## タスク 8。確認:ノードが実際に pod を受け入れる

`Ready` は、まだノードが機能していることの証明にはなりません。そのノードに具体的に
pod をスケジュールします:

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

タスク 7 と同じ方法で証拠を記録します:この pod はこのノード上で生きており、タスク 9
でインスタンスが終了すると一緒に消えます。

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/probe.txt <<EOF
pod_phase=$(kubectl get pod probe -n eks-119 -o jsonpath='{.status.phase}')
pod_node=$(kubectl get pod probe -n eks-119 -o jsonpath='{.spec.nodeName}')
EOF
cat /var/work/tests/artifacts/8/probe.txt
```

## タスク 9。後片付け:self-managed インスタンスを終了する

この EC2 インスタンスはラボの terraform state の一部ではありません:`make
delete_eks_task` はこれに触れません。ラボを閉じる前に自分で終了させてください:

```bash
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/9
echo "terminated $INSTANCE_ID at $(date -u +%FT%TZ)" > /var/work/tests/artifacts/9/terminated.txt
```

access entry、テスト用ロール、instance profile も削除しておく価値があります:お金はか
かりませんが、名前が静的なので、`make delete_eks_task` の後もアカウントに残り続けま
す。順序が重要です - まず access entry、それからロールです:

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

## クイックチェック

```bash
check_result
```
