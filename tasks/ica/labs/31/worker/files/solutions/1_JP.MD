[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 31 - リファレンスソリューション

Istio `1.29.1` がインストールされています（ingress gateway は NodePort `32080`）。5つのバックエンドサービス
が namespace `app` で実行されています: `frontend`、`catalog`、`cart`、`api-v1`、`api-v2`（それぞれ
`Server Name: <name>` を返します）。

## 移行元のレガシー構成（ingress-nginx）

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

## Istio における同等の構成

### ステップ1. 両方のホストに対する1つの Gateway

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

### ステップ2. shop.local - path-based routing（1つの VirtualService）

順序は重要です。最も具体的な prefix を先に置き、catch-all の `/` を最後に置きます。

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

### ステップ3. api.local - header-based routing（1つの VirtualService）

nginx で別の canary Ingress が必要だったものは、Istio では単一の `match` ブロックになります。

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

### ステップ4. 検証

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## nginx Ingress → Istio の対応表

| ingress-nginx | Istio |
|---|---|
| `Ingress`（host + paths） | `Gateway`（host/port）+ `VirtualService`（routing） |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + `gateways:` in VS |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| canary-by-header（extra Ingress） | 1つの `http[].match[].headers` ブロック |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| `nginx.ingress.kubernetes.io/*` annotations | VS/DestinationRule の first-class fields |

## 移行する理由

- **すべての routing を1つのモデルで扱える**: paths、headers、weights、mirroring、retries、fault
  injection が同じ `VirtualService` に集約されます。annotation の乱立も、追加の canary
  Ingress オブジェクトも不要です。
- Routing は **エッジから分離** されています: 同じ `VirtualService` ルールが
  in-mesh traffic にも適用され（gateway `mesh`）、mTLS、telemetry、policy も追加の設定なしで利用できます。