[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 02 - Referenzlösung (Dark Launch / Header-basiertes Routing)

## Schritt 1. Sidecar-Injektion aktivieren

```bash
kubectl label namespace default istio-injection=enabled
```

## Schritt 2. Anwendung bereitstellen (v1 / v2 / v3)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/02/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default   # ensure pods get the sidecar
kubectl get pods                                 # each pod 2/2
```

## Schritt 3. DestinationRule (Teilmengen)

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

## Schritt 4. VirtualService (Header-Route + Canary)

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

## Schritt 5. Gateway

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

## Überprüfen

```bash
# testers -> always v3
curl -s -H "x-user: tester" http://myapp.local:32080/ | grep 'Server Name:'

# regular users -> 90% v1 / 10% v2, never v3
for i in {1..10}; do curl -s http://myapp.local:32080 | grep 'Server Name:'; done
```
