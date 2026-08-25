[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 03 - Solution de référence (Injection de pannes + nouvelles tentatives)

## Étape 1. Activer l'injection de sidecar

```bash
kubectl label namespace default istio-injection=enabled
```

## Étape 2. Déployer l'application (frontend + ping-pong)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/03/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods                # each pod 2/2
```

## Étape 3. Gateway + VirtualService du frontend

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

## Étape 4. Injection de pannes - interrompre le backend (50 % de 503)

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

## Étape 5. Nouvelles tentatives - résoudre le problème sans modifier le code

Mettez à jour `frontend-vs` en ajoutant un bloc `retries` :

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

## Vérification

```bash
# fault is still active, but retries mask it -> ~100% success
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Backend Status'; done

# retry counter on the frontend Envoy
kubectl exec -it $(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- \
  pilot-agent request GET stats | grep upstream_rq_retry
```
