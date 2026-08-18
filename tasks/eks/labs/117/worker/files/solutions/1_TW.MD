[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 117 - 參考解決方案(每個 AZ 一個 NAT 對比單一 NAT、VPC endpoint、cross-AZ)

所有命令都在工作機(worker)上透過 SSH 執行。kubectl 已經配置好對應的集群(工作機啟動
時就透過 `aws eks update-kubeconfig` 構建好了 kubeconfig)。

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## 任務 1。有多少個 NAT Gateway,分別在哪些 zone

這個實驗的網路設定成三個私有 AZ 中只有兩個帶有 NAT Gateway。先找到這個 VPC 中的所有
NAT Gateway:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

對每個 NAT,確定其子網所在的 AZ:

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

帶有 NAT 的兩個 AZ 是 `eu-central-1a` 和 `eu-central-1b`。`eu-central-1c` 中的私有子
網是存在的(它帶有 `karpenter.sh/discovery` 標籤,所以 Karpenter 可以把節點放進
去),但這個 zone 中沒有 NAT Gateway:

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

## 任務 2。重現 cross-AZ 陷阱

先找到子網 `private-subnet-3` 的路由表(它在 `eu-central-1c`,沒有 NAT):

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

把這張路由表的 `0.0.0.0/0` 路由指向鄰近 AZ 之一的 NAT Gateway - 我們選
`NAT1`(在 `eu-central-1a`),這正是創造出 cross-AZ 路徑的那一步:

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

創建一個明確要求 zone `eu-central-1c` 的負載,讓 Karpenter 在那裡拉起一個節點。映像
是 `curlimages/curl:latest`,配上一個休眠的 `command`:之後我們要用 `kubectl exec` 從
這個 pod 檢查 egress,所以容器需要一個 shell 和 `curl`:

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

檢查節點和它所在的 zone,然後從 pod 內部檢查 egress:

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

Egress 是通的(`200`),但這正是第 31 章中的陷阱:pod 位於 `eu-central-1c`,而它的封
包會先跨越 AZ 邊界抵達 `eu-central-1a` 中的 NAT,然後才真正出去。這一跳會被單獨計為
cross-AZ 流量,和 NAT 本身的處理費是分開的 - 也就是說同一個位元組被收了兩次錢。正確的
模式是每個有節點的 AZ 都要有一個 NAT Gateway(這個實驗中 `eu-central-1a` 和
`eu-central-1b` 已經是這樣做的),讓節點的流量在抵達 NAT 之前永遠不需要離開自己的
zone。

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

eu-central-1c 子網的 0.0.0.0/0 路由指向另一個 zone($NAT1_AZ)的 NAT Gateway,所以
eu-central-1c 中節點的所有出站流量都會走 cross-AZ:先是一次到 NAT 的跨 AZ 跳躍,然後
才是 NAT 本身的處理。這會被計費兩次 - 一次是跨 AZ(cross-AZ)流量,一次是 NAT 處理的
GB 數。正確的模式是每個有節點的 AZ 都要有一個 NAT Gateway,這樣流量就完全不需要跨越
zone 邊界。
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## 任務 3。S3 的 Gateway VPC endpoint - 一條免費路由

先找到全部三個私有子網的路由表:

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

為 S3 創建一個 gateway endpoint,並立即把它掛接到全部三個路由表:

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

S3 的 gateway endpoint 不會創建 ENI,也不按小時或處理的 GB 數收費 - 它只是一條路由
表條目,這使它成為第一個、也是最划算的優化步驟:

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

S3 的 gateway endpoint 只是一條路由表條目,完全免費(бесплат):既沒有按小時計費,也
沒有按處理資料量計費,這一點和 interface endpoint 不同。
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## 任務 4。高流量服務的 Interface VPC endpoint

選擇 `sts`:每個使用 IRSA 或 EKS Pod Identity 的 pod,在每次啟動和每次憑證刷新時,都
會透過 STS 把 token 換成臨時憑證,如果沒有 endpoint,這次交換每次都要走 NAT。(另一個
選項是 `ecr.api`:每次 pull 都要做映像倉庫授權;選任何一個都會被測試接受。)

取得預設 security group,並立即在其中放行來自 VPC CIDR 的 inbound HTTPS。沒有這條規
則,endpoint 會創建成功但無法連通:預設 security group 的 inbound 規則只允許來自同一
個 group 成員的流量,而 Karpenter 的節點和 pod 位於其他 group 中。

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

檢查這個 endpoint 是否真的能從集群內部得到回應 - `private_dns_enabled=true` 意味著
名稱 `sts.eu-central-1.amazonaws.com` 現在在整個 VPC 範圍內都會解析到 endpoint ENI
的私有位址,如果沒有添加 `443` 規則,STS 會在整個 VPC 中同時失效:

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

這個名稱解析到 `10.10.15.0/24` 和 `10.10.16.0/24` 中的位址(這些就是 endpoint 的
ENI),而 `curl` 回傳代碼 `302` - 這是透過 PrivateLink 得到的真實 STS 回應。代碼
`000` 加超時則意味著 endpoint 的 security group 沒有放行來自 pod 的流量。

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

選擇 sts:IRSA 和 EKS Pod Identity 在每次 pod 啟動和每次憑證刷新時都會透過 STS 把
token 換成臨時金鑰,這是一個高頻請求,沒有 endpoint 時它會走 NAT。Interface endpoint
把這部分流量從 NAT 中移走,代價是每個 AZ 中每個 ENI 的按小時計費,加上處理資料量的
費用。
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## 任務 5。NAT 指標:每個 gateway 通過了多少位元組

對每個 NAT(namespace `AWS/NATGateway`),取得最近幾小時 `BytesOutToDestination` 的
總和:

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

`NAT1` 正是任務 2 中 `eu-central-1c` 子網的路由所指向的那個 NAT Gateway。它同時接手
了自己 zone `eu-central-1a` 的正常流量,以及來自 `crossaz` 節點的 cross-AZ 流量,所以
在同一個時間窗口內,它的 `BytesOutToDestination` 預期會比只服務自己 AZ 的 `NAT2` 更
大:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

指標:AWS/NATGateway BytesOutToDestination,同一時段內各資料點之和。
NAT $NAT1 除了自己 zone 的正常流量之外,還接手了 eu-central-1c 中 crossaz 節點的
cross-AZ 流量(任務 2),所以預期它的 BytesOutToDestination 數值會比只服務自己 AZ 的
$NAT2 更大。
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

如果測試負載成功產生了明顯的流量(例如來自 `crossaz` pod 的重複 `curl` 請求),差異
在第一個指標窗口內就已經可見;如果負載只是一次性的,差異可能很小 - 重要的是接手
cross-AZ 節點的那個 NAT,其流量不小於另一個 NAT。

## 快速檢查

```bash
check_result
```
