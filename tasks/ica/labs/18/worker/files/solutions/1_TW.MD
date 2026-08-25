[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 18 - 參考解答

已安裝 Istio `1.29.1`（ingress gateway 位於 NodePort `32080`），並將分散式
追蹤連接至 `zipkin` 擴充提供者（`zipkin.istio-system:9411`）。**Jaeger**
附加元件已部署為追蹤後端。應用程式 `ping-pong` 已部署於命名空間 `app`，並透過
`http://myapp.local:32080/` 公開。存取日誌預設為**停用**，且目前尚不存在
`Telemetry` 資源。

## 目標

使用 **Telemetry API** 來：
- 為 `app` 命名空間啟用 Envoy 存取日誌（內建 `envoy` 提供者）；
- 透過 `zipkin` 提供者以 100% 取樣率啟用追蹤，確保追蹤資料確實
  收集至 Jaeger。

## 步驟 1. 確認存取日誌為關閉狀態

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## 步驟 2. 透過 Telemetry 設定日誌和追蹤

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

## 步驟 3. 產生流量

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## 步驟 4. 驗證收集結果

存取日誌（位於 sidecar stdout）：

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

追蹤資料（在叢集內查詢 Jaeger）：

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

您也可以轉送 Jaeger UI 的連接埠：

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## 日誌和追蹤資料的去向

| 訊號 | 提供者 | 目的地 |
|---|---|---|
| 存取日誌 | `envoy`（內建） | sidecar stdout → `kubectl logs -c istio-proxy` |
| 追蹤資料 | `zipkin` 擴充提供者 | Jaeger（`zipkin.istio-system:9411`）→ Jaeger UI |

## 運作方式

- **Telemetry API**（`telemetry.istio.io`）以宣告方式設定日誌、指標和追蹤，
  並支援範圍層級：全 mesh（根命名空間）→ 命名空間 →
  工作負載（`selector`）。
- **`accessLogging.providers.name: envoy`** 將存取日誌寫入 sidecar stdout。
- **`tracing.providers.name: zipkin`** 將 span 指向 `zipkin` 擴充提供者，該提供者
  宣告於 `meshConfig.extensionProviders`，並將其轉送至 Jaeger。
  若未參照提供者，取樣原則便沒有可傳送 span 的目的地。
- **`randomSamplingPercentage: 100`** 會追蹤每個請求（在正式環境中請使用較低值，
  以控制額外負擔）。
