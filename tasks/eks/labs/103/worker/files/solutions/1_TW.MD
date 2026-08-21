[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 103 - 參考解答(位址規劃:ENI、prefix delegation、secondary CIDR)

所有指令都在工作機(worker)上透過 SSH 執行。kubectl 已經設定好連接叢集(kubeconfig 是
機器開機時透過 `aws eks update-kubeconfig` 組裝的)。

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## 任務 1. 用公式計算 max-pods 並與實際值核對

建立基礎工作負載,等待 Karpenter 為它建立一個處於一般(按位址)VPC CNI 模式的 EC2 節點 -
add-on 尚未切換到 prefix delegation:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

取得這個 instance 類型的 ENI 數量、每個 ENI 的 IP 數與 vCPU:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

用公式 `max-pods = ENI * (每個 ENI 的 IP 數 - 1) + 2` 計算,並套用 managed node group 的
上限(`vCPU < 30` 時為 `110`,否則為 `250`):

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

以 `m5.large` 為例:`ENI=3`、`每個 ENI 的 IP 數=10` 得出 `formula = 3*(10-1)+2 = 29`,
上限 `110` 不會產生影響(`29 < 110`),所以 `expected_max_pods = 29` - 這正是
`kubectl get node` 應該顯示的結果。

將計算結果與實際值儲存為產物:

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

如果 `expected_max_pods` 和 `actual_allocatable_pods` 不一致 - kubelet 只在節點啟動時
才會知道 max-pods,因此核對必須在一個已經完全 Ready 的節點上進行。

## 任務 2. Prefix delegation:新節點對比舊節點

在啟用 prefix delegation 之前,先記錄舊節點(按位址模式)的狀態:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

在 managed add-on `vpc-cni` 上啟用 prefix delegation(只在基於 Nitro 的 instance 上
生效,因此 NodePool 使用這類機型很重要):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation 只會影響新節點:舊節點 `baseline` 在啟動時就已經從 kubelet 取得了
`allocatable.pods` 的上限,在被重建之前不會重新計算。用一個塞不進舊節點的工作負載,促使
新節點被建立:

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

找出新節點並比較上限:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

以 `m5.large` 在前綴模式下為例:上限從 `29` 跳到 `434`(受 managed node group 上限
`110` 限制,因此實際上限是 `110`,但仍遠高於按位址模式的 `29`)。

將比較結果與說明儲存為產物:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods 沒有改變,因為 kubelet 只在節點啟動時計算一次 max-pods,
而 prefix delegation 只影響新節點,不會影響已經在運行的節點。new_node 是在啟用
prefix delegation 之後才建立的,所以它的 ENI 佔用的是 /28 前綴(每個 16 個位址),
而不是單獨的 IP,因此 pod 上限明顯更高。
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## 任務 3. 為成長規劃子網路大小

計算最終需求:`850` 個 pod,`20%` 的緩衝給 warm pool,再加 `15%` 給 rolling
update(緩衝依序相乘):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

結果:`850 * 1.20 = 1020`,`1020 * 1.15 = 1173` - 最終需求大約是 `1173` 個位址。與
每種子網路前綴的可用位址表對照(AWS 每個子網路會保留 `5` 個位址):

- `/24` - 總共 `256`,可用 `251` - 少於 `1173`,不合適;
- `/22` - 總共 `1024`,可用 `1019` - 同樣少於 `1173`,不合適;
- `/20` - 總共 `4096`,可用 `4091` - 有很大的餘裕,綽綽有餘。

`4091 / 1173 ≈ 3.5` 倍的緩衝,足以涵蓋目前的計算和未來的成長,因此選擇 `/20`。

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
需求:850 個 pod * 1.20(warm pool 緩衝) * 1.15(rolling update 緩衝)
= 1173 個位址(最終位址需求)。

/24(總共 256,可用 251) - 不合適,可用量小於需求。
/22(總共 1024,可用 1019) - 不合適,可用量小於需求(1173)。
/20(總共 4096,可用 4091) - 合適:4091 / 1173 ~= 3.5 倍緩衝。

選擇:/20。Karpenter 的 warm pool 與同時進行的 rolling update 會短暫佔用額外的
位址,因此子網路必須明顯大於單點高峰,而不是剛好卡在 1173 個位址上。
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## 任務 4. Secondary CIDR:擴展 VPC 的位址規劃

找出叢集的 `vpc-id`,並掛上一個來自 RFC 6598 shared address space 的 secondary
CIDR(`100.64.0.0/16` 不會與這個 VPC 的主要 CIDR `10.10.0.0/16` 重疊):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

等待狀態變為 `associated`(呼叫之後區塊可能暫時處於 `associating`):

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

在新的區塊中建立子網路:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

將結果儲存為產物:

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

如果我們嘗試用 `172.16.0.0/12` 或 `192.168.0.0/16` 取代 `100.64.0.0/16` - AWS 不會
允許把它們加到一個主要 CIDR 已經在 `10.0.0.0/8` 範圍內的 VPC 上(與 RFC 1918 私有範圍
重疊),所以通常會選用 RFC 6598。

## 任務 5. 診斷位址不足(不造成真正的失敗)

不要動這一課的基礎設施:不縮減子網路,也不人為耗盡位址。查看叢集子網路目前的狀態 -
這正是用來診斷正在運行的叢集位址不足的相同指令:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

將位址不足診斷的說明儲存為產物:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
如何在正在運行的叢集上診斷 IP 位址不足:

1. pod 上的徵兆:kubectl describe pod 會在 Events 中顯示來自 aws-cni 的
   FailedCreatePodSandBox 事件 - 這是 VPC CNI 無法分配位址的第一個訊號。

2. 子網路整體位址不足:aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' -
   如果某個 AZ 的 AvailableIpAddressCount 為 0,這就是該子網路和該 AZ 位址耗盡的
   直接診斷結論。

3. 碎片化而非真正不足:如果啟用了 prefix delegation,但子網路中沒有連續的 /28
   區塊(位址被單獨佔用的 IP 分散開來),ipamd/aws-node 的日誌中會出現
   InsufficientCidrBlocks 錯誤,即使子網路的 AvailableIpAddressCount 看起來很
   大。這是同一個外部徵兆(pod 無法取得位址)的不同原因,解決方式也不同:位址不足
   要透過擴展 CIDR 或增加 secondary CIDR 來解決(任務 4),碎片化則要透過釋放空間
   給連續區塊,或建立新的子網路來解決。
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## 快速檢查

```bash
check_result
```
