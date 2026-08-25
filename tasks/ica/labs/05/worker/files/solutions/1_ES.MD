[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 05 - Solución de referencia

Hosts externos utilizados:
- `httpbin.org` - API externa aprobada (registrada y enrutada a través de la puerta de enlace de salida)
- `example.com` - host no aprobado (debe bloquearse)

## Paso 1. Habilitar la inyección de sidecar

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## Paso 2. Desplegar el cliente de malla

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/05/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/mesh-client -n default
```

## Paso 3. Registrar el servicio externo (ServiceEntry)

```yaml
# service-entry.yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: httpbin-ext
  namespace: default
spec:
  hosts:
  - httpbin.org
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
  location: MESH_EXTERNAL
```

```bash
kubectl apply -f service-entry.yaml
```

## Paso 4. Enrutar el tráfico de salida a través de la puerta de enlace de salida

```yaml
# egress-gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: istio-egressgateway
  namespace: default
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.org
---
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: egressgateway-for-httpbin
  namespace: default
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: httpbin
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin-through-egress
  namespace: default
spec:
  hosts:
  - httpbin.org
  gateways:
  - mesh
  - istio-egressgateway
  http:
  # 1) traffic from the mesh -> send to the egress gateway
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: httpbin
        port:
          number: 80
      weight: 100
  # 2) traffic that arrived at the egress gateway -> send to the external host
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: httpbin.org
        port:
          number: 80
      weight: 100
```

```bash
kubectl apply -f egress-gateway.yaml
```

Verifica que el tráfico fluya a través de la puerta de enlace de salida:

```bash
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200   # 200

kubectl logs -n istio-system -l istio=egressgateway --tail=20 | grep httpbin.org
```

## Paso 5. Limitar la salida con un recurso Sidecar

```yaml
# sidecar.yaml
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: default
spec:
  egress:
  - hosts:
    - "istio-system/*"   # the egress gateway lives here
    - "./*"              # own namespace (includes the ServiceEntry)
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY  # only registered hosts are reachable
```

```bash
kubectl apply -f sidecar.yaml
```

## Verificación

```bash
# approved host (registered + via egress gw) -> 200
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200

# unapproved host (not registered) -> 502 (blocked by REGISTRY_ONLY)
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://example.com/
```
