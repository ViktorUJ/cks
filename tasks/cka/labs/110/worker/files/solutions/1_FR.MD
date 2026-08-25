[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 — solution de référence (Service/DNS, Ingress, NetworkPolicy)

## Tâche 1. DNS : pod + service, enregistrer les résultats

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# vérification de la résolution depuis un pod temporaire
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# enregistrer les résultats
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## Tâche 2. Ingress pour `/cat`

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
curl cka.local:30102/cat    # ou IP_DU_NŒUD:30102/cat
```

## Tâche 3. NetworkPolicy dans `prod-db`

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
# allow depuis le namespace prod
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

## Tâche 4. Migration Ingress → Gateway API

L'`Ingress shop-ingress` de départ (ns `gw`) : host `shop.local`, path `/api` → service
`shop:8080`, rewrite `/`. Nous le transférons vers la paire `Gateway` + `HTTPRoute`.

```bash
# regarder ce que l'on migre
kubectl get ingress shop-ingress -n gw -o yaml
# les GatewayClass disponibles (de NGINX Gateway Fabric)
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # le nom issu de kubectl get gatewayclass
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
# après la vérification de parité, l'ancien Ingress peut être supprimé :
# kubectl delete ingress shop-ingress -n gw
```

Correspondance des champs : `host` → `hostnames`, `path`+`pathType` → `matches.path`,
`backend.service` → `backendRefs`, `rewrite-target` → `filters: URLRewrite`. Un brouillon peut
être obtenu automatiquement avec l'utilitaire `ingress2gateway print --providers ingress-nginx -A`.
