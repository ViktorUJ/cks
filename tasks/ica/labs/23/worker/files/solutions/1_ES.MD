[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 23 - Solución de referencia

Istio `1.29.1` está instalado (gateway de entrada en NodePort `32080`). La aplicación `ping-pong`
está desplegada en el espacio de nombres `app` y expuesta en `http://myapp.local:32080/`.

## Objetivo

Amplía el plano de datos de Envoy con un módulo de **WebAssembly**: carga la extensión Wasm
comunitaria `basic_auth` en el gateway de entrada para que las solicitudes necesiten autenticación HTTP Basic.

> Istio `1.29` usa la API `WasmPlugin` (`extensions.istio.io/v1alpha1`). En `1.30+`
> esta se está reemplazando por la API `TrafficExtension`.

## Paso 1. Línea base (no se requiere autenticación)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Paso 2. Aplicar el WasmPlugin

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

El agente de Istio en el gateway de entrada descarga la imagen OCI Wasm, la almacena localmente
en caché y la inyecta como filtro HTTP. Espera unos segundos.

## Paso 3. Verificar

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Cómo funciona

- **WebAssembly (Wasm)** te permite añadir lógica personalizada a Envoy sin reconstruir el proxy
y cargarla dinámicamente durante el tiempo de ejecución.
- **`url: oci://...`**: el módulo se distribuye como un artefacto OCI; el agente de Istio lo descarga y
lo almacena en caché. También puedes usar `file://` (integrado en la imagen) o `http(s)://`.
- **`phase: AUTHN`** coloca el filtro al inicio de la cadena (antes del enrutamiento/autorización).
- **`selector`** limita el plugin a las cargas de trabajo mediante etiquetas (aquí, el gateway de entrada). Un
WasmPlugin en `istio-system` con un selector de gateway afecta solamente al gateway.
- **`pluginConfig`** se pasa al módulo. El módulo `basic_auth` lee
`basic_auth_rules` (prefijo de ruta, métodos y credenciales aceptadas).

## Cuándo usar Wasm

- Autenticación personalizada, enriquecimiento de encabezados, validación de solicitudes o lógica de protocolo que los
CRD integrados de Istio (`AuthorizationPolicy`, `EnvoyFilter`) no pueden expresar.
- Prefiere primero las API integradas; usa Wasm cuando realmente necesites código personalizado en el plano de
datos. Considera el coste operativo: distribución del módulo, control de versiones y la obtención en tiempo de ejecución
(`failStrategy` controla el comportamiento si la descarga falla).
