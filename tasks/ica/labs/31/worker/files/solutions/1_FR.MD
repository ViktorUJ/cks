[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 31 - Solution de référence

Istio `1.29.1` est installé (passerelle d'entrée sur NodePort `32080`). Cinq services backend
s'exécutent dans l'espace de noms `app` : `frontend`, `catalog`, `cart`, `api-v1`, `api-v2` (chacun répond
`Server Name: <name>`).

## La configuration héritée depuis laquelle nous migrons (ingress-nginx)

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

## L'équivalent Istio

### Étape 1. Une Gateway pour les deux hôtes

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

### Étape 2. shop.local - routage basé sur le chemin (un VirtualService)

L'ordre est important : les préfixes les plus spécifiques d'abord, le fourre-tout `/` en dernier.

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

### Étape 3. api.local - routage basé sur l'en-tête (un VirtualService)

Ce qui nécessitait un Ingress canary séparé dans nginx correspond à un unique bloc `match` dans Istio.

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

### Étape 4. Vérifier

```bash
curl -s http://shop.local:32080/catalog | grep "Server Name"   # catalog
curl -s http://shop.local:32080/cart    | grep "Server Name"   # cart
curl -s http://shop.local:32080/        | grep "Server Name"   # frontend
curl -s http://api.local:32080/         | grep "Server Name"   # api-v1
curl -s -H "x-api-version: v2" http://api.local:32080/ | grep "Server Name"   # api-v2
```

## Correspondance nginx Ingress → Istio

| ingress-nginx | Istio |
|---|---|
| `Ingress` (hôte + chemins) | `Gateway` (hôte/port) + `VirtualService` (routage) |
| `ingressClassName: nginx` | `Gateway.selector: istio=ingressgateway` + `gateways:` dans VS |
| `rules[].host` | `Gateway.servers[].hosts` + `VirtualService.hosts` |
| `paths[].path` + `pathType` | `http[].match[].uri.{exact,prefix}` |
| canary-by-header (Ingress supplémentaire) | un bloc `http[].match[].headers` |
| `nginx.ingress.kubernetes.io/rewrite-target` | `http[].rewrite.uri` |
| annotations `nginx.ingress.kubernetes.io/*` | champs de première classe dans VS/DestinationRule |

## Pourquoi migrer

- **Un modèle pour tout le routage** : chemins, en-têtes, poids, mise en miroir, tentatives,
  et injection de pannes sont regroupés dans le même `VirtualService` - pas de prolifération
  d'annotations, pas d'objets Ingress canary supplémentaires.
- Le routage est **découplé de la périphérie** : les mêmes règles `VirtualService` s'appliquent
  aussi au trafic dans le maillage (passerelle `mesh`), et vous bénéficiez gratuitement de mTLS,
  de télémétrie et de politiques.
