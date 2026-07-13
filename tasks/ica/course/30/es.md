[RU version](ru.md) · [Eng version](en.md) · [Version française](fr.md) · [Deutsche Version](de.md)

# Capítulo 30. Rendimiento y operación del control plane

> **Qué sigue.** Hemos pasado de lo básico al multi-clúster y a las VMs. Este capítulo cierra el
> bloque de operaciones: cómo funciona el control plane, de qué depende su rendimiento, qué
> monitorizar, cómo afinarlo y cómo mantener la malla sana en producción. Quedan por delante dos
> capítulos más: el hardening y el modelo de amenazas (capítulo 31) y la preparación para el examen
> ICA (capítulo 32).

## 30.1. Cómo funciona el control plane y qué afecta a su rendimiento

Recuerda del capítulo 4: istiod (el control plane) no procesa tráfico por sí mismo. Su trabajo es
observar el estado del clúster (servicios, pods, tus configs) y **repartir la configuración
actualizada** a todos los Envoy por xDS. Es exactamente este trabajo el que carga el control plane.

```mermaid
flowchart LR
    E["un cambio<br>(pod / config)"] --> D["debounce / batching"]
    D --> C["istiod recalcula"]
    C --> P["push por xDS a todos los proxies"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

El rendimiento de istiod se ve afectado por:

- **El número de servicios y pods**: cuantos más haya, más configuración hay que calcular y enviar.
- **La tasa de cambio (churn)**: cada nuevo pod, cada cambio de servicio o regla dispara un recálculo
  y un push.
- **El número de proxies conectados**: la config hay que entregarla a cada uno.
- **El tamaño de la configuración por proxy**: si cada sidecar conoce toda la malla (capítulo 19), el
  volumen crece de forma cuadrática.

## 30.2. Monitorizar el control plane

istiod hay que monitorizarlo por separado de las aplicaciones. Guíate por sus "señales de oro":

- **Latencia de propagación de la config**: `pilot_proxy_convergence_time`. La señal principal:
  cuánto tarda un cambio en llegar a los proxies. Una subida es la primera señal de que el control
  plane no da abasto.
- **Pushes y errores**: `pilot_xds_pushes` (cuántos repartos) y contadores de configs
  rechazadas/errores xDS. Un pico de errores significa problemas de config o de conectividad.
- **Proxies conectados**: cuántos Envoy están conectados a istiod.
- **Saturación**: la CPU y la memoria de istiod. Si llega a sus límites, toda la propagación de
  config se resiente.

Estas métricas son la base de las alertas del control plane (capítulo 17). Los proxies en marcha
siguen funcionando incluso cuando istiod no está disponible (con la última configuración recibida),
pero los cambios nuevos no llegarán, así que la salud de istiod es crítica.

**Comprueba tu trabajo.** Consultas PromQL básicas para las señales de oro de istiod:

```promql
# p99 del tiempo de convergencia de la config (seg) - la señal principal
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# la tasa de pushes xDS por tipo (cds/eds/lds/rds)
sum(rate(pilot_xds_pushes[5m])) by (type)

# configuraciones rechazadas - debería ser 0
sum(rate(pilot_total_xds_rejects[5m]))

