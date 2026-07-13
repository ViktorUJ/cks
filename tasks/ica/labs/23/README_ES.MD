[RU version](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD)

# Lab 23 - WasmPlugin: extender el data plane mediante WebAssembly

## Resumen

A veces los CRD integrados de Istio (`AuthorizationPolicy`, `EnvoyFilter`) no bastan:
necesitas tu propia lógica directamente en el data plane. Para eso existe **WebAssembly
(Wasm)**: escribes (o tomas uno ya hecho) un módulo, y Envoy lo carga dinámicamente en
tiempo de ejecución, sin recompilar el proxy.

En este lab conectarás el módulo de la comunidad **`basic_auth`** en el ingress gateway,
para que las peticiones requieran autenticación HTTP Basic.

> Istio `1.29` usa la API `WasmPlugin` (`extensions.istio.io/v1alpha1`). En `1.30+` la
> reemplaza la API `TrafficExtension`.

Istio ya está instalado (ingress gateway en el NodePort `32080`), la aplicación
`ping-pong` está desplegada en el namespace `app` y publicada en
`http://myapp.local:32080/`.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"sin creds/creds inválidas"| R["401 Unauthorized"]
    GW -->|"creds correctas"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## Qué es WebAssembly (para quienes no lo han visto)

En pocas palabras: **WebAssembly (Wasm)** es un formato de pequeños programas compilados
que se pueden ejecutar de forma segura dentro de otro programa. En origen, Wasm se ideó
para los navegadores (para correr código en C++/Rust junto a JavaScript), pero hoy se usa
en cualquier lugar, incluido el interior de proxies de red.

Veamos paso a paso qué ocurre aquí:

- **Qué es el data plane y Envoy.** En Istio, junto a cada pod funciona un proxy
  **Envoy** (ese mismo «sidecar»). Por él pasa todo el tráfico de red del pod, entrante y
  saliente. Al conjunto de estos proxies se le llama *data plane*. Es Envoy quien realmente
  aplica las reglas: mTLS, enrutamiento, límites, autorización.
- **El problema.** Envoy sabe hacer mucho «de fábrica», pero no todo se puede prever.
  Antes, para añadir tu propia lógica, había que recompilar Envoy en C++ y sustituir la
  imagen del proxy: algo lento, arriesgado y que se rompe con las actualizaciones.
- **La idea del plugin Wasm.** En lugar de recompilar, escribes un pequeño módulo en el
  lenguaje que prefieras (**Rust, C++, Go/TinyGo, AssemblyScript**), lo compilas a `.wasm`
  y se lo «das de comer» a Envoy. Envoy carga ese módulo **al vuelo, sin reinicio ni
  recompilación**, y empieza a pasar las peticiones a través de él.
- **Sandbox (caja de arena).** El módulo Wasm se ejecuta en un entorno aislado: no tiene
  acceso directo a la memoria de Envoy ni al host, y se comunica con el proxy únicamente a
  través de una interfaz estrictamente definida. Incluso si el módulo «se cae», no derriba
  al proxy. Esto hace que ejecutar código propio o ajeno en los proxies sea relativamente
  seguro.
- **proxy-wasm ABI.** La interacción «Envoy ↔ módulo Wasm» está estandarizada por el
  protocolo **proxy-wasm** (un conjunto de funciones-hook: «llegó una petición», «llegó una
  cabecera», «llegó el cuerpo», etc.). Gracias a este estándar común, un mismo módulo
  funciona en distintas versiones de Envoy/Istio e incluso en otros proxies compatibles con
  proxy-wasm.
- **Cómo llega el módulo al proxy.** El módulo se empaqueta en una **imagen OCI** (como una
  imagen Docker normal) y se sube a un registro. En el `WasmPlugin` indicas `url: oci://...`
  y el istio-agent descarga el módulo por sí mismo, lo cachea en el nodo y lo conecta a
  Envoy como filtro HTTP.

Una analogía: es como un «plugin/extensión de navegador», solo que aquí el plugin no se
instala en el navegador, sino en el proxy de red, y no procesa páginas web, sino peticiones
de red entre servicios. En este lab, ese «plugin» será el módulo ya hecho `basic_auth`, que
exige usuario/contraseña (HTTP Basic auth) a la entrada de la malla.

