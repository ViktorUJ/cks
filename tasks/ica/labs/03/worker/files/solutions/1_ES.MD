[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 03 - Solución de referencia (Inyección de fallos + Reintentos)

## Paso 1. Habilitar la inyección de sidecar

```bash
kubectl label namespace default istio-injection=enabled
```

## Paso 2. Desplegar la aplicación (frontend + ping-pong)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/03/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods                # each pod 2/2
```

## Paso 3. Gateway + VirtualService de frontend

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

## Paso 4. Inyección de fallos - interrumpir el backend (50 % 503)

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

## Paso 5. Reintentos - solucionarlo sin tocar el código

Actualiza `frontend-vs` añadiendo un bloque `retries`:

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

## Verificar

```bash
# fault is still active, but retries mask it -> ~100% success
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Backend Status'; done

# retry counter on the frontend Envoy
kubectl exec -it $(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- \
  pilot-agent request GET stats | grep upstream_rq_retry
```
