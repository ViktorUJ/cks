[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 31 - Solución de referencia

Istio `1.29.1` está instalado (gateway de entrada en NodePort `32080`). Cinco servicios de backend
se ejecutan en el espacio de nombres `app`: `frontend`, `catalog`, `cart`, `api-v1`, `api-v2` (cada uno responde
`Server Name: <name>`).

## La configuración heredada desde la que migramos (ingress-nginx)

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

## El equivalente en Istio

### Paso 1. Un Gateway para ambos hosts

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

### Paso 2. shop.local - enrutamiento basado en rutas (un VirtualService)

El orden importa: primero los prefijos más específicos y al final el comodín `/`.

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

### Paso 3. api.local - enrutamiento basado en encabezados (un VirtualService)

Lo que necesitaba un Ingress canary independiente en nginx es un único bloque `match` en Istio.

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

### Paso 4. Verificar

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## Mapeo de nginx Ingress a Istio

| ingress-nginx | Istio |
|---|---|
| `Ingress` (host + rutas) | `Gateway` (host/puerto) + `VirtualService` (enrutamiento) |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + `gateways:` en VS |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| canary-by-header (Ingress adicional) | un bloque `http[].match[].headers` |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| anotaciones `nginx.ingress.kubernetes.io/*` | campos de primera clase en VS/DestinationRule |

## Por qué migrar

- **Un modelo para todo el enrutamiento**: rutas, encabezados, pesos, duplicación, reintentos e
  inyección de fallos están en el mismo `VirtualService` - sin proliferación de anotaciones ni objetos
  Ingress canary adicionales.
- El enrutamiento está **desacoplado del borde**: las mismas reglas de `VirtualService` se aplican también
  al tráfico dentro de la malla (gateway `mesh`), y obtienes mTLS, telemetría y políticas sin esfuerzo.