## Módulos ya hechos y cómo crear el tuyo

**Módulos Wasm ya hechos (no hace falta escribir código).** A menudo la funcionalidad que
necesitas ya la escribió alguien: basta con indicar el enlace a la imagen en el
`WasmPlugin`:

- **istio-ecosystem/wasm-extensions** - ejemplos oficiales de la comunidad de Istio
  (`basic_auth` y otros), publicados en `ghcr.io/istio-ecosystem/wasm-extensions/...`
  (es justo el que usamos en el lab).
- **Módulos de producto ya hechos** de proveedores (por ejemplo, coraza-WAF como Wasm, OPA,
  distintos filtros de auth/rate-limit), que se distribuyen como imágenes OCI.
- **WebAssembly Hub / registros OCI** - los módulos se empaquetan como imágenes OCI
  normales, por eso se pueden almacenar en cualquier registro (ghcr, Docker Hub, ECR,
  Harbor privado).

La regla es simple: si el módulo está como imagen OCI, solo escribes `url: oci://...` y no
hace falta escribir código.

**Si necesitas tu propio módulo, el camino corto.** La lógica propia se escribe en un
lenguaje que compile a Wasm, usando el proxy-wasm SDK:

1. **Elegir lenguaje y SDK.** Populares: **Rust** (`proxy-wasm/proxy-wasm-rust-sdk`),
   **Go/TinyGo** (`proxy-wasm-go-sdk`), C++ o AssemblyScript. Para producción se suele
   tomar Rust (rápido, `.wasm` compacto).
2. **Escribir los hooks.** En el SDK implementas los callbacks del ciclo de vida de la
   petición, por ejemplo `on_http_request_headers` (llegaron las cabeceras de la petición),
   `on_http_response_headers`, etc. Dentro va tu lógica: comprobar una cabecera,
   añadirla/modificarla, devolver un error.
3. **Compilar a Wasm.** Por ejemplo, para Rust:
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # resultado: target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **Empaquetar en imagen OCI y hacer push.** Istio espera el Wasm dentro de un artefacto
   OCI. Es cómodo construirlo con herramientas como `buildah`/`docker` o `func-e`/`wasme`;
   luego `docker push <registry>/my-plugin:1.0`.
5. **Conectar mediante WasmPlugin.** Indicas `url: oci://<registry>/my-plugin:1.0` y, si
   hace falta, `pluginConfig` con tus parámetros, igual que en este lab.

Ejemplo mínimo de lógica en Rust (añadimos una cabecera de respuesta):

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

Para el desarrollo real, consulta las guías del repositorio
`istio-ecosystem/wasm-extensions` (cómo escribir, probar y construir imágenes OCI).

## Tarea

1. Comprobar que sin el plugin la aplicación está accesible (`200`).
2. Aplicar un `WasmPlugin` que, en el ingress gateway (`selector: istio=ingressgateway`),
   cargue el módulo `basic_auth` desde un registro OCI y exija autenticación Basic.
3. Comprobar que sin credenciales la petición se rechaza con `401` y con credenciales
   correctas devuelve `200`.

## Paso 1. Comportamiento base (sin auth)

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

El istio-agent en el ingress gateway descargará la imagen OCI del Wasm, la cacheará
localmente y la incrustará como filtro HTTP. Dale unos segundos.

## Paso 3. Comprobación

```bash
# sin credenciales -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# con credenciales correctas -> 200  (base64 de admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Cómo funciona

- **WebAssembly (Wasm)** permite añadir a Envoy lógica personalizada sin recompilar el
  proxy y cargarla dinámicamente en tiempo de ejecución.
- **`url: oci://...`** - el módulo se entrega como artefacto OCI; el istio-agent lo
  descarga y lo cachea. También se soportan `file://` (embebido en la imagen) y
  `http(s)://`.
- **`phase: AUTHN`** coloca el filtro temprano en la cadena (antes del routing/autorización).
- **`selector`** limita el plugin a los workloads por labels (aquí, el ingress gateway).
- **`pluginConfig`** se pasa al módulo; `basic_auth` lee `basic_auth_rules` (prefijo de
  ruta, métodos, credenciales admitidas).

## Cuándo es útil (escenarios reales)

