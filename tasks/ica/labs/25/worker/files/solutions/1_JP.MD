[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 25 - リファレンスソリューション

Istio `1.29.1` + Prometheus がインストールされています。**Flagger** は `istio-system` で実行されています。Namespace
`test`（istio-injection）にはデモアプリ **podinfo**（`6.0.0`）、
**flagger-loadtester**（分析中にトラフィックを生成）があり、`istio-system` には
`public-gateway` が存在します。

## 目標

Flagger が **プログレッシブデリバリー**を実行する `Canary` リソースを作成します。新しい
イメージごとに、トラフィックを徐々に canary へ移動し、メトリクスを確認して、自動昇格します
（失敗時は自動ロールバック）。

## ステップ 1. Canary を作成する

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## ステップ 2. Flagger の初期化を待つ

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## ステップ 3. canary リリースをトリガーする

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger は新しいリビジョンを検出して分析を開始します。トラフィックの 20% → 40% → 50% を
canary に移動し、各 interval ごとに `request-success-rate` と `request-duration` を確認します。
loadtester はメトリクスが存在するようにトラフィックの送信を続けます。

## ステップ 4. 昇格を監視する

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

上記の設定では昇格におよそ 2～3 分かかります。`podinfo-primary` が `6.0.1` に更新された後で
`check_result` を実行してください。

## 自動ロールバック（任意）

別のリリースをトリガーし、分析中に失敗を注入します。

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

失敗したメトリクスチェックがしきい値に達すると、Flagger は停止してロールバックします。トラフィックは
primary に戻り、canary はゼロまでスケールし、STATUS は `Failed` になります。

## 仕組み

- Flagger は対象の `Deployment` を監視します。spec の変更時に **canary** deployment を
  作成または更新し、Istio `VirtualService`/`DestinationRule` の重みを介してトラフィックを段階的に移動します。
- 各ステップで、設定されたメトリクスについて **Prometheus** にクエリします。しきい値の範囲内で
  あれば次へ進み、そうでなければ `threshold` 回の失敗後にロールバックします。
- `podinfo-primary` は常に「既知の正常な」バージョンを保持します。canary が完全に成功して昇格されるまで、
  実際のトラフィックは primary によって処理されます。
- これにより、リスクの高い手動 canary（Lab 06 のトラフィック移動）が、自動ロールバックを内蔵した
  メトリクスゲート付きの自動リリースになります。これがプログレッシブデリバリーの本質です。
