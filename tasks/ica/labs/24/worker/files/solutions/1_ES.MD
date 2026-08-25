[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 24 - Solución de referencia

Istio `1.29.1` está instalado en modo **ambient** (istiod + istio-cni + ztunnel). El
espacio de nombres `app` está inscrito en ambient (`istio.io/dataplane-mode: ambient`) y ejecuta
`ping-pong` además de `app-client`, ambos **sin** sidecars. `istioctl` está disponible en
el PC de trabajo.

## Contexto

- **ztunnel** proporciona a cada carga de trabajo ambient mTLS L4 e identidad, pero **no**
  entiende HTTP. Por tanto, las políticas L4 (permitir/denegar por identidad/puerto) funcionan, pero las reglas L7
  (métodos HTTP, rutas, encabezados) no.
- Para aplicar una política **L7**, agregue un **proxy waypoint**, un Envoy por espacio de nombres (o
  por servicio) a través del cual se enruta el tráfico ambient para el procesamiento L7.

## Objetivo

Agregue un waypoint al espacio de nombres `app` y una `AuthorizationPolicy` L7 que permita solo
solicitudes `GET` a `ping-pong` (todo lo demás → `403`).

## Paso 1. Aprovisione un waypoint

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` etiqueta el espacio de nombres (`istio.io/use-waypoint: waypoint`), de modo que el tráfico
a los servicios de `app` se enruta a través del waypoint.

## Paso 2. Aplique una AuthorizationPolicy L7

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

Una política `ALLOW` deniega de forma predeterminada todo lo que no coincida, por lo que solo `GET`
pasa; los demás métodos reciben `403`.

## Paso 3. Verifique

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## Cómo funciona

- **L4 sin sidecar (ztunnel)** gestiona mTLS e identidad para todo el espacio de nombres sin
  un proxy por pod. Es económico y siempre está activo en ambient.
- **Waypoint (L7)** se agrega solo donde necesita capacidades de nivel HTTP: autorización L7,
  enrutamiento, reintentos, división del tráfico. Solo utiliza un Envoy para esos servicios.
- La `AuthorizationPolicy` usa `targetRefs` para referirse al `Gateway` waypoint, por lo que se aplica en
  el salto L7. La misma política adjunta a un sidecar/ingress también funciona, ambient solo traslada
  el punto de aplicación L7 al waypoint.
- Este modelo en capas (ztunnel para L4 en todas partes, waypoint para L7 donde se necesita) es la idea
  clave de ambient: menor coste base que los sidecars, L7 opcional.

## Material relacionado

El laboratorio 09 cubre los conceptos básicos de ambient (ztunnel L4). El laboratorio 04 cubre la misma `AuthorizationPolicy`
en el modelo sidecar.
