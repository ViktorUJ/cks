[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 02 - 參考解答（Dark Launch／以標頭為基礎的路由）

## 步驟 1. 啟用 Sidecar 注入

```bash
kubectl label namespace default istio-injection=enabled
```

## 步驟 2. 部署應用程式（v1／v2／v3）

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/02/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default   # ensure pods get the sidecar
kubectl get pods                                 # each pod 2/2
```

## 步驟 3. DestinationRule（子集）

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
  namespace: default
spec:
  host: ping-pong
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

## 步驟 4. VirtualService（標頭路由 + 金絲雀）

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
  namespace: default
spec:
  hosts:
  - "ping-pong"
  - "myapp.local"
  gateways:
  - ping-pong-gateway
  - mesh
  http:
  - match:
    - headers:
        x-user:
          exact: tester
    route:
    - destination:
        host: ping-pong
        subset: v3
  - route:
    - destination:
        host: ping-pong
        subset: v1
      weight: 90
    - destination:
        host: ping-pong
        subset: v2
      weight: 10
```

## 步驟 5. Gateway

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: ping-pong-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.local"
```

## 驗證

```bash
# testers -> always v3
curl -s -H "x-user: tester" http://myapp.local:32080/ | grep 'Server Name:'

# regular users -> 90% v1 / 10% v2, never v3
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Server Name:'; done
```
