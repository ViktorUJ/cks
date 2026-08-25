[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 32 - 參考解答

已安裝 Istio `1.29.1`（預設設定檔）。命名空間 `app`（已啟用
istio-injection）執行 `viktoruj/ping_pong` 映像，它使用 gRPC
（`PingPong.Echo` 回傳提供服務之 pod 的主機名稱）：

- **grpc-server** - gRPC Echo/Health 伺服器，**3 個複本**（gRPC 位於連接埠
  `8079`）；
- **grpc-client** - 相同映像，用於產生 gRPC 負載
  （`/app -grpc-client ...`）。

`grpc-server` 的 **Service** 建立時使用了**命名錯誤的**連接埠（`tcp`）。
因此，Istio 將連接埠 `8079` 視為原始 L4 TCP：單一長時間存活的 HTTP/2 gRPC
連線會固定至一個 pod，因此用戶端只會看到**一個**不同的伺服器，且不會發生
逐請求負載平衡。

## 目標

1. 讓 Istio 辨識 gRPC 連接埠，使其能在所有後端 pod 之間進行**逐請求**
   （HTTP/2）負載平衡。
2. 為 `grpc-server` 新增包含 gRPC **重試**與**逾時**的 `VirtualService`。

## 步驟 1. 修正 Service 連接埠命名

gRPC 是 HTTP/2，不是原始 TCP。Istio 會從連接埠**名稱前綴**（`grpc`、
`http2`、...）或明確的 `appProtocol` 欄位偵測通訊協定。將連接埠重新命名為
`grpc`（及/或設定 `appProtocol: grpc`）：

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

等效的完整資訊清單：

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

一旦 Istio 看到 HTTP/2（gRPC）叢集，Envoy 就會在共用連線內對**每個請求**
於所有端點之間進行負載平衡，無需額外設定。

## 步驟 2. 具有 gRPC 重試與逾時的 VirtualService

gRPC 建立於 HTTP 之上，因此透過 `http` 區塊（而非 `tcp`）設定：重試、
逾時、標頭路由及逐請求負載平衡皆適用。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` 使用可識別 gRPC 的條件：`unavailable`、`cancelled`、
  `deadline-exceeded` 對應至 gRPC 狀態碼；`refused-stream` 與
  `connect-failure` 涵蓋傳輸層問題。
- `timeout` 限制整個請求；`perTryTimeout` 限制每次嘗試。

## 步驟 3. （選用）固定負載平衡策略

連接埠成為 gRPC 後，逐請求負載平衡預設為啟用。若要明確指定策略：

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## 步驟 4. 驗證

從用戶端產生 gRPC 負載，並確認請求命中**全部三個**後端 pod（逐請求
負載平衡）：

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

預期的結尾：

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` 證明請求是逐請求進行負載平衡。在修正前（連接埠命名為
`tcp`），相同命令會回報 `distinct servers: 1`。

## 運作原理

- **gRPC 是 HTTP/2，而非 TCP。** 使用 L4/TCP 視角時，Envoy 會對*連線*進行
  負載平衡：一個 gRPC 用戶端會維持單一長時間存活的連線，因此每次呼叫都會固定
  至同一個 pod。將連接埠宣告為 `grpc` 可讓 Envoy 剖析 HTTP/2，並在端點之間
  平衡**每個請求**（串流）。
- **連接埠命名是關鍵。** 連接埠必須命名為 `grpc` / `grpc-*`（或 `http2`），
  或帶有 `appProtocol: grpc`。中性名稱（`tcp`、未命名）會捨棄所有 L7 功能：
  沒有逐請求 LB、重試、逾時或 gRPC 指標。
- **L7 功能適用於 gRPC。** 因為它是 HTTP，gRPC 可使用 `http` 重試
  （具 gRPC 感知的 `retryOn`）、`timeout`/`perTryTimeout`、標頭路由、故障
  注入與豐富的遙測功能，完全如同純 HTTP。
