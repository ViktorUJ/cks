[RU version](ru.md) · [Eng version](en.md) · [Version française](fr.md) · [Deutsche Version](de.md)

# Capítulo 11. La Kubernetes Gateway API

> **Qué sigue.** En los capítulos 5-10 gestionamos el tráfico mediante recursos de Istio:
> Gateway y VirtualService. Pero Kubernetes ha hecho crecer un estándar común para lo mismo: la
> Kubernetes Gateway API. Istio la soporta plenamente y la considera el futuro del ingress. En
> este capítulo vemos qué es, la comparamos con los recursos de Istio y, lo más importante,
> aclaramos qué usar y cuándo.

## 11.1. Por qué se necesitaba un estándar aparte

Los recursos `Gateway` y `VirtualService` de `networking.istio.io` funcionan de maravilla, pero
tienen un inconveniente: es una API **específica de Istio**. Si mañana decides cambiar de malla
o de controlador de ingress, habrá que reescribir todos los manifiestos para otro producto.
Cada solución (Istio, nginx, Traefik, gateways de nube) tenía su propio conjunto de recursos.

La comunidad de Kubernetes resolvió este problema con un único estándar: la **Kubernetes Gateway
API** (`gateway.networking.k8s.io`). Es una API neutral respecto al proveedor para gestionar el
tráfico entrante, implementada por muchos productos, Istio entre ellos. Lo escribes una vez
contra el estándar y funciona en cualquier implementación compatible.

Avisemos de inmediato sobre la confusión de nombres. Hay dos recursos distintos con la palabra
`Gateway`:

- `Gateway` de `networking.istio.io`: el recurso de Istio (lo hemos usado desde el capítulo 5).
- `Gateway` de `gateway.networking.k8s.io`: el recurso del estándar Kubernetes Gateway API.

Son APIs distintas con estructuras distintas. De aquí en adelante, por "Gateway API" nos
referimos exactamente a la segunda, la estándar.

## 11.2. Roles y recursos de la Gateway API

En la Gateway API la responsabilidad se divide entre varios recursos, cada uno para su propio
rol:

| Recurso | Responsable de | Contraparte en Istio |
|----------|-----------------|-------------------|
| `GatewayClass` | el tipo de implementación (quién maneja el tráfico) | se fija al instalar |
| `Gateway` | en qué escuchar: puertos, protocolos, TLS | `Gateway` de Istio |
| `HTTPRoute` | reglas de enrutamiento HTTP | `VirtualService` de Istio |

Además de `HTTPRoute` hay otras routes para distintos protocolos: `TCPRoute`, `TLSRoute`,
`GRPCRoute`. La idea es la misma que en Istio: "en qué escuchamos" (Gateway) separado de "hacia
dónde enrutamos" (Route).

## 11.3. Instalación de las CRDs de la Gateway API

Un punto práctico importante en el que la gente suele tropezar: los recursos de la Gateway API
son **CRDs que pueden no estar en el clúster por defecto**. Istio implementa el estándar, pero
las definiciones en sí (`GatewayClass`, `Gateway`, `HTTPRoute`…) deben instalarlas o bien la
comunidad o bien Istio. Si las CRDs no están instaladas, tus manifiestos simplemente no se
aplicarán.

Comprueba su presencia:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

Si faltan las CRDs, instálalas desde la release oficial del estándar (el canal `standard`
contiene los recursos estables, `experimental` añade además `TCPRoute`/`TLSRoute` y más):

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio instala una `GatewayClass` llamada `istio` automáticamente al instalarse (istiod observa
las CRDs y crea la clase). Comprueba que la clase esté en su sitio:

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway y HTTPRoute con un ejemplo

Levantemos un gateway en el puerto 80 y enrutemos todo el tráfico al servicio `reviews`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # esta implementación la provee Istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # a qué Gateway se vincula la route
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # directamente el nombre del Service de Kubernetes
      port: 8080
