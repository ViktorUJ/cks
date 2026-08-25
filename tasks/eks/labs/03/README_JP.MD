[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)


# ラボ: KEDA と Prometheus によるアプリケーションの自動スケーリング

## 概要

このラボでは、**Prometheus** メトリクスに基づいて **KEDA**（Kubernetes Event-Driven Autoscaling）を使用し、Amazon EKS 上の Web アプリケーションを自動的にスケーリングする方法を示します。アプリケーションは独自のリクエストメトリクスをエクスポートし、Prometheus がそれを収集、KEDA が実際の毎秒リクエスト数（RPS）に応じてデプロイメントをスケールアップおよびスケールダウンします。

クラスターにはすでに **Karpenter** と 2 つの専用 NodePool が準備されています。
- `monitoring` — 監視スタック用（Prometheus、KEDA、metrics-server）
- `default` — テストアプリケーション用

**学習する内容:**
- Helm を使用して公式 Prometheus Operator（kube-prometheus-stack）をインストールする方法
- nodeAffinity と tolerations を使用してワークロードを専用ノードに固定する方法
- 迅速なアクセスのために LoadBalancer 経由で Prometheus を公開する方法
- ServiceMonitor を使用してアプリケーションのカスタムメトリクスを収集する方法
- KEDA をインストールし、Prometheus クエリに基づく ScaledObject を設定する方法
- 負荷を生成し、自動スケールアップ／スケールダウンを観察する方法
- クラウドリソース（LoadBalancer、Karpenter ノード）を正しく削除する方法

