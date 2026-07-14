[RU version](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD)

# Istio Certified Associate (ICA) - Materiales de formación

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

Preparación completa para la certificación **Istio Certified Associate (ICA)**: un curso
de autoaprendizaje, laboratorios prácticos y exámenes de práctica completos, todo en un
solo lugar.

## Qué incluye

| Parte | Ruta | Qué es |
|------|------|-----------|
| **Curso** | [`course/`](course/README_ES.md) | Curso de autoaprendizaje de 32 capítulos: desde la idea de un service mesh hasta las operaciones en producción |
| **Laboratorios** | [`labs/`](labs/) | 35 laboratorios prácticos en clústeres reales de AWS, cada uno vinculado a un capítulo del curso |
| **Exámenes de práctica** | [`mock/`](mock/) | 2 exámenes de práctica completos que simulan la experiencia real del ICA |

Ruta recomendada: estudia un capítulo del curso, refuérzalo con su laboratorio y luego
haz los exámenes de práctica contra el reloj.

## El curso

El curso ([`course/README_ES.md`](course/README_ES.md)) tiene 32 capítulos, escritos para
ingenieros que ya conocen Kubernetes (nivel CKA):

- **Parte 1 (capítulos 1-24)** - fundamentos y cobertura completa de los dominios del
  examen ICA (gestión del tráfico, seguridad, observabilidad, escenarios avanzados,
  troubleshooting, instalación).
- **Parte 2 (capítulos 25-31)** - buenas prácticas del mundo real: entrega progresiva,
  migración sin downtime, Istio en EKS, multiclúster, cargas de trabajo VM, rendimiento
  del control plane, hardening.
- **Preparación del examen (capítulo 32)** - formato del ICA, consejos y enlaces a los
  exámenes de práctica.

Cada capítulo termina con una sección de **Práctica** que enlaza al laboratorio
correspondiente.

## Los laboratorios

35 laboratorios prácticos (`labs/01` .. `labs/35`), cada uno completamente localizado:
inglés (`README.MD`), ruso (`README_RU.MD`), español (`README_ES.MD`), francés
(`README_FR.MD`) y alemán (`README_DE.MD`). Despliegan clústeres reales en AWS mediante
Terragrunt:

```bash
TASK=01 make run_ica_task      # desplegar el laboratorio 01
TASK=01 make delete_ica_task   # eliminarlo
```

Temas de los laboratorios (y el capítulo del curso que cubre la teoría):

| Lab | Tema | Capítulo |
|-----|-------|---------|
| 01 | Instalación de Istio, Bookinfo, inyección de sidecar | 2 |
| 02 | Dark launch, enrutamiento por cabeceras, canary | 5, 6 |
| 03 | Fault injection y reintentos | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress: ServiceEntry, egress gateway, REGISTRY_ONLY | 12 |
| 06 | Balanceo de carga + mirroring de tráfico | 6, 7 |
| 07 | Instalación con Helm + actualización canary (revisiones) | 3 |
| 08 | Observabilidad: Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode (sin sidecars) | 22 |
| 10 | Resiliencia: timeout + circuit breaker | 8 |
| 11 | Autenticación de usuario final: RequestAuthentication + JWT | 15 |
| 12 | Troubleshooting con istioctl | 24 |
| 13 | TLS en el borde (SIMPLE) | 9 |
| 14 | Failover según la localidad | 7 |
| 15 | Instalación y configuración (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | Rate limiting local (EnvoyFilter) | 20 |
| 18 | Telemetry API: access logs + tracing | 18 |
| 19 | CA personalizada en istiod | 16 |
| 20 | Migración de mTLS PERMISSIVE a STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient: waypoint proxy + autorización L7 | 22 |
| 25 | Entrega progresiva con Flagger | 25 |
| 26 | CA dinámica: cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | Enrutamiento TCP | 10 |
| 29 | Ingress TLS: MUTUAL y PASSTHROUGH | 9 |
| 30 | StatefulSet y servicios headless | 23 |
| 31 | Migración sin downtime: ingress-nginx a Istio | 26 |
| 32 | gRPC: balanceo per-request, nombrado de puertos, reintentos | 10 |
| 33 | Control plane: rendimiento y operación | 30 |
| 34 | Hardening y modelo de amenazas | 31 |
| 35 | Malla multiclúster (multi-primary, multi-network) | 28 |

## Exámenes de práctica

Dos exámenes de práctica completos que imitan el formato del ICA:

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 17 tareas sobre conceptos básicos de Istio.
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 16 tareas sobre patrones avanzados de service mesh.

Hazlos contra el reloj, sin pistas, y apunta a un **70%+**.

## Entorno de terminal personalizado

![Terminal Interface](../../docs/images/cockpit.png)

La infraestructura proporciona una terminal preconfigurada con herramientas y ayudas
pensadas para la práctica del ICA.

### Comandos disponibles
- **`time_left`** - consultar el tiempo restante del laboratorio
- **`check_result`** - verificar la finalización de la tarea (`check_result <task>` para una tarea concreta)
- **`hosts`** - mostrar información del ingress gateway (mapeos NodePort e IPs)

### Herramientas preconfiguradas (con autocompletado bash)
- **`kubectl | k`**, **`istioctl`**, **`helm`**, **`yq`**, **`curl`/`wget`**,
  **`podman`**, **`aws`**

### Acceso SSH
```bash
ssh <kubernetes_nodename>
```

## Inicio rápido

```bash
# comprobar tu puntuación (todas las tareas o una específica)
check_result
check_result <task_number>

# información del clúster/ingress para probar el acceso externo
hosts

# tiempo restante durante una ejecución con límite de tiempo
time_left
```

## Recursos permitidos durante el examen

Puedes consultar la documentación oficial de Istio:
**https://istio.io/latest/docs/** y todos sus subdominios. Los exámenes de práctica
reproducen esto.

## Consejos para tener éxito

1. **Lee los requisitos de la tarea con cuidado** - los nombres exactos, namespaces y
   specs importan.
2. **Verifica tu contexto** con `kubectl config current-context`.
3. **Prueba tu trabajo** - usa `curl` desde pods sleep para comprobar el enrutamiento y
   las políticas.
4. **Usa `istioctl analyze`, `proxy-status`, `proxy-config`** para encontrar errores de
   configuración.
5. **Revisa las soluciones de referencia** después de intentar las tareas.

## Errores comunes

- **Hosts en VirtualService**: para tráfico entre namespaces, incluye el nombre corto y
  el FQDN.
- **Selectores de Gateway**: deben coincidir con las etiquetas reales del ingress gateway.
- **Inyección de sidecar**: los pods deben mostrar `2/2` contenedores.
- **Cambio de contexto**: verifica el clúster antes de aplicar recursos.

---

**¡Buena suerte con tu certificación ICA!** La práctica hace al maestro: trabaja el
curso, los laboratorios y ambos exámenes de práctica hasta que puedas completar las
tareas con confianza dentro de los límites de tiempo.
