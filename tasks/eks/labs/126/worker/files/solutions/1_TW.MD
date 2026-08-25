[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 126 - 參考解答（security groups for pods）

所有指令都是在 worker 機器上透過 SSH 執行的，跟課程其他 lab 一樣：worker 角色已取得
建立 security group、為它加規則，以及把 `AmazonEKSVPCResourceController` 政策掛到叢集
角色上的權限（見 README「基礎架構」一節）。

整份解答共用的變數：

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## 任務 1。Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## 任務 2。檢查先決條件

找出 control plane 角色的名稱，並檢查已掛載的政策（在 worker 上執行）：

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

預設情況下它不存在（這個角色只有 `AmazonEKSClusterPolicy` 和加密政策），所以我們把它
掛上去：

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

這個政策要掛在 **control plane**（叢集）的角色上，不是 Karpenter 節點角色 - 正是它讓
EKS 能夠建立/刪除 branch ENI 並管理它們的 IP。

我們檢查三個 VPC CNI 變數 - 全部都已經由 terraform 透過 `vpc-cni` 附加元件的
`configuration` 設定好了：

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

預期輸出：`ENABLE_POD_ENI: true`、`POD_SECURITY_GROUP_ENFORCING_MODE: strict`、
`DISABLE_TCP_EARLY_DEMUX: true`。第一個啟用 trunk interface，第二個讓來自節點的流量
持續套用 pod SG 規則檢查（在 `standard` 模式下不會這樣，任務 4 中的症狀就不會出現），
第三個讓 `kubelet` 能夠對 branch ENI 上的 pod 開啟 TCP 連線。

儲存兩項確認結果：

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## 任務 3。不完整的 security group 與 SecurityGroupPolicy

在這個 lab 的 VPC 中建立 SG。重點是：不要設定 `karpenter.sh/discovery` 標籤，否則
EC2NodeClass 會把它當作節點 SG 選走：

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

我們暫時不加任何 `authorize-security-group-ingress` 或 `egress`：一個全新的 SG 只有
AWS 預設的 allow-all egress 和零條 inbound 規則 - 這正是會產生症狀的狀態。

建立 `SecurityGroupPolicy`：

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## 任務 4。症狀：Running，但永遠不 Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

pod 卡在 `0/1 Ready`，即使 phase 顯示 `Running` - branch ENI 已經建立，但 pod 的 SG
不讓 kubelet 探針通過。儲存診斷結果：

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

事件看起來是這樣的（已在測試台上驗證）：

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

我們確認這個 pod 確實在 branch ENI 上，而不是節點的 ENI 上：

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

這個註解會包含 `eniId`、`vlanId` 和一個類似 `trunk-assoc-...` 的 `associationID`，限制
會顯示 `vpc.amazonaws.com/pod-eni: 1`，介面類型會是 `branch`，並帶有跟 pod 相同的 IP。

## 任務 5。修復探針：來自節點 SG 的 inbound 規則

透過 `secured-app` 所在的節點，找出 Karpenter 節點的 SG（在 worker 上執行）：

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

在 pod 的 SG 中加入一條 inbound 規則：

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

等待探針通過並儲存結果：

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

現在 `READY` 應該會顯示 `1/1` - kubelet 現在可以在探針埠上連上 pod 的 branch ENI 了。

## 任務 6。診斷並修復 DNS

檢查從 `secured-app` 內部的解析情況。`viktoruj/ping_pong:latest` 這個 image 沒有任何
DNS 用的 shell 工具（基於 `scratch` 建置），所以我們用一個帶有相同標籤 `app: secured`
的獨立診斷 pod，這樣 `secured-sgp` 也會套用到它：

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

輸出是 `;; connection timed out; no servers could be reached`。重要的是要正確指出
原因：這裡的問題不是 egress，一個全新的 SG 有預設的 allow-all egress 規則，請求可以
順利離開。封包是在接收方的入站 (inbound) 一側被丟掉的，因為那邊沒有對應我們 SG 的規則。
這個 lab 中的 CoreDNS 運行在 Fargate 上，位於 cluster primary security group 之後：

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

我們在 cluster primary SG 上加入一條 inbound `53` TCP 和 UDP 規則，來源設為我們 pod 的
SG。這一條規則就足夠了，因為 security group 是 stateful 的：對一個被允許的 inbound
請求的回應會自動返回，不需要另外的規則。

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

我們再次檢查解析結果：

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

現在做第二步，遵循最小權限原則。pod SG 預設的 allow-all egress 意味著「這個 pod 可以
發出任何 outbound 流量」 - 對於一個擁有自己 security group 的 pod 來說，這正是我們原本
想要避免的。我們把 egress 收窄到 `53`，並確認 DNS 仍然可以運作：

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

建立產物：

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
修復前（dns_before.txt）：對 kubernetes.default 的 nslookup 失敗，錯誤是
";; connection timed out; no servers could be reached"。

原因不是 egress：一個全新的 security group ${SG_ID} 有預設的 allow-all egress
規則，pod 發出的請求可以順利離開。封包是在接收方的入站 (inbound) 一側被丟掉的 -
CoreDNS on Fargate 位於其後的 cluster primary security group ${CLUSTER_PRIMARY_SG}
沒有對我們 SG 的 inbound 規則。規則正好需要加在那裡，而且一條就夠：security group
是 stateful 的，對一個被允許的 inbound 請求的回應會自動返回。

修復方式：在 ${CLUSTER_PRIMARY_SG} 上加入 inbound 53 TCP 和 UDP，
source-group 為 ${SG_ID}。之後，nslookup 就能解析
kubernetes.default.svc.cluster.local（dns_after.txt）。

第二步：從 pod 的 SG 中移除了預設的 allow-all egress，改為加入一條明確的
egress 53 TCP 和 UDP 指向 ${CLUSTER_PRIMARY_SG}。DNS 仍然可以運作 - 這說明了
來源端的 egress 和接收端的 inbound 是兩條獨立的規則，為此並不需要允許 pod 所有
outbound 流量。
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## 任務 7。陷阱：同一個節點，不同的 security group

執行一個實驗：同一個節點上帶有不同 security group 的兩個 pod。為標籤 `app: other`
設定第二個 SG 和第二個 `SecurityGroupPolicy`：

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

我們找出 Deployment 的 pod（specifically 是那一個，不是診斷用的那些 pod - 它們也帶有
`app: secured` 標籤），並在它旁邊啟動一個帶有不同 SG 的 pod：

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

結果是 `wget: download timed out`：這個 pod 有自己的 SG，鄰居也有自己的 SG，而且沒有
任何規則允許它們之間的流量。加入規則後再重複一次：

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

現在請求成功了（`RC=0`）。這說明在 `strict` 模式下，pod 的 SG 規則即使在同一個節點
內部也會套用 - 兩個 pod 都有自己的 branch ENI，是規則決定了結果。建立產物：

```bash
{
  echo "=== 帶有 SecurityGroupPolicy secured-sgp 的 Deployment pod（branch ENI） ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== 帶有不同 security group（other-sgp）的 pod，同一個節點 ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== 加規則之前 ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== 加入來自第二個 SG 的 inbound 8080 規則之後 ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== CoreDNS 在哪裡 ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

實驗的結論。我們的 POD_SECURITY_GROUP_ENFORCING_MODE 是 strict，在這個模式下，
pod 的 security group 規則即使對同一個節點內部的流量也會套用：同一節點上帶有不同
SG 的兩個 pod 一開始無法連線（download timed out），加入一條 inbound 規則之後
就能連線。所以這裡的診斷思路是常規的 - 去看規則，而不是拓撲結構。

值得了解的對比（AWS 文件，standard 模式）：在 standard 模式下，pod 的 SG 規則
**不會**套用到同一節點上 pod 與服務之間的流量，包括 kubelet 和 nodeLocalDNS，
而同一節點上帶有不同 security group 的 pod 完全無法互通，因為它們處在不同的子網
中，彼此之間的路由被停用了。在那裡，同樣的情況無法用規則修復，只能把 pod 分散到
不同的節點上。這也正是為什麼 standard 模式無法重現任務 4 和 5 中的症狀：kubelet
探針會跳過 SG 規則，即使 security group 裡連一條 inbound 規則都沒有，readiness
也會通過。
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## 快速檢查

```bash
check_result
```