# cuántos proxies están conectados a istiod
pilot_xds
```

Una subida en el p99 de la convergencia o un `pilot_total_xds_rejects` distinto de cero es una señal
para investigar: sobrecarga de istiod, una config rota o problemas de conectividad.

## 30.3. Afinado del rendimiento

Las palancas principales (muchas de las cuales ya hemos mencionado):

- **discovery selectors** (capítulo 19): istiod observa solo los namespaces necesarios, ignorando el
  resto. La mayor ganancia si parte del clúster no está en la malla.
- **Alcance del Sidecar** (capítulo 19): cada proxy recibe la config solo de los servicios que
  necesita, no de toda la malla. Reduce drásticamente el volumen de configuración y la carga sobre
  istiod.
- **Batching de eventos y debounce**: istiod no hace push de la config en cada pequeño cambio, sino
  que agrupa cambios en un intervalo corto (debounce) y limita la tasa de push. Estos parámetros (por
  ejemplo, `PILOT_DEBOUNCE_AFTER`, `PILOT_PUSH_THROTTLE`) se afinan según la carga: más batching,
  menos pushes, pero una latencia de propagación algo mayor.
- **Recursos de istiod y HA** (capítulo 27): varias réplicas + un HPA, suficiente CPU/memoria.
- **Reducir el churn**: menos cambios innecesarios (por ejemplo, no tocar configs sin necesidad) =
  menos recálculos.

Los parámetros de batching se establecen como variables de entorno de istiod, en el `IstioOperator`
vía `components.pilot.k8s.env`:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # esperar a que haya calma antes de recalcular
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # pero no más que esto
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # máximo de pushes concurrentes
          value: "100"
```

Más debounce, menos recálculos y pushes durante un pico de cambios, pero una latencia de propagación
algo mayor (vigila `pilot_proxy_convergence_time`, sección 30.2). Los valores por defecto sirven para
la mayoría; tócalos de forma deliberada, ante un problema concreto.

## 30.4. Políticas de despliegue: OPA Gatekeeper

En una malla grande es importante que los equipos no desplieguen configuraciones inseguras o que
rompan cosas. Aquí ayuda **OPA Gatekeeper**: un controlador de admisión que comprueba los recursos al
crearse (como el webhook del capítulo 4) y rechaza los que no cumplen las reglas.

Políticas típicas para Istio:

- exigir una etiqueta de inyección (o `istio.io/rev`) en los namespaces de aplicación;
- prohibir un `PeerAuthentication` con `mode: DISABLE` (para que nadie apague mTLS por accidente);
- exigir que los puertos de un Service estén nombrados correctamente (capítulo 10);
- prohibir un `AuthorizationPolicy` o un `EnvoyFilter` demasiado amplio sin revisión.

Gatekeeper convierte las buenas prácticas de este curso en **reglas de cumplimiento automático**: no
"acordamos hacerlo así", sino "de lo contrario simplemente no se desplegará".

Ejemplo: prohibir un `PeerAuthentication` con `mode: DISABLE`. La política se describe con dos
recursos: un `ConstraintTemplate` (qué comprobar, en Rego) y un `Constraint` (a qué aplicarlo):

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "PeerAuthentication mode DISABLE está prohibido por la política"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

Ahora cualquier `PeerAuthentication` con mTLS apagado será rechazado en la admisión: nadie "hace un
agujero" en la malla por accidente. Una alternativa a Gatekeeper con una sintaxis YAML más simple
(sin Rego) es **Kyverno**; la elección entre ambos suele ser cuestión de la herramienta adoptada en
tu equipo.

## 30.5. Operación en EKS/AWS

Un par de puntos específicos de EKS que afectan al control plane.

- **Monitorizar istiod vía servicios gestionados.** Las señales de oro de istiod se escriben
  cómodamente en **Amazon Managed Prometheus (AMP)** y se ven en **Grafana (AMG)**, con las métricas
  recogidas por el agente **ADOT** (capítulo 17). istiod puede en este caso vivir en **Fargate**
  (capítulo 27): es stateless.
- **Karpenter y los nodos spot aumentan el churn.** El autoscaling de nodos (Karpenter) y el spot con
  sus interrupciones implican una aparición/desaparición frecuente de nodos y pods. Para el control
  plane esto es un **aumento del churn**: cada pod recreado es un evento de endpoints y nuevos pushes
  xDS. Lo que ayuda: una **consolidación** no demasiado agresiva en Karpenter, un `disruption budget`
  en el node pool, PDBs en las aplicaciones, para que los nodos no se "rearmen" constantemente. Más
  el mismo alcance (capítulo 19), para que un pico de cambios en una parte del clúster no se reparta a
  todos los proxies.
