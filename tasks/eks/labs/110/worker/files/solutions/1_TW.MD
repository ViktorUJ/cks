[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 110 - 參考解答(VPC CNI 網路政策:預設拒絕、標籤、egress)

所有指令都在工作機上透過 SSH 執行。kubectl 已經配置好指向該集群(kubeconfig 是機器
啟動時透過 `aws eks update-kubeconfig` 構建的)。`enableNetworkPolicy` 已經透過
Terraform 在 `vpc-cni` 附加元件上啟用,因此 `aws-node` 中的 `aws-network-policy-agent`
代理在你開始任務之前就已經存在於節點上。

## 任務 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## 任務 2. 檢查強制執行器是否已啟用

我們檢查兩個事實:DaemonSet `aws-node` 中的代理容器,以及附加元件的配置旗標。

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

輸出應該包含 `aws-node` 中的容器 `aws-network-policy-agent`,以及附加元件配置中類似
`enableNetworkPolicy":"true"` 的一行。這確認了 control plane 與節點代理確實會強制
執行 `NetworkPolicy` 對象,而不只是把它當作一個 API 對象接受。

## 任務 3. 在任何政策之前的症狀:預設允許連通性

我們創建 `api`(伺服器)和 `client`(供 `kubectl exec curl` 使用),以及 `api` 的
Service:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

我們檢查連通性:`client` 應該能透過 Service 名稱連接到 `api`。

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

檔案應該包含 `HTTP_CODE=200`:在沒有任何政策的情況下,VPC CNI 允許所有東西向流量 -
集群中還沒有創建任何 `NetworkPolicy` 對象。

## 任務 4. 預設拒絕 ingress

我們拒絕所有進入 namespace `eks-110` 的入站流量:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

我們檢查 `client` 是否已經無法連接到 `api`(等待超時,避免卡住):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

檔案應該顯示 `HTTP_CODE=000`(連線未建立) - `podSelector: {}` 意味著「namespace 中
的每一個 pod」,而不帶 `ingress` 區塊的 `policyTypes: ["Ingress"]` 意味著「拒絕所有
入站流量」。這是一個經典的預設拒絕,由 `aws-network-policy-agent` 代理透過 eBPF 強制
執行。

## 任務 5. 依標籤允許:`app: frontend` -> `app: api`

我們新增一個政策,只允許帶有標籤 `app: frontend` 的 pod 對 `app: api` 的 pod 進行入站
流量,端口為 `8080`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

我們創建一個帶有正確標籤的客戶端(`frontend`)以及一個沒有該標籤的客戶端
(`client-other`),以便對比結果:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` 會自動設定標籤 `app: <name>`,因此 `frontend` 已經帶有
`app: frontend`,而 `client-other` 獲得的是 `app: client-other`(與規則不匹配)。

我們檢查這兩種情況:

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt` 應該顯示 `HTTP_CODE=200`(標籤與 `ingress.from` 中的
`podSelector` 規則匹配),而 `blocked_other.txt` 應該顯示 `HTTP_CODE=000`(任務 4 中
的 `default-deny-ingress` 仍然適用於每一個沒有明確允許規則的 pod)。

## 任務 6. 帶有 DNS 例外的 Egress

我們限制 `frontend` 的出站流量:只允許前往 `app: api` 的 pod 以及前往 DNS
(`kube-system`,端口 `53` UDP/TCP)的流量。其他一切(任何外部位址)都會被封鎖。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

我們檢查解析名稱 `api` 並存取它是否仍然可行(DNS 與允許的 egress 到 `api` pod 兩者都
需要):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` 確認了政策中的 `to.podSelector: app: api` 項目允許前往 `api` 的流量,
而 `kube-system` 中端口 `53` 的例外讓 `frontend` 能夠解析名稱。

現在我們檢查一個任意的外部位址(不在允許規則覆蓋範圍內)是否被封鎖:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` 確認了拒絕:`restrict-egress` 定義了 `app: frontend` 完整的允許目的地
清單,其他一切都會被拒絕(包括網際網路以及集群中除 `api` 之外的任何其他 pod)。

## 快速檢查

```bash
check_result
```