```

```mermaid
flowchart LR
    C["Cliente"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>reglas de enrutamiento"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

Campos clave:

- **`gatewayClassName: istio`**: dice que este Gateway lo implementa Istio. Es la contraparte de
  cómo en un Gateway de Istio nos vinculábamos al ingress gateway vía `selector`.
- **`parentRefs`** en la HTTPRoute enlaza la route con un Gateway concreto. En Istio este rol lo
  cumplía el campo `gateways` en el VirtualService.
- **`backendRefs`** apunta directamente a un Service y puerto de Kubernetes. No hay subsets ni
  DestinationRule en la Gateway API base: las versiones y políticas se describen de otra forma.

Una comodidad más: cuando creas un `Gateway` con `gatewayClassName: istio`, Istio puede
desplegar automáticamente un deployment de Envoy dedicado para ese gateway. No necesitas
instalar un ingress gateway por adelantado: aparece para el Gateway concreto.

## 11.5. TLS: HTTPS en la Gateway API

El TLS en el borde del capítulo 9 se describe con sus propios campos en la Gateway API. Un
listener HTTPS se declara con `protocol: HTTPS` y un bloque `tls`, donde viven el modo y la
referencia al Secret del certificado:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # el gateway termina TLS (como SIMPLE en Istio)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # el mismo Secret tls que en el capítulo 9
    allowedRoutes:
      namespaces:
        from: All                    # qué namespaces pueden adjuntar routes (ver 11.7)
```

La correspondencia con los modos del capítulo 9:

- **`mode: Terminate`**: el gateway descifra TLS (como `SIMPLE`/`MUTUAL` en Istio). La
  verificación del certificado de cliente (el análogo de `MUTUAL`) se configura vía
  `frontendValidation`/`BackendTLSPolicy` y depende de la versión del estándar.
- **`mode: Passthrough`**: el gateway no descifra, el tráfico pasa por SNI (como `PASSTHROUGH`);
  para él usas una `TLSRoute`, no una `HTTPRoute`.

El certificado se almacena en un `Secret` corriente de Kubernetes de tipo `tls`; también puede
emitirlo cert-manager (capítulo 9), solo que ahora la route lo referencia vía `certificateRefs`
en lugar de `credentialName`.

## 11.6. Canary y filtros en HTTPRoute

La división ponderada del tráfico (el canary del capítulo 6) en la Gateway API es una capacidad
**estándar**, no una extensión: `backendRefs` tiene un campo `weight`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # 90% del tráfico a v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% a v2
      port: 8080
      weight: 10
```

Nota: no hay subsets/DestinationRule en la Gateway API, así que las distintas versiones son
**distintos Services de Kubernetes** (`reviews-v1`, `reviews-v2`), no un subset de un mismo
servicio.

HTTPRoute puede modificar peticiones a través de **filtros** (`filters`), la contraparte de
parte de las capacidades del VirtualService:

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # añadir/quitar cabeceras
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # mirroring de tráfico (capítulo 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

Tipos de filtro útiles: `RequestHeaderModifier`/`ResponseHeaderModifier` (cabeceras),
`RequestRedirect` (redirecciones, incluida HTTP→HTTPS), `URLRewrite` (reescritura de la
ruta/host), `RequestMirror` (mirroring). Pero **fault injection** no está en el estándar: eso
sigue siendo exclusivo de la API de Istio (capítulo 8).

## 11.7. Routes entre namespaces: allowedRoutes y ReferenceGrant

Un punto fuerte de la Gateway API es la separación explícita y segura de derechos entre
namespaces. Aquí hay dos mecanismos.

**`allowedRoutes` en un listener**: el propio Gateway decide qué namespaces pueden adjuntarle
routes (`from: Same`: solo el propio, `All`: cualquiera, `Selector`: por etiquetas de
namespace):

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # solo routes de namespaces con esta etiqueta
```

**`ReferenceGrant`**: cuando un recurso de un namespace referencia un recurso de **otro** (por
ejemplo, una HTTPRoute en `apps` quiere enviar tráfico a un Service en `data`), esto está
prohibido por defecto. El permiso se concede con un `ReferenceGrant` en el namespace **destino**:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # el namespace donde vive el Service destino
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # quién referencia
  to:
  - group: ""
    kind: Service              # qué permitimos que se referencie
```

Esto protege de que una route ajena "secuestre" tráfico hacia un servicio de tu namespace sin
tu consentimiento; la API de Istio no tiene un mecanismo integrado así.

## 11.8. Comparación con la API de Istio

| | API de Istio | Kubernetes Gateway API |
|---|-----------|------------------------|
| Recursos de ingress | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Vinculación de la route | el campo `gateways` en VirtualService | `parentRefs` en la Route |
| Elección de implementación | `selector` en el ingress gateway | `gatewayClassName` |
| Versiones/subsets | `DestinationRule` (subsets) | distintos Services + `weight` en `backendRefs` |
| Canary ponderado | peso en `VirtualService` | `backendRefs.weight` (integrado) |
| Mirroring | mirror en `VirtualService` | filtro `RequestMirror` (integrado) |
| Fault injection | sí | no (solo Istio) |
| Políticas de backend | `DestinationRule` (LB, circuit breaking) | no (solo Istio) |
| Separación de derechos por namespace | sin soporte integrado | `allowedRoutes` + `ReferenceGrant` |
| Estándar | específico de Istio | común, neutral respecto al proveedor |
| Portabilidad | solo Istio | cualquier ingress/malla compatible |

La conclusión principal de la tabla: la Gateway API gana en estandarización, portabilidad y
separación de derechos entre equipos, mientras que la API de Istio gana en la amplitud de
capacidades en el receptor (`DestinationRule`: balanceo, circuit breaking, subsets) y en fault
injection. El mirroring y el canary ponderado existen en ambas APIs.

## 11.9. Qué usar y cuándo (buenas prácticas)

Recomendaciones prácticas de qué elegir en proyectos reales.

**Toma la Kubernetes Gateway API cuando:**

- inicias un proyecto nuevo y quieres estar sobre el estándar actual;
- importa la portabilidad: no quieres quedar atado a Istio a nivel de manifiestos;
- necesitas una división clara de responsabilidad entre equipos (el equipo de plataforma es
  dueño del `Gateway`, los equipos de producto son dueños de sus `HTTPRoute`s);
- las capacidades estándar de enrutamiento bastan (por ruta, cabeceras, pesos);
- trabajas con **modo ambient**: los waypoint proxies (capítulo 22) se configuran precisamente
  a través de la Gateway API.

**Quédate en la API de Istio (VirtualService/DestinationRule) cuando:**

- necesitas funciones que el estándar no tiene: **fault injection** (capítulo 8), políticas de
  `DestinationRule` (balanceo de grano fino, circuit breaking, outlier detection, subsets),
  delegación de routes;
- ya tienes muchos manifiestos funcionando sobre la API de Istio y ninguna razón para
  reescribirlos.

(El mirroring y el canary ponderado existen en ambas APIs, así que no hace falta migrar ni
quedarse por su causa.)

### El recurso clásico Ingress de Kubernetes (legacy)

Hay también una tercera vía: el `Ingress` corriente de Kubernetes (`networking.k8s.io/v1`), el
que se usa con nginx-ingress, Traefik y controladores de nube. Istio puede actuar como
controlador de ingress para él: el ingress gateway de Istio lee los recursos `Ingress` si
especifican la clase `istio`.

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # servido por el ingress gateway de Istio
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # un Secret tls, como en el capítulo 9
```

Por qué esto es **legacy** y por qué no debería elegirse para tráfico nuevo:

- El propio estándar `Ingress` tiene un conjunto de capacidades muy pobre: host, ruta, TLS, y
  eso es todo. Ni pesos, ni mirroring, ni redirecciones, ni divisiones basadas en cabeceras.
- Todo lo que va encima se implementa vía **anotaciones no estándar** del controlador (como las
  de nginx, capítulo 26). Las anotaciones son incompatibles entre controladores, e Istio soporta
  solo un pequeño subconjunto de ellas: la mayoría de las conocidas
  `nginx.ingress.kubernetes.io/*` no funcionan.
- La dirección de la industria y del propio Istio es hacia la Gateway API, creada como el
  "`Ingress` de nueva generación".

La conclusión práctica: el `Ingress` clásico en Istio se mantiene solo por compatibilidad con
manifiestos antiguos durante una migración (capítulo 26). Para ingress nuevo toma la Kubernetes
Gateway API o, si necesitas funciones de Istio, el `Gateway` + `VirtualService` de Istio.

**Reglas generales:**

- No describas la misma route a la vez con un VirtualService y una HTTPRoute: eso es confusión y
  conflictos. Para un único servicio elige uno.
- La API de Istio no va a desaparecer y está plenamente soportada, así que la migración puede
  ser gradual: servicios nuevos sobre la Gateway API, los antiguos se quedan como están.
- La dirección de la industria es hacia la Gateway API, así que conviene conocerla y dominarla
  aunque hoy la mayor parte de tu tráfico esté sobre la API de Istio.

## 11.10. Resumen del capítulo

- La Kubernetes Gateway API (`gateway.networking.k8s.io`) es un estándar neutral respecto al
  proveedor para gestionar el tráfico entrante; Istio lo implementa.
- No confundas el `Gateway` de Istio y el `Gateway` de la Gateway API: son recursos distintos.
- Los roles en la Gateway API: `GatewayClass` (la implementación), `Gateway` (en qué escuchar),
  `HTTPRoute` y otras Routes (hacia dónde enrutar).
- La vinculación route-gateway es vía `parentRefs`, la elección de implementación vía
  `gatewayClassName: istio`.
- Las CRDs de la Gateway API pueden no estar por defecto: se instalan aparte (el canal
  `standard`), mientras que Istio crea la `GatewayClass istio` por sí mismo.
- TLS: un listener HTTPS con `tls.mode: Terminate`/`Passthrough` y una referencia a un Secret
  vía `certificateRefs` (la contraparte de `credentialName`); los certificados también los emite
  cert-manager.
- El canary ponderado (`backendRefs.weight`, pero las versiones son distintos Services) y el
  mirroring (el filtro `RequestMirror`) están integrados; fault injection y las políticas de
  `DestinationRule` son solo de la API de Istio.
- Separación de derechos entre namespaces: `allowedRoutes` en un listener y `ReferenceGrant`
  para referencias entre namespaces; no hay análogo integrado en la API de Istio.
- Buena práctica: la Gateway API para ingress nuevo, escenarios estándar y ambient; la API de
  Istio cuando necesitas fault injection o políticas de DestinationRule; no mezcles ambas para
  una misma route.
- Istio también sirve el `Ingress` clásico de Kubernetes (`ingressClassName: istio`), pero eso
  es legacy: las capacidades son pobres, lo avanzado va por anotaciones no estándar (un pequeño
  subconjunto). Se mantiene por compatibilidad durante la migración y no se elige para tráfico
  nuevo.

## 11.11. Preguntas de autoevaluación

1. ¿Qué problema resuelve la Kubernetes Gateway API frente a la API de Istio?
2. ¿En qué se diferencian los dos recursos llamados `Gateway`?
3. ¿Qué recursos de la Gateway API se corresponden con el Gateway y el VirtualService de Istio?
4. ¿De qué se encargan `gatewayClassName` y `parentRefs`?
5. ¿En qué casos es mejor quedarse en el VirtualService/DestinationRule de Istio? ¿Qué funciones
   le faltan a la Gateway API?
6. ¿Por qué no deberías describir una misma route en ambas APIs a la vez?
7. ¿Cómo configuras HTTPS y el canary ponderado en la Gateway API? ¿En qué se diferencia el
   canary respecto a Istio (qué pasa con los subsets)?
8. ¿Para qué sirven `allowedRoutes` y `ReferenceGrant`? ¿Qué problema de seguridad resuelven?
9. ¿Qué deberías comprobar si los manifiestos de la Gateway API no se aplican en el clúster?
10. ¿Puede Istio servir el `Ingress` clásico de Kubernetes, y por qué se considera legacy?
    ¿Cuándo se sigue usando?

## Práctica

Configura ingress a través de la Kubernetes Gateway API (Gateway + HTTPRoute):

🧪 Laboratorio 16: [tasks/ica/labs/16](../../labs/16/README_ES.MD)

---
[Índice](../README_ES.md) · [Capítulo 10](../10/es.md) · [Capítulo 12](../12/es.md)
