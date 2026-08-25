[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 110 - 参考解答(VPC CNI ネットワークポリシー:default deny、ラベル、egress)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は既にクラスタ向けに
設定されています(kubeconfig はマシン起動時に `aws eks update-kubeconfig` で構築されて
います)。`enableNetworkPolicy` は Terraform を通じて `vpc-cni` アドオン上で既に有効に
なっているため、`aws-node` 内の `aws-network-policy-agent` エージェントは、タスクを
始める前から既にノード上に存在しています。

## タスク 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## タスク 2. エンフォーサーが有効になっていることの確認

エージェントのコンテナが DaemonSet `aws-node` に存在すること、そしてアドオンの設定
フラグの両方を確認します。

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

出力には `aws-node` にコンテナ `aws-network-policy-agent` が含まれ、アドオンの設定に
`enableNetworkPolicy":"true"` のような行が含まれているはずです。これは、control plane
とノードエージェントが `NetworkPolicy` オブジェクトを単なる API オブジェクトとして
受け入れるだけでなく、実際に強制していることを確認するものです。

## タスク 3. ポリシーがない状態での症状:デフォルトで接続が許可されている

`api`(サーバー)と `client`(`kubectl exec curl` 用)、そして `api` 用の Service を
作成します:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

接続を確認します:`client` は Service 名で `api` に到達できるはずです。

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

ファイルには `HTTP_CODE=200` が含まれているはずです:ポリシーが何もない状態では、
VPC CNI はすべての east-west トラフィックを許可します - クラスタにはまだ 1 つも
`NetworkPolicy` オブジェクトが作成されていません。

## タスク 4. デフォルトで ingress を拒否する

namespace `eks-110` へのすべてのインバウンドトラフィックを拒否します:

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

`client` がもはや `api` に到達できないことを確認します(ハングしないようタイムアウト
を待ちます):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

ファイルには `HTTP_CODE=000`(接続が確立されなかった)が表示されるはずです -
`podSelector: {}` は「namespace 内のすべての Pod」を意味し、`ingress` セクションのない
`policyTypes: ["Ingress"]` は「すべてのインバウンドトラフィックを拒否する」ことを
意味します。これは典型的な default deny であり、`aws-network-policy-agent` エージェント
が eBPF を通じて強制しています。

## タスク 5. ラベルによる許可:`app: frontend` -> `app: api`

`app: api` の Pod へのインバウンドトラフィックを、`app: frontend` ラベルを持つ Pod
からのみ、ポート `8080` で許可するポリシーを追加します:

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

正しいラベル(`frontend`)を持つクライアントと、それを持たないクライアント
(`client-other`)を作成し、結果を比較できるようにします:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` はラベル `app: <name>` を自動的に設定するため、`frontend`
には既に `app: frontend` が付いており、`client-other` には(ルールに一致しない)
`app: client-other` が付きます。

両方のケースを確認します:

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

`allowed_frontend.txt` には `HTTP_CODE=200` が表示されるはずです(ラベルが
`ingress.from` の `podSelector` ルールに一致したため)。一方 `blocked_other.txt` には
`HTTP_CODE=000` が表示されるはずです(明示的な許可ルールがないすべての Pod には、
タスク 4 の `default-deny-ingress` が依然として適用されるため)。

## タスク 6. DNS 例外付きの egress

`frontend` からのアウトバウンドトラフィックを制限します:`app: api` の Pod への
トラフィックと、DNS(`kube-system`、ポート `53` の UDP/TCP)へのトラフィックのみを
許可します。それ以外(任意の外部アドレス)はすべてブロックされます。

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

名前 `api` の解決と、それへのアクセスが依然として機能することを確認します(DNS と、
`api` Pod への許可された egress の両方が必要です):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` は、ポリシー内の `to.podSelector: app: api` のエントリが `api` への
トラフィックを許可していること、そして `kube-system` のポート `53` に対する例外が
`frontend` に名前を解決させていることを確認しています。

次に、許可ルールに含まれない任意の外部アドレスがブロックされることを確認します:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` は拒否を確認しています:`restrict-egress` は `app: frontend` に対する
許可された宛先の完全なリストを定義しており、それ以外はすべて拒否されます(インター
ネットも、`api` 以外のクラスタ内の他の Pod も含みます)。

## クイックチェック

```bash
check_result
```
