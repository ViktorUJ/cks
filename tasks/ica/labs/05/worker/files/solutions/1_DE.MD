[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 05 - Referenzlösung

Verwendete externe Hosts:
- `httpbin.org` - genehmigte externe API (registriert und über das Egress-Gateway weitergeleitet)
- `example.com` - nicht genehmigter Host (muss blockiert werden)

## Schritt 1. Sidecar-Injektion aktivieren

```bash
kubectl label namespace default istio-injection=enabled --overwrite
```

## Schritt 2. Mesh-Client bereitstellen

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/05/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl rollout status deployment/mesh-client -n default
```

## Schritt 3. Externen Dienst registrieren (ServiceEntry)

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

## Schritt 4. Egress-Datenverkehr über das Egress-Gateway weiterleiten

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

Überprüfen, ob der Datenverkehr durch das Egress-Gateway fließt:

```bash
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200   # 200

kubectl logs -n istio-system -l istio=egressgateway --tail=20 | grep httpbin.org
```

## Schritt 5. Egress mit einer Sidecar-Ressource begrenzen

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

## Überprüfung

```bash
# approved host (registered + via egress gw) -> 200
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://httpbin.org/status/200

# unapproved host (not registered) -> 502 (blocked by REGISTRY_ONLY)
kubectl exec -n default deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://example.com/
```
