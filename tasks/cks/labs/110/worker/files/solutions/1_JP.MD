[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 110 - 参考解答: gVisor、WireGuard、Istio STRICT

> 試験と同じように作業します：`kubectl`、`cilium`、`istioctl` は作業マシンで実行し、ノードに対する操作
> (containerd、tcpdump) はノード自体で行います：`ssh <ノード>` で入り、root になり
> (`sudo -i`)、コマンドを実行して抜けます (`exit`、`exit`)。名前 `gvisor-sandbox`、
> `runc-baseline`、`gvisor-echo`、`market-api`、`market-client`、`mesh-outside` と、
> 成果物のパスは、実習の検証される契約の一部です。

## ドキュメントで例を見つける場所

| 必要なもの | ページとセクション |
| :--- | :--- |
| `/etc/containerd/config.toml` のセクション `runsc` (`runtime_type = "io.containerd.runsc.v1"`)、containerd の再起動、`handler: runsc` を持つ `RuntimeClass` の YAML | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`、フィールド `scheduling.nodeSelector` と `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| WireGuard を有効にし (`encryption.enabled=true`、`encryption.type=wireguard`)、確認する (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `mtls.mode: STRICT` を持つ `PeerAuthentication` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. containerd runtime を復元して RuntimeClass を作成する

ノード `k8s110_node_gvisor` は、`runsc` がインストールされた dedicated pool としてすでに用意されていますが、
bootstrap は `/etc/containerd/config.toml` から `runsc` の runtime セクションを意図的に取り除いています -
バイナリはあるのに containerd がそれを知らないという、試験で典型的な状況です。

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# gVisor ノードで (root): バイナリはあり、containerd は active で、設定に runsc のセクションはない
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# runsc のセクションを書き足し (runtime_type の値は正確でなければなりません) containerd を再起動する
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # root から
exit   # gVisor ノードから
```

kubelet を再起動する必要はありません：`RuntimeClass` は、kubelet の起動時ではなく、Pod を作成するたびに
containerd runtime handler を名前で呼び出します。

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

`scheduling.nodeSelector` は重要な境界です：scheduler は、そのような handler がない
control-plane に `runsc` の workload を割り当てません。一方、gVisor ノードには taint
`sandbox.runtime/gvisor=true:NoSchedule` が付けられています (`kubectl describe node <gvisor-ノード> | grep Taints`)：
それを許容する Pod 以外は、そこにスケジュールされません。RuntimeClass の `scheduling.tolerations` は、
このクラスを持つすべての Pod に自動的に追加されるため、`gvisor-sandbox` はそこに配置され、
その他の Pod は配置されません。

## 2. sandboxed Pod と Service を起動する

`busybox httpd` は、`uname` 用の shell と、WireGuard のノード間の実験のための小さな HTTP endpoint を
同時に提供します。`runtimeClassName` は、コンテナではなく Pod に適用されています。

`nodeSelector` と `tolerations` は Pod で明示的に設定されています：これで、どのノードに、なぜ配置されるのかが分かります。
これは `RuntimeClass` 自体の `scheduling` に記述されているものと同じです。Pod で指定しなくても
何も壊れません：`runtimeClassName` を持つ Pod を作成するとき、Kubernetes が `RuntimeClass.scheduling` から
`nodeSelector` と `tolerations` を自分で Pod に**追加します** (確認：`kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`)。しかしその場合、manifest にはそれが見えず、
RuntimeClass に `scheduling` がなければ、Pod は `runsc` のないノードに配置されて起動しない可能性があります。

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

gVisor Sentry は workload に合成された kernel view を見せます；`dmesg` は
制限されている場合があります。これは想定内であり、コンテナに余分な privileges を与える理由にはなりません。

## 3. 比較用の通常の runc Pod

`runtimeClassName` がなければ、デフォルトの handler `runc` のままです。Selector は意図的に
この Pod を control-plane に配置するため、次の課題はノード間の
トラフィックを生成します。

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

通常の `runc` コンテナはホストのカーネルの release を見ますが、gVisor の workload は Sentry の view を見ます。
これは実行の追加の境界であり、`SecurityContext`、seccomp、image の確認の
代わりではありません。

## 4. Cilium WireGuard を有効にする

Cilium は WireGuard の keys と peers を自分で管理します。暗号化の backend を 1 つだけ有効にします -
IPsec は追加しません。重要：**クライアント側**の `cilium` CLI (worker にインストール済み) には
サブコマンド `encrypt enable` がありません；WireGuard はランタイムのコマンドではなく、Cilium の設定を通じて
有効にします。まずバージョンを記録し、agent を requirements matrix と照合します：

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

クラスターは、Cilium を **Helm 経由で**インストールするコマンド `cilium install` でデプロイされています。
永続的な source of truth は、release `cilium` の Helm values です；固定された Cilium CLI の upgrade を使用し、その後で live の ConfigMap と agents を確認します：

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm は ConfigMap のみを変更します: DaemonSet のテンプレートは変わらないため、agents は
# 自分では再起動せず、WireGuard なしで動作し続けます - 明示的に再起動してください。
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

暗号化の status は、agent で `cilium-dbg` を通じて読み取ります：これは Cilium agent に同梱されている Pod 内の debug CLI です。ローカルの `cilium` CLI は install/cluster-level のツールのままで、Pod 内でのそれの代わりにはなりません。`cilium-dbg status` には `--all-encryption` フラグは「ありません」 (1.20.x で利用できるのは `--all-addresses`、`--all-clusters`、`--all-controllers`、`--all-health`、`--all-nodes`、`--all-redirects`、`--verbose` のみです) - 詳細な peer/allowed-IP/remote-node の evidence は、存在しないフラグではなく `cilium-dbg debuginfo --output json` で取得します。

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

## 5. ノード間の WireGuard パケットのキャプチャ

WireGuard はデフォルトで UDP/51871 を使用します。`udp port 51871` のみによるフィルターは、plaintext の TCP を結果から
あらかじめ除外するため、その不在を証明しません - 代わりに、
同じキャプチャ scope (`host <remote-node-ip>`、ポートフィルターなし) を使用し、同じノード間 flow について
WireGuard の有効化の前後を比較します。

`any` でのキャプチャは、on-wire の状態を観察する正しい地点ではありません：`any` は内部の
Cilium インターフェース `cilium_wg0` も見ますが、そこではトンネルの構造上、すでに復号されたトラフィックが
通ります。キャプチャすべきは、リモートノードへの物理的な egress インターフェースです (`any`、`cilium_*`、
`lxc*`、`veth*` ではありません)。

2 つのターミナルが必要です：**ターミナル 1** は control-plane (そこで `tcpdump`)、**ターミナル 2** は
作業マシン (リクエストと `kubectl`) です。

```bash
# ターミナル 2 (作業マシン): gVisor-Pod があるノードの IP - これが control-plane にとっての「リモート」ノードです
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# ターミナル 1: control-plane に入り、remote_ip への物理インターフェースを調べる
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# ターミナル 1 (control-plane、root): ターミナル 2 の remote_ip の値を入力します
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- インターフェース (ens5)、any / cilium_* / lxc* / veth* ではありません
```

**Baseline: WireGuard 無効。** 一時的に WireGuard を無効にして、同じリクエストを 同じ
capture scope で繰り返します。最後に必ず `enable-wireguard: "true"` を戻します。

```bash
# ターミナル 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# ターミナル 1 (control-plane、root): 20 秒キャプチャし、すぐにターミナル 2 でリクエストを実行します
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# ターミナル 2: キャプチャ中 (最初の約 15 秒)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# ターミナル 1 (キャプチャ終了後): plaintext の marker が見える、WireGuard は無効
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**After: WireGuard 有効。** WireGuard を復元し、同じリクエストを 同じ
キャプチャ scope で繰り返します：今度は WireGuard UDP/51871 が見え、marker はないはずです。

```bash
# ターミナル 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# ターミナル 1 (control-plane、root): 20 秒キャプチャ
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# ターミナル 2: キャプチャ中
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# ターミナル 1 (キャプチャ終了後)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # root から
exit   # control-plane から
```

```bash
# ターミナル 2: 確認用に capture を取得する
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

Pod netns での `tcpdump` から結論を出さないでください：そこでは、Cilium の encryption point の前のトラフィックは
まだ plaintext の可能性があります。ここでの証明は、同じ capture scope で、marker が見える状態 (WireGuard 無効) から
見えない状態 (WireGuard 有効) への移行です。

## 6. Istio と PeerAuthentication STRICT

Istio の control plane のみを minimal profile でインストールします。Namespace は
`istio-injection=enabled` で準備されているため、`market` の workloads は
作成時に Envoy sidecar を受け取ります。`market-api` は gVisor worker に、client は control-plane に配置され、
これにより、リクエストはノード間のものにもなります。

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

# Baseline (STRICT はまだ適用されていません): mesh の外の plaintext client は 200 を受け取るはずです -
# これは、接続性が原理的に機能していることを証明し、その後の拒否が、独立した DNS/network の問題ではなく、
# まさに STRICT mTLS によるものであることを示します。
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# 期待される結果: HTTP/1.1 200 OK と、末尾の exit_code=0
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

# mesh の内側からのリクエスト (sidecar を持つ client)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# 期待される結果: HTTP/1.1 200 OK と、末尾の exit_code=0

# 同じリクエストを mesh の外側から (plaintext、sidecar なし)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# 期待される結果: Recv failure: Connection reset by peer と、末尾の exit_code=56 (0 ではない)
```

`PeerAuthentication` は inbound の server mode を制御します。内部の client は
証明書を受け取り、mTLS を自動的に使用します；`default` の Pod は sidecar を持たず、
plaintext を送信するため、Envoy server は `STRICT` のもとで接続をリセットします。最後に次を実行します：

```bash
check_result
```
