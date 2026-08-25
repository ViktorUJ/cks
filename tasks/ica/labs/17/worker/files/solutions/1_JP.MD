[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 17 - 参照ソリューション

Istio `1.29.1` がインストールされています（ingress gateway は NodePort `32080` 上）。アプリ `ping-pong`
は名前空間 `app` にデプロイされ、ingress gateway 経由で
`http://myapp.local:32080/` に公開されています。

## 目標

ingress gateway に `EnvoyFilter` を使用して **ローカルレート制限** を適用します。1 分あたり最大 5 リクエストを許可し、残りは HTTP `429` で拒否します。

## ステップ 1. ベースライン

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ステップ 2. ローカルレート制限を適用する（EnvoyFilter）

```bash
cat > ratelimit.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-local-rate-limit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 5
                tokens_per_fill: 5
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              filter_enforced:
                runtime_key: local_rate_limit_enforced
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              response_headers_to_add:
                - append_action: OVERWRITE_IF_EXISTS_OR_ADD
                  header:
                    key: x-local-rate-limit
                    value: "true"
EOF

kubectl apply -f ratelimit.yaml
```

## ステップ 3. 検証

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## 仕組み

- **`token_bucket`** - `max_tokens: 5`、`tokens_per_fill: 5`、`fill_interval: 60s`：
  バケットには 5 個のトークンが保持され、60 秒ごとに 5 個まで補充されます。各リクエストは
  1 個のトークンを消費し、バケットが空になると、リクエストは `429` で拒否されます。
- **`filter_enabled` / `filter_enforced`** - フィルターが有効になっているリクエストの割合と、実際に
  制限を適用する割合です（ここではどちらも `100%`）。
- **context: GATEWAY** - フィルターは ingress gateway の listener に挿入されるため、
  この制限はエッジですべての受信トラフィックに適用されます。

## ローカルとグローバルのレート制限

- **ローカルレート制限**（このラボ）- 各 Envoy インスタンスが独自のトークンバケットを保持します。
  シンプルで追加コンポーネントは不要ですが、有効な制限値は gateway レプリカ数に応じて増加します。
- **グローバルレート制限** - Envoy は外部のレート制限サービス（Redis がバックエンド）を呼び出すため、
  制限はすべてのレプリカ間で共有されます。これは `envoy.filters.http.ratelimit` フィルターと、
  descriptors を含む `ConfigMap`、およびデプロイされた ratelimit サービスを使用します。クラスター全体で正確なクォータが必要な場合に使用してください。
