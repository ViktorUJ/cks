[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 110 - 參考解答(Service/DNS、Ingress、NetworkPolicy)

## 任務 1。DNS:pod + service,儲存記錄

```bash
kubectl run nginx-resolver --image=viktoruj/ping_pong:latest
kubectl expose pod nginx-resolver --name=nginx-resolver-service --port=80 --target-port=8080

# 從臨時 pod 檢查解析
kubectl run test-nslookup --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup nginx-resolver-service

# 儲存記錄
kubectl get svc nginx-resolver-service -o wide > /var/work/tests/artifacts/dns/nginx.svc
kubectl get pod nginx-resolver -o wide       > /var/work/tests/artifacts/dns/nginx.pod
```

## 任務 2。`/cat` 的 Ingress

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
curl cka.local:30102/cat    # 或 節點IP:30102/cat
```

## 任務 3。`prod-db` 中的 NetworkPolicy

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

## 任務 4。把 Ingress 遷移到 Gateway API

原本的 `Ingress shop-ingress`(ns `gw`):host `shop.local`、path `/api` → service
`shop:8080`、rewrite `/`。我們把它搬到 `Gateway` + `HTTPRoute` 這組物件。

```bash
# 看看我們要遷移的是什麼
kubectl get ingress shop-ingress -n gw -o yaml
# 可用的 GatewayClass(來自 NGINX Gateway Fabric)
kubectl get gatewayclass
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shop-gw
  namespace: gw
spec:
  gatewayClassName: nginx        # kubectl get gatewayclass 中的名稱
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
# 對照確認等價之後,舊的 Ingress 就可以刪除:
# kubectl delete ingress shop-ingress -n gw
```

欄位對應:`host` → `hostnames`、`path`+`pathType` → `matches.path`、
`backend.service` → `backendRefs`、`rewrite-target` → `filters: URLRewrite`。也可以用
`ingress2gateway print --providers ingress-nginx -A` 工具自動產生草稿。
