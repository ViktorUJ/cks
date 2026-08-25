[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 09 - Solución de referencia (modo ambient)

## Paso 1. Inscribir el espacio de nombres en ambient

```bash
kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
```

## Paso 2. Desplegar la aplicación (sin sidecars)

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/09/k8s-1/scripts/1.yaml

# pods are 1/1 - NO sidecar
kubectl get pods -n default
```

## Paso 3. Verificar la conectividad L4 (ztunnel mTLS)

```bash
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/    # 200 (already mTLS via ztunnel)

kubectl get daemonset ztunnel -n istio-system
```

## Paso 4. Desplegar un proxy waypoint (para L7)

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

## Paso 5. Aplicar una AuthorizationPolicy L7 (solo GET)

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

## Verificar la aplicación de L7

```bash
# GET -> allowed
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/          # 200

# POST -> denied by the waypoint
kubectl exec -n default deploy/curl-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X POST http://ping-pong:8080/  # 403
```
