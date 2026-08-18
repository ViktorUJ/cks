[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 114 - 参考解答(可観測性:Container Insights と Managed Prometheus)

すべてのコマンドはワーカーマシン(worker)上で SSH 経由で実行します。kubectl と helm は
すでに設定されています。Terraform は AMP workspace をすでに作成しており、その alias は
`~/lab114_hints.txt` に書かれています。

```bash
cat ~/lab114_hints.txt
```

## タスク 1。Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## タスク 2。症状:メトリクスがまったく取れない

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== kubectl top nodes ==="
  kubectl top nodes
  echo "=== kubectl top pods -A ==="
  kubectl top pods -A
} > /var/work/tests/artifacts/2/kubectl_top_before.txt 2>&1

cat /var/work/tests/artifacts/2/kubectl_top_before.txt
```

両方のコマンドが `error: Metrics API not available` で失敗します。metrics-server がまだ
インストールされていないため、Metrics API(`metrics.k8s.io`)が登録されていません。

## タスク 3。基本レイヤー:metrics-server アドオン

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

Metrics API が実際の数値を返すようになるまで待ちます(アドオンが `ACTIVE` になってから
通常 1-2 分かかります):

```bash
for i in $(seq 1 24); do
  out=$(kubectl top nodes 2>&1)
  if [[ "$out" != *"not available"* ]]; then
    break
  fi
  sleep 10
done

mkdir -p /var/work/tests/artifacts/3
kubectl top nodes > /var/work/tests/artifacts/3/kubectl_top_after.txt
cat /var/work/tests/artifacts/3/kubectl_top_after.txt
```

## タスク 4。Container Insights:amazon-cloudwatch-observability アドオン

アドオンには CloudWatch に送信する権限が必要です。EKS Pod Identity はクラスタの OIDC
プロバイダを使わないため、ロールの trust policy はサービス `pods.eks.amazonaws.com` を
直接信頼します:

```bash
ROLE_NAME="eks-task114-test-cw-agent"

cat > /tmp/trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }
  ]
}
EOF

aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "$ROLE_ARN"
```

この ServiceAccount に対する Pod Identity association を指定してアドオンをインストール
します:

```bash
aws eks create-addon --cluster-name "$CLUSTER_NAME" \
  --addon-name amazon-cloudwatch-observability \
  --pod-identity-associations serviceAccount=cloudwatch-agent,roleArn="$ROLE_ARN"

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" \
  --addon-name amazon-cloudwatch-observability

for i in $(seq 1 30); do
  running=$(kubectl get pods -n amazon-cloudwatch \
    -l app.kubernetes.io/name=cloudwatch-agent \
    -o jsonpath='{.items[*].status.phase}')
  [[ "$running" == *Running* ]] && break
  sleep 10
done

mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n amazon-cloudwatch > /var/work/tests/artifacts/4/cloudwatch_agent_pods.txt
cat /var/work/tests/artifacts/4/cloudwatch_agent_pods.txt
```

## タスク 5。kube-prometheus-stack:アプリケーションメトリクスの実際の収集

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` が重要です:これがないと Prometheus は
自分自身の Helm リリースの ServiceMonitor しか見えず、別の namespace の `ping-app` を
無視してしまいます。

メトリクスエンドポイントを持つアプリケーションと、それに対する ServiceMonitor を展開し
ます:

```bash
kubectl create deployment ping-app --image=viktoruj/ping_pong:latest --replicas=1 -n eks-114
kubectl rollout status deployment/ping-app -n eks-114

kubectl expose deployment ping-app -n eks-114 --port=9090 --target-port=9090 \
  --name=ping-app
kubectl label service ping-app -n eks-114 app=ping-app --overwrite

kubectl -n eks-114 patch service ping-app --type merge -p '
spec:
  ports:
    - name: metrics
      port: 9090
      targetPort: 9090
'

cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ping-app
  namespace: eks-114
spec:
  selector:
    matchLabels:
      app: ping-app
  endpoints:
    - port: metrics
      path: /metrics
EOF
```

Prometheus がターゲットを取り込むまで待ち(通常は 1 回のスクレイプサイクル、最大 1
分)、API 経由でメトリクスを取得します。`prometheus` コンテナのイメージは最小限で、
`wget` も `curl` も `which` すら含んでいません - HTTP リクエストのための `kubectl exec`
は機能しません。ポートをワーカーマシンに転送して、そこからリクエストする方が簡単です:

```bash
sleep 60

kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 5

mkdir -p /var/work/tests/artifacts/5
curl -s 'http://localhost:9090/api/v1/query?query=requests_total' \
  > /var/work/tests/artifacts/5/prom_query.txt
cat /var/work/tests/artifacts/5/prom_query.txt

kill "$PF_PID"
```

Prometheus のサービス名は `<リリース名>-prometheus` です(この解答ではリリース名が
`kube-prometheus-stack` なので、サービスは `kube-prometheus-stack-prometheus` になりま
す。ClusterIP を持たない headless サービスである `prometheus-operated` と混同しないで
ください)。

レスポンスは `"status":"success"` を含む JSON で、配列 `"result"` の各要素には
`"metric"` フィールドがあります - これは、アプリケーションのメトリクスが手動の
`scrape_config` ではなく ServiceMonitor 経由で Prometheus まで届いたことの確認です。

## タスク 6。Managed Prometheus:メトリクスを受け付ける準備ができた workspace

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

出力の `workspace.prometheusEndpoint` には `aps-workspaces.<region>.amazonaws.com` が
含まれています - これが remote-write 用のエンドポイントです。収集パイプライン自体
(managed collector や ADOT)はこのラボの範囲には含まれません:目的は、managed
Prometheus 互換のバックエンドがすでに作成されデータを受け付ける準備ができていること、
第 33 章にある Container Insights や self-managed kube-prometheus-stack と並ぶ第 3 の
メトリクス経路を示すことです。

## クイックチェック

```bash
check_result
```
