[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 31 - Referenzlösung

Istio `1.29.1` ist installiert (Ingress-Gateway auf NodePort `32080`). Fünf Backend-Services
laufen im Namespace `app`: `frontend`, `catalog`, `cart`, `api-v1`, `api-v2` (jeder antwortet
mit `Server Name: <name>`).

## Die Legacy-Konfiguration, von der wir migrieren (ingress-nginx)

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

## Das Istio-Äquivalent

### Schritt 1. Ein Gateway für beide Hosts

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

### Schritt 2. shop.local - pfadbasiertes Routing (ein VirtualService)

Die Reihenfolge ist wichtig: zuerst die spezifischsten Präfixe, der Catch-all `/` zuletzt.

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

### Schritt 3. api.local - headerbasiertes Routing (ein VirtualService)

Was in nginx einen separaten Canary-Ingress benötigte, ist in Istio ein einzelner `match`-Block.

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

### Schritt 4. Überprüfen

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## nginx Ingress → Istio-Zuordnung

| ingress-nginx | Istio |
|---|---|
| `Ingress` (Host + Pfade) | `Gateway` (Host/Port) + `VirtualService` (Weiterleitung) |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + `gateways:` in VS |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| canary-by-header (zusätzlicher Ingress) | ein `http[].match[].headers`-Block |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| Annotationen `nginx.ingress.kubernetes.io/*` | integrierte Felder in VS/DestinationRule |

## Warum migrieren

- **Ein Modell für sämtliches Routing**: Pfade, Header, Gewichtungen, Spiegelung, Wiederholungen und
  Fehlerinjektion befinden sich im selben `VirtualService` - keine Annotation-Flut, keine zusätzlichen
  Canary-Ingress-Objekte.
- Routing ist **vom Edge entkoppelt**: dieselben `VirtualService`-Regeln gelten auch für
  In-Mesh-Traffic (Gateway `mesh`), und Sie erhalten mTLS, Telemetrie und Richtlinien ohne Zusatzaufwand.