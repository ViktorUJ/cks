[Русская версия](ru.md) · [Eng version](README.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Capítulo 06. Cilium NetworkPolicy

> **El problema.** Un frontend comprometido puede usar el acceso TCP permitido
> al backend para `POST /admin` o enviar datos a una IP externa después de DNS-resolve:
> NetworkPolicy L3/L4 no distingue esto. Sin restricciones L7, FQDN e identity-aware,
> una conexión permitida se convierte en un canal para una solicitud peligrosa o exfiltración,
> y la falta de observabilidad dificulta detectar un DROP e investigarlo.

> **Qué sigue.** Las NetworkPolicy nativas ya permiten aislar Pods y cerrar el
> acceso a servicios de metadata. Pero para algunos escenarios no es suficiente: se debe permitir
> un método HTTP específico, tener en cuenta nombres DNS de servicios externos, diferenciar el tráfico al clúster
> del tráfico a Internet y ver la causa de cada DROP (un paquete descartado sin respuesta
> para el remitente). **CiliumNetworkPolicy** amplía
> las capacidades básicas de las políticas de red de Cilium con filtrado L7, reglas FQDN, identities y
> observabilidad. Este capítulo profundiza la competencia CKS Cluster Setup «Use Network security
> policies to restrict cluster level access» y sirve de base para el laboratorio 102.
>
> El programa público de CKS no exige CiliumNetworkPolicy, `toFQDNs` ni Hubble en
> todos los entornos de examen, por lo que debes considerar los comandos y CRD específicos de Cilium como
> una profundización para clústeres donde Cilium esté realmente disponible.

> **Cilium no aparece por sí solo en el clúster.** Es un CNI independiente que
> instala el administrador del clúster, mediante la CLI `cilium` o un Helm chart, sobre un clúster ya
> creado o en lugar del CNI estándar al crearlo. Si Cilium aún no está instalado en tu entorno,
> todos los ejemplos de este capítulo son inaplicables hasta instalarlo. Instrucción oficial:
> [Instalación rápida de Cilium](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/).
> Encontrarás ejemplos L3/L4/L7 más detallados que los analizados en este capítulo en la sección oficial
> [Resumen de Network Policy](https://docs.cilium.io/en/stable/security/policy/),
> incluidas páginas independientes para las políticas Layer 3, Layer 4 y Layer 7.

> **Qué necesitas de CKA.** Consulta el modelo básico de CNI y las direcciones IP de Pods y Services en el
> [capítulo 30 de CKA](../../../cka/course/30/es.md), y el propósito de CNI y su lugar en el stack
> de red en el [capítulo 40 de CKA](../../../cka/course/40/es.md). La sintaxis básica de Kubernetes
> NetworkPolicy se explica en el capítulo 04 de este curso; aquí no la repetimos, sino que usamos las
> capacidades de Cilium.

> 🧠 `kube-proxy` dirige `ClusterIP:port` al Pod seleccionado y el CNI aplica `NetworkPolicy` por separado.

## 06.0. Qué es nuevo para ti: eBPF datapath en vez de kube-proxy

### Baseline sin Cilium: cómo llega actualmente el tráfico a un Service

Hasta este capítulo, `kube-proxy` proporcionaba la ruta de un paquete a un Service. El mecanismo tiene tres
partes:

- **Observación.** En cada nodo, `kube-proxy` escucha cambios en los objetos Service y
  `EndpointSlice`.
- **Programación del kernel.** En cada cambio actualiza reglas del kernel, normalmente mediante
  `iptables` o `nftables` (el obsolescente `ipvs` también es posible).
- **Interceptación y DNAT.** Una regla intercepta tráfico hacia `ClusterIP:port` y realiza DNAT a la IP
  de un Pod específico elegido de forma aleatoria o por session affinity.

La `NetworkPolicy` del capítulo 04 es una capa independiente sobre este mismo modelo: el CNI, por su parte,
lee el objeto `NetworkPolicy` y añade sus propias reglas de kernel que permiten o bloquean un paquete **antes o después**
de las reglas de kube-proxy, según la implementación.

> 🧠 Cilium vincula los labels de workload con identity y aplica la policy L3/L4 mediante eBPF maps; L7 requiere una proxy path.

### Qué cambia Cilium: eBPF como datapath L3/L4 principal

Cilium propone una arquitectura diferente para la misma ruta de paquetes:

- **eBPF como datapath L3/L4 principal.** Para pod networking, policy L3/L4 y
  kube-proxy-replacement, Cilium usa programas eBPF y BPF maps. Los programas se
  conectan a hook points del kernel, por ejemplo, interfaces de red y cgroup.
- **Map lookup en lugar de recorrido lineal de `iptables`.** En kube-proxy-replacement, Cilium
  almacena el estado Service/backend en BPF maps y realiza lookup sin recorrer secuencialmente una
  larga cadena de `iptables`. Esta es una diferencia importante específicamente frente a kube-proxy en modo `iptables`.
  No extiendas esta comparación a kube-proxy `nftables`: el modo nftables moderno también
  usa map-based dispatch (`verdict map`) con lookup aproximadamente O(1); consulta los detalles en
  el blog oficial de Kubernetes sobre el modo nftables de kube-proxy.
- **Dos modos de funcionamiento.** El **kube-proxy-replacement** completo implementa todo el Service load
  balancing en eBPF y permite eliminar `kube-proxy` del clúster. En modo de coexistencia,
  `kube-proxy` sigue atendiendo Service, mientras Cilium añade policy enforcement y capacidades L7
  a su lado.

Ambos modos son posibles en producción y el examen CKS no exige uno concreto.

Es importante separar las capas. L3/L4 forwarding, policy enforcement y Service load balancing en
kube-proxy-replacement de Cilium se implementan principalmente mediante eBPF.

La policy L7 HTTP/DNS funciona de forma distinta: el tráfico seleccionado se redirige a un node-local userspace
proxy (Envoy o DNS proxy). En las versiones stable actuales de Cilium, dicha redirección de proxy
también puede usar netfilter/`iptables` TPROXY. Por ello, Cilium no debe describirse como un
datapath que, con cualquier función, excluye por completo `iptables` y userspace.

> 🎯 Usa `NetworkPolicy` nativa para labels/CIDR y puertos L3/L4, CNP para L7 HTTP/DNS, `toFQDNs`, `toEntities` y observabilidad de Cilium.

### Cuándo basta `NetworkPolicy` y cuándo se necesita CNP

De la diferencia entre mecanismos se sigue un criterio práctico para elegir entre la
`NetworkPolicy` nativa y CiliumNetworkPolicy (CNP):

- **Empieza con `NetworkPolicy` nativa.** Si la tarea es permitir o denegar tráfico
  entre Pods por labels, namespace, CIDR y puerto TCP/UDP/SCTP, basta con ella. La policy es
  portable entre clústeres y CNI, por lo que pasar a CNP sin motivo complica la migración
  y el mantenimiento.
- **Pasa a CNP cuando necesites control dentro de una conexión L3/L4 ya permitida.** Los
  desencadenantes típicos son limitar un método o ruta HTTP específicos (L7), permitir o
  denegar nombres DNS externos específicos (`toFQDNs`), describir explícitamente el tráfico a
  `world`, `cluster` o `host` (`toEntities`), u obtener observabilidad mediante Hubble para
  investigar un `DROP`.
- **Ambos modelos se pueden combinar.** La `NetworkPolicy` nativa sigue siendo un control L3/L4
  portable, y CNP aporta más granularidad donde L3/L4 ya no basta.
  Los detalles de la evaluación conjunta de allow/deny se analizan más adelante en este capítulo.

> 🧠 CNP añade labels, L7 y FQDN a `NetworkPolicy` nativa; un deny explícito de Cilium tiene prioridad sobre allow.

## 06.1. Por qué se necesita una policy de Cilium

La `NetworkPolicy` nativa describe relaciones de red en las capas L3/L4: qué Pods,
CIDR y puertos pueden intercambiar tráfico TCP/UDP. Intencionadamente no conoce rutas HTTP,
nombres DNS ni contexto de conexión. Cilium implementa policy de red en eBPF y añade
identities de workloads, proxy L7 y observabilidad.

Escenario de ataque: frontend se compromete mediante una vulnerabilidad de la aplicación. Una policy
normal puede permitirle TCP/80 hacia backend, por lo que el atacante obtiene el mismo acceso. Si
backend acepta solo `GET /`, `POST /admin` o `DELETE /data` no deberían pasar ni siquiera
con una conexión TCP permitida. Otro escenario frecuente es que un Pod contacte una IP externa arbitraria
tras DNS-resolve y envíe datos al atacante.

```mermaid
flowchart TB
    attacker["frontend<br/>comprometido"]
    gap["L3/L4 permite<br/>TCP/80: POST /admin<br/>y también el servidor<br/>externo"]
    cnp["CiliumNetworkPolicy:<br/>L7 · solo GET /<br/>FQDN DNS-aware"]
    blocked["Solicitudes peligrosas<br/>bloqueadas"]

    attacker --> gap --> cnp --> blocked

    style attacker fill:#db4437,color:#fff
    style gap fill:#f4b400,color:#000
    style cnp fill:#673ab7,color:#fff
    style blocked fill:#0f9d58,color:#fff
```

Cilium evalúa la policy por identity, no solo por IP. Para workloads de Kubernetes, la
identity se construye a partir de labels. Al recrearse un Pod cambia su IP, pero una regla con
`endpointSelector` sigue funcionando si los labels se mantienen iguales.

| Capacidad | `NetworkPolicy` nativa | `CiliumNetworkPolicy` |
|---|---|---|
| L3: pod/CIDR | sí | sí, labels e identities |
| L4: puerto TCP/UDP/SCTP | sí | sí |
| L7: HTTP, DNS | no | sí |
| Reglas por FQDN | no | sí, `toFQDNs` |
| `world` / `cluster` / `host` | no | sí, `toEntities` |
| Observabilidad de flujos | depende de CNI | Hubble y CLI `cilium` |

`CiliumNetworkPolicy` (CNP) opera en el namespace de su objeto. Es adecuada para policies
de equipo o aplicación. `CiliumClusterwideNetworkPolicy` (CCNP) opera en todo el
clúster y resulta cómoda para reglas comunes de plataforma, por ejemplo denegar egress peligroso en todos los
namespaces. CCNP tiene consecuencias más fuertes: un error en un selector amplio puede aislar todo el
clúster, por lo que primero debes comprobar la regla en un namespace independiente y usar labels específicos.

### Trabajo conjunto con `NetworkPolicy` nativa

La `NetworkPolicy` del [capítulo 04](../04/es.md) y CNP/CCNP pueden seleccionar el mismo
endpoint simultáneamente. Sus reglas allow se tienen en cuenta juntas, pero un Cilium `ingressDeny`/`egressDeny`
explícito tiene prioridad sobre **todas** las reglas allow: de CNP, CCNP y `NetworkPolicy`
nativa de Kubernetes. Por ello, un allow de una `NetworkPolicy` ordinaria no puede sortear un deny de Cilium.
Ante un `DROP` inesperado, inventaría todos estos objetos, sus selectors y direcciones, no busques el
error solo en la última CNP aplicada. La policy nativa sigue siendo un control L3/L4 portable; Cilium la
complementa con L7, FQDN, entities y observabilidad.

> **Avanzado: `ClusterNetworkPolicy` de Kubernetes.** En versiones modernas de Cilium, junto con
> `NetworkPolicy`, CNP y CCNP puede aplicarse `ClusterNetworkPolicy` (KCNP) de Kubernetes,
> `v1alpha2`. Su modelo de tiers separa `Admin`, `NetworkPolicy` y `Baseline`; las reglas del
> tier `Admin` tienen prioridad sobre CNP, CCNP y `NetworkPolicy` ordinaria. Es útil para límites
> platform-wide, pero no es un tema CKS independiente obligatorio: antes de usarlo, comprueba que las
> API y el soporte correspondientes estén habilitados en tu clúster Cilium.

> 🎯 En CNP, `endpointSelector` selecciona Pods, `fromEndpoints`/`toEndpoints` la identity y `toPorts` el protocolo y puerto; ingress y egress crean default-deny de forma independiente.

## 06.2. L3/L4: permitir solo el workload y puerto necesarios

Una policy se vuelve aplicable a un endpoint cuando lo selecciona `endpointSelector`. En
`policyEnforcementMode: default`, Cilium habilita enforcement cuando un endpoint es seleccionado
por una policy; `always` lo habilita para todos los endpoints (un endpoint sin reglas allow recibe
una denegación), y `never` deshabilita enforcement. De forma predeterminada, la allow-list actúa
**para cada dirección por separado**: la presencia de `ingress` hace ingress default-deny hasta
coincidir con una regla allow, y la presencia de `egress` hace default-deny solo para egress.
Una policy con solo `ingress` no cierra egress, y viceversa. Por ello, el selector debe ser
preciso.

Este comportamiento se puede cambiar mediante `enableDefaultDeny`: una dirección para la que se
establece `false` no se considera al convertir un endpoint en default-deny. Así, el
administrador puede aplicar con seguridad una policy cluster-wide, por ejemplo, para interceptar DNS,
sin riesgo de convertir un endpoint en default-deny y bloquear tráfico legítimo. La excepción
no debe trasladarse a una L7-policy: `enableDefaultDeny` no se aplica a reglas layer-7,
y añadir una regla L7 sin el L7 allow-all correspondiente provocará DROP incluso con
default-deny explícitamente deshabilitado.

Cilium sigue el estado de conexión: permitir un flujo iniciador de ingress o egress
permite **el tráfico de respuesta de la misma conexión**, pero no permite una conexión nueva en sentido
inverso. Por tanto, no dupliques mecánicamente una regla para la respuesta, pero describe explícitamente una
llamada independiente de vuelta si la aplicación la necesita.

A continuación, backend con el label `app: backend` acepta solo TCP/80 desde frontend con el label
`app: frontend` en el mismo namespace `cks-102`. `fromEndpoints` es una restricción L3 por identity,
`toPorts` una restricción L4 por protocolo y puerto.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-from-frontend-http
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
```

Aplica el manifest y comprueba el objeto antes de considerar que la policy funciona:

```bash
kubectl apply -f backend-l3-l4.yaml
kubectl -n cks-102 get ciliumnetworkpolicy
kubectl -n cks-102 describe ciliumnetworkpolicy backend-from-frontend-http

# Primero comprueba los labels con los que Cilium construye identity.
kubectl -n cks-102 get pod --show-labels
```

Para tráfico cross-namespace, añade un namespace label a `matchLabels`. Cilium añade automáticamente
Kubernetes labels con el prefijo `k8s:`; el namespace suele representarse mediante el label
`k8s:io.kubernetes.pod.namespace`.

```yaml
  ingress:
  - fromEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: storefront
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

No sustituyas identity por una regla con `toCIDR` arbitrario si el destinatario es un Pod. Un CIDR no
sigue la recreación de un workload y puede incluir IP ajenas. `toCIDR` se justifica para redes externas
estables o rangos de servicio específicos, no como forma habitual de conectar dos Services de Kubernetes.

> 🔬 Active FTP usa un puerto de respuesta dinámico que una CNP L3/L4 estática no puede expresar; se necesita un protocol-aware gateway o passive FTP con un rango fijo.

### Caso límite: active FTP no se expresa mediante L3/L4

Active FTP muestra el límite de una policy L3/L4. El cliente abre una conexión de control en TCP/21
y comunica al servidor su puerto para la conexión de datos; después **el propio servidor inicia una nueva
conexión TCP de vuelta al cliente** en ese puerto. El puerto es desconocido de antemano y se negocia
dinámicamente dentro de la sesión, por lo que una regla estática `toPorts`/`fromEndpoints` no puede
describir «permite la conexión entrante al puerto que las partes acordarán más tarde».

Antes de Kubernetes y Cilium, este problema lo resolvía el **connection tracking de nivel de kernel**:
el módulo `nf_conntrack_ftp` analiza el canal de control, ve el puerto acordado y añade dinámicamente la
conexión related como permitida. `kube-proxy` y sus reglas `iptables`/`nftables` por sí solas no resuelven
esta tarea: la resuelve un conntrack helper independiente sobre netfilter, no el propio mecanismo de
Service forwarding.

Para protocolos con semántica application-level admitida, Cilium puede usar un L7 proxy, pero FTP no
es uno de ellos.

La CiliumNetworkPolicy estándar no proporciona un helper FTP-aware ni un FTP L7 parser integrado.
Por eso, Cilium no puede determinar automáticamente por el canal de control FTP el negotiated
port de una conexión de datos active-mode ni crear para ella una autorización temporal de policy.

Para entornos Kubernetes se prefiere **passive FTP** con un rango limitado previamente de data ports:
entonces el control traffic en TCP/21 y el data traffic en un rango fijo se pueden expresar con
reglas de policy L3/L4 ordinarias (`endPort`).

Si una aplicación legacy necesita obligatoriamente active FTP con puertos negociados dinámicamente, ya
es una tarea de un protocol-aware gateway/proxy independiente o de una capa de red especialmente diseñada,
no de una CNP estándar.

Entre las reglas application-level integradas de Cilium moderno, oriéntate por HTTP y DNS.
gRPC se filtra mediante semántica HTTP/2 con `rules.http`; no existe un tipo de regla gRPC independiente.
La network policy Kafka-aware se eliminó en Cilium 1.20.

> 🎯 En `toPorts.rules.http`, permite solo los method y path necesarios y comprueba tanto la solicitud permitida como la denegada.

## 06.3. L7: limitar HTTP y DNS

Una regla L7 se añade dentro de un elemento `toPorts`. Cilium dirige el tráfico seleccionado a través del
L7-proxy correspondiente: HTTP o DNS. Consecuencia importante: las reglas L7 se aplican solo a un
protocolo reconocido correctamente en el puerto indicado. No esperes filtrado HTTP si el cliente habla TLS
en un puerto sin TLS termination configurada: el proxy no ve HTTP en plaintext.

La siguiente regla permite al frontend solo `GET /` hacia backend. La expresión regular de ruta
`^/$` es intencionadamente estrecha: `/healthz`, `/api` y cualquier `POST` no coincidirán y se denegarán.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-read-only
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "^/$"
```

Comprueba no solo una solicitud satisfactoria, sino también la denegación. La imagen del Pod de prueba debe tener
`curl` u otro cliente HTTP:

```bash
kubectl -n cks-102 exec deploy/frontend -- curl -i http://backend/
kubectl -n cks-102 exec deploy/frontend -- \
  curl -i -X POST http://backend/

# Esperado: GET devuelve 200; Cilium proxy rechaza una solicitud L7 sin coincidencia, normalmente con 403.
```

Para una API es más seguro enumerar los métodos, rutas y, si es necesario, headers permitidos, en vez de
usar un `path: ".*"` amplio. La L7-policy no sustituye autenticación y autorización de la aplicación:
reduce la superficie disponible, pero no conoce al usuario ni las reglas de negocio de la API.

Cilium también puede filtrar DNS por el nombre de la solicitud. No habilites L7-proxy sin necesidad: añade
procesamiento a la ruta de tráfico y requiere pruebas de carga independientes.

> 🔬 gRPC se filtra como HTTP/2 mediante `POST` y la ruta del método.

### gRPC: filtrado mediante HTTP, pero con una particularidad de balanceo

Cilium no tiene un «parser gRPC» independiente. gRPC funciona sobre HTTP/2 y cada llamada de método
se codifica como una solicitud HTTP ordinaria: `POST` a una ruta del tipo `/Paquete.Servicio/Método`.
Por tanto, el filtrado gRPC L7 es la misma regla HTTP `path` que acabas de ver arriba,
solo que el regex o ruta exacta describe `/cloudcity.DoorManager/GetName` en vez de `/`.

Por ejemplo, la regla siguiente permite a `public-terminal` llamar en `cc-door-mgr` solo a la lectura
de estado, pero no al cambio de código de acceso:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: door-read-only-grpc
spec:
  endpointSelector:
    matchLabels:
      app: cc-door-mgr
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: public-terminal
    toPorts:
    - ports:
      - port: "50051"
        protocol: TCP
      rules:
        http:
        - method: "POST"
          path: "/cloudcity.DoorManager/GetName"
        - method: "POST"
          path: "/cloudcity.DoorManager/GetLocation"
```

La llamada `SetAccessCode` no coincide con ninguna regla y será rechazada: el cliente recibirá
el estado gRPC `PERMISSION_DENIED`, no un timeout de red ordinario. Hay un ejemplo detallado paso a paso
con una aplicación de demostración en la documentación oficial: [Protección de gRPC](https://docs.cilium.io/en/stable/security/grpc/).

Surge un problema independiente de balanceo si Cilium **reemplaza completamente
kube-proxy** (`kube-proxy-replacement`). gRPC mantiene una conexión TCP de larga duración y ejecuta
muchas llamadas consecutivas a través de ella. El balanceo eBPF ordinario de Cilium elige un Pod
**una vez al establecer la conexión**, no para cada llamada individual que contiene. Si el cliente
abre la conexión y la mantiene mucho tiempo, todo su tráfico irá al mismo Pod y las demás réplicas de
backend no recibirán su parte de carga: esto se llama connection pinning.

La solución es habilitar en Cilium **Proxy Load Balancing** para el Service necesario: el tráfico
se dirige por Envoy integrado, que puede inspeccionar el flujo HTTP/2 y distribuir llamadas gRPC individuales
entre Pods, en vez de toda la conexión. Sin esta configuración, los clientes gRPC de larga duración en un
clúster sin kube-proxy se deben probar por separado para comprobar la distribución uniforme de carga entre réplicas.

Se habilita con una anotación en el objeto Service, sin cambiar el manifest del workload:

```bash
kubectl annotate service payment-grpc-service \
  service.cilium.io/lb-l7=enabled
```

Después, el tráfico a `payment-grpc-service` pasa por Envoy gestionado por Cilium, que distribuye
llamadas individuales entre Pods en vez de fijar toda la conexión TCP a un backend. El algoritmo de
balanceo se puede precisar con la anotación independiente
`service.cilium.io/lb-l7-algorithm` (`round_robin`, `least_request` o `random`). La función
tiene estado **beta**; antes de habilitarla en producción, comprueba su comportamiento en
tu versión de Cilium. Encontrarás un ejemplo detallado con observación de tráfico mediante Hubble en la
documentación oficial: [Proxy Load Balancing para Kubernetes Services](https://docs.cilium.io/en/stable/network/servicemesh/envoy-load-balancing/).

**Dónde está Envoy físicamente.** No es un sidecar en cada Pod. Envoy forma parte de la imagen
Cilium y se ejecuta **una vez en cada nodo**: como proceso dentro de `cilium-agent` o como
un DaemonSet `cilium-envoy` independiente compartido por todos los Pods de ese nodo. En los
escenarios analizados arriba, pasa por él el tráfico redirigido por L7-policy o proxy load balancing
(`lb-l7`). No es una lista exhaustiva: Cilium Ingress, Gateway API y `CiliumEnvoyConfig` también
dirigen tráfico por el mismo Envoy per-node. El tráfico L3/L4 Pod-to-Pod ordinario, para el que no se ha
habilitado ninguna de estas funciones proxy-based, permanece en el eBPF datapath sin pasar por userspace.

**Cómo afecta esto a la latencia y parámetros de conexión.** Cada paquete redirigido
pasa por una transición adicional mediante el proceso userspace Envoy en el mismo nodo, no por la
red hacia otro nodo o Pod. Esto añade:

- **Pequeña latencia adicional** a cada solicitud: transición del kernel a userspace y
  de vuelta, más el análisis de protocolo (HTTP/gRPC). La cantidad suele ser pequeña para un
  hop local, pero no nula, y debe medirse bajo carga real antes de habilitarla.
- **Uso adicional de CPU y memoria en el nodo:** Envoy procesa el tráfico como proceso
  independiente, por lo que la carga del nodo crece proporcionalmente con un gran volumen de
  tráfico L7.
- **La source address depende de proxy path y configuración.** El mero paso por
  Envoy no implica que backend vea obligatoriamente la source IP del proxy. Para enforcement de policy
  L7, Cilium usa por defecto la original source address; `CiliumEnvoyConfig`, Ingress y Gateway API tienen
  configuraciones y reglas independientes de source visibility. Por ello, la source IP/port visible para backend se debe
  comprobar para el modo concreto, no deducirse solo del uso de Envoy.
- **El overhead se aplica solo al tráfico seleccionado:** las conexiones L3/L4 ordinarias sin
  reglas L7 y sin anotación `lb-l7` no pagan este coste: permanecen en la ruta rápida
  eBPF sin Envoy.

> **Vigencia.** El filtrado Kafka L7 de Cilium está deprecated desde la versión 1.18 y se eliminó
> en la versión 1.20. Para CKS, oriéntate por HTTP L7 y DNS/`toFQDNs`, y considera la policy Kafka
> solo como un ejemplo histórico, no como práctica actual.

> 🎯 Permite UDP/TCP 53 hacia CoreDNS confiable y limita el acceso externo con `toFQDNs`; Cilium usa respuestas DNS observadas y una caché FQDN.

## 06.4. Egress basado en DNS y `toFQDNs`

Las IP de un servicio SaaS público cambian, una CDN entrega direcciones diferentes y la aplicación
suele conocer no una IP, sino un nombre. `toFQDNs` permite el egress hacia nombres al asociarlos
con las IP que el DNS-proxy de Cilium observó en respuestas DNS permitidas; no es una resolución
DNS estática al aplicar YAML. El proxy llena la caché FQDN teniendo en cuenta el TTL y luego permite
la conexión a una IP de esta caché. Por tanto, dirija la resolución DNS solo a DNS de clúster
confiable (por ejemplo, CoreDNS), seleccionado mediante un selector exacto: Cilium no consulta DNS
por sí mismo y no debe confiar en un nameserver arbitrario.

La policy siguiente permite consultas DNS de frontend a CoreDNS y HTTPS solo a
`example.com`. `rules.dns` permite la consulta DNS y `toFQDNs`, la conexión posterior
a la IP devuelta para el nombre permitido.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: frontend-external-api-only
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s:k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      - port: "53"
        protocol: TCP
      rules:
        dns:
        - matchPattern: "*"
  - toFQDNs:
    - matchName: "example.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
```

`matchName` selecciona exactamente un nombre. Para un conjunto controlado de subdominios, use
`matchPattern`, por ejemplo, `"*.example.com"`: este wildcard no debe considerarse una autorización
para el nombre apex `example.com`. Si necesita tanto `example.com` como sus subdominios, expréselos
en reglas separadas. No use `"*"` sin una necesidad explícita: en `toFQDNs`, ese pattern elimina
la restricción por nombre DNS y permite destinos obtenidos de la caché DNS para todos los nombres
coincidentes; las demás condiciones de la misma regla, como `toPorts`, continúan aplicándose.
Antes de aplicarla, compruebe los labels reales de CoreDNS en su clúster: en algunas instalaciones
se usa una etiqueta distinta en vez de `k8s-app: kube-dns`.

```bash
kubectl -n kube-system get pod --show-labels | grep -E 'coredns|dns'
```

El siguiente ejemplo es una comprobación manual ilustrativa, no un acceptance test determinista.
IANA indica explícitamente que el servicio HTTP de los dominios de documentación (`example.com`,
`example.org`, etc.) se proporciona best-effort y no está destinado a ser un endpoint de testing
para software: https://www.iana.org/news/2024/example-domain-http-methods.
Si `example.com`/`www.google.com` no están disponibles en su entorno (restricciones de red,
un fallo temporal o bloqueo en una red concreta), esto no significa que la policy sea errónea:
sustitúyalos por un FQDN para el que haya confirmado independientemente, antes de aplicar la policy,
la resolución DNS y un HTTPS funcional.

```bash
kubectl -n cks-102 exec deploy/frontend -- \
  curl -I --max-time 5 https://example.com
kubectl -n cks-102 exec deploy/frontend -- \
  curl -I --max-time 5 https://www.google.com
```

Antes de aplicar la policy, confirme que ambas solicitudes anteriores pasan sin restricciones.
Solo después aplique `toFQDNs` y compare: `example.com:443` debe pasar, y
`www.google.com:443` debe ser bloqueado específicamente por la policy, no por una indisponibilidad
accidental del servicio externo.

`toFQDNs` no es un DLP completo ni una comprobación del HTTP `Host`: es control de acceso de red
basado en la resolución DNS observada. DoH/DoT ocultan la consulta DNS del DNS-proxy y tampoco
llenan la caché FQDN. Una conexión directa a una IP tampoco crea una asociación FQDN; solo funciona
si esa IP ya está en la caché tras una respuesta DNS permitida o si la permite una regla L3/L4 más
amplia. No permita servidores DNS no autorizados, DoH/DoT ni IP directas si esto es relevante para
el modelo de amenazas: limite el egress a DNS confiable, habilite la DNS visibility necesaria y
combine las reglas con un proxy/firewall en el perímetro de red.

> 🔬 `world`, `cluster`, `host` y CCNP para límites en toda la plataforma; pruebe un scope estrecho y tenga en cuenta el host firewall y el tráfico del sistema.

## 06.5. Entities y policy para todo el clúster

Entities proporcionan identificadores legibles para grupos de direcciones para los que los labels de
Kubernetes no son adecuados. Los valores más útiles son:

| Entity | Qué incluye | Caso típico |
|---|---|---|
| `world` | direcciones fuera del clúster | permitir salida a una API externa o entrada desde fuera |
| `cluster` | endpoints dentro del clúster | separar el tráfico dentro del clúster de Internet |
| `host` | endpoint host local del nodo | controlar explícitamente el acceso al nodo |
| `remote-node` | otros nodos del clúster | permitir la interacción necesaria entre nodos |
| `kube-apiserver` | Kubernetes API server | restringir el acceso de workloads a la API |

Por ejemplo, un Service que deba aceptar HTTPS solo desde Internet se puede seleccionar por
label y restringir su ingress a la entity `world`:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: public-gateway-from-world
  namespace: cks-102
spec:
  endpointSelector:
    matchLabels:
      app: public-gateway
  ingress:
  - fromEntities:
    - world
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
```

Para la protección de la plataforma se usa CCNP. El ejemplo siguiente niega el egress hacia la IP
de metadata a todos los endpoints seleccionados por la policy, pero conserva el resto del egress:
una policy `egress` aplicable activa por sí misma egress default-deny, por lo que aquí es necesario
un allow explícito `toEntities: [all]`. `egressDeny` tiene prioridad sobre cualquier allow,
incluido este allow-all y las reglas de otros CNP/CCNP, por lo que la IP de metadata no se podrá
abrir por accidente. Primero evalúe si los workloads del sistema necesitan llamadas de metadata y,
si es necesario, exclúyalos mediante un selector o namespace separado.

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: deny-cloud-metadata
spec:
  endpointSelector: {}
  egress:
  - toEntities:
    - all
  egressDeny:
  - toCIDR:
    - 169.254.169.254/32
```

No interprete `host` como un objeto inofensivo. `toEntities: host` controla el acceso de red
al nodo local y a host-networked workloads, y por tanto puede abrir una ruta hacia kubelet u otros
listeners TCP/UDP en el host. El runtime CRI socket es un mecanismo separado: por ejemplo,
containerd suele estar disponible a través del Unix domain socket
`/var/run/containerd/containerd.sock`, y su exposición depende de los mounts de filesystem/
`hostPath` y de los privilegios del Pod, no de `toEntities: host` por sí solo. Restringir el tráfico
del host requiere entender el host firewall de Cilium, el modo `hostFirewall.enabled` y el tráfico
del control plane; compruébelo en un clúster de prueba para no perder acceso a los nodos o al API
server. Restrinja por separado el acceso al runtime socket mediante controles de mount/privilege.

## 06.6. Observabilidad y verificación con Hubble

### Qué es Hubble y qué problema resuelve

Una `NetworkPolicy` o `CiliumNetworkPolicy` ordinaria responde a la pregunta «qué está permitido».
No responde a «qué ocurrió realmente»: por qué no pasó una solicitud concreta, con qué regla exacta
se relaciona un DROP, si el cliente ve un TCP-connect o si el rechazo ocurrió ya en L7. Sin una
herramienta así, la investigación se reduce a releer YAML y hacer conjeturas.

**Hubble** es un componente de observabilidad de Cilium que lee los mismos eventos eBPF que ya
recopila el datapath y los convierte en un flujo legible de flow-events: identity de source/destination,
contexto L4/L7, verdict (`FORWARDED`/`DROPPED`) y motivo del rechazo. No sustituye el Kubernetes
audit log ni lee por usted el contenido de la solicitud: muestra qué decidió hacer Cilium con una
conexión concreta y por qué.

> 🔬 La arquitectura de Hubble Server/Relay/UI, el CLI y los componentes dependen de la versión y del método de instalación de Cilium.

Desde el punto de vista arquitectónico, Hubble consta de cuatro partes:

- **Hubble Server** - integrado en `cilium-agent` y se ejecuta en cada nodo; entrega flow
  events mediante gRPC.
- **Hubble Relay** (`hubble-relay`) - componente separado que se conecta al Server de todos
  los nodos y ofrece una vista unificada del clúster en vez de nodo por nodo.
- **Hubble CLI** (`hubble`) - cliente de línea de comandos; se conecta a Relay para una
  vista de todo el clúster o al Server local de un nodo.
- **Hubble UI** (`hubble-ui`) - interfaz gráfica opcional sobre Relay con un mapa de las
  relaciones de servicios.

**Cómo se habilita.** En distribuciones gestionadas e instalaciones estándar de Cilium, Hubble
suele habilitarse con una flag de Helm durante la instalación o actualización, por ejemplo
`--set hubble.relay.enabled=true --set hubble.ui.enabled=true`; la flag exacta depende de la
versión del chart. Para CKS y este capítulo basta con saber una cosa: si Hubble ya está habilitado
en el clúster, `cilium status` muestra su estado, y el CLI `hubble` puede conectarse mediante
port-forward a Relay, como se muestra abajo. No es necesario habilitar Hubble desde cero para la
lab: es tarea del administrador del clúster, no parte del CNP que se aplica.

> 🎯 Genere tráfico permitido y denegado esperado y, a continuación, observe Hubble flows con un filtro de namespace, verdict o protocol.

Antes de la prueba, asegúrese de que los agentes Cilium estén sanos. Los comandos suelen ejecutarse
en una máquina de trabajo que tiene disponible el CLI `cilium`; el método exacto para habilitar
Hubble depende de la instalación de Cilium.

`hubble` es un binario separado, no parte del CLI `cilium`. Debe instalarse una vez en la máquina
de trabajo descargando el release correspondiente de GitHub; los pasos para cada plataforma están
en la instrucción oficial [Instalar el cliente Hubble](https://docs.cilium.io/en/stable/observability/hubble/setup/#install-the-hubble-client).
Tras la instalación, compruebe el binario con el comando `hubble help`.

```bash
cilium status --wait
cilium connectivity test

# Si Hubble relay está habilitado, el CLI creará una conexión local a él.
cilium hubble port-forward &
hubble status

# Tráfico y rechazos solo del namespace de formación.
hubble observe --namespace cks-102 --verdict DROPPED
hubble observe --namespace cks-102 --protocol http
```

La secuencia de comprobación de L3/L4, L7 y FQDN en la lab 102 debe ser reproducible:

1. Asegúrese de que `frontend` y `backend` estén Running y que sus labels coincidan con los selectores.
2. Aplique un CNP L3/L4. Una solicitud desde frontend a backend:80 debe pasar; desde un Pod sin
   `app: frontend`, debe obtener un timeout o DROP.
3. Sustituya o complemente la regla con un CNP L7. `GET /` debe devolver `200` y `POST /` debe
   recibir un rechazo del proxy (normalmente `403`).
4. Aplique la policy DNS/FQDN. Compruebe la resolución y HTTPS al nombre permitido; después,
   intente acceder a un nombre no permitido.
5. En una terminal separada, observe Hubble y guarde el flow permitido y el rechazado como
   evidencia del resultado.

Para el diagnóstico también son útiles el CLI del agente y los objetos Kubernetes:

```bash
kubectl -n cks-102 get ciliumnetworkpolicy -o yaml
kubectl -n kube-system get pods -l k8s-app=cilium

# Se ejecuta en el Pod cilium del nodo elegido.
kubectl -n kube-system exec ds/cilium -- cilium-dbg endpoint list
kubectl -n kube-system exec ds/cilium -- cilium-dbg policy get
```

Si `hubble observe` está vacío, compruebe primero `hubble status`, la presencia de Hubble Relay,
el contexto kubeconfig y los filtros de namespace/verdict. Si DNS deja de funcionar después de
default deny, casi siempre falta permitir UDP/TCP 53 hacia los endpoints CoreDNS reales. Si una
regla L7 no coincide inesperadamente, compruebe el puerto, protocol, HTTP method, la expresión
regular path y TLS: HTTP cifrado sin una configuración adecuada no es visible para el L7-proxy.

> 🎯 Compruebe labels/selectors, dirección, puertos y DNS; después compare el flow permitido y el rechazado en Hubble; despliegue desde un allow estrecho con rollback.

## 06.7. Errores frecuentes y orden seguro de despliegue

| Síntoma | Causa probable | Qué comprobar |
|---|---|---|
| Los nombres dejan de resolverse después de la policy | DNS no está permitido o el selector de CoreDNS es incorrecto | labels de CoreDNS, UDP y TCP 53, Hubble DROPPED |
| Tanto `GET` como `POST` se rechazan | la identity L3 o el puerto L4 no coincidieron | labels del endpoint, puerto Service y targetPort |
| Una regla L7 no restringe una solicitud | el tráfico no se reconoce como HTTP o hay una regla más amplia | protocol, TLS, `cilium policy get`, Hubble HTTP flows |
| La policy FQDN no da acceso al Service | el nombre no coincide con la respuesta DNS o la caché IP aún no está llena | `hubble observe --protocol dns`, `matchName`, TTL |
| CCNP rompió el tráfico del sistema | el selector es demasiado amplio o no se consideraron endpoints del sistema | scope de la policy, namespace/labels, rollout en un namespace de prueba |
| No hay eventos en Hubble | Hubble Relay/CLI no están conectados o el filtro es demasiado estrecho | `hubble status`, port-forward, quitar filtros |

**Cilium Policy Audit Mode** es útil durante la preparación de una policy L3/L4: cuando se
habilita para el daemon (`--policy-audit-mode=true`) o para un endpoint seleccionado, deja pasar
el tráfico que la policy de otro modo habría descartado y registra el policy verdict correspondiente.
En este modo, no busque tal tráfico solo mediante `--verdict DROPPED`: observe los policy verdicts:

```bash
hubble observe flows -t policy-verdict --namespace cks-102
```

Un flow que coincide con una denegación futura se verá como `AUDITED`, aunque la conexión aún
pasa. Tras deshabilitar Audit Mode, la misma prueba se convierte en `DENIED` si la regla realmente
la deniega, o sigue siendo `ALLOWED` si una regla allow cubre el flow. Primero recopile estos eventos
mediante Hubble, estreche las reglas allow y solo entonces habilite el enforcement. Es un modo de
diagnóstico temporal, no una protección de producción: en él no se aplican bloqueos; para una
policy L7 tampoco sustituye una prueba HTTP/DNS real.

Orden seguro: en staging, primero observe Hubble y guarde un baseline de flows reales; si es
necesario, use brevemente Policy Audit Mode; después añada un allow estrecho y pruébelo desde un
Pod de prueba; solo entonces habilite un deny o amplíe el scope en producción. No empiece con
`endpointSelector: {}` en una CCNP en un clúster de producción. Cada cambio necesita rollback:
`kubectl delete ciliumnetworkpolicy <name> -n <namespace>` o reversión mediante GitOps, no una
edición manual sin historial.

> 🏭 Rollout de CNP: review, staging, GitOps, baseline flows y propiedad separada de CCNP y la policy de aplicación.

## 06.8. Cómo se usa esto en producción

- **Mantenga las policies junto al workload.** Los CNP de aplicaciones pasan por code review,
  se prueban en staging y se aplican mediante una herramienta GitOps. El equipo de plataforma posee
  por separado los CCNP de aplicación amplia.
- **Los labels son un contrato de seguridad.** Los equipos estandarizan labels como `app`,
  `component` y `tenant`, y no permiten que un workload modifique arbitrariamente labels relevantes
  para seguridad. De lo contrario, un selector de policy puede empezar a seleccionar el endpoint
  equivocado.
- **Use L7 para API valiosas.** Permitir solo HTTP methods/paths esperados reduce el riesgo de
  lateral movement, pero no sustituye OAuth, mTLS ni la autorización de la aplicación.
- **Construya el egress a partir de DNS y destino.** Use `toFQDNs` para API externas conocidas,
  no como regla universal. DNS, un proxy y un perimeter firewall siguen siendo capas de defense
  in depth.
- **Habilite Hubble antes de un incidente.** Dashboards para flows `DROPPED` y flow logs
  conservados permiten distinguir un error de policy de un fallo de aplicación e investigar más
  rápido un egress sospechoso.

## 06.9. Mini-glosario

- **Cilium** - una plataforma de CNI y seguridad basada en eBPF para Kubernetes.
- **CiliumNetworkPolicy (CNP)** - recurso de policy de Cilium con alcance de namespace.
- **CiliumClusterwideNetworkPolicy (CCNP)** - policy de Cilium para todo el clúster.
- **Identity** - identificador de endpoint construido por Cilium a partir de labels.
- **L3/L4** - capa de red y protocolo/puerto de transporte.
- **L7** - capa de protocolo, por ejemplo, un HTTP method/path o DNS.
- **`toFQDNs`** - regla de egress por nombres DNS y respuestas DNS observadas.
- **Entity** - grupo de direcciones predefinido de Cilium, por ejemplo, `world`, `cluster` o `host`.
- **Hubble** - observabilidad de flujos de red de Cilium.
- **eBPF** - mecanismo del kernel de Linux sobre el que Cilium implementa el datapath y el enforcement de policy.

## 06.10. Resumen del capítulo

- Cilium complementa la NetworkPolicy nativa con policies L3/L4/L7, identities, FQDN y
  observabilidad de Hubble.
- CNP se aplica en un namespace, mientras que CCNP se aplica en todo el clúster; los CCNP amplios
  requieren un rollout especialmente cuidadoso.
- `endpointSelector` selecciona el endpoint protegido, `fromEndpoints`/`toEndpoints` definen L3
  y `toPorts` define L4.
- Las reglas HTTP L7 permiten solo los métodos y paths necesarios, pero no sustituyen la
  autenticación de aplicación y requieren un protocolo plaintext reconocible.
- `toFQDNs` restringe el egress externo por nombres; requiere permitir DNS por separado y tener
  en cuenta la caché DNS, el TTL y posibles bypasses.
- `toEntities` expresa acceso a `world`, `cluster`, `host` y otros grupos del sistema.
- Hubble muestra flows permitidos y denegados y es la herramienta principal para la verificación
  y la resolución de problemas de policy.

## 06.11. Cómo ayuda esto: en el examen y en el trabajo real

**En el examen.** La habilidad portátil de aplicar network security policies es obligatoria: leer
rápidamente los labels, escoger un namespace y dirección (`ingress`/`egress`), permitir el flow
necesario y demostrar el resultado. **Si el clúster o fixture proporcionado usa Cilium**, también
debe saber crear una `CiliumNetworkPolicy` con `endpointSelector`, restringir HTTP o `toFQDNs`
cuando sea necesario y verificar flows con `hubble observe`. L7, FQDN y Hubble son temas avanzados
específicos de Cilium, no una interfaz garantizada por el currículo público en cada tarea; aun así,
permita DNS con una regla separada.

**En el trabajo real.** La policy de Cilium convierte los límites arquitectónicos en reglas
ejecutables: un frontend no obtiene acceso arbitrario a un backend, un workload no puede acceder a
un destino arbitrario de Internet y el flow hacia una API se puede estrechar a las operaciones
necesarias. Hubble hace verificables estos límites durante el rollout y la investigación de incidentes.

## 06.12. Preguntas de autoevaluación

<details>
<summary>1. ¿En qué se diferencia CNP de la `NetworkPolicy` nativa, además del formato del recurso?</summary>

CNP usa identities de Cilium construidas a partir de labels y añade filtrado L7 HTTP/DNS, `toFQDNs`,
entities (`world`, `cluster`, `host`) y observabilidad de Hubble. NetworkPolicy nativa sigue siendo
un control L3/L4 portable, y CNP/CCNP la complementan; una denegación explícita de Cilium tiene
prioridad sobre un allow de ambos tipos de policy.
</details>

<details>
<summary>2. ¿Qué ocurre con el ingress de un endpoint si CNP lo selecciona, pero el tráfico no coincide con ninguna regla allow?</summary>

En `policyEnforcementMode: default`, un endpoint queda aislado para la dirección descrita por una
policy aplicable. Si un CNP contiene `ingress`, este actúa como default-deny hasta que coincida una
regla allow; de igual modo, `egress` aísla solo el tráfico saliente.
</details>

<details>
<summary>3. ¿Cómo expresar en una regla CNP «solo frontend a backend TCP/80»?</summary>

Un CNP selecciona el backend mediante un `endpointSelector` con `app: backend` y usa
`fromEndpoints` con `app: frontend` en `ingress`. En `toPorts`, establezca el puerto `"80"` y
`protocol: TCP`; para una conexión entre namespaces, añada `k8s:io.kubernetes.pod.namespace` a
los `matchLabels` de origen.
</details>

<details>
<summary>4. ¿Por qué permitir TCP/80 aún no restringe `POST /admin`, y cómo se puede restringir?</summary>

Una regla L3/L4 permite toda la conexión TCP en el puerto 80 y no distingue un HTTP method o path.
Dentro de `toPorts`, añada `rules.http`, por ejemplo `method: "GET"` y un `path: "^/$"` estrecho;
el L7-proxy de Cilium rechazará entonces una solicitud que no coincida, normalmente con 403.
</details>

<details>
<summary>5. ¿Cómo funcionan `toFQDNs` y por qué DNS se debe permitir por separado junto con ellos?</summary>

`toFQDNs` no resuelve un nombre al aplicar YAML: el DNS-proxy de Cilium observa una respuesta DNS
permitida, llena una caché FQDN con TTL y permite una conexión a la IP obtenida. Por ello, permita
por separado el DNS de un Pod hacia CoreDNS confiable; DoH/DoT no llena esta caché y una IP directa
no crea una asociación FQDN.
</details>

<details>
<summary>6. ¿Cuándo encajan las entities `world`, `cluster` y `host`, y por qué `host` requiere especial cuidado?</summary>

`world` designa direcciones fuera del clúster, `cluster` designa endpoints dentro de él y `host`
designa el endpoint host local del nodo y los host-networked workloads. El acceso a `host` puede
afectar a kubelet y a otros listeners de red del nodo, así que requiere una policy de host firewall
cuidadosa. El runtime CRI socket es otra ruta de ataque: normalmente es un Unix socket en el
filesystem del nodo y se debe proteger restringiendo `hostPath`, privilegios y otros mecanismos de
acceso al filesystem del host.
</details>

<details>
<summary>7. ¿Qué comandos de Hubble ayudan a demostrar que Cilium descartó un flow prohibido?</summary>

Después de `cilium status --wait` y de configurar el acceso a Hubble, observe los rechazos con
`hubble observe --namespace cks-102 --verdict DROPPED`. Para correlacionar HTTP y DNS, use
respectivamente `hubble observe --namespace cks-102 --protocol http` y la observación DNS; en
Policy Audit Mode, una denegación futura aparece como `AUDITED` mediante
`hubble observe flows -t policy-verdict --namespace cks-102`.
</details>

<details>
<summary>8. ¿Por qué es peligroso comenzar un despliegue CCNP con `endpointSelector: {}` en un clúster de producción?</summary>

CCNP se aplica en todo el clúster y un selector vacío selecciona todos los endpoints, por lo que un
error de allow/deny puede cortar el tráfico del sistema y de las aplicaciones. Primero pruebe la
regla con labels estrechos en un namespace separado, observe el baseline mediante Hubble y prepare
el rollback eliminando la policy o revirtiéndola mediante GitOps.
</details>

## Práctica

Refuerce L3/L4, L7 HTTP, egress basado en DNS y Hubble en la lab 102. Complete las tareas en
orden de policy, en vez de intentar depurar todas las capas a la vez.

🧪 Lab 102 (Cilium NetworkPolicy L3/L4/L7): [tasks/cks/labs/102](../../labs/102/README_ES.MD)

🎮 Cilium Hubble (documentación y ejemplos interactivos):
[Observabilidad de Hubble](https://docs.cilium.io/en/stable/observability/hubble/) ·
[Network policy](https://docs.cilium.io/en/stable/security/network/)

---
[Índice](../README_ES.md) · [Capítulo 05](../05/es.md) · [Capítulo 07](../07/es.md)
