[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 10 - Solución de referencia (Timeout + Circuit Breaker)

## Paso 1. Habilitar la inyección de sidecar

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## Paso 2. Desplegar la aplicación

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/10/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/slow -n default
kubectl rollout status deployment/backend -n default
```

## Paso 3. Timeout de solicitud

```yaml
# slow-vs.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: slow-vs
  namespace: default
spec:
  hosts:
  - slow
  http:
  - timeout: 2s
    route:
    - destination:
        host: slow
```

```bash
kubectl apply -f slow-vs.yaml

# slow responds after 5s, but the 2s timeout fires first -> 504
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://slow:8080/
```

## Paso 4. Circuit Breaker (connection pool + outlier detection)

```yaml
# backend-cb.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: backend-cb
  namespace: default
spec:
  host: backend
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 5s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
```

```bash
kubectl apply -f backend-cb.yaml
```

## Paso 5. Activar el circuit breaker con carga

```bash
# concurrency (5) far exceeds the pool (1 conn + 1 pending) -> overflow 503
kubectl exec -n default deploy/fortio -c fortio -- \
  fortio load -c 5 -qps 0 -n 50 -quiet http://backend:8080/
```

Observa la distribución de códigos devuelta: una gran proporción de respuestas `503` significa que el
circuit breaker rechazó el exceso.

```bash
# overflow counter on the client-side Envoy
kubectl exec -n default deploy/fortio -c istio-proxy -- \
  pilot-agent request GET stats | grep backend | grep upstream_cx_overflow
```

## Verificar

```bash
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://slow:8080/        # 504

kubectl get destinationrule backend-cb -n default -o yaml | grep -A8 trafficPolicy
```
