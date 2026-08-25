[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 31 - Эталонное решение

Установлен Istio `1.29.1` (ingress gateway на NodePort `32080`). Пять backend-сервисов
работают в namespace `app`: `frontend`, `catalog`, `cart`, `api-v1`, `api-v2` (каждый отвечает
`Server Name: <name>`).

## Устаревшая конфигурация, с которой мы мигрируем (ingress-nginx)

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

## Эквивалент Istio

### Шаг 1. Один Gateway для обоих hosts

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

### Шаг 2. shop.local - path-based routing (один VirtualService)

Порядок важен: сначала наиболее специфичные prefixes, в конце catch-all `/`.

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

### Шаг 3. api.local - header-based routing (один VirtualService)

То, для чего в nginx требовался отдельный canary Ingress, в Istio представляет собой один блок `match`.

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

### Шаг 4. Проверка

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## Сопоставление nginx Ingress и Istio

| ingress-nginx | Istio |
|---|---|
| `Ingress` (host + paths) | `Gateway` (host/port) + `VirtualService` (routing) |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + `gateways:` in VS |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| canary-by-header (extra Ingress) | one `http[].match[].headers` block |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| `nginx.ingress.kubernetes.io/*` annotations | first-class fields on VS/DestinationRule |

## Зачем выполнять миграцию

- **Одна модель для всей маршрутизации**: paths, headers, weights, mirroring, retries и fault
  injection находятся в одном `VirtualService` - без нагромождения annotations и дополнительных canary
  объектов Ingress.
- Маршрутизация **отделена от edge**: те же правила `VirtualService` применяются также к
  in-mesh-трафику (gateway `mesh`), и вы бесплатно получаете mTLS, telemetry и policy.
