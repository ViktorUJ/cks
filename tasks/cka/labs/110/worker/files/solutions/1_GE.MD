[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 — ეტალონური ამოხსნა (Service/DNS, Ingress, NetworkPolicy)

## დავალება 1. DNS: pod + service, ჩანაწერების შენახვა

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# რეზოლვინგის შემოწმება დროებითი პოდიდან
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# ჩანაწერების შენახვა
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## დავალება 2. Ingress `/cat`-ისთვის

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
curl cka.local:30102/cat    # ან NODE_IP:30102/cat
```

## დავალება 3. NetworkPolicy `prod-db`-ში

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
# allow namespace prod-იდან
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

## დავალება 4. მიგრაცია Ingress → Gateway API

საწყისი `Ingress shop-ingress` (ns `gw`): host `shop.local`, path `/api` → service
`shop:8080`, rewrite `/`. გადავიტანთ წყვილზე `Gateway` + `HTTPRoute`.

```bash
# ვნახოთ, რას ვამიგრირებთ
kubectl get ingress shop-ingress -n gw -o yaml
# ხელმისაწვდომი GatewayClass (NGINX Gateway Fabric-იდან)
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # სახელი kubectl get gatewayclass-იდან
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
# პარიტეტის შემოწმების შემდეგ ძველი Ingress შეიძლება წაიშალოს:
# kubectl delete ingress shop-ingress -n gw
```

ველების შესაბამისობა: `host` → `hostnames`, `path`+`pathType` → `matches.path`,
`backend.service` → `backendRefs`, `rewrite-target` → `filters: URLRewrite`. მონახაზი
ავტომატურად შეიძლება მიიღოთ უტილიტით `ingress2gateway print --providers ingress-nginx -A`.
