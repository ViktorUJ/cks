[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 110 - 參考解答：gVisor、WireGuard 與 Istio STRICT

> 像考試中一樣工作：`kubectl`、`cilium` 與 `istioctl` 在工作機上執行，而對
> 節點的操作(containerd、tcpdump)則在節點本身上執行：用 `ssh <節點>` 登入，切換到 root
> (`sudo -i`)，執行指令，然後離開(`exit`、`exit`)。名稱 `gvisor-sandbox`、
> `runc-baseline`、`gvisor-echo`、`market-api`、`market-client`、`mesh-outside` 以及
> artifacts 的路徑，都是實驗可驗證約定的一部分。

## 在文件中哪裡可以找到範例

| 需要什麼 | 頁面與章節 |
| :--- | :--- |
| `/etc/containerd/config.toml` 中的 `runsc` 區段(`runtime_type = "io.containerd.runsc.v1"`)、重新啟動 containerd，以及帶有 `handler: runsc` 的 `RuntimeClass` YAML | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`、欄位 `scheduling.nodeSelector` 與 `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| 啟用 WireGuard(`encryption.enabled=true`、`encryption.type=wireguard`)並檢查(`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| 帶有 `mtls.mode: STRICT` 的 `PeerAuthentication` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. 還原 containerd runtime 並建立 RuntimeClass

節點 `k8s110_node_gvisor` 已經作為 dedicated pool 交付，並安裝了 `runsc`，但是
bootstrap 刻意從 `/etc/containerd/config.toml` 中移除了 `runsc` 的 runtime 區段 -
這是考試中典型的情況：二進位檔存在，但 containerd 不知道它。

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# 在 gVisor 節點上(root):二進位檔存在,containerd 為 active,設定中沒有 runsc 區段
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# 補寫 runsc 區段(runtime_type 的值必須精確)並重新啟動 containerd
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # 離開 root
exit   # 離開 gVisor 節點
```

不需要重新啟動 Kubelet:kubelet 會在每次建立 Pod 時，把 `RuntimeClass` 中的 handler 名稱傳給 containerd,
而不是在 kubelet 啟動時。

```yaml
# runtimeclass-gvisor.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass gvisor -o yaml
printf 'RuntimeClass gvisor: handler runsc\n' \
  > /var/work/tests/artifacts/1/runsc-runtime.txt
```

`scheduling.nodeSelector` 是重要的邊界：scheduler 不會把 `runsc` workload 指派到
沒有這個 handler 的 control-plane 上。同時 gVisor 節點被標上 taint
`sandbox.runtime/gvisor=true:NoSchedule`(`kubectl describe node <gvisor-節點> | grep Taints`):
除了能容忍它的 Pod 之外，沒有任何 Pod 會被排程到它上面。RuntimeClass 中的 `scheduling.tolerations`
會自動加到所有帶有這個 class 的 Pod 上，因此 `gvisor-sandbox` 能到達那裡，
而其他的不能。

## 2. 啟動 sandboxed Pod 與 Service

`busybox httpd` 同時為 `uname` 提供 shell，並為
節點間的 WireGuard 實驗提供小型的 HTTP endpoint。`runtimeClassName` 設在 Pod 上，而不是容器上。

Pod 中的 `nodeSelector` 與 `tolerations` 是明確設定的：這樣可以看出它被排程到哪個節點以及為什麼。
這與 `RuntimeClass` 自己的 `scheduling` 中描述的相同。如果在 Pod 中不指定它們，
也不會出問題：在建立帶有 `runtimeClassName` 的 Pod 時，Kubernetes 會自己從 `RuntimeClass.scheduling` 把
`nodeSelector` 與 `tolerations` **加入**其中(檢查：`kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`)。但那樣在 manifest 中就看不出來，而且如果 RuntimeClass 中沒有
`scheduling`,Pod 可能會被排程到沒有 `runsc` 的節點上而無法啟動。

```yaml
# gvisor-sandbox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-sandbox
  namespace: sandbox-110
  labels:
    app: gvisor-echo
spec:
  runtimeClassName: gvisor
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      mkdir -p /www
      printf 'CKS110-WIREGUARD-MARKER\n' >/www/index.html
      exec httpd -f -p 8080 -h /www
    ports:
    - containerPort: 8080
      name: http
---
apiVersion: v1
kind: Service
metadata:
  name: gvisor-echo
  namespace: sandbox-110
spec:
  selector:
    app: gvisor-echo
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f gvisor-sandbox.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/gvisor-sandbox --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf '\n--- gvisor dmesg ---\n'
  kubectl exec -n sandbox-110 gvisor-sandbox -- dmesg 2>&1 || true
} > /var/work/tests/artifacts/2/gvisor-kernel.txt
cat /var/work/tests/artifacts/2/gvisor-kernel.txt
kubectl get pod -n sandbox-110 gvisor-sandbox -o wide
```

gVisor Sentry 向 workload 顯示合成的 kernel view;`dmesg` 輸出的不是節點的
核心日誌，而是一段簡短的合成日誌，以 `Starting gVisor...` 這一行開頭(checker 正是等待這一行)。這是預期的，並不構成給容器額外 privileges 的理由。

## 3. 用來比較的一般 runc Pod

沒有 `runtimeClassName` 時，保留預設的 handler `runc`。Selector 刻意
把這個 Pod 放在 control-plane 上，因此後續任務會產生節點間
流量。

```yaml
# runc-baseline.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runc-baseline
  namespace: sandbox-110
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f runc-baseline.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/runc-baseline --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf 'runc uname -r: '
  kubectl exec -n sandbox-110 runc-baseline -- uname -r
} > /var/work/tests/artifacts/3/runtime-comparison.txt
cat /var/work/tests/artifacts/3/runtime-comparison.txt
```

一般的 `runc` 容器看到的是 host kernel release，而 gVisor workload 看到的是 Sentry view。
這是額外的執行邊界，而不是取代 `SecurityContext`、seccomp 或
image 檢查。

## 4. 啟用 Cilium WireGuard

Cilium 自己管理 WireGuard keys 與 peers。我們啟用一種加密 backend -
不加入 IPsec。重要：**用戶端**的 `cilium` CLI(安裝在 worker 上)沒有
子指令 `encrypt enable`;WireGuard 是透過 Cilium 設定啟用的，而不是
runtime 指令。首先記錄版本，並把 agent 與 requirements matrix 對照：

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf 'Kubernetes='
  kubectl version -o json | jq -r '.serverVersion.gitVersion'
  printf 'Cilium agent='
  kubectl -n kube-system get pod "$agent" -o jsonpath='{.spec.containers[?(@.name=="cilium-agent")].image}'
  printf '\n'
  cilium version --client
  printf 'Cilium CLI=v0.19.7\n'
  printf 'Cilium data plane=verify current supported lab build against Kubernetes 1.36 requirements matrix\n'
  printf 'Istio=1.30.4\n'
} > /var/work/tests/artifacts/4/tool-versions.txt
cat /var/work/tests/artifacts/4/tool-versions.txt
```

叢集是用指令 `cilium install` 部署的，它**透過 Helm** 安裝 Cilium。
長期的 source of truth 是 release `cilium` 的 Helm values；我們使用固定版本的 Cilium CLI upgrade，之後檢查 live 的 ConfigMap 與 agents:

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm 只更改 ConfigMap:DaemonSet 的 template 不變,因此 agents 自己
# 不會重新啟動,並繼續在沒有 WireGuard 的情況下運作 - 請明確重新啟動它們。
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

加密狀態透過 `cilium-dbg` 從 agent 讀取：這是隨 Cilium agent 一同提供的 in-pod debug CLI。本機的 `cilium` CLI 仍然是 install/cluster-level 的工具，不能在 Pod 內取代它。`cilium-dbg status` 「沒有」旗標 `--all-encryption`(在 1.20.x 中只有 `--all-addresses`、`--all-clusters`、`--all-controllers`、`--all-health`、`--all-nodes`、`--all-redirects`、`--verbose`) - 詳細的 peer/allowed-IP/remote-node evidence 是透過 `cilium-dbg debuginfo --output json` 取得，而不是透過不存在的旗標。

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf '$ cilium-dbg encrypt status
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg encrypt status
  printf '$ cilium-dbg debuginfo --output json
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg debuginfo --output json
} > /var/work/tests/artifacts/4/cilium-encrypt-status.txt
cat /var/work/tests/artifacts/4/cilium-encrypt-status.txt
grep -Eqi 'peer|allowed[ -]?ip|remote node' /var/work/tests/artifacts/4/cilium-encrypt-status.txt
```

## 5. 擷取節點間的 WireGuard 封包

WireGuard 預設使用 UDP/51871。「只」依 `udp port 51871` 過濾，會事先把
plaintext TCP 從結果中排除，因此「無法」證明它不存在 - 所以我們改用
同一個 capture 範圍(`host <remote-node-ip>`，不帶埠過濾)，並針對同一個節點間 flow
比較啟用 WireGuard 之前/之後。

在 `any` 上擷取「不是」觀察 on-wire 狀態的正確位置：`any` 也會看到內部的
Cilium 介面 `cilium_wg0`，依隧道的設計，「已經解密的」
流量會通過它。應該擷取通往遠端節點的實體 egress 介面(不是 `any`、`cilium_*`、
`lxc*`、`veth*`)。

需要兩個終端機：**終端機 1** - control-plane(在那裡執行 `tcpdump`),**終端機 2** -
工作機(請求與 `kubectl`)。

```bash
# 終端機 2(工作機):帶有 gVisor-Pod 的節點的 IP - 對 control-plane 而言是「遠端」節點
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# 終端機 1:登入 control-plane 並找出通往 remote_ip 的實體介面
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# 終端機 1(control-plane,root):填入終端機 2 中的 remote_ip 值
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- 介面(ens5),不是 any / cilium_* / lxc* / veth*
```

**Baseline:WireGuard 關閉**。暫時停用 WireGuard，並以「相同的」
capture 範圍重複「同一個」請求。最後務必恢復 `enable-wireguard: "true"`。

```bash
# 終端機 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# 終端機 1(control-plane,root):擷取 20 秒,然後立刻在終端機 2 中發出請求
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# 終端機 2:在擷取進行期間(最初的約 15 秒)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# 終端機 1(擷取結束之後):可以看到 plaintext marker,WireGuard 已關閉
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**之後：WireGuard 啟用**。恢復 WireGuard，並以「相同的」擷取範圍重複「同一個」請求：
現在必須能看到 WireGuard UDP/51871，而且不能有 marker。

```bash
# 終端機 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# 終端機 1(control-plane,root):擷取 20 秒
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# 終端機 2:在擷取進行期間
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# 終端機 1(擷取結束之後)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 終端機 2:取回 capture 供檢查
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

不要依據 Pod netns 中的 `tcpdump` 下結論：在那裡，位於 Cilium encryption point 之前的流量仍可能是
plaintext。這裡的證明，是在「同一個」capture 範圍下，從可見的 marker(WireGuard 已關閉)轉變為
它不存在(WireGuard 已啟用)。

## 6. Istio 與 PeerAuthentication STRICT

我們只以 minimal profile 安裝 Istio control plane。Namespace 事先設定了
`istio-injection=enabled`，因此 `market` 中的 workloads 在
建立時會取得 Envoy sidecar。`market-api` 位於 gVisor worker 上，client 則位於 control-plane 上，這
同樣使請求成為節點間的請求。

```bash
istioctl install --set profile=minimal -y
kubectl -n istio-system rollout status deployment/istiod --timeout=180s
kubectl get namespace market --show-labels
```

```yaml
# market-workloads.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-api}
  template:
    metadata:
      labels: {app: market-api}
    spec:
      nodeSelector:
        lab.cks.io/role: gvisor
      tolerations:
      - key: sandbox.runtime/gvisor
        operator: Equal
        value: "true"
        effect: NoSchedule
      automountServiceAccountToken: false
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-ec", "mkdir -p /www; printf 'market-110\\n' >/www/index.html; exec httpd -f -p 8080 -h /www"]
        ports:
        - containerPort: 8080
          name: http
        readinessProbe:
          httpGet:
            path: /
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: market-api
  namespace: market
spec:
  selector: {app: market-api}
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-client
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-client}
  template:
    metadata:
      labels: {app: market-client}
    spec:
      nodeSelector:
        lab.cks.io/role: control-plane
      automountServiceAccountToken: false
      containers:
      - name: app
        image: curlimages/curl:8.11.0
        command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: mesh-outside
  namespace: default
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: curlimages/curl:8.11.0
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f market-workloads.yaml
kubectl rollout status -n market deployment/market-api --timeout=180s
kubectl rollout status -n market deployment/market-client --timeout=180s
kubectl wait -n default --for=condition=Ready pod/mesh-outside --timeout=180s
kubectl get pods -n market

# Baseline(尚未套用 STRICT):mesh 外的 plaintext client 必須得到 200 -
# 這證明連通性原則上是正常的,而且之後任何拒絕
# 都正是由 STRICT mTLS 造成的,而不是獨立的 DNS/網路問題。
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# 預期:HTTP/1.1 200 OK,結尾為 exit_code=0
```

```yaml
# market-strict.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f market-strict.yaml
kubectl get peerauthentication -n market market-strict -o yaml

# 從 mesh 內部發出的請求(帶有 sidecar 的 client)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# 預期:HTTP/1.1 200 OK,結尾為 exit_code=0

# 從 mesh 外部發出的同一個請求(plaintext,沒有 sidecar)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# 預期:Recv failure: Connection reset by peer,結尾為 exit_code=56(不是 0)
```

`PeerAuthentication` 控制 inbound server mode。內部的 client 會取得
憑證並自動使用 mTLS;`default` 中的 Pod 沒有 sidecar，並傳送
plaintext，因此在 `STRICT` 下 Envoy server 會重設連線。最後執行：

```bash
check_result
```
