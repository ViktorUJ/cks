[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 115 - 簡要解答

> Advanced/production track。確切的版本/CLI 旗標在不同的 Cilium
> 版本之間可能不同 - 如果下面的內容無法逐字運作,請檢查 `cilium install --help`/`cilium upgrade --help`。

## 1. Baseline

```bash
kubectl -n kube-system get ds kube-proxy
kubectl get nodes
```

```
Error from server (NotFound): daemonsets.apps "kube-proxy" not found
NAME              STATUS     ROLES           AGE   VERSION
ip-10-115-1-xxx   NotReady   control-plane   2m    v1.36.0
```

## 2. Cilium 作為 kube-proxy 的替代品

```bash
node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
cilium install --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443
cilium status --wait
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep KubeProxyReplacement
kubectl get nodes
```

> cilium-cli 0.19 的 `cilium status` 不會印出 `KubeProxyReplacement`/`Encryption` 這幾行;
> 它們由 agent Pod 內的 `cilium-dbg status` 顯示(checker 也是這樣檢查的)。

```
KubeProxyReplacement:   True   [ens5 10.115.1.x (Direct Routing)]
NAME              STATUS   ROLES           AGE   VERSION
ip-10-115-1-xxx   Ready    control-plane   4m    v1.36.0
```

```bash
kubectl run svc-check --image=curlimages/curl:8.11.1 --restart=Never --command -- sleep 300
kubectl wait --for=condition=Ready pod/svc-check --timeout=90s
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

`403`(不是 `000`)- 表示透過 Service ClusterIP 到 API 的 TCP/TLS 在沒有
kube-proxy 的情況下確實可以運作;這裡 `403` 是預期的,因為請求沒有 token,有回應這個事實本身就足夠了。

## 3. WireGuard encryption

```bash
cilium upgrade --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
cilium status --wait
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status | grep Encryption
```

> `cilium upgrade` 只更改 ConfigMap:agent 在重新啟動之後才會套用 `encryption.*`
> (在那之前是 `Encryption: Disabled`)。

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

沒有退化 - 與任務 2 的結果相同。

## 4. Cilium Mutual Authentication(SPIRE)

相對於任務中最小的設定,這個實驗台需要多三個參數:

- `authentication.enabled=true` - 沒有它,chart 會拒絕 `spire.enabled=true`
  (`SPIRE integration requires .Values.authentication.enabled=true ...`)。
- `install.server.dataStorage.enabled=false` - 叢集中沒有 StorageClass,因此 PVC
  `spire-data-spire-server-0` 永遠是 `Pending`,而 `spire-server-0` 也是 `Pending`
  (對實驗來說暫時性的儲存就足夠了)。
- `install.server.securityContext.runAsUser=0` - 映像 `spire-server` 以 uid 1000 啟動,
  無法在 `root:755` 的 hostPath 目錄中建立 `api.sock`;伺服器會悄悄地結束
  endpoint,並被 liveness-probe 殺掉(`cilium-init` 中的 `Waiting for spire-server to start...`)。

```bash
cilium upgrade --version 1.20.1 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$node_ip" \
  --set k8sServicePort=6443 \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set authentication.enabled=true \
  --set authentication.mutual.spire.enabled=true \
  --set authentication.mutual.spire.install.enabled=true \
  --set authentication.mutual.spire.install.server.dataStorage.enabled=false \
  --set authentication.mutual.spire.install.server.securityContext.runAsUser=0
kubectl -n cilium-spire rollout status statefulset/spire-server --timeout=300s
kubectl -n cilium-spire rollout status daemonset/spire-agent --timeout=300s
kubectl get pods -A | grep spire
```

```
cilium-spire   spire-agent-xxxxx    1/1     Running   0    2m
cilium-spire   spire-server-0       2/2     Running   0    2m
```

SPIRE 的 Pod 位於 namespace `cilium-spire`。安裝之後請立刻重新啟動 Cilium,
讓 agent 與 operator 在已經運作的 SPIRE 中重新註冊 identities:

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. 帶有強制 mutual authentication 的 CiliumNetworkPolicy

```bash
kubectl create ns ingress-115
kubectl create ns app-115
kubectl -n app-115 run backend --image=viktoruj/ping_pong:alpine -l app=backend --port=80 --env=SRV_PORT=80
kubectl -n app-115 expose pod backend --port=80
kubectl -n ingress-115 run client --image=curlimages/curl:8.11.1 -l role=client --command -- sleep 3600
kubectl -n app-115 wait --for=condition=Ready pod/backend --timeout=90s
kubectl -n ingress-115 wait --for=condition=Ready pod/client --timeout=90s

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-auth-required
  namespace: app-115
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: ingress-115
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
      authentication:
        mode: "required"
EOF
```

```
namespace/ingress-115 created
namespace/app-115 created
pod/backend created
service/backend exposed
pod/client created
ciliumnetworkpolicy.cilium.io/backend-auth-required created
```

## 6. Positive/negative control

Negative control - 是 `app-115` 中的**單獨 Pod**:Pod 對它自己的流量(包括
透過 Service)Cilium 永遠放行,因此在 `backend` 內做 `exec` 什麼也證明不了。

```bash
kubectl -n app-115 run intruder --image=curlimages/curl:8.11.1 --command -- sleep 3600
kubectl -n app-115 wait --for=condition=Ready pod/intruder --timeout=90s
sleep 20
kubectl -n ingress-115 exec client -- curl -sS -o /dev/null -w 'client HTTP:%{http_code}\n' -m10 http://backend.app-115.svc.cluster.local/
kubectl -n app-115 exec intruder -- curl -sS -o /dev/null -w 'intruder HTTP:%{http_code}\n' -m5 http://backend.app-115.svc.cluster.local/ || true
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg bpf auth list
```

```
client HTTP:200
curl: (28) Connection timed out after 5002 milliseconds
intruder HTTP:000
SRC IDENTITY   DST IDENTITY   REMOTE NODE ID   AUTH TYPE   EXPIRATION
11376          33174          0                spire       ...
```

來自 `ingress-115` 的 `client` 通過 mutual authentication(`auth list` 中有 `spire` 記錄),並
得到 `200`;來自 `app-115` 的 `intruder` - transport deny(沒有針對它的 identity 的 allow)。
新 client 的第一個請求可能需要幾秒鐘:在 SPIFFE-handshake 進行期間 SYN 會被丟棄,
然後重傳才通過。

---

## 檢查

```bash
check_result
```
