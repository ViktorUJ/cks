[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 31 - 參考解答

已安裝 Istio `1.29.1`（NodePort `32080` 上的入口閘道）。五個後端服務
在命名空間 `app` 中執行：`frontend`、`catalog`、`cart`、`api-v1`、`api-v2`（各自回應
`Server Name: <name>`）。

## 要遷移的舊有設定（ingress-nginx）

```yaml
# shop.local - path-based routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
spec:
  ingressClassName: nginx
  rules:
  - host: shop.local
    http:
      paths:
      - {path: /catalog, pathType: Prefix, backend: {service: {name: catalog, port: {number: 8080}}}}
      - {path: /cart,    pathType: Prefix, backend: {service: {name: cart,    port: {number: 8080}}}}
      - {path: /,        pathType: Prefix, backend: {service: {name: frontend, port: {number: 8080}}}}
---
# api.local - header-based routing needs TWO Ingresses in nginx (main + canary)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
spec:
  ingressClassName: nginx
  rules:
  - host: api.local
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: api-v1, port: {number: 8080}}}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "x-api-version"
    nginx.ingress.kubernetes.io/canary-by-header-value: "v2"
spec:
  ingressClassName: nginx
  rules:
  - host: api.local
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: api-v2, port: {number: 8080}}}}
```

## Istio 對等設定

### 步驟 1. 適用於兩個主機的一個 Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: shop-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port: {number: 80, name: http, protocol: HTTP}
      hosts:
        - "shop.local"
        - "api.local"
EOF
```

### 步驟 2. shop.local - 以路徑為基礎的路由（一個 VirtualService）

順序很重要：最特定的前綴在前，萬用的 `/` 放在最後。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: shop
  namespace: app
spec:
  hosts: ["shop.local"]
  gateways: ["shop-gateway"]
  http:
    - match: [{uri: {prefix: /catalog}}]
      route: [{destination: {host: catalog, port: {number: 8080}}}]
    - match: [{uri: {prefix: /cart}}]
      route: [{destination: {host: cart, port: {number: 8080}}}]
    - route: [{destination: {host: frontend, port: {number: 8080}}}]
EOF
```

### 步驟 3. api.local - 以標頭為基礎的路由（一個 VirtualService）

在 nginx 中需要獨立 canary Ingress 的設定，在 Istio 中只需一個 `match` 區塊。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: api
  namespace: app
spec:
  hosts: ["api.local"]
  gateways: ["shop-gateway"]
  http:
    - match:
        - headers:
            x-api-version:
              exact: v2
      route: [{destination: {host: api-v2, port: {number: 8080}}}]
    - route: [{destination: {host: api-v1, port: {number: 8080}}}]
EOF
```

### 步驟 4. 驗證

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## nginx Ingress → Istio 對應關係

| ingress-nginx | Istio |
|---|---|
| `Ingress`（主機 + 路徑） | `Gateway`（主機/連接埠）+ `VirtualService`（路由） |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + VS 中的 `gateways:` |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| 依標頭的 canary（額外的 Ingress） | 一個 `http[].match[].headers` 區塊 |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| `nginx.ingress.kubernetes.io/*` 註解 | VS/DestinationRule 上的一級欄位 |

## 為何遷移

- **所有路由使用一個模型**：路徑、標頭、權重、鏡像、重試和故障
  注入都在同一個 `VirtualService` 中 - 沒有散落的註解，也不需要額外的 canary
  Ingress 物件。
- 路由與**邊緣解耦**：相同的 `VirtualService` 規則也適用於
  網格內流量（gateway `mesh`），並可免費獲得 mTLS、遙測和政策。