[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 03 - საცნობარო გადაწყვეტა (შეცდომის ინექცია + განმეორებითი ცდა)

## ნაბიჯი 1. sidecar-ის ინექციის ჩართვა

```bash
kubectl label namespace default istio-injection=enabled
```

## ნაბიჯი 2. აპლიკაციის განთავსება (frontend + ping-pong)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/03/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods                # each pod 2/2
```

## ნაბიჯი 3. Gateway + frontend VirtualService

```yaml
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
  name: frontend-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - main-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 8080
```

## ნაბიჯი 4. შეცდომის ინექცია - backend-ის მწყობრიდან გამოყვანა (50% 503)

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ping-pong-vs
  namespace: default
spec:
  hosts:
  - "ping-pong"
  gateways:
  - mesh
  http:
  - fault:
      abort:
        httpStatus: 503
        percentage:
          value: 50.0
    route:
    - destination:
        host: ping-pong
```

```bash
# ~50% of client requests now show Backend Status 503
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Backend Status'; done
```

## ნაბიჯი 5. განმეორებითი ცდები - პრობლემის გამოსწორება კოდში ჩარევის გარეშე

განაახლეთ `frontend-vs` და დაამატეთ `retries` ბლოკი:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - main-gateway
  http:
  - retries:
      attempts: 7
      perTryTimeout: 2s
      retryOn: 5xx
    route:
    - destination:
        host: frontend
        port:
          number: 8080
```

```bash
kubectl apply -f frontend-vs-retry.yaml
```

## შემოწმება

```bash
# fault is still active, but retries mask it -> ~100% success
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Backend Status'; done

# retry counter on the frontend Envoy
kubectl exec -it $(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- \
  pilot-agent request GET stats | grep upstream_rq_retry
```
