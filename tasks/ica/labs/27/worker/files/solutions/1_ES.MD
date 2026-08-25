[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 27 - Solución de referencia

Istio `1.29.1` está instalado (gateway de entrada en NodePort `32080`). La aplicación `ping-pong`
está desplegada en el espacio de nombres `app` y expuesta en `http://myapp.local:32080/`.

## Objetivo

Adjunta un `EnvoyFilter` con un filtro HTTP de **Lua en línea** al gateway de entrada que:
- agrega un encabezado de respuesta `x-lua-lab: hello-from-lua`;
- rechaza cualquier solicitud que incluya `x-block: yes` con un `403`.

## Paso 1. Línea base

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## Paso 2. Aplica el EnvoyFilter de Lua

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: lua-edge
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_request(request_handle)
                if request_handle:headers():get("x-block") == "yes" then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "blocked by lua\n")
                end
              end
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-lua-lab", "hello-from-lua")
              end
EOF
```

## Paso 3. Verifica

```bash
# response header added by Lua
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab
# x-lua-lab: hello-from-lua

# request blocked by Lua
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/
# 403

# normal request still works
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# 200
```

## Cómo funciona

- **`EnvoyFilter`** modifica la configuración sin procesar de Envoy que genera Istio. Aquí inserta el
  filtro HTTP integrado de **Lua** (`envoy.filters.http.lua`) en el gateway de entrada,
  justo antes del router.
- El script de Lua implementa dos callbacks de ciclo de vida:
  - `envoy_on_request(request_handle)` - se ejecuta por solicitud; puede leer/modificar encabezados, leer
    el cuerpo o realizar un cortocircuito con `request_handle:respond(...)`.
  - `envoy_on_response(response_handle)` - se ejecuta por respuesta; aquí agrega un encabezado.
- `context: GATEWAY` limita el parche al gateway de entrada. Usa `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND` para dirigirlo a los sidecars de las cargas de trabajo.

## Lua frente a Wasm frente a los CRD integrados

- **Lua en línea** - la forma más rápida de añadir lógica personalizada pequeña: sin imagen, sin compilación, edita el
  script en YAML. Ideal para ajustes de encabezados, filtrado simple de solicitudes y experimentos rápidos.
- **Wasm** (Laboratorio 23) - para lógica más compleja/reutilizable en un lenguaje real (Rust/Go), versionada
  y distribuida como una imagen OCI, que se ejecuta en un entorno aislado.
- **CRD integrados** (`AuthorizationPolicy`, `Telemetry`, ...) - prefiérelos siempre primero;
  recurre a Lua/Wasm solo cuando no puedan expresar lo que necesitas.

> `EnvoyFilter` es una API de bajo nivel sensible a versiones - Istio advierte que su configuración puede
> cambiar entre versiones. Mantén dichos parches mínimos y pruébalos en las actualizaciones.
