[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 117 - 参考解答(AZ ごとの NAT と単一 NAT、VPC endpoint、cross-AZ)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl はマシンの起動時に
`aws eks update-kubeconfig` で構築済みで、すでにクラスタ用に設定されています。

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## タスク 1。NAT Gateway はいくつあり、どの zone にあるか

このラボのネットワークは、3 つの private AZ のうち 2 つだけに NAT Gateway があるように
設定されています。この VPC 内の NAT Gateway をすべて調べます:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

各 NAT について、その subnet の AZ を調べます:

```bash
NAT1=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[0].NatGatewayId' --output text)
NAT1_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT1" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT1_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT1_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

NAT2=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[1].NatGatewayId' --output text)
NAT2_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT2" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT2_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT2_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

echo "nat1=$NAT1 az=$NAT1_AZ / nat2=$NAT2 az=$NAT2_AZ"
```

NAT がある両方の AZ は `eu-central-1a` と `eu-central-1b` です。`eu-central-1c` の
private subnet は存在します(`karpenter.sh/discovery` タグが付いているので Karpenter は
そこにノードを配置できます)が、その zone には NAT Gateway がありません:

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/natdiscovery.txt <<EOF
nat_count=2
nat_1_id=$NAT1
nat_1_az=$NAT1_AZ
nat_2_id=$NAT2
nat_2_az=$NAT2_AZ
no_nat_az=eu-central-1c
EOF
cat /var/work/tests/artifacts/1/natdiscovery.txt
```

## タスク 2。cross-AZ の罠を再現する

subnet `private-subnet-3` の route table を調べます(これは `eu-central-1c` にあり、
NAT がありません):

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

この route table の `0.0.0.0/0` route を隣接する AZ の NAT Gateway に向けます -
`NAT1`(`eu-central-1a` にある)を使います。これがまさに cross-AZ パスを作り出すステッ
プです:

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

zone `eu-central-1c` を明示的に要求するワークロードを作成し、Karpenter がそこにノードを
立ち上げるようにします。イメージは `curlimages/curl:latest` で、`command` はスリープさ
せます:あとでこの Pod から `kubectl exec` で egress を確認するため、コンテナにはシェル
と `curl` が必要です:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crossaz
  namespace: eks-117
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crossaz
  template:
    metadata:
      labels:
        app: crossaz
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1c
      containers:
      - name: app
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/crossaz -n eks-117
```

ノードとその zone を確認し、続いて Pod の内側から egress を確認します:

```bash
POD=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
echo "node=$NODE zone=$NODE_ZONE"

HTTP_CODE=$(kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}' https://checkip.amazonaws.com)
echo "egress_http_code=$HTTP_CODE"
```

egress は動作します(`200`)が、これはまさに第 31 章の罠です:Pod は `eu-central-1c` に
存在しますが、そのパケットはまず AZ の境界を越えて `eu-central-1a` の NAT に渡り、そこ
から初めて外に出ます。このホップは、NAT 自体の処理料金とは別に cross-AZ トラフィックと
して課金されます - つまり同じバイトに対して二重に支払っていることになります。正しいパ
ターンは、ノードがある AZ ごとに NAT Gateway を用意すること(このラボでは
`eu-central-1a` と `eu-central-1b` ではすでにそうなっています)で、そうすればノードのト
ラフィックは NAT に到達する前に自分の zone を出ることがありません。

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

eu-central-1c の subnet の 0.0.0.0/0 route は別の zone($NAT1_AZ)の NAT Gateway を指し
ているため、eu-central-1c のノードからの outbound トラフィックはすべて cross-AZ にな
ります:まず inter-AZ ホップで NAT に渡り、それから NAT 自体での処理が行われます。これ
は二重に課金されます - inter-AZ(cross-AZ)トラフィックとして 1 回、NAT で処理されたギ
ガバイトとして 1 回です。正しいパターンは、ノードがある AZ ごとに NAT Gateway を用意す
ることで、そうすればトラフィックは zone の境界をまったく越えません。
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## タスク 3。S3 用の gateway VPC endpoint - 無料の route

3 つすべての private subnet の route table を調べます:

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

S3 用の gateway endpoint を作成し、すぐに 3 つすべての route table にアタッチします:

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Gateway --service-name com.amazonaws.eu-central-1.s3 \
  --route-table-ids "$RTB_A" "$RTB_B" "$RTB_C" \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the S3 endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
  --query 'VpcEndpoints[0].{State:State,RouteTableIds:RouteTableIds}'
```

S3 用の gateway endpoint は ENI を作成せず、時間単位でも処理したギガバイト単位でも課金
されません - これは単なる route table のエントリなので、最初で最もコスト効率の良い最
適化ステップです:

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

S3 用の gateway endpoint は単なる route table のエントリであり、無料(бесплат)です:
interface endpoint とは異なり、時間単位の料金もデータ処理単位の料金もありません。
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## タスク 4。高頻度サービス用の interface VPC endpoint

`sts` を選びます - IRSA または EKS Pod Identity を使うすべての Pod は、起動ごと、そして
credentials のリフレッシュごとに、自分のトークンを STS 経由で一時的な credentials に交
換します。endpoint がなければ、その交換は毎回 NAT を経由します。(代替として
`ecr.api` もあります:pull ごとの image registry authorization。どちらを選んでもテスト
は受け付けます。)

デフォルトの security group を使い、そこに VPC の CIDR からの inbound HTTPS をすぐに許
可します。この rule がないと、endpoint は作成されても到達不能になります:デフォルトの
security group の inbound rule は同じグループのメンバーからのトラフィックしか許可せ
ず、Karpenter のノードと Pod は別のグループに存在します。

```bash
SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" \
  "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 443 --cidr 10.10.0.0/16

STS_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Interface --service-name com.amazonaws.eu-central-1.sts \
  --subnet-ids "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-1" \
    --query 'Subnets[0].SubnetId' --output text)" \
    "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-2" \
    --query 'Subnets[0].SubnetId' --output text)" \
  --security-group-ids "$SG" --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the sts endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
  --query 'VpcEndpoints[0].{State:State,PrivateDnsEnabled:PrivateDnsEnabled}'
