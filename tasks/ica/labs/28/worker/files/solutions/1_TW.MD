[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 28 - 參考解答

Istio `1.29.1` 已安裝於 ingress gateway，並使用固定的 TCP NodePort `31400`。應用程式
`tcp-echo` 在命名空間 `app` 中部署了兩個版本：
- **v1** 以 `one` 前綴回應；
- **v2** 以 `two` 前綴回應。

兩者皆監聽原始 TCP 連接埠 `9000`（非 HTTP）。

## 目標

透過 ingress gateway 路由原始 **TCP** 服務，使用帶有 `TCP` 接聽器的 `Gateway`，以及包含
`tcp` 路由的 `VirtualService`（在 v1 與 v2 之間進行加權）。

## 步驟 1. 具有 TCP 接聽器的 Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## 步驟 2. 包含子集的 DestinationRule

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## 步驟 3. 包含 TCP 路由的 VirtualService

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## 步驟 4. 驗證

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

（若已安裝 `nc`：`echo hello | nc myapp.local 31400`。）

## 運作方式

- **TCP 路由** 在第 4 層運作：沒有 HTTP 主機名稱、路徑或標頭，因此路由依據
  **接聽器連接埠**（`match.port`）。具有 `protocol: TCP` 的 `Gateway` 伺服器會讓
  Envoy 開啟純 TCP 接聽器；`VirtualService.tcp` 路由會將連線轉送至所選的後端子集。
- **連接埠命名很重要**：服務/gateway 連接埠必須命名為 `tcp`（或 `tcp-*`）。Istio
  使用連接埠名稱前綴偵測通訊協定；未加前綴或使用 `http-*` 的名稱會讓
  Istio 將其視為 HTTP，原始通訊協定便會失效。
- **加權 TCP** 會在子集間分配*連線*（而非請求）：每個新的 TCP
  連線都會依權重路由。
- L7 功能（重試、標頭路由、故障注入）**不會**套用至 TCP 路由：僅能透過 `DestinationRule`
  使用連線層級的政策（連線集區、逾時）。

## 相關通訊協定

- **MongoDB/MySQL/Redis**：將連接埠命名為 `mongo-*` / `mysql-*` / `redis-*`，以便 Envoy
  套用正確的通訊協定剖析器；路由仍使用 `tcp` 路由。
- **WebSocket**：雖然它是長連線，但它基於 HTTP `Upgrade`，因此請使用一般的
  `http` 路由與 `http-*` 連接埠名稱，而非 TCP。
