[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 16 - Referenzlösung

Istio `1.29.1` ist bereits installiert (Standardprofil), und die Kubernetes-Gateway-API-
CRDs (`v1.2.1`) sind vorhanden. Die App (`ping-pong-v1` / `ping-pong-v2`) ist im
Namespace `app` bereitgestellt.

## Schritt 1. Die Anwendung bereitstellen

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

Jeder Pod sollte den Status `2/2` haben (App + istio-proxy-Sidecar).

## Schritt 2. Ein Gateway erstellen (Kubernetes Gateway API)

Das Gateway wird annotiert, sodass Istio einen **NodePort**-Service dafür bereitstellt
(diese Testumgebung hat keinen Cloud-Load-Balancer).

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: app
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

kubectl apply -f gateway.yaml
```

Istio stellt automatisch ein Deployment und einen Service namens `web-gateway-istio` im
Namespace `app` bereit:

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## Schritt 3. Eine HTTPRoute erstellen

Leite den Header `x-version: canary` an **v2** weiter, alles andere an **v1**.

```bash
cat > httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ping-pong-route
  namespace: app
spec:
  parentRefs:
    - name: web-gateway
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: ping-pong-v2
          port: 8080
    - backendRefs:
        - name: ping-pong-v1
          port: 8080
EOF

kubectl apply -f httproute.yaml
```

## Schritt 4. Das Routing überprüfen

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

Erwartet: Die Standardanfrage gibt `Ping-Pong-V1 (Stable)` zurück, und die Anfrage mit
dem Header `x-version: canary` gibt `Ping-Pong-V2 (Canary)` zurück.

## Istio API vs. Gateway API

| Konzept | Istio API | Kubernetes Gateway API |
|---|---|---|
| Einstiegspunkt | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| Routing-Regeln | `VirtualService` | `HTTPRoute` |
| Backend | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Gateway-Pod | gemeinsam genutztes `istio-ingressgateway` | automatisch für jedes `Gateway` bereitgestellt |
| Portabilität | Istio-spezifisch | herstellerneutral, über Meshes/Ingress hinweg portierbar |