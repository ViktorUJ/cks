[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 03 - эталонное решение (Fault Injection + Retry)

## Шаг 1. Включите инъекцию sidecar

```bash
kubectl label namespace default istio-injection=enabled
```

## Шаг 2. Разверните приложение (frontend + ping-pong)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/03/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods                # each pod 2/2
```

## Шаг 3. Gateway + VirtualService для frontend

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

## Шаг 4. Fault Injection - нарушьте работу backend (50% 503)

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

## Шаг 5. Retries - исправьте без изменения кода

Обновите `frontend-vs`, добавив блок `retries`:

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

## Проверка

```bash
# fault is still active, but retries mask it -> ~100% success
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Backend Status'; done

# retry counter on the frontend Envoy
kubectl exec -it $(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- \
  pilot-agent request GET stats | grep upstream_rq_retry
```
