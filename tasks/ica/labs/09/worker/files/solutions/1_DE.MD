[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 09 - Referenzlösung (Ambient-Modus)

## Schritt 1. Den Namespace in Ambient aufnehmen

```bash
kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
```

## Schritt 2. Die App bereitstellen (keine Sidecars)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/09/k8s-1/scripts/1.yaml

# pods are 1/1 - NO sidecar
kubectl get pods -n default
```

## Schritt 3. L4-Konnektivität überprüfen (ztunnel mTLS)

```bash
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/    # 200 (already mTLS via ztunnel)

kubectl get daemonset ztunnel -n istio-system
```

## Schritt 4. Einen Waypoint-Proxy bereitstellen (für L7)

```yaml
# waypoint.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: default
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

```bash
kubectl apply -f waypoint.yaml

# route the ping-pong service through the waypoint
kubectl label service ping-pong -n default istio.io/use-waypoint=waypoint

kubectl get pods -n default -l gateway.networking.k8s.io/gateway-name=waypoint
```

## Schritt 5. Eine L7-Autorisierungsrichtlinie anwenden (nur GET)

```yaml
# authz.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ping-pong-get-only
  namespace: default
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: ping-pong
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["GET"]
```

```bash
kubectl apply -f authz.yaml
```

## L7-Durchsetzung überprüfen

```bash
# GET -> allowed
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/          # 200

# POST -> denied by the waypoint
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://ping-pong:8080/  # 403
```
