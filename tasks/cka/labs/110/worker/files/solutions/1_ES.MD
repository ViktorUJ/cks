[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 — solución de referencia (Service/DNS, Ingress, NetworkPolicy)

## Tarea 1. DNS: pod + service, guardar los registros

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# comprobación de la resolución desde un pod temporal
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# guardar los registros
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## Tarea 2. Ingress para `/cat`

```bash
kubectl create namespace cat
kubectl -n cat create deployment cat --image=viktoruj/ping_pong:latest
kubectl -n cat expose deployment cat --name=cat --port=80 --target-port=8080
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cat
  namespace: cat
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /cat
        pathType: Prefix
        backend:
          service:
            name: cat
            port:
              number: 80
```

```bash
kubectl apply -f ingress.yaml
curl cka.local:30102/cat    # o IP_DEL_NODO:30102/cat
```

## Tarea 3. NetworkPolicy en `prod-db`

```yaml
# default-deny ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: prod-db
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# allow desde el namespace prod
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-prod
  namespace: prod-db
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: prod
```

```bash
kubectl apply -f netpol.yaml
kubectl get netpol -n prod-db
```

## Tarea 4. Migración de Ingress → Gateway API

El `Ingress shop-ingress` de partida (ns `gw`): host `shop.local`, path `/api` → service
`shop:8080`, rewrite `/`. Lo trasladamos a la pareja `Gateway` + `HTTPRoute`.

```bash
# ver qué estamos migrando
kubectl get ingress shop-ingress -n gw -o yaml
# GatewayClass disponibles (de NGINX Gateway Fabric)
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # el nombre de kubectl get gatewayclass
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "shop.local"
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
  namespace: gw
spec:
  parentRefs:
  - name: shop-gw
  hostnames: ["shop.local"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /       # = rewrite-target: /
    backendRefs:
    - name: shop
      port: 8080
```

```bash
kubectl apply -f gwapi.yaml
kubectl get gateway,httproute -n gw
# tras la comprobación de paridad se puede eliminar el Ingress antiguo:
# kubectl delete ingress shop-ingress -n gw
```

Correspondencia de campos: `host` → `hostnames`, `path`+`pathType` → `matches.path`,
`backend.service` → `backendRefs`, `rewrite-target` → `filters: URLRewrite`. Un borrador se
puede obtener automáticamente con la utilidad `ingress2gateway print --providers ingress-nginx -A`.
