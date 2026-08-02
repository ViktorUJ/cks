[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 110 - 参考解答（Service/DNS、Ingress、NetworkPolicy）

## 課題 1。DNS：pod + service、記録を保存する

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# 一時的な Pod からの解決を確認
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# 記録を保存
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## 課題 2。`/cat` 用の Ingress

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
curl cka.local:30102/cat    # または ノードのIP:30102/cat
```

## 課題 3。`prod-db` の NetworkPolicy

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
# allow from namespace prod
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

## 課題 4。Ingress から Gateway API への移行

元の `Ingress shop-ingress`（ns `gw`）：host `shop.local`、path `/api` → service
`shop:8080`、rewrite `/`。これを `Gateway` + `HTTPRoute` のペアへ移します。

```bash
# 何を移行するのか確認する
kubectl get ingress shop-ingress -n gw -o yaml
# 利用可能な GatewayClass（NGINX Gateway Fabric のもの）
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # kubectl get gatewayclass で得られる名前
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
# パリティ確認のあと、古い Ingress は削除できます：
# kubectl delete ingress shop-ingress -n gw
```

フィールドの対応：`host` → `hostnames`、`path`+`pathType` → `matches.path`、
`backend.service` → `backendRefs`、`rewrite-target` → `filters: URLRewrite`。下書きは
ユーティリティ `ingress2gateway print --providers ingress-nginx -A` で自動生成できます。