```

endpoint が実際にクラスタの内側から応答することを確認します - `private_dns_enabled=true`
は、`sts.eu-central-1.amazonaws.com` という名前が VPC 全体で endpoint の ENI のプライ
ベートアドレスに解決されるようになったことを意味します。もし `443` の rule が追加されて
いなければ、STS はすべての Pod に対して一斉に機能しなくなります:

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

その名前は `10.10.15.0/24` と `10.10.16.0/24`(これらは endpoint の ENI です)のアドレ
スに解決され、`curl` はコード `302` を返します - PrivateLink を経由した本物の STS の応
答です。コード `000` とタイムアウトは、endpoint の security group が Pod からのトラフ
ィックを通していないことを意味していたはずです。

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

sts を選択:IRSA と EKS Pod Identity は Pod の起動ごと、credentials のリフレッシュごと
にトークンを一時的な鍵に STS 経由で交換します。これは頻繁なリクエストであり、endpoint
がなければ NAT を経由します。interface endpoint はこのトラフィックを NAT から取り除き
ますが、代わりに各 AZ の ENI ごとの時間単位の料金と、処理したギガバイトに対する料金が
かかります。
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## タスク 5。NAT メトリクス:各 gateway を通過したバイト数

各 NAT について、直近数時間の `BytesOutToDestination` の合計を取得します(namespace
`AWS/NATGateway`):

```bash
START=$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

NAT_A_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT1" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_A_SUM" == "None" ]] && NAT_A_SUM=0

NAT_B_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT2" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_B_SUM" == "None" ]] && NAT_B_SUM=0

TOTAL=$(python3 -c "print(int(${NAT_A_SUM%.*}) + int(${NAT_B_SUM%.*}))")
echo "nat_a=$NAT1 sum=$NAT_A_SUM / nat_b=$NAT2 sum=$NAT_B_SUM / total=$TOTAL"
```

`NAT1` は、タスク 2 で `eu-central-1c` の subnet の route を向けた、まさにその NAT
Gateway です。この NAT は自分の zone `eu-central-1a` の通常のトラフィックに加えて、
`crossaz` ノードからの cross-AZ トラフィックも引き受けたため、同じ期間の
`BytesOutToDestination` の量が `NAT2`(自分の AZ だけを担当している)よりも大きくなる
と予想されます:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

メトリクス:AWS/NATGateway BytesOutToDestination、期間内のデータポイントの合計。
NAT $NAT1 は eu-central-1c の crossaz ノード(タスク 2)からの cross-AZ トラフィックを、
自分の zone の通常のトラフィックに加えて引き受けたため、自分の AZ だけを担当している
$NAT2 よりも大きな BytesOutToDestination の量を示すと予想されます。
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

テストワークロードが目に見えるトラフィックを発生させられた場合(例えば `crossaz` Pod
からの繰り返しの `curl` リクエスト)、合計の差は最初のメトリクスの期間ですでに見えていま
す。負荷が一度きりだった場合、差はわずかかもしれません - 重要なのは、cross-AZ ノードを
引き受けた NAT が、もう一方の NAT より小さくない量を示しているという事実です。

## クイックチェック

```bash
check_result
```
