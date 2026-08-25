[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ132 - 参考解答（VPC CNIの上でCNI chainingモードで動くCilium）

すべてのコマンドはワークマシン（worker）上でSSH経由で実行します。kubectlとhelmはすでに
設定されています（kubeconfigはマシン起動時に`aws eks update-kubeconfig`で組み立てられ
ています）。

> Ciliumのバージョンとchainingモードのvaluesフラグの正確な名前はリリースごとに素早く
> 変わります。以下のコマンドはCilium `1.20.0`とEKS `1.36`の実際の環境で検証されていま
> す。別のバージョンを使う場合は、Ciliumのドキュメント
> （`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`）で構文を確認
> してください。

## タスク1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## タスク2. `cilium-demo`プール上の負荷、Ciliumなし

NodePool `cilium-demo`はすでにコードとして存在しています（taint
`dedicated=cilium-demo:NoSchedule`、label `work_type=cilium-demo`）。しかし
tolerationを持つpodが入るまでは、Karpenterは1つもノードを立ち上げません。Deployment
`api`と`client`は、最初から`nodeSelector`とtolerationを付けて作成し、そこに確実に
乗るようにします：

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

Karpenterはプール`cilium-demo`に新しいノードを立ち上げます（通常60-90秒）。
`rollout status`がReadyを確認したら、標準のVPC CNI経由で接続性を確認します - Ciliumは
まだインストールされていません：

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## タスク3. Helm経由でCNI chainingモードでCiliumを、`cilium-demo`にのみ

Ciliumのリポジトリを追加し、valuesファイルを準備します。重要なパラメータは
`cni.chainingMode: aws-cni`です：VPC CNI（`aws-node`）が主要なIPAMのままで、Ciliumは
チェーンに加わり、podの既に設定済みのインターフェースの上にeBPFプログラムを追加します。

3つの`nodeSelector`/`tolerations`ブロック（agent用のトップレベル、`envoy`、
`operator`）がCiliumのすべてのコンポーネントをプール`cilium-demo`に限定します。トップ
レベルの`nodeSelector`はDaemonSet `cilium`にのみ効きます。`cilium-envoy`と
`cilium-operator`には独自のセクションがあり、これがないとEnvoyのpodは他のすべての
ノードで`Pending`のまま止まり、`cilium status`は`Envoy DaemonSet: 1 errors`を表示
します。

別途`operator.unmanagedPodWatcher.restart`を無効にします。これはこのような環境では
必須のフラグであり、細かいチューニングではありません：デフォルトでは、operatorは15秒
ごとに`CiliumEndpoint`を持たないpodを削除し、再起動させてCNIのチェーンに入れようとし
ます。`coredns`のpodはFargate上で動作しており、そこにはCiliumのagentが存在せず、存在
することもできません。そのため決してmanagedにはなりません - operatorは無限にそれらを
殺し続け、毎回新しいFargateノードを立ち上げ、クラスタのDNSが壊れます（詳細は下の「
落とし穴」の節を参照）。

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

`api`と`client`のpodはCiliumのインストール前に起動されているため、CNI chainingは
まだそれらに効いていません（Ciliumのドキュメントはこれについて明確に警告しています：
既存のpodは再起動が必要です）。両方のDeploymentを再起動します：

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Cilium CLIをインストールし、状態を確認します：

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

出力には`Cilium: OK`、`Operator: OK`、`Envoy DaemonSet: OK`があるはずで、両方の
DaemonSetの`Desired`の数は`cilium-demo`のノード数と一致するはずです。

## タスク4. chainingの証明：アドレスは依然VPC CNIから

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

`api`と`client`のpodのIPはCIDR`10.10.0.0/16` - VPC自体と同じ範囲です。もしこれが
overlayモードでのVPC CNIの完全な置き換えだったら、アドレスはノードのサブネットではな
く、別の仮想プール（`cluster-pool`）から来ていたはずです。ここではIPAMは依然VPC CNI
の管理下にあります - これがchainingの本質です（第8章）。

## タスク5. L7ポリシー：GETのみ

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

許可されたGETとブロックされたPOSTを確認します：

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

GETは通ります（`HTTP_CODE=200`）、POSTはCiliumのEnvoyプロキシによってL7レベルで
ブロックされます（`HTTP_CODE=403`、リクエストがアプリケーションに届く前にアクセスが
拒否される）。組み込みのVPC CNI NetworkPolicyにはこのようなHTTPメソッドによるフィルタ
はありません - L3/L4だけです（第8章）。

完全な名前`ciliumnetworkpolicies.cilium.io`を使ってください：このクラスタでは短い
`cnp`はあいまいです。VPC CNIが自分のリソース
`clusternetworkpolicies.networking.k8s.aws`を持ち込むため、kubectlはこれについて警告
を出します。

## タスク6. FQDNポリシー：egressを`aws.amazon.com`のみに

このポリシーがドキュメントの典型的な例とは異なる振る舞いをする箇所が2つあります。

1つ目：DNSのルールをラベル`k8s-app: kube-dns`を使った`toEndpoints`で書くことはできま
せん。`toEndpoints`はCiliumのidentityに基づいて動作しますが、このクラスタの`coredns`
のpodはFargate上で動作しており、そこにはCiliumのagentがありません - それらは
`CiliumEndpoint`を持たず、`ipcache`に入らず、ポリシーの観点からは`reserved:world`とし
て見えます。ラベルによるルールは決してマッチせず、DNSはdefault-denyで閉じられ、
`curl`は名前解決すらできません。そのためDNSはCIDRで許可します：クラスタのサービス範囲
（`172.20.0.0/16`、ここにClusterIP `kube-dns`があります）とVPCのCIDR
（`10.10.0.0/16`、ここに`coredns`のpod自体があります）。`toCIDRSet`上のL7ルール
`rules.dns`は通常どおり機能します - これはまさにCiliumが外部DNSサーバーのケースを
説明している方法です。

2つ目：`app: client`に対する`endpointSelector`は、このpodの全egressに対して
default-denyを有効にします。`toFQDNs`とDNSだけを残すと、タスク5のGETから`api`への
アクセスが壊れます - そのパケットはドロップされます。そのため3番目のブロックで明示的
に`api:8080`へのegressを許可します。これにより環境の最終状態は整合します：タスク5と
タスク6が同時に成立します。

ブロックの順序は重要です：`toFQDNs`は最初（`egress[0]`）に残す必要があります。自動
テストはまさにそこを見ています。

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

確認します：

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

`aws.amazon.com`は解決され、`curl`は通ります - `HTTP_CODE=200`。`example.com`も解決
されます（DNSは許可されている）が、そのアドレスへのTCPセッションは`toFQDNs`に含まれ
ないため、パケットはドロップされ、`curl`は`--max-time`まで固まります -
`HTTP_CODE=000`。組み込みのVPC CNI NetworkPolicyにはこのようなDNS名によるポリシーは
まったくありません - IP/CIDRによる`ipBlock`だけです（第8章）。

## タスク7. Hubble：verdict付きのフロー可観測性

すでにインストールされているCiliumの上でHubble relayを有効にします。同じ
`nodeSelector`で`cilium-demo`に：

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

Hubble CLIをインストールします：

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

relay（`4245`）へのport-forwardを立ち上げ、タスク5と6でブロックされたリクエストを
繰り返して`DROPPED`イベントを取得し、フローを読みます：

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

port-forwardは必ず`setsid nohup ... </dev/null &`経由で起動してください：普通の
`kubectl port-forward &`はSSHセッションを保持し、セッションが終了すると中断されます。

ファイルにはverdict `DROPPED`を含む行が見つかるはずです - これは`example.com`の
アドレスへのドロップされたSYNです（`policy-verdict:none ... Policy denied
DROPPED`）。組み込みのVPC CNI network policyの診断には、このようなper-flow
verdict付きのフローマップはまったくありません - `aws-network-policy-agent`のログと
メトリクスだけです（第8章）。

## タスク8. 比較：このラボにおけるVPC CNI NPとCiliumの対比

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
組み込みのVPC CNI NetworkPolicyができること - Ciliumが追加したもの - 何を代償にした
か：

1. VPC CNI NetworkPolicyはL3/L4だけをカバーします。このラボでCiliumはHTTPメソッド
   によるL7ルールを追加しました：GETは許可（200）、POSTはEnvoyプロキシによって403で
   拒否されます。

2. VPC CNI NPにはDNS名によるポリシーがありません。CiliumはtoFQDNsを持つ
   CiliumNetworkPolicyを追加しました - egressはaws.amazon.comのみに許可され、
   example.comはドロップされます（HTTP_CODE=000）。

3. 組み込みのVPC CNI NPの診断はagentのログとメトリクスだけです。Ciliumは
   hubble observeを通じてper-flow verdict（FORWARDED/DROPPED）付きのフローマップ
   であるHubbleをもたらしました。

4. その代償：自分で運用するCiliumのHelm releaseとそのアップグレード、チームにとって
   の2つ目のCRDモデル、データパスの追加のレイヤー、そしてcilium-demoプールの外にある
   pod（例えばFargate上のcoredns）はCiliumのデータパスの外に留まり、ポリシー上では
   reserved:worldとしてしか見えず、labelによるルールは適用されないという点です。

5. VPC CNIの完全な置き換え（aws-nodeを削除し、Cilium自身がIPAMになる）はこのラボの
   範囲には含まれません：稼働中のクラスタでCNIを切り替えるのは、新しいノードを使った
   blue/green操作であり、稼働中にフラグを切り替えるようなものではありません（chapter 8、
   8.8節）。ここでは安全な方法であるCNI chainingだけを練習しました。
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## 簡易チェック

```bash
check_result
```

## このラボでよく引っかかる落とし穴

4つの項目すべて、実際の環境で検証済みです。

1. `cilium-operator`がクラスタのDNSを奪います。デフォルトでは
   `operator.unmanagedPodWatcher.restart=true`：operatorは15秒ごとに
   `CiliumEndpoint`を持たないpodを削除します。Fargate上の`coredns`は決してそれを
   持つことがないため、そのpodは無限に削除され続け、そのたびに新しいFargateの
   マイクロVMが生まれ、クラスタのDNSは不安定になります。pod側から見た症状：
   `nslookup`が`connection timed out; no servers could be reached`を返します。
   誰がpodを削除しているかは、control planeのauditログで確認できます：
   `coredns`のpodに対する`verb: delete`のレコードには
   `user.username = system:serviceaccount:kube-system:cilium-operator`と
   `userAgent = cilium-operator-generic/1.20.0`が記録されています。対処法は
   フラグ`operator.unmanagedPodWatcher.restart=false`です（`cilium-config`に
   `unmanaged-pod-watcher-interval: "0"`が現れます）。

2. Fargateプロファイルは`nodeSelector`を理解しません。プロファイルがnamespace
   `kube-system`全体をカバーしている場合
   （`selectors = [{ namespace = "kube-system" }]`）、Fargate webhookは、後で
   このnamespaceに追加するあらゆるpod（`cilium-operator`を含む）に自分のプロファ
   イルの印を付けます。その後、そのpodは`fargate-scheduler`だけがスケジュールし、
   これは`hostNetwork`も`nodeSelector`も対応しておらず、通常のschedulerに戻る
   こともありません。症状：`Pod not supported on Fargate: fields not supported:
   HostNetwork, port contains HostIP or HostPort`、そして
   `operator.hostNetwork=false`の後は
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's
   node selector/affinity requirements`。そのためこのラボでは、プロファイルは
   labelセレクタ`eks.amazonaws.com/component: coredns`に絞られています
   （`eks_fargate_system/terragrunt.hcl`を参照）。

3. Fargateプロファイルが再作成された場合 - それが引き受けるべきpodを再起動して
   ください。podのmutationはその作成時にのみ発生するため、新しいプロファイルが
   `ACTIVE`になる前に作成された`karpenter`のpodは、
   `0/N nodes are available: N node(s) had untolerated taint(s)`という状態で
   永久に`Pending`のままになります。対処法はこのpodに対して`kubectl delete pod`
   を実行することです。

4. トップレベルの`nodeSelector`だけを指定した場合、`cilium-envoy`のpodは
   `Pending`のまま止まります。DaemonSet `cilium-envoy`には独自のセクション
   `envoy.nodeSelector` / `envoy.tolerations`があります。これがないと、それは
   すべてのLinuxノードを対象にしてしまい、`cilium status`は
   `Envoy DaemonSet: 1 errors`を表示します。
