[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 115 - 簡易解答

> Advanced/production track。CLI の正確なバージョン/フラグは、Cilium のリリースによって
> 異なる場合があります - 以下のどれかが文字どおりには動作しない場合は、`cilium install --help`/`cilium upgrade --help` を
> 確認してください。

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

## 2. kube-proxy の代替としての Cilium

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

> cilium-cli 0.19 の `cilium status` は、`KubeProxyReplacement`/`Encryption` の行を出力しません；
> それらは agent の Pod 内の `cilium-dbg status` が表示します (checker もそのように確認します)。

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

`403` (`000` ではない) は、Service ClusterIP 経由の API への TCP/TLS が kube-proxy なしで実際に動作していることを意味します；
トークンなしのリクエストなので、ここで `403` は想定どおりです。応答があったこと自体で十分です。

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

> `cilium upgrade` は ConfigMap のみを変更します：agent は再起動の後に `encryption.*` を適用します
> (それまでは `Encryption: Disabled` です)。

```
Encryption:             Wireguard       [NodeEncryption: Disabled, cilium_wg0 (Pubkey: ..., Port: 51871, Peers: 0)]
```

```bash
kubectl exec svc-check -- curl -sSk -o /dev/null -w 'api HTTP:%{http_code}\n' -m5 https://kubernetes.default.svc.cluster.local/
```

```
api HTTP:403
```

リグレッションはありません - 課題 2 と同じ結果です。

## 4. Cilium Mutual Authentication (SPIRE)

課題の最小限のものに加えた 3 つのパラメータは、まさにこの環境で必要です：

- `authentication.enabled=true` - これがないと chart は `spire.enabled=true` を拒否します
  (`SPIRE integration requires .Values.authentication.enabled=true ...`)。
- `install.server.dataStorage.enabled=false` - クラスターに StorageClass がないため、PVC
  `spire-data-spire-server-0` が永久に `Pending` のままになり、`spire-server-0` も `Pending` になります
  (実習には一時的なストレージで十分です)。
- `install.server.securityContext.runAsUser=0` - イメージ `spire-server` は uid 1000 で起動し、
  `root:755` の hostPath ディレクトリに `api.sock` を作成できません；サーバーは黙って
  endpoint を終了し、liveness プローブによって kill されます (`cilium-init` の `Waiting for spire-server to start...`)。

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

SPIRE の Pod は namespace `cilium-spire` にあります。インストールの直後に Cilium を再起動し、
agent と operator が、すでに動作している SPIRE に identities を再登録するようにします：

```bash
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s
kubectl -n kube-system rollout status deploy/cilium-operator --timeout=180s
cilium status --wait
kubectl delete pod svc-check --ignore-not-found
```

## 5. 必須の mutual authentication を持つ CiliumNetworkPolicy

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

ネガティブコントロールは `app-115` の**別の Pod** です：Pod 自身へのトラフィック (Service 経由を含む) は
Cilium が常に通すため、`backend` への `exec` は何も証明しません。

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

`ingress-115` の `client` は mutual authentication を通り (`auth list` の `spire` のエントリ)、
`200` を受け取ります；`app-115` の `intruder` は transport deny です (その identity に対する allow がありません)。
新しい client の最初のリクエストには数秒かかることがあります：SPIFFE-handshake が行われている間は SYN が破棄され、
その後の再送が通ります。

---

## 検証

```bash
check_result
```
