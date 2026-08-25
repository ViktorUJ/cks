[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 16 - Solución de referencia

Istio `1.29.1` ya está instalado (perfil predeterminado) y los CRD de la API Gateway de Kubernetes
(`v1.2.1`) están presentes. La aplicación (`ping-pong-v1` / `ping-pong-v2`) está desplegada en el
namespace `app`.

## Paso 1. Desplegar la aplicación

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

Cada pod debe ser `2/2` (app + sidecar istio-proxy).

## Paso 2. Crear un Gateway (API Gateway de Kubernetes)

El Gateway está anotado para que Istio aprovisione un Service **NodePort** para él (este entorno
de pruebas no tiene un balanceador de carga en la nube).

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

Istio aprovisiona automáticamente un Deployment y un Service llamados `web-gateway-istio` en el
namespace `app`:

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## Paso 3. Crear un HTTPRoute

Enruta el encabezado `x-version: canary` a **v2**; todo lo demás a **v1**.

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

## Paso 4. Verificar el enrutamiento

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

Resultado esperado: la solicitud predeterminada devuelve `Ping-Pong-V1 (Stable)`, y la solicitud
con el encabezado `x-version: canary` devuelve `Ping-Pong-V2 (Canary)`.

## API de Istio frente a API Gateway

| Concepto | API de Istio | API Gateway de Kubernetes |
|---|---|---|
| Punto de entrada | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| Reglas de enrutamiento | `VirtualService` | `HTTPRoute` |
| Backend | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Pod de Gateway | `istio-ingressgateway` compartido | aprovisionado automáticamente por cada `Gateway` |
| Portabilidad | Específico de Istio | independiente del proveedor, portable entre meshes/ingress |
