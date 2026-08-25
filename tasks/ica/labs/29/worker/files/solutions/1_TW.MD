[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 29 - 參考解答

已安裝 Istio `1.29.1`（入口閘道 HTTPS 使用 NodePort `32443`）。已預先建立
PKI：
- 適用於 `myapp.local` 的閘道伺服器憑證 + 用戶端 CA → secret `myapp-credential`
  （`istio-system`）；
- 用戶端憑證套件 → secret `client-certs`（`app`）；
- 適用於 `passthrough.local` 的 TLS 憑證 → secret `backend-tls`（`backend`）。

工作負載：`ping-pong`（命名空間 `app`，已注入）和僅使用 TLS 的 `secure-backend`
（命名空間 `backend`，自行終止 TLS，回應 `secure-ok`）。

## 目標

在連接埠 443 上設定具有兩種 TLS 模式的入口閘道，透過 SNI 選擇：
- `myapp.local` 使用 **MUTUAL**：終止 TLS 並要求用戶端憑證（邊緣的 mTLS）；
- `passthrough.local` 使用 **PASSTHROUGH**：將加密串流轉送至後端，由後端終止 TLS。

## 步驟 1. 建立含有 MUTUAL + PASSTHROUGH 伺服器的 Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-mutual
        protocol: HTTPS
      tls:
        mode: MUTUAL
        credentialName: myapp-credential
      hosts:
        - "myapp.local"
    - port:
        number: 443
        name: https-passthrough
        protocol: HTTPS
      tls:
        mode: PASSTHROUGH
      hosts:
        - "passthrough.local"
EOF
```

## 步驟 2. 路由 MUTUAL 主機（終止後的 HTTP）

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: app
spec:
  hosts:
    - "myapp.local"
  gateways:
    - edge-gateway
  http:
    - route:
        - destination:
            host: ping-pong
            port:
              number: 8080
EOF
```

## 步驟 3. 路由 PASSTHROUGH 主機（TLS，依據 SNI）

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: app
spec:
  hosts:
    - "passthrough.local"
  gateways:
    - edge-gateway
  tls:
    - match:
        - sniHosts:
            - "passthrough.local"
      route:
        - destination:
            host: secure-backend.backend.svc.cluster.local
            port:
              number: 443
EOF
```

## 步驟 4. 驗證

```bash
# MUTUAL - without a client cert the handshake is rejected
curl -sk -o /dev/null -w "%{http_code}\n" https://myapp.local:32443/        # not 200

# MUTUAL - with the client cert it succeeds
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key
curl -sk --cert /tmp/c.crt --key /tmp/c.key https://myapp.local:32443/      # 200

# PASSTHROUGH - TLS terminates at the backend
curl -sk https://passthrough.local:32443/                                   # secure-ok
```

## TLS 模式一覽

| 模式 | 由誰終止 TLS | 用戶端憑證 | 典型用途 |
|---|---|---|---|
| `SIMPLE`（Lab 13） | 閘道 | 否 | 標準 HTTPS 入口 |
| `MUTUAL` | 閘道 | **必要**（依據 `ca.crt` 驗證） | 邊緣 mTLS、B2B/合作夥伴 API |
| `PASSTHROUGH` | 後端 | 閘道不適用 | 端對端加密，閘道無法或不應看到明文 |
| `ISTIO_MUTUAL` | 閘道（Istio 憑證） | 由 Istio 管理 | 網格內部閘道流量 |

## 運作方式

- 單一 `Gateway` 可在**相同連接埠上託管多個伺服器**；Istio 會依 TLS **SNI**
  （`myapp.local` 與 `passthrough.local`）選擇伺服器。
- **MUTUAL**：閘道會提供其伺服器憑證並要求用戶端憑證，依據 `myapp-credential`
  內的 `ca.crt` 進行驗證。終止後，會使用一般 L7（`http` 路由）進行路由。
- **PASSTHROUGH**：閘道不會解密；它會在 L4 透過 SNI，使用
  `VirtualService.tls` + `sniHosts` 比對進行路由，並將原始 TLS 轉送至後端，後端
  擁有憑證並終止 TLS。