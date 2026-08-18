[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 120 - 參考解答(網路故障、負載平衡器目標不健康)

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經設定好指向叢集。
Terraform 已經建立好「損壞的」security group(元件 `eks_network_break_demo`)
以及給 AWS Load Balancer Controller 使用的 IRSA role(`eks_lbc_irsa`) - 名稱
和 id 都在 `~/lab120_hints.txt` 中。

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## 任務 1. Namespace 與這個實驗的工作負載

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## 任務 2. 基準連線與 SG 診斷

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

這裡的連線運作正常:node SG 允許叢集內 pod 之間的流量,而且 SG 是 stateful
的,所以這個請求的回應會自動通過(第 46.3 章)。我們來看看 `api` pod 的 ENI
上實際掛的是哪些 SG:

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

用哪個 filter 來找 ENI 很重要。使用 VPC CNI 時,pod 的 IP 是 node ENI 上的
**次要**位址,所以 filter `private-ip-address`(只看介面的主要位址)會回傳
`null`。你需要的是 `addresses.private-ip-address`,它會搜尋介面上所有的
位址:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## 任務 3. 安裝 AWS Load Balancer Controller

```bash
LBC_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER}-lbc-irsa" \
  --query 'Role.Arn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

這個環境有一個重要的細節:`kube-system` namespace 落在 Fargate profile 下,
所以 controller 的 pod 會在 Fargate 上執行,而 Fargate **沒有 IMDS**。沒有
IMDS,controller 就無法自行判斷 region 和 VPC,並且會失敗,顯示 `failed to
get VPC ID: ... ec2imds ... context deadline exceeded`。所以要明確設定
`region` 和 `vpcId`:

```bash
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## 任務 4. 症狀:NLB 目標不健康

我們把「損壞的」SG 設定為負載平衡器自己的 security group。一旦透過
annotation 明確指定了某個 SG,LBC 就不會再幫我們把缺少的 inbound 規則加到
node SG 上 - 這正是這個故障的成因(第 46.6 章):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  namespace: eks-120
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${SG_ID}
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl get svc api-lb -n eks-120 -w
```

我們等待外部位址出現,找到 target group,並檢查目標的健康狀態:

```bash
HOSTNAME=$(kubectl get svc api-lb -n eks-120 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table > /var/work/tests/artifacts/4/unhealthy.txt
cat /var/work/tests/artifacts/4/unhealthy.txt
```

所有目標都是 `unhealthy` - 負載平衡器的 SG 不讓 health check 通過到 node
SG,所以它也永遠到不了 `api` pod。

## 任務 5. 診斷:是誰的 SG 擋住了 health check

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

空列表證實了這一點:負載平衡器的 SG 沒有一條 inbound 規則。

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
負載平衡器的 security group(${SG_ID})透過 aws-load-balancer-security-groups
annotation 指派給 api-lb,且不包含任何 inbound 規則。來自 NLB 的 health check
會以一個新的 TCP 連線,從負載平衡器的 security group 送到 node 的 security
group(${NODE_SG}),目標是應用程式的 port 8080。node 的 security group 在
這個 port 上不允許來自負載平衡器 security group 的 inbound 流量,所以 health
check 會失敗,targets 會維持 unhealthy(第 46.6 章)。
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## 任務 6. 修復:authorize-security-group-ingress,目標變健康

兩條規則:允許 health check 與應用程式流量從負載平衡器的 SG 到 node SG,並在
port 80 上為客戶端開放 NLB 的 listener:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$NODE_SG" \
  --protocol tcp --port 8080 \
  --source-group "$SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0
```

我們等到目標變成 `healthy`(通常是 1-2 分鐘),並用 curl 驗證:

```bash
sleep 90

mkdir -p /var/work/tests/artifacts/6
{
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
  echo
  curl -s --max-time 5 "http://${HOSTNAME}"
} > /var/work/tests/artifacts/6/healthy.txt
cat /var/work/tests/artifacts/6/healthy.txt
```

## 任務 7. DNS 正常運作:對照檢查

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

我們用完整的 FQDN 來查詢內部名稱。透過 busybox 的 `nslookup` 查詢簡短的
`kubernetes.default` 會回傳 `NXDOMAIN`:這個 resolver 不會像一般 client
那樣,自動加上 `/etc/resolv.conf` 裡的 search domain,而這個回應很容易被
誤認為一個實際上不存在的 DNS 故障。

兩個名稱都能正常解析(`kubernetes.default.svc.cluster.local` 解析到
`kubernetes` service 的位址,`example.com` 解析到外部位址) - 在這個實驗
中,DNS 不是問題的來源(第 46.5、46.7 章),這一點和任務 4-6 中的 security
group 不同。

## 任務 8. 最終檢查清單:症狀 - 可能原因 - 該檢查什麼

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
症狀:NLB target group 中的 targets 為 unhealthy,api-lb service 回傳 503。
可能原因:負載平衡器的 security group 在 health check 的 port 上不允許
inbound 流量進到 node SG(第 46.6 章)。
該檢查什麼:aws elbv2 describe-target-health --target-group-arn <arn> 會顯示
TargetHealth.Reason=Target.FailedHealthChecks,而 aws ec2
describe-security-groups 會確認負載平衡器的 SG 沒有任何 inbound 規則。
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## 快速檢查

```bash
check_result
```
