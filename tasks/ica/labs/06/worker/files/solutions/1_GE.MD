[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 06 - ეტალონური გადაწყვეტა

## ნაბიჯი 1. sidecar-ის ინექციის ჩართვა

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## ნაბიჯი 2. აპლიკაციის განთავსება

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/06/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/ping-pong-v1 -n default
kubectl rollout status deployment/ping-pong-v2 -n default
```

## ნაბიჯი 3. Gateway + VirtualService (მარშრუტიზაცია v1-ზე)

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
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
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  - "ping-pong"
  gateways:
  - main-gateway
  - mesh
  http:
  - route:
    - destination:
        host: ping-pong
        subset: v1
```

```bash
kubectl apply -f gateway.yaml
```

## ნაბიჯი 4. დატვირთვის დაბალანსება (DestinationRule)

```yaml
# destination-rule.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
  namespace: default
spec:
  host: ping-pong
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN          # global algorithm
    portLevelSettings:
    - port:
        number: 8080
      loadBalancer:
        simple: LEAST_REQUEST      # per-port override for 8080
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

```bash
kubectl apply -f destination-rule.yaml
```

დააკვირდით დატვირთვის დაბალანსებას v1-ის სამ რეპლიკას შორის:

```bash
for i in $(seq 12); do curl -s http://myapp.local:32080 | grep 'Server Name'; done | sort | uniq -c
```

მხარდაჭერილი `simple` ალგორითმებია: `ROUND_ROBIN`, `LEAST_REQUEST`, `RANDOM`, `PASSTHROUGH`.

## ნაბიჯი 5. ტრაფიკის ასახვა (ჩრდილოვანი ტრაფიკი v2-ზე)

```yaml
# mirror-vs.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  - "ping-pong"
  gateways:
  - main-gateway
  - mesh
  http:
  - route:
    - destination:
        host: ping-pong
        subset: v1          # 100% of real responses come from v1
    mirror:
      host: ping-pong
      subset: v2            # a copy of every request is sent to v2
    mirrorPercentage:
      value: 100.0
```

```bash
kubectl apply -f mirror-vs.yaml
```

## შემოწმება

```bash
# client always gets v1
for i in $(seq 10); do curl -s http://myapp.local:32080 | grep 'Server Name'; done

# v2 receives mirrored requests (fire-and-forget, response is ignored)
kubectl exec -n default deploy/ping-pong-v2 -c istio-proxy -- \
  pilot-agent request GET stats | grep istio_requests_total | grep destination_workload.ping-pong-v2
```
