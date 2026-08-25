[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 05 - リファレンスソリューション

使用する外部ホスト:
- `httpbin.org` - 承認済みの外部 API（登録済みで、egress gateway 経由でルーティングされる）
- `example.com` - 未承認のホスト（ブロックする必要がある）

## ステップ 1. sidecar injection を有効にする

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## ステップ 2. mesh client をデプロイする

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/05/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/mesh-client -n default
```

## ステップ 3. 外部サービスを登録する（ServiceEntry）

```yaml
# service-entry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin-ext
  namespace: default
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
```

```bash
kubectl apply -f service-entry.yaml
```

## ステップ 4. egress traffic を egress gateway 経由でルーティングする

```yaml
# egress-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: istio-egressgateway
  namespace: default
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.org
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-httpbin
  namespace: default
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: httpbin
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin-through-egress
  namespace: default
spec:
  hosts:
  - httpbin.org
  gateways:
  - mesh
  - istio-egressgateway
  http:
  # 1) traffic from the mesh -> send to the egress gateway
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: httpbin
        port:
          number: 80
      weight: 100
  # 2) traffic that arrived at the egress gateway -> send to the external host
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
      weight: 100
```

```bash
kubectl apply -f egress-gateway.yaml
```

egress gateway 経由でトラフィックが流れることを確認します:

```bash
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200   # 200

kubectl logs -n istio-system -l istio=egressgateway --tail=20 | grep httpbin.org
```

## ステップ 5. Sidecar resource で egress のスコープを設定する

```yaml
# sidecar.yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: default
spec:
  egress:
  - hosts:
    - "istio-system/*"   # the egress gateway lives here
    - "./*"              # own namespace (includes the ServiceEntry)
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY  # only registered hosts are reachable
```

```bash
kubectl apply -f sidecar.yaml
```

## 検証

```bash
# approved host (registered + via egress gw) -> 200
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200

# unapproved host (not registered) -> 502 (blocked by REGISTRY_ONLY)
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://example.com/
```
