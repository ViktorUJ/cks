[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 110 — Referenzlösung (Service/DNS, Ingress, NetworkPolicy)

## Aufgabe 1. DNS: pod + service, Ausgaben speichern

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# Prüfung der Auflösung aus einem temporären Pod
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# Ausgaben speichern
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## Aufgabe 2. Ingress für `/cat`

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
curl cka.local:30102/cat    # oder NODE_IP:30102/cat
```

## Aufgabe 3. NetworkPolicy in `prod-db`

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
# allow aus dem Namespace prod
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

## Aufgabe 4. Migration Ingress → Gateway API

Der ursprüngliche `Ingress shop-ingress` (ns `gw`): host `shop.local`, path `/api` → service
`shop:8080`, rewrite `/`. Wir übertragen ihn auf das Paar `Gateway` + `HTTPRoute`.

```bash
# ansehen, was wir migrieren
kubectl get ingress shop-ingress -n gw -o yaml
# verfügbare GatewayClass (von NGINX Gateway Fabric)
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # der Name aus kubectl get gatewayclass
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
# nach der Paritätsprüfung kann der alte Ingress gelöscht werden:
# kubectl delete ingress shop-ingress -n gw
```

Feldzuordnung: `host` → `hostnames`, `path`+`pathType` → `matches.path`,
`backend.service` → `backendRefs`, `rewrite-target` → `filters: URLRewrite`. Einen Entwurf
kann man automatisch mit dem Werkzeug `ingress2gateway print --providers ingress-nginx -A` erzeugen.