- **El coste de la observabilidad.** Las métricas de Istio son de alta cardinalidad; en un clúster
  EKS grande la factura de AMP/almacenamiento crece rápido: gestiónalo vía la Telemetry API (capítulo
  18): desactiva dimensiones innecesarias, muestrea las trazas con sensatez.

## 30.6. Operar a escala: una checklist

Reunamos las prácticas operativas dispersas por el curso:

- **Monitoriza el control plane** por separado (las señales de oro de istiod), no solo las
  aplicaciones.
- **Optimiza el alcance** (discovery selectors + Sidecar) en clústeres grandes: la palanca de
  rendimiento principal.
- **Actualiza vía revisiones/canary** (capítulo 3), no in-place sobre producción viva.
- **Establece de antemano la PKI y una CA común** (capítulos 16, 28), planifica la rotación de la
  raíz.
- **Mantén versiones uniformes** de Istio en los clústeres de un multi-clúster (capítulo 28).
- **Automatiza políticas** vía Gatekeeper: buenas prácticas como reglas obligatorias.
- **Observabilidad en toda la malla** con alertas (capítulos 17-18), muestreo sensato.
- **Ensaya actualizaciones y rollbacks** antes de necesitarlos en batalla.
- **No te compliques prematuramente**: introduce ambient, multi-clúster, VMs para una necesidad
  concreta, no "porque puedes".

## 30.7. Resumen del capítulo

- El control plane (istiod) no transporta tráfico, pero calcula y reparte la configuración a todos
  los proxies; esa es su carga.
- El rendimiento depende del número de servicios/pods, la tasa de cambio, el número de proxies y el
  tamaño de la config por proxy.
- Monitoriza las señales de oro de istiod: tiempo de propagación de la config
  (`pilot_proxy_convergence_time`), pushes y errores, el número de proxies, CPU/memoria.
- Afinado: **discovery selectors** y **alcance del Sidecar** (capítulo 19), batching/throttle de push
  (`PILOT_DEBOUNCE_AFTER`/`PILOT_PUSH_THROTTLE` vía el `IstioOperator`), recursos de istiod y HA,
  reducir el churn.
- **OPA Gatekeeper** (o Kyverno) convierte las buenas prácticas en reglas de admisión obligatorias
  (`ConstraintTemplate` + `Constraint`), por ejemplo prohibiendo mTLS `DISABLE`.
- En EKS: monitoriza istiod vía AMP/AMG/ADOT, istiod en Fargate; **Karpenter/spot** aumentan el
  churn, modera la consolidación y mantén el alcance estrecho; vigila el coste de las métricas de alta
  cardinalidad.
- Operar a escala: monitorización del control plane, optimización del alcance, actualizaciones vía
  revisiones, PKI de antemano, versiones uniformes, automatización de políticas, observabilidad de
  extremo a extremo, ensayo de rollbacks, rechazo de complejidad innecesaria.

## 30.8. Preguntas de autoevaluación

1. ¿Qué carga al control plane si no procesa tráfico de usuario?
2. ¿Qué factores afectan al rendimiento de istiod?
3. Nombra las señales de oro del control plane y qué significa una subida de
   `pilot_proxy_convergence_time`.
4. ¿Qué palancas de afinado del rendimiento conoces? ¿Cómo estableces los parámetros de batching de
   istiod?
5. ¿Qué aporta OPA Gatekeeper en el contexto de operar Istio? ¿De qué recursos consta una política y
   con qué se puede sustituir?
6. ¿Con qué consultas PromQL comprobarías la salud del control plane?
7. ¿Cómo afectan Karpenter y los nodos spot a la carga de istiod y qué haces al respecto?

## Práctica

Practica operaciones y rendimiento de forma práctica: discovery selectors y alcance del Sidecar,
monitorización de las señales de oro de istiod, políticas de despliegue vía OPA Gatekeeper.

🧪 Laboratorio 33: [tasks/ica/labs/33](../../labs/33/README_ES.MD)

---
[Índice](../README_ES.md) · [Capítulo 29](../29/es.md) · [Capítulo 31](../31/es.md)
