[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 132 - 參考解答（Cilium 在 CNI chaining 模式下疊加於 VPC CNI）

所有命令都在工作機（worker）上透過 SSH 執行。kubectl 和 helm 已經配置好（kubeconfig 是
機器啟動時透過 `aws eks update-kubeconfig` 建立的）。

> Cilium 的版本以及 chaining 模式 values 標誌的確切名稱在各版本之間變化很快。以下命令
> 已在使用 Cilium `1.20.0` 和 EKS `1.36` 的實際環境中驗證過。如果使用其他版本，請對照
> Cilium 文檔核對語法
> （`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`）。

## 任務 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## 任務 2. 在 `cilium-demo` 池上運行負載，但不安裝 Cilium

NodePool `cilium-demo` 已作為代碼存在（taint `dedicated=cilium-demo:NoSchedule`，
label `work_type=cilium-demo`），但只要沒有帶 toleration 的 pod 進入，Karpenter 就不會
拉起任何節點。我們直接用 `nodeSelector` 和 toleration 創建 Deployment `api` 和
`client`，讓它們正好落到那裡：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Karpenter 會在池 `cilium-demo` 中拉起一個新節點（通常 60-90 秒）。一旦
`rollout status` 確認就緒，我們就透過標準 VPC CNI 檢查連通性 - Cilium 還沒有安裝：

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## 任務 3. 透過 Helm 以 CNI chaining 模式安裝 Cilium，僅限於 `cilium-demo`

添加 Cilium 的倉庫並準備 values 檔案。關鍵參數是 `cni.chainingMode: aws-cni`：VPC
CNI（`aws-node`）仍然是主要的 IPAM，Cilium 加入鏈路，在 pod 已配置好的接口之上添加
eBPF 程式。

三個 `nodeSelector`/`tolerations` 區塊（頂層用於 agent，`envoy` 和 `operator`）將
Cilium 的所有組件限制在池 `cilium-demo` 中。頂層 `nodeSelector` 只作用於 DaemonSet
`cilium`；`cilium-envoy` 和 `cilium-operator` 有各自的區塊，沒有它們，Envoy 的 pod 會
在所有其他節點上卡在 `Pending`，`cilium status` 會顯示
`Envoy DaemonSet: 1 errors`。

另外要關閉 `operator.unmanagedPodWatcher.restart`。對這種環境來說，這是必須的標誌，
不是可選的微調：默認情況下，operator 每 15 秒刪除沒有 `CiliumEndpoint` 的 pod，讓它們
重啟並加入 CNI 鏈路。`coredns` 的 pod 運行在 Fargate 上，那裡沒有也不可能有 Cilium
agent，因此它們永遠不會成為 managed - operator 會無限地殺死它們，每次都拉起一個新的
Fargate 節點，集群的 DNS 就會癱瘓（詳情見下面的「常見問題」部分）。

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
envoy:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
  unmanagedPodWatcher:
    restart: false
EOF

helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

`api` 和 `client` 的 pod 是在安裝 Cilium 之前啟動的，因此 CNI chaining 尚未對它們生效
（Cilium 的文檔明確警告了這一點：現有 pod 需要重啟）。我們對兩個 Deployment 都執行
重啟：

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

安裝 Cilium CLI 並檢查狀態：

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"

mkdir -p /var/work/tests/artifacts/3
cilium status | tee /var/work/tests/artifacts/3/cilium_status.txt
```

輸出中應該有 `Cilium: OK`、`Operator: OK` 和 `Envoy DaemonSet: OK`，兩個 DaemonSet 的
`Desired` 數量應該與 `cilium-demo` 節點數量一致。

## 任務 4. 證明 chaining：地址仍來自 VPC CNI

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

`api` 和 `client` pod 的 IP 屬於 CIDR `10.10.0.0/16` - 與 VPC 本身相同的範圍。如果這是
以 overlay 模式完全替換 VPC CNI，地址會來自一個獨立的虛擬池（`cluster-pool`），而不是
節點的子網。這裡 IPAM 仍由 VPC CNI 負責 - 這正是 chaining 的本質（chapter 8）。

## 任務 5. L7 政策：只允許 GET

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-l7-allow-get
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/.*"
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-l7-allow-get -n eks-132
```

檢查允許的 GET 和被阻止的 POST：

```bash
mkdir -p /var/work/tests/artifacts/5
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_get.txt
cat /var/work/tests/artifacts/5/allowed_get.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 -X POST \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_post.txt || true
cat /var/work/tests/artifacts/5/blocked_post.txt
```

GET 通過（`HTTP_CODE=200`），POST 被 Cilium 的 Envoy 代理在 L7 層阻止
（`HTTP_CODE=403`，訪問在請求到達應用程式之前就被拒絕）。內建的 VPC CNI
NetworkPolicy 沒有這種按 HTTP 方法的過濾 - 只有 L3/L4（chapter 8）。

請使用完整名稱 `ciliumnetworkpolicies.cilium.io`：在這個集群中，短名稱 `cnp` 是有歧義
的，因為 VPC CNI 帶來了自己的資源 `clusternetworkpolicies.networking.k8s.aws`，kubectl
會對此發出警告。

## 任務 6. FQDN 政策：egress 只允許 `aws.amazon.com`

有兩處地方，這個政策的行為與文檔中的典型範例不同。

第一：不能透過帶標籤 `k8s-app: kube-dns` 的 `toEndpoints` 來寫 DNS 規則。
`toEndpoints` 按 Cilium 的 identity 工作，而這個集群中的 `coredns` pod 運行在
Fargate 上，那裡沒有 Cilium agent - 它們沒有 `CiliumEndpoint`，不會進入 `ipcache`，
從政策的角度看它們就是 `reserved:world`。按標籤的規則永遠不會匹配，DNS 會被
default-deny 阻止，`curl` 甚至無法解析域名。因此我們按 CIDR 允許 DNS：集群的服務範圍
（`172.20.0.0/16`，那裡有 ClusterIP `kube-dns`）和 VPC 的 CIDR（`10.10.0.0/16`，那裡
是 `coredns` 的 pod 本身）。`toCIDRSet` 上的 L7 規則 `rules.dns` 能正常工作 - Cilium
文檔正是這樣描述外部 DNS 伺服器場景的。

第二：`endpointSelector` 對 `app: client` 會對這個 pod 的整個 egress 啟用
default-deny。如果只留下 `toFQDNs` 和 DNS，任務 5 中到 `api` 的 GET 就會失敗 - 它的
封包會被丟棄。因此我們用第三個區塊明確允許 egress 到 `api:8080`。這樣環境的最終狀態
就是一致的：任務 5 和任務 6 同時成立。

區塊的順序很重要：`toFQDNs` 必須保持在第一位（`egress[0]`），自動測試正是檢查那裡。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-fqdn-allow-aws
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "aws.amazon.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toCIDRSet:
    - cidr: 172.20.0.0/16
    - cidr: 10.10.0.0/16
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toEndpoints:
    - matchLabels:
        app: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-fqdn-allow-aws -n eks-132
```

檢查：

```bash
mkdir -p /var/work/tests/artifacts/6
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://aws.amazon.com \
  > /var/work/tests/artifacts/6/allowed_fqdn.txt || true
cat /var/work/tests/artifacts/6/allowed_fqdn.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://example.com \
  > /var/work/tests/artifacts/6/blocked_other_domain.txt || true
cat /var/work/tests/artifacts/6/blocked_other_domain.txt
```

`aws.amazon.com` 能被解析，`curl` 通過 - `HTTP_CODE=200`。`example.com` 也能被解析
（DNS 是允許的），但到其地址的 TCP 連接不屬於 `toFQDNs`，封包會被丟棄，`curl` 會一直
掛起到 `--max-time` - `HTTP_CODE=000`。內建的 VPC CNI NetworkPolicy 完全沒有這種按
DNS 名稱的政策 - 只有按 IP/CIDR 的 `ipBlock`（chapter 8）。

## 任務 7. Hubble：帶 verdict 的流量可觀測性

在已安裝的 Cilium 之上啟用 Hubble relay，使用同樣指向 `cilium-demo` 的
`nodeSelector`：

```bash
cat <<'EOF' >> /tmp/cilium-values.yaml
hubble:
  relay:
    enabled: true
    nodeSelector:
      work_type: cilium-demo
    tolerations:
      - key: dedicated
        operator: Equal
        value: cilium-demo
        effect: NoSchedule
EOF

helm upgrade cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status deployment/hubble-relay --timeout=240s
```

安裝 Hubble CLI：

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

建立到 relay 的 port-forward（`4245`），重複任務 5 和 6 中被阻止的請求以獲得
`DROPPED` 事件，並讀取流量：

```bash
setsid nohup kubectl -n kube-system port-forward service/hubble-relay 4245:80 \
  </dev/null >/tmp/pf.log 2>&1 &
sleep 5

CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
for i in 1 2 3; do
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 -X POST \
    http://api.eks-132.svc.cluster.local:8080 >/dev/null 2>&1 || true
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
    https://example.com >/dev/null 2>&1 || true
done

mkdir -p /var/work/tests/artifacts/7
hubble observe --server localhost:4245 -n eks-132 --last 200 \
  | tee /var/work/tests/artifacts/7/hubble_denied.txt
grep -c DROPPED /var/work/tests/artifacts/7/hubble_denied.txt
```

一定要透過 `setsid nohup ... </dev/null &` 啟動 port-forward：普通的
`kubectl port-forward &` 會佔用 SSH 會話，會話一結束它就會中斷。

檔案中應該能看到帶 verdict `DROPPED` 的行 - 這些是到 `example.com` 地址的被丟棄的
SYN（`policy-verdict:none ... Policy denied DROPPED`）。內建的 VPC CNI network
policy 完全沒有這種帶 per-flow verdict 的流量地圖 - 只有 `aws-network-policy-agent`
的日誌和指標（chapter 8）。

## 任務 8. 比較：本實驗中的 VPC CNI NP 對比 Cilium

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
內建 VPC CNI NetworkPolicy 能做什麼 - Cilium 添加了什麼 - 代價是什麼：

1. VPC CNI NetworkPolicy 只覆蓋 L3/L4。本實驗中 Cilium 添加了按 HTTP 方法的 L7
   規則：GET 被允許（200），POST 被 Envoy 代理以 403 拒絕。

2. VPC CNI NP 沒有按 DNS 名稱的政策。Cilium 添加了帶 toFQDNs 的
   CiliumNetworkPolicy - egress 只允許到 aws.amazon.com，example.com 被丟棄
   （HTTP_CODE=000）。

3. 內建 VPC CNI NP 的診斷只有 agent 日誌和指標。Cilium 帶來了 Hubble：透過
   hubble observe 得到帶 per-flow verdict（FORWARDED/DROPPED）的流量地圖。

4. 代價：需要自己維護的 Cilium Helm release 及其升級，團隊需要面對第二套 CRD
   模型，數據路徑中多了一層，而且 cilium-demo 池之外的 pod（例如 Fargate 上的
   coredns）仍在 Cilium 的數據路徑之外，在政策中只顯示為 reserved:world - 按
   label 的規則對它們不適用。

5. 完全替換 VPC CNI（刪除 aws-node，Cilium 自身成為 IPAM）不在本實驗範圍內：在
   存活集群上更換 CNI 是透過新節點的 blue/green 操作，而不是臨時切換一個標誌
   （chapter 8，8.8 節）。這裡只練習了安全的方案 - CNI chaining。
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## 快速檢查

```bash
check_result
```

## 本實驗中常見的坑

以下四點都在實際環境中驗證過。

1. `cilium-operator` 會拖垮集群的 DNS。默認情況下
   `operator.unmanagedPodWatcher.restart=true`：operator 每 15 秒刪除沒有
   `CiliumEndpoint` 的 pod。Fargate 上的 `coredns` 永遠不會擁有它，因此它的 pod
   會被循環刪除，每次都會誕生一個新的 Fargate 微型 VM，集群的 DNS 時好時壞。從 pod
   一側的症狀是：`nslookup` 返回
   `connection timed out; no servers could be reached`。到底是誰在刪除 pod，可以
   在 control plane 的 audit 日誌中看到：對 `coredns` pod 的 `verb: delete` 記錄
   中，`user.username = system:serviceaccount:kube-system:cilium-operator`，
   `userAgent = cilium-operator-generic/1.20.0`。解決方法是設置標誌
   `operator.unmanagedPodWatcher.restart=false`（`cilium-config` 中會出現
   `unmanaged-pod-watcher-interval: "0"`）。

2. Fargate profile 不支援 `nodeSelector`。如果 profile 覆蓋整個 namespace
   `kube-system`（`selectors = [{ namespace = "kube-system" }]`），Fargate
   webhook 會給您之後添加到這個 namespace 的任何 pod 打上自己的 profile 標記，
   包括 `cilium-operator`。之後這個 pod 只能由 `fargate-scheduler` 調度，它不支援
   `hostNetwork`，也不支援 `nodeSelector`，且永遠不會回退到普通 scheduler。症狀：
   `Pod not supported on Fargate: fields not supported: HostNetwork, port
   contains HostIP or HostPort`，而在 `operator.hostNetwork=false` 之後則是
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's
   node selector/affinity requirements`。因此本實驗中 profile 被縮小到 label
   選擇器 `eks.amazonaws.com/component: coredns`（見
   `eks_fargate_system/terragrunt.hcl`）。

3. Fargate profile 被重建後 - 需要重啟它應該接管的 pod。pod 的 mutation 只發生
   在其創建的那一刻，因此在新 profile 變為 `ACTIVE` 之前創建的 `karpenter` pod
   會永久停留在 `Pending`，報錯 `0/N nodes are available: N node(s) had
   untolerated taint(s)`。解決方法是對這個 pod 執行 `kubectl delete pod`。

4. 如果只設置頂層 `nodeSelector`，`cilium-envoy` 的 pod 會卡在 `Pending`。
   DaemonSet `cilium-envoy` 有自己的區塊 `envoy.nodeSelector` /
   `envoy.tolerations`；沒有它，它會瞄準所有 Linux 節點，`cilium status` 會顯示
   `Envoy DaemonSet: 1 errors`。
