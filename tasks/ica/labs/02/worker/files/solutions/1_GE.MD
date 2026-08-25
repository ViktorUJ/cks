[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 02 - საცნობარო გადაწყვეტა (Dark Launch / სათაურზე დაფუძნებული მარშრუტიზაცია)

## ნაბიჯი 1. sidecar-ის ინექციის ჩართვა

```bash
kubectl label namespace default istio-injection=enabled
```

## ნაბიჯი 2. აპლიკაციის განთავსება (v1 / v2 / v3)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/02/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default   # ensure pods get the sidecar
kubectl get pods                                 # each pod 2/2
```

## ნაბიჯი 3. DestinationRule (ქვეჯგუფები)

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

## ნაბიჯი 4. VirtualService (სათაურის მარშრუტი + canary)

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

## ნაბიჯი 5. Gateway

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

## შემოწმება

```bash
# testers -> always v3
curl -s -H "x-user: tester" http://myapp.local:32080/ | grep 'Server Name:'

# regular users -> 90% v1 / 10% v2, never v3
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Server Name:'; done
```