## 目次
- [環境の準備](#環境の準備)
  - [ラボの開始](#ラボの開始)
  - [作成されるリソース](#作成されるリソース)
  - [前提条件](#前提条件)
- [NodePool の確認](#nodepool-の確認)
- [監視スタックのインストール](#監視スタックのインストール)
  - [Prometheus Operator と metrics-server](#prometheus-operator-と-metrics-server)
  - [インストールの確認](#インストールの確認)
- [アプリケーションのデプロイ](#アプリケーションのデプロイ)
- [アプリケーションメトリクスの収集](#アプリケーションメトリクスの収集)
  - [ServiceMonitor の作成](#servicemonitor-の作成)
  - [ターゲットの確認](#ターゲットの確認)
  - [Prometheus でメトリクスを確認](#prometheus-でメトリクスを確認)
- [KEDA のインストール](#keda-のインストール)
- [自動スケーリングの設定](#自動スケーリングの設定)
  - [利用可能なアプリケーションメトリクス](#利用可能なアプリケーションメトリクス)
  - [ScaledObject の作成](#scaledobject-の作成)
- [負荷の生成とスケーリングの観察](#負荷の生成とスケーリングの観察)
- [リソースのクリーンアップ](#リソースのクリーンアップ)
- [まとめ](#まとめ)


## 環境の準備

### ラボの開始
[Docker 経由でプラットフォームを起動する](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

ラボを開始するには、次のコマンドを実行します。

```bash
TASK=03 make run_eks_task
```

**このコマンドの実行時に行われること:**
- Terraform/Terragrunt が必要な AWS インフラストラクチャ全体を自動的にデプロイします
- 処理にはおよそ 15～20 分かかります
- コマンド出力に重要な情報（SSH 接続、リソース名）が表示されます

### 作成されるリソース

コマンドを実行すると、次の AWS インフラストラクチャがデプロイされます。

#### ネットワークインフラストラクチャ（VPC）
- リージョン `eu-central-1` にある CIDR ブロック `10.10.0.0/16` の **VPC**
- インターネットアクセス可能なリソース用の **パブリックサブネット**（`eks-AZ-1`、`eks-AZ-2`）
- EKS ノードと RDS 用の **プライベートサブネット**
- プライベートサブネットからのアウトバウンドインターネットトラフィック用 **NAT Gateway**

#### EKS クラスター
- バージョン `1.35` の **EKS Control Plane**
- システム Pod 用の **Fargate プロファイル**（`kube-system`、`karpenter`）— 注意: CoreDNS は Fargate 上で動作します
- バージョン `1.8.1` の **Karpenter**（自動スケーリングコントローラー）
- **EKS Add-ons**: coredns、kube-proxy、vpc-cni、eks-pod-identity-agent

#### 事前設定済み Karpenter NodePool
- **`default`** — アプリケーションワークロード用（30 秒後に空のノードを統合）
- **`monitoring`** — 監視スタック専用。taint `dedicated=monitoring:NoSchedule` および label `work_type=monitoring` を持ちます（300 秒後に統合）

#### メイン設定ファイル

すべてのインフラストラクチャパラメータは `tasks/eks/labs/03/env.hcl` ファイルに設定されています。設定を変更するには、このファイル内の対応するパラメータを編集してください。

### 前提条件

以下があることを確認してください。
- 適切なアクセス権限を持つ **AWS CLI**
- リージョン `eu-central-1` で引き上げられたノード制限（必要な場合）
- worker ノードへの SSH 接続（接続文字列は `make run_eks_task` の出力で確認してください）
- worker ノードで利用可能な `kubectl`、`helm`、`jq`


## NodePool の確認

2 つの NodePool はすでに準備されています。確認しましょう。

```bash
kubectl get nodepools.karpenter.sh
```

**想定される出力:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — Prometheus、KEDA、metrics-server 用
- **`default`** — テストアプリケーション用

`monitoring` NodePool をさらに詳しく確認します。

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**仕様の主要部分:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # nodeAffinity で使用される
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # 適切な toleration を持つ Pod のみがここに配置される
```

**これは何を意味するか:** 監視 Pod には `work_type=monitoring` への `nodeAffinity` と、`dedicated=monitoring:NoSchedule` 用の `toleration` の両方が必要です。これにより、監視スタックが専用ノード上で動作し、不要なものがそこに配置されないことが保証されます。


## 監視スタックのインストール

### Prometheus Operator と metrics-server

Helm を使用して **kube-prometheus-stack**（公式 Prometheus Operator）と **metrics-server** をインストールします。Grafana は無効です。すべてのコンポーネントは、`nodeAffinity` + `tolerations` により NodePool `monitoring` に固定されます。

> **セキュリティに関する注意:** 以下の Prometheus Service は、**認証なし**でパブリック LoadBalancer を介して公開されます。これはラボでの利便性のためだけです。production では Prometheus を保護する必要があります（認証 / OAuth2 proxy、Security Groups または NetworkPolicy による IP 制限、TLS を使用する Ingress）。

```bash
# Helm リポジトリを追加する
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Prometheus 用の values ファイルを作成する
cat <<'EOF' > prometheus-values.yaml
# 警告: Prometheus LoadBalancer は認証なしで公開されます。
# これはラボ専用です。production では Prometheus を
# 認証、IP 制限（Security Groups / NetworkPolicy）、TLS で保護してください。

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# metrics-server 用の values ファイルを作成する
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# Prometheus Operator をインストールする
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# metrics-server をインストールする
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**values の説明:**
- `serviceMonitorSelectorNilUsesHelmValues: false` と空のセレクターにより、Prometheus は **すべての** namespace の ServiceMonitor を取得できます（後でアプリケーションメトリクスを収集するために必要です）。
- 各コンポーネントは `nodeAffinity`（`work_type=monitoring`）を宣言しているため、監視ノード上に**のみ**スケジュールされます。`nodeSelector` だけでは不十分です — affinity が配置を保証します。
- `node-exporter` には toleration のみが適用されます（DaemonSet として各ノードで動作する必要があります）。

### インストールの確認

```bash
# すべての監視 Pod は監視ノード上で Running になっている必要がある
kubectl get pods -n monitoring -o wide

# 監視ノードが起動している必要がある
kubectl get nodes -l work_type=monitoring

# metrics-server が動作している必要がある
kubectl top nodes

# Prometheus LoadBalancer のアドレスを取得する（Prometheus UI はポート 9090）
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Prometheus UI にアクセスするには、ブラウザーで `http://<LB-ADDRESS>:9090` を開きます。


## アプリケーションのデプロイ

テストアプリケーション（`ping_pong`）をデプロイします。Service は 2 つのポートを公開します: `http`（80 → 8080）と `metrics`（9090 → 9090）。

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

アプリケーションが起動したことを確認します。

```bash
kubectl get po -n team-19
```

**想定される出力:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

NodeClaim を確認します — 監視用とアプリケーション用にそれぞれ別のノードが存在する必要があります。

```bash
kubectl get nodeclaims.karpenter.sh
```

**想定される出力:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## アプリケーションメトリクスの収集

### ServiceMonitor の作成

アプリケーションは、パス `/metrics` のポート `9090` で Prometheus メトリクスをエクスポートします。アプリケーションの Service にはすでに `metrics` ポートが定義されているため、必要なのは ServiceMonitor のみです。Label `release: prometheus` により、Prometheus Operator がこれを取得できます。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### ターゲットの確認

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# ターゲットが存在し、正常である必要がある（health: up）
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Prometheus でメトリクスを確認

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# requests_total メトリクスを確認する
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

結果が空の `[]` の場合、ServiceMonitor はまだ取得されていません。少し待ってから再試行するか、上記のターゲットの正常性を確認してください。

ブラウザーで `http://<PROM_URL>:9090` を開き、Expression フィールドに `requests_total` を入力することもできます。

> **ヒント:** メトリクス値は、`"value": [<timestamp>, "<値>"]` として返されます。最初の数値はスクレイプ時刻、2 番目の値（文字列）が値そのものです。アプリケーションへのトラフィックが発生するまでは `0` です。


## KEDA のインストール

KEDA は Prometheus と同じノード（NodePool `monitoring`）で動作します。KEDA Helm チャートは、トップレベルの `tolerations` と `affinity` を**すべての**コンポーネント（operator、metrics apiserver、webhooks）に適用します。

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# すべての KEDA コンポーネント向けのグローバル tolerations と affinity
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### KEDA の確認

```bash
# KEDA Pod は監視ノード上で Running になっている必要がある
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# KEDA CRD がインストールされている必要がある
kubectl get crd | grep keda
```

> **注記:** KEDA の `metrics-apiserver` は KEDA の内部コンポーネントです（Kubernetes HPA 用の外部メトリクスを提供します）。これは、前にインストールしたクラスターの `metrics-server` と同じものではありません — 両方が必要です。


## 自動スケーリングの設定

### 利用可能なアプリケーションメトリクス

アプリケーション `ping_pong` は、次の Prometheus メトリクスをエクスポートします（ポート 9090、パス `/metrics`）。

| メトリクス | 種類 | 説明 |
|---------|-----|----------|
| `requests_total` | Counter | リクエストの合計数 |
| `requests_per_second` | Gauge | 瞬間 RPS（ノイジーで、アイドル時に 0 へ戻らない） |
| `requests_per_minute` | Gauge | 瞬間 RPM |
| `goroutines` | Gauge | 現在の goroutine 数 |

スケーリングには、生の gauge `requests_per_second` ではなく **`rate(requests_total[1m])`** を使用します。カウンターに基づく `rate()` は、負荷に応じて線形に増加し、トラフィック停止時には正確に 0 へ低下する、真に平滑化された RPS を提供します。そのため、しきい値を容易に選定できます。

### ScaledObject の作成

ルール: レプリカ数 = `ceil(sum(rate(requests_total[1m])) / threshold)`。負荷低下後に Pod を迅速に削除できるよう、`behavior` によって素早いスケールダウンを設定します。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # 高速なスケールダウン: 安定化ウィンドウは 10 秒、最大 100% の Pod を削除可能
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> カウンターからの実際の RPS。すべての Pod の合計。
      # レプリカ数 = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**説明:**
- `threshold` — HPA が維持しようとする、**Pod あたり**の目標 RPS です。
- `activationThreshold: 3` は、合計 RPS が 3 を超えるまで KEDA が 1 レプリカを維持することを意味し、アイドル時の頻繁な変動を防止します。
- `query` では `sum(...)`（レプリカ数に依存しない合計 RPS）を使用しているため、望ましいレプリカ数が安定します。ここで `avg(...)` を使用すると、Pod 追加時に振動が発生します。

ScaledObject と、それが作成した HPA を確認します。

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## 負荷の生成とスケーリングの観察

アプリケーション Service に負荷を生成する Pod を起動します。内部ループが N 件のリクエストを送信し、外部の `sleep 1` がペースを設定します。そのため、`seq 1 N` の数値はおおよそ目標 RPS に相当します。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### スケーリングの観察

単一の `watch` で、Pod、HPA、および Prometheus からの Pod あたり RPS を一度に表示します。PromQL クエリは URL エンコードされています（`--data-urlencode`）。そうしないと、文字 `{`、`}`、`=` がパーサーを壊します。

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**確認すべき内容:** 負荷が増加するにつれて、Pod 数は `ceil(合計_rps / threshold)` に近づきます。HPA の `TARGETS` 列（Pod あたり RPS）は、watch が出力する `rps per pod` と一致します。

> **選定のヒント:** Pod 数 ≈ （`seq 1 N` の数値）/ threshold。`seq 1 50` と `threshold: 10` では、およそ 5 Pod になります。より多くの Pod を得るには数値を増やしてください。

### 負荷の停止

```bash
kubectl delete pod traffic-generator -n team-19
```

トラフィック停止後、`rate(requests_total[1m])` は 0 に低下します。`cooldownPeriod`（10 秒）とスケールダウン安定化ウィンドウ（10 秒）以内に、KEDA は `minReplicaCount: 1` までスケールバックします。


## リソースのクリーンアップ

### アプリケーションの削除

```bash
# ScaledObject を削除する（KEDA は HPA の管理を停止する）
kubectl delete scaledobject team19-scaledobject -n team-19

# トラフィックジェネレーターを削除する（まだ動作している場合）
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# ServiceMonitor を削除する
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# アプリケーション自体を削除する（deployment、service、namespace）
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Prometheus の削除（重要: LoadBalancer も削除される）

Helm リリースを削除すると LoadBalancer タイプの Service も削除され、AWS が ELB を解放します。

```bash
# prometheus を削除する（これにより Service LoadBalancer -> AWS ELB が削除される）
helm uninstall prometheus -n monitoring

# metrics-server と keda を削除する
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

LoadBalancer（ELB）が実際に削除されたことを確認します。

```bash
# prometheus Service は存在しないはず
kubectl get svc -n monitoring | grep prometheus

# AWS で ELB が削除されたことを確認する
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

何らかの理由で Service が残り、ELB の削除をブロックしている場合は、手動で削除してください。

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

次に namespace を削除します。

```bash
kubectl delete namespace monitoring
```

> **重要:** ノードまたはクラスターを削除する**前に**、必ず LoadBalancer タイプの Service を削除してください。
> 先にノード／クラスターを削除すると、AWS ELB が orphaned リソースとして「残存」する可能性があり、
> コンソールまたは CLI 経由で手動削除が必要になります。

### Karpenter がすべてのノードを削除したことの確認

すべてのワークロードを削除すると、`default` と `monitoring` のノードは空になり、Karpenter がそれらを統合（削除）するはずです。

```bash
# nodeclaims の数がゼロになるまで確認する
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter は各 NodePool の `consolidateAfter` に従って空のノードを削除します
（`default` = 30 秒、`monitoring` = 300 秒）。そのため、監視ノードの削除にはより時間がかかります。

両方のコマンドが空の結果を返すまで待ちます。

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

ノードが削除されない場合は、統合を妨げている Pod を確認してください（例: コントローラーのない Pod や `karpenter.sh/do-not-disrupt` を持つ Pod）。

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### インフラストラクチャの削除

Karpenter がすべてのノードを削除した後にのみ、ラボのインフラストラクチャを削除してください。

```bash
TASK=03 make delete_eks_task
```

確認のために `y` を入力します。削除にはおよそ 10～15 分かかります。

> Karpenter がノードを削除する前にインフラストラクチャを削除すると、orphaned EC2 インスタンスが残る可能性があります。


## まとめ

おめでとうございます! EKS 上にイベント駆動型自動スケーリングシステムを構築しました。

**実施したこと:**

1. **監視スタック** — 公式 Prometheus Operator と metrics-server をインストールし、nodeAffinity と tolerations を通じて専用ノードに固定しました
2. **公開** — 迅速なアクセスのために LoadBalancer 経由で Prometheus を公開しました（ラボ専用、認証なし）
3. **カスタムメトリクス** — ServiceMonitor を使用してアプリケーション独自のリクエストメトリクスを収集しました
4. **KEDA** — KEDA をインストールし、Prometheus クエリに基づく ScaledObject を設定しました
5. **自動スケーリング** — 高速なスケールダウンを備えた `rate(requests_total[1m])` により、実際の RPS に基づいてアプリケーションをスケーリングしました
6. **クリーンアップ** — LoadBalancer を正しく削除し、インフラストラクチャを削除する前に Karpenter がノードを解放できるようにしました

**主なポイント:**

- ノイジーな瞬間 gauge の代わりに、カウンターに基づく `rate()` を使用して安定的かつ予測可能な自動スケーリングを実現してください
- スケーラークエリでは `avg(...)` ではなく `sum(...)` を使用し、Pod 追加時に望ましいレプリカ数が振動しないようにしてください
- nodeAffinity **と** tolerations を通じて、インフラストラクチャワークロードを専用ノードに固定してください
- orphaned ELB を避けるため、クラスターを削除する前に必ず LoadBalancer タイプの Service を削除してください

**追加リソース:**
- [KEDA ドキュメント](https://keda.sh/docs/)
- [KEDA の Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/)
- [kube-prometheus-stack チャート](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Karpenter ドキュメント](https://karpenter.sh/docs/)
