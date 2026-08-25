[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 17 - 參考解答

已安裝 Istio `1.29.1`（ingress gateway 使用 NodePort `32080`）。應用程式 `ping-pong`
已部署於命名空間 `app`，並透過 ingress gateway 公開於
`http://myapp.local:32080/`。

## 目標

使用 `EnvoyFilter` 在 ingress gateway 上套用**本機速率限制**：每分鐘最多允許 5 個請求，其餘請求以 HTTP `429` 拒絕。

## 步驟 1. 基準測試

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## 步驟 2. 套用本機速率限制（EnvoyFilter）

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

## 步驟 3. 驗證

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## 運作方式

- **`token_bucket`** - `max_tokens: 5`、`tokens_per_fill: 5`、`fill_interval: 60s`：
  bucket 可容納 5 個 token，且每 60 秒補充至 5 個。每個請求會消耗一個 token；當 bucket 為空時，請求會以 `429` 拒絕。
- **`filter_enabled` / `filter_enforced`** - filter 啟用並實際強制執行的請求百分比（此處兩者皆為 `100%`）。
- **context: GATEWAY** - filter 會插入 ingress gateway 的 listener，因此此限制會套用至邊緣所有傳入流量。

## 本機與全域速率限制

- **本機速率限制**（本實驗）- 每個 Envoy 執行個體各自維護自己的 token bucket。
  簡單且不需要額外元件，但實際限制會隨 gateway replica 數量倍增。
- **全域速率限制** - Envoy 呼叫外部速率限制服務（由 Redis 支援），
  因此限制會在所有 replica 之間共享。它使用
  `envoy.filters.http.ratelimit` filter，加上一個包含 descriptor 的 `ConfigMap` 和一個
  已部署的 ratelimit service。需要整個 cluster 範圍內的精確 quota 時，請使用此方式。
