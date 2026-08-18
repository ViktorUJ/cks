[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 103 - 参考解答(アドレスプラン:ENI、prefix delegation、secondary CIDR)

すべてのコマンドはワーカーマシン(worker)上で SSH を通じて実行します。kubectl は既に
クラスタ向けに設定されています(kubeconfig はマシン起動時に `aws eks
update-kubeconfig` によって組み立てられます)。

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## タスク 1. 式による max-pods の計算と実際の値との照合

基本のワークロードを作成し、Karpenter が VPC CNI の通常(アドレスごと)モードで EC2
ノードを立ち上げるのを待ちます - アドオンはまだ prefix delegation に切り替わっていま
せん:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

このインスタンスタイプの ENI 数、ENI あたりの IP 数、vCPU を取得します:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

式 `max-pods = ENI * (ENI あたりの IP 数 - 1) + 2` で計算し、managed node group の
cap(`vCPU < 30` のとき `110`、それ以外は `250`)を適用します:

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

`m5.large` の例:`ENI=3`、`ENI あたりの IP 数=10` から `formula = 3*(10-1)+2 = 29` と
なり、cap `110` は影響しません(`29 < 110`)。つまり `expected_max_pods = 29` - これが
まさに `kubectl get node` が示すべき値です。

計算結果と実際の値をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/maxpods.txt <<EOF
node=$NODE
instance_type=$TYPE
eni=$ENI
ips_per_eni=$IPS
vcpu=$VCPU
formula=$FORMULA
cap=$CAP
expected_max_pods=$EXPECTED
actual_allocatable_pods=$ACTUAL
EOF
cat /var/work/tests/artifacts/1/maxpods.txt
```

`expected_max_pods` と `actual_allocatable_pods` が一致しない場合 - kubelet は
max-pods をノード起動時にしか知らないため、照合は既に完全に Ready になったノードで
行う必要があります。

## タスク 2. Prefix delegation:新しいノード対古いノード

prefix delegation を有効化する前に、古いノード(アドレスごとのモード)の状態を記録し
ます:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

managed addon `vpc-cni` で prefix delegation を有効化します(Nitro ベースのインスタン
スでのみ機能するため、NodePool がそれらのタイプを使っていることが重要です):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation は新しいノードにのみ関係します:古いノード `baseline` は起動時に
kubelet から既に `allocatable.pods` の上限を受け取っており、再作成されるまで再計算し
ません。古いノードに収まらないワークロードで、新しいノードの作成を促します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale
  namespace: eks-103
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "1"
            memory: "128Mi"
EOF

kubectl rollout status deployment/scale -n eks-103
```

新しいノードを特定し、上限を比較します:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

`m5.large` のプレフィックスモードの例:上限は `29` から `434` に跳ね上がります
(managed node group の cap `110` によって実際の上限は `110` になりますが、それでも
アドレスごとのモードの `29` よりはるかに大きい値です)。

比較結果と説明をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods が変わらなかったのは、kubelet が max-pods をノード起動時
に一度だけ計算し、prefix delegation は新しいノードにのみ影響し、既に動いているノード
には影響しないためです。new_node は prefix delegation を有効化した後に作成された
ため、その ENI は単独の IP ではなく /28 のプレフィックス(それぞれ 16 アドレス)を
占有しており、Pod 上限が明らかに高くなっています。
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## タスク 3. 成長を見据えたサブネットサイズの計画

最終的な需要を計算します:`850` 個の Pod、warm pool のために `20%` の余裕、さらに
ローリングアップデートのために `15%`(余裕は逐次的に乗算されます):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

結果:`850 * 1.20 = 1020`、`1020 * 1.15 = 1173` - 最終的な需要はおおよそ `1173` アド
レスです。サブネットプレフィックスごとの利用可能アドレスの表と照合します(AWS はサブ
ネットごとに `5` アドレスを予約します):

- `/24` - 合計 `256`、利用可能 `251` - `1173` より少なく、合わない;
- `/22` - 合計 `1024`、利用可能 `1019` - こちらも `1173` より少なく、合わない;
- `/20` - 合計 `4096`、利用可能 `4091` - 大きな余裕をもって十分。

`4091 / 1173 ≈ 3.5` 倍の余裕があり、現在の計算と将来の成長の両方をカバーするため、
`/20` を選びます。

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
需要: 850 個の Pod * 1.20 (warm pool の余裕) * 1.15 (rolling update の余裕)
= 1173 アドレス (最終的なアドレス需要)。

/24 (合計 256、利用可能 251) - 合わない、利用可能が需要より少ない。
/22 (合計 1024、利用可能 1019) - 合わない、利用可能が需要 (1173) より少ない。
/20 (合計 4096、利用可能 4091) - 合う: 4091 / 1173 ~= 3.5 倍の余裕。

選択: /20。Karpenter の warm pool と同時進行のローリングアップデートは短時間、
余分なアドレスを占有し続けるため、サブネットは一時的なピークよりも明らかに大きく
しておく必要があり、1173 アドレスにぎりぎり合わせるべきではありません。
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## タスク 4. Secondary CIDR:VPC のアドレスプランを拡張する

クラスタの `vpc-id` を確認し、RFC 6598 の shared address space から secondary CIDR を
接続します(`100.64.0.0/16` はこの VPC のプライマリ CIDR `10.10.0.0/16` と重複しませ
ん):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

`associated` 状態になるまで待ちます(呼び出しの直後はブロックが `associating` かも
しれません):

```bash
until aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text | grep -q associated; do
  echo "waiting for secondary CIDR to become associated..."
  sleep 5
done

aws ec2 describe-vpcs --vpc-ids "$VPC" \
  --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}'
```

新しいブロック内にサブネットを作成します:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

結果をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "secondary_cidr=100.64.0.0/16"
  aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}' \
    --output table
  echo "subnet_id=$SUBNET"
} > /var/work/tests/artifacts/4/secondary_cidr.txt
cat /var/work/tests/artifacts/4/secondary_cidr.txt
```

`100.64.0.0/16` の代わりに `172.16.0.0/12` や `192.168.0.0/16` を試したとしたら -
プライマリ CIDR が既に `10.0.0.0/8` の範囲にある VPC には AWS が追加を許可しません
(RFC 1918 のプライベートレンジの重複)。そのため通常はまさに RFC 6598 が使われます。

## タスク 5. アドレス不足の診断(実際の障害を起こさずに)

ラボのインフラストラクチャには触れません:サブネットを削ったり、アドレスを人為的に
使い切ったりはしません。クラスタのサブネットの現在の状態を見ます - これは稼働中の
クラスタでアドレス不足を診断するのと同じコマンドです:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

アドレス不足診断の説明をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
稼働中のクラスタで IP アドレス不足を診断する方法:

1. Pod 上の症状: kubectl describe pod は Events に aws-cni からの
   FailedCreatePodSandBox イベントを表示する - これは VPC CNI がアドレスを割り当て
   られなかった最初のシグナルです。

2. サブネットにおける全体的なアドレス不足: aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' -
   その AZ の AvailableIpAddressCount が 0 であれば、その サブネットと AZ における
   アドレス枯渇の直接的な診断結果です。

3. 実際の不足ではなく断片化: prefix delegation が有効なのに、サブネット内に連続した
   /28 ブロックがない場合(アドレスが個々に占有された IP に分散している)、
   ipamd/aws-node のログに InsufficientCidrBlocks エラーが出ます。これはサブネット
   の AvailableIpAddressCount が大きく見えていても起こります。これは同じ外部症状
   (Pod がアドレスを取得できない)の異なる原因であり、対処方法も異なります:アドレス
   不足は CIDR の拡張や secondary CIDR の追加(タスク 4)で対処し、断片化は連続した
   ブロックのためのスペースの解放や新しいサブネットの作成で対処します。
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## クイックチェック

```bash
check_result
```
