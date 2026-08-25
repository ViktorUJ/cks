[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 18 - リファレンスソリューション

Istio `1.29.1` がインストールされています（NodePort `32080` 上のイングレスゲートウェイ）。分散
トレーシングは `zipkin` 拡張プロバイダー（`zipkin.istio-system:9411`）に接続されています。
**Jaeger** アドオンがトレーシングバックエンドとしてデプロイされています。アプリ `ping-pong` は
名前空間 `app` にデプロイされ、`http://myapp.local:32080/` で公開されています。アクセスログは
デフォルトで**無効**になっており、`Telemetry` リソースはまだ存在しません。

## 目標

**Telemetry API** を使用して、以下を行います。
- `app` 名前空間の Envoy アクセスログを有効にする（組み込み `envoy` プロバイダー）。
- すべてのトレースが実際に Jaeger に収集されるよう、`zipkin` プロバイダー経由のトレーシングを
  100% サンプリングで有効にする。

## ステップ 1. アクセスログがオフであることを確認する

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## ステップ 2. Telemetry でログとトレースを設定する

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## ステップ 3. トラフィックを生成する

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## ステップ 4. 収集を検証する

アクセスログ（サイドカーの stdout 内）：

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

トレース（クラスター内からクエリする Jaeger 内）：

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

Jaeger UI をポートフォワードすることもできます。

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## ログとトレースの送信先

| シグナル | プロバイダー | 送信先 |
|---|---|---|
| アクセスログ | `envoy`（組み込み） | サイドカー stdout → `kubectl logs -c istio-proxy` |
| トレース | `zipkin` 拡張プロバイダー | Jaeger（`zipkin.istio-system:9411`）→ Jaeger UI |

## 仕組み

- **Telemetry API**（`telemetry.istio.io`）は、ログ、メトリクス、トレースを宣言的に設定し、
  メッシュ全体（ルート名前空間）→ 名前空間 → ワークロード（`selector`）というスコープ階層をサポートします。
- **`accessLogging.providers.name: envoy`** は、アクセスログをサイドカーの stdout に書き込みます。
- **`tracing.providers.name: zipkin`** は、`meshConfig.extensionProviders` で宣言された
  `zipkin` 拡張プロバイダーにスパンを送信し、それが Jaeger に転送します。
  プロバイダー参照がなければ、サンプリングポリシーにはスパンの送信先がありません。
- **`randomSamplingPercentage: 100`** はすべてのリクエストをトレースします（本番環境では、
  オーバーヘッドを制御するため低い値を使用してください）。