- **Autenticación/autorización personalizada**: Basic auth, comprobación de API-key, firma
  HMAC de la petición, integración con un IdP no estándar, es decir, lo que no se puede
  expresar mediante `RequestAuthentication`/`AuthorizationPolicy`.
- **Manipulación de peticiones/respuestas**: enriquecimiento de cabeceras desde una fuente
  externa, cálculo de firma, edición del cuerpo (enmascarado de PII), normalización de
  rutas.
- **Lógica de protocolo y de negocio en el borde**: rate limiting específico por una clave
  personalizada, feature flags, A/B basado en reglas complejas, decodificación de un
  protocolo propietario.
- **Compliance y seguridad**: audit-logging en un formato especial, comprobaciones tipo
  WAF, bloqueo por firmas personalizadas.
- **Sacar la lógica de la aplicación**: una misma lógica transversal (auth, logging,
  cabeceras) se implementa una vez en la malla, y no en cada servicio y en cada lenguaje.

## Ventajas frente a las alternativas

| Enfoque | Pros | Contras / cuándo es peor que Wasm |
|---|---|---|
| **CRD integrados** (`AuthorizationPolicy`, `RequestAuthentication`, `Telemetry`, `EnvoyFilter` local ratelimit) | Sencillo, declarativo, soportado por Istio | Limitados a capacidades predefinidas; no permiten expresar lógica arbitraria |
| **`EnvoyFilter` + Lua** (ver lua-scripts) | Sin recompilar, script inline | Solo Lua; las tareas pesadas son más lentas; sin tipado estricto/tests; la lógica queda «desperdigada» por YAML |
| **`EnvoyFilter` con filtro C++ nativo** | Máxima velocidad | Requiere recompilar Envoy y una imagen de proxy personalizada; incompatible con las actualizaciones; barrera de entrada alta |
| **Lógica en la propia aplicación** | Control total | Se duplica en cada servicio y en cada lenguaje; difícil garantizar uniformidad y actualización |
| **Servicio externo (ext_authz / callout)** | Cualquier lenguaje, despliegue aparte | Salto de red adicional y latencia en cada petición; un componente más que operar |
| **WasmPlugin (este lab)** | Tu propio código en cualquier lenguaje que compile a Wasm (C++, Rust, Go/TinyGo, AssemblyScript); carga **en tiempo de ejecución sin recompilar Envoy y sin reinicio**; se ejecuta **in-process** (sin salto de red, como sí ocurre con ext_authz); sandbox de Wasm: aislamiento y seguridad; portabilidad entre versiones de Envoy/Istio gracias al proxy-wasm ABI estable; versionado y entrega mediante registro OCI | API en estado Alpha; sobrecosto de la carga en runtime y el cacheo del módulo; el código propio hay que mantenerlo, probarlo y versionarlo; depurar es más difícil que con los CRD declarativos |

**En resumen:** Wasm gana cuando necesitas lógica *arbitraria* en el data plane, pero a la
vez importan la baja latencia (in-process, sin el salto extra de ext_authz), la seguridad
(sandbox) y la posibilidad de desplegar/actualizar el filtro dinámicamente sin recompilar
el proxy.

**Orden de elección en la práctica:** primero los CRD integrados → si no bastan,
`EnvoyFilter` (incluido Lua para lo simple) → `ext_authz` externo si la lógica es más fácil
de mantener como servicio aparte y la latencia no es crítica → **Wasm** cuando necesitas tu
propio código rápido in-process dentro del propio proxy. Ten en cuenta el coste operativo
de Wasm: entrega del módulo, versionado y carga en runtime (`failStrategy` define el
comportamiento ante una carga fallida: fail-open o fail-close).

## Verificación del resultado

Ejecuta en el worker PC:

```bash
check_result
```

## Conclusión

Has extendido el data plane con tu propio módulo Wasm, cargado desde un registro OCI, y has
añadido autenticación Basic en el borde de la malla sin modificar la aplicación. Trabajar
con `WasmPlugin` es una habilidad senior para los casos en que las capacidades integradas de
Istio no bastan.

## Infraestructura

| Componente | Tipo | Cantidad | Rol |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | capacidad para la aplicación |
| worker PC | `t3.small` | 1 | puesto de trabajo: `kubectl`, `curl`, `check_result` |

Región: `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).
