[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ124 - 参考解答（HPA、KEDA、Prometheus）

すべてのコマンドはワーカーマシン上でSSH経由で実行します。kubectlとhelmはすでに設定されています（kubeconfigはマシン起動時に`aws eks update-kubeconfig`で組み立てられます）。

## タスク1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## タスク2. namespace `monitoring`内のkube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

これら3つのフラグは装飾ではありません。このラボにはGrafanaやAlertmanagerは不要で、Grafanaはチャートの中で最も重いpodです（テストベンチで約325 MiB）。明示的な`requests`はPrometheusを`BestEffort`から`Burstable`に移します: schedulerと、`requests`の合計に基づいてノードのサイズを決めるKarpenterの両方が、そのニーズを認識できるようになります。これがなければ監視スタックは最も安いインスタンスに配置され、kubeletはメモリ不足時にPrometheusを退避させます - 詳しい解説はラボのREADMEを参照してください。

podが準備完了になるまで待ちます:

```bash
kubectl get pods -n monitoring -w
```

すべてのpodが`Running`かつ`1/1`（または`2/2`）Readyになるまで待ちます - 通常2〜3分かかります。KEDAが監視するServiceと、podのQoSクラスを確認します:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

2番目のコマンドの期待される出力は`Burstable`です。

## タスク3. namespace `keda`内のKEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

operatorとmetrics apiserverが起動していることを確認します:

```bash
kubectl get pods -n keda
```

期待される結果: `keda-operator-...`および`keda-operator-metrics-apiserver-...`のような名前のpodが`Running`状態であること。

## タスク4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## タスク5. `prometheus`スケーラーを使うScaledObject

cAdvisorメトリクス`container_cpu_usage_seconds_total`は、ServiceMonitorを必要とせずに、kube-prometheus-stackによってすべてのpodからそのまま収集されます。ここではタスク6の負荷ジェネレータのpodの合計CPU使用量を計算します。`demo-app`自体ではありません: このアプリケーションは他人の負荷に基づいてスケールし、通常のCPUベースのHPAはこれができません - 外部メトリクスはまさにこのために存在します。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

このクエリが実際に何かを返すかどうかは、クラスタから直接確認できます（まだジェネレータがない間は、結果は空になりますが、これは正常です - その場合KEDAはHPAにゼロを報告します）:

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

KEDAがScaledObjectを管理下に置き、HPAを作成したことを確認します:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

HPAの名前は`keda-hpa-demo-app`です - これはKEDAがHPAを置き換えるのではなく、内部で通常の`HorizontalPodAutoscaler`を作成・管理していることの証拠です。

## タスク6. 負荷テスト: スケールアップ

まず負荷をかける前の状態を記録します:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

負荷ジェネレータを作成します。これは独自のlabel（`app=stress-generator`）を持ちます - タスク5のPromQLクエリはNAMEでpodを選択しており、labelではないため、ジェネレータを`demo-app`のselectorに混ぜることは不要であり、むしろ有害です: selectorが重複する2つのDeploymentはアンチパターンです。`limits.cpu`は必須です、そうでなければ4つのCPUワーカーがkubeletからCPUを奪い、ノードが`NotReady`になります。`nodeSelector`が必要な理由は、`polinux/stress`が`amd64`用にしかビルドされていない一方で、このラボのNodePoolは`arm64`も許可しているためです:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

メトリクスとレプリカ数が増えていく様子を観察します:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

1〜2分待ちます（KEDAがPrometheusをポーリングし、HPAがレプリカ数を計算し、必要に応じてKarpenterがノードを追加します）。テストベンチではこのようになりました:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

`REPLICAS`が`1`より大きくなったらすぐに保存します:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## タスク7. 負荷の削除: スケールダウン

```bash
kubectl delete deployment stress-generator -n eks-124
```

ジェネレータのpodが消え、そのシリーズはPrometheusから消え、KEDAはHPAにゼロを報告します。`TARGETS`の値は約30秒でゼロに落ちますが、レプリカ数はそのまま維持されます: HPAのscaleDownの`stabilizationWindowSeconds`はデフォルトで300秒です。テストベンチでの計測 - メトリクスは06:40:07にゼロ、レプリカは06:44:40と06:45:07に`5 -> 2 -> 1`:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

`REPLICAS`が`1`に戻ったらすぐにアーティファクトを保存します:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## タスク8. 通常のHPAとKEDAが作成したHPAの比較

```bash
kubectl get hpa -A
```

出力を見ると、HPA `keda-hpa-demo-app`は列の内容としては通常のHPAと同一に見えます - 同じ`TARGETS`、`MINPODS`、`MAXPODS`、`REPLICAS`。唯一の違いは名前（プレフィックス`keda-hpa-`）と、誰がそれを`управляет`するか、つまり誰が管理・制御するかです: 通常のHPAはエンジニアが`HorizontalPodAutoscaler`マニフェストを通じて直接作成・編集しますが、`keda-hpa-demo-app`はKEDA operatorによって`ScaledObject`リソースに基づいて作成され`управляется`されます、つまり管理されます - `ScaledObject`を削除すると、KEDAはこのHPAも一緒に削除します。

説明をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
kubectl get hpa -Aの出力では、通常のHPAとHPA keda-hpa-demo-appは列の内容としては同一に見える:
TARGETS/MINPODS/MAXPODS/REPLICAS - 唯一の違いは名前とオブジェクトの出自である。

KEDAはHPAを置き換えるわけではない: KEDA operatorはScaledObjectを監視し、自ら
keda-hpa-<ScaledObject名>という名前の通常のHorizontalPodAutoscalerを作成し
управляет（管理・制御）する。一方でKEDAのmetrics adapterはexternal.metrics.k8s.io
経由でそこにメトリクス値を供給する。レプリカ数は常と同じHPAの仕組みによって計算される。
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## クイックチェック

```bash
check_result
```
