[Русская версия](ADR_RU.md) · [Eng version](ADR.md) · [Version française](ADR_FR.md) · [Deutsche Version](ADR_DE.md) · [ქართული ვერსია](ADR_GE.md) · [繁體中文版](ADR_TW.md) · [日本語版](ADR_JP.md)

# Decisiones de arquitectura del curso EKS (ADR)

[Índice del curso](README_ES.md) · [Glosario](GLOSSARY_ES.md)

## Cómo usar este documento

Un ADR (Architecture Decision Record) es un registro breve de una decisión: por qué se eligió
esa opción, qué alternativas había y cuál es el coste de la elección. El propósito no es crear
documentación por crearla, sino evitar volver a debatirlo dentro de un año y ayudar a que una
persona nueva del equipo entienda el motivo, no solo el resultado.

Las plantillas siguientes ya están completadas con material del curso: las alternativas, sus
ventajas y su coste proceden de los capítulos, no se han inventado aquí. Pero **el contexto, el
estado, la fecha y la decisión en sí los escribe el ingeniero** para su proyecto: el curso no
conoce su flota de clústeres, los requisitos de cumplimiento ni si cuenta con un equipo de
plataforma.

Una «alternativa descartada» no significa «mala». En casi todas las bifurcaciones del curso
ambas opciones son válidas, y la descartada pasa a ser correcta con otros datos de entrada. Para
eso existe el campo «condiciones de revisión».

## Plantilla vacía

```markdown
## ADR-NN. Título breve de la decisión

Estado: propuesto / aceptado / rechazado / sustituye ADR-NN
Fecha: YYYY-MM-DD

**Contexto.** Cuál es la tarea, qué restricciones existen y qué cuestiones se deben resolver.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
|  |  |  |  |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos:
- Qué coste tiene:

**Decisión.** Qué se eligió y con qué alcance (toda la flota, un clúster, piloto).

**Condiciones de revisión.** Desencadenantes concretos que hacen que el registro se reabra.

**Referencias.** Capítulos del curso y documentos internos del proyecto.
```

## ADR-01. Cómputo: EKS Auto Mode frente a una pila propia de Karpenter

Estado: _lo completa el ingeniero_
Fecha: _lo completa el ingeniero_

**Contexto.** Responder antes de elegir:

- si seguridad exige una imagen de nodo (AMI certificado, bootstrap propio);
- si se necesita acceso al nodo para depuración o para agentes de nodo mediante DaemonSet;
- si se necesita un CNI que no sea VPC CNI y control sobre el propio controlador Karpenter, no
  solo sobre NodePool;
- cuán crítico es el coste: si el recargo de gestión por encima de EC2 es aceptable;
- si hay un equipo preparado para operar los nodos o si el objetivo es precisamente minimizar
  la operación.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
| EKS Auto Mode | nodos como appliance: Bottlerocket, SELinux enforcing, raíz de solo lectura, rotación no superior a 21 días, Karpenter, IPAM, network policy, EBS CSI, ELB y Pod Identity integrados | recargo de gestión por encima de EC2 (no aplica a descuentos Reserved ni Savings Plans), sin SSH ni SSM, no se pueden modificar los NodePool y NodeClass predeterminados, no es posible usar un CNI ajeno | el objetivo es minimizar la operación de nodos, sin requisitos de imagen ni acceso al nodo |
| Pila propia: managed node groups o self-managed más Karpenter propio | launch template y AMI propios, acceso al nodo, cualquier CNI, control completo de la versión y configuración de Karpenter | los nodos, add-ons, actualizaciones y manejo de interrupciones son responsabilidad propia; se paga solo por EC2 | hay un requisito que Auto Mode no cubre o la economía no admite el recargo |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos: un modelo único de operación de nodos por clúster y un límite predecible de
  responsabilidades entre AWS y el equipo.
- Qué coste tiene: con Auto Mode siguen siendo responsabilidad propia los contenedores, la
  configuración del clúster y de la VPC, los volúmenes de PVC y los balanceadores; los NodePool
  propios no heredan las restricciones de los predeterminados, por lo que los límites y tipos de
  instancias se establecen manualmente; de lo contrario, el pool crece sin límite.

**Decisión.** _completar para el proyecto propio_

**Condiciones de revisión.** Apareció el requisito de una imagen de nodo certificada; se necesitó
un agente de nodo que no funcione como sidecar; se necesitó Cilium como CNI principal; los
disruption budgets empezaron a bloquear las actualizaciones durante más tiempo que la vida útil
del nodo; la flota creció hasta un volumen donde los picos de reemplazo de nodos y el recargo de
gestión son apreciables en la factura.

**Referencias.** [capítulo 9](09/es.md) - tipos de cómputo, secciones 9.6-9.8;
[capítulo 10](10/es.md) - launch template y AMI propios; [capítulo 12](12/es.md) - NodePool y
disruption; [capítulo 43](43/es.md) - análisis de costes.

## ADR-02. Identidad de pods: IRSA frente a EKS Pod Identity

Estado: _lo completa el ingeniero_
Fecha: _lo completa el ingeniero_

**Contexto.** Responder antes de elegir:

- cuántos clústeres hay y si los roles se trasladan entre ellos;
- si hay cargas de trabajo en Fargate o en nodos Windows;
- si se necesita identidad fuera de EKS (EC2, ECS, Lambda) con los mismos roles;
- si se necesita cross-account y de qué forma;
- cuál es la platform version de los clústeres existentes.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
| IRSA | federación OIDC mediante STS, funciona fuera de EKS, cross-account directo, compatible con Fargate y nodos Windows | un IAM OIDC provider por clúster, la trust policy se reescribe para cada clúster, session tags manuales | Fargate, Windows, identidad fuera de EKS, cross-account mediante federación |
| EKS Pod Identity | una trust policy para `pods.eks.amazonaws.com` en todos los clústeres, vinculación mediante asociación en la API de EKS sin anotaciones, session tags y ABAC listos para usar | solo nodos Linux de Amazon EC2, sin Fargate, Windows, Outposts ni EKS Anywhere; requiere un agente add-on y una platform version mínima | clústeres nuevos en nodos EC2, flota de clústeres con roles reutilizables |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos: una forma única de conceder permisos a los pods y una fuente de verdad clara
  sobre dónde se vincula un rol a un ServiceAccount.
- Qué coste tiene: una flota mixta exige mantener ambos modelos; cuando se configuran ambos en
  el mismo ServiceAccount, gana IRSA porque web identity se sitúa antes en la cadena SDK que el
  proveedor de contenedor, y la asociación de Pod Identity se ignora silenciosamente.

**Decisión.** _completar para el proyecto propio_

**Condiciones de revisión.** Se añadieron perfiles Fargate o nodos Windows a la flota; apareció
un requisito de ABAC basado en session tags; las restricciones de Pod Identity se redujeron en la
documentación; se necesitó el mismo rol para cargas de trabajo dentro y fuera de EKS.

**Referencias.** [capítulo 16](16/es.md) - IRSA e IAM OIDC provider; [capítulo 17](17/es.md) -
Pod Identity, comparación y orden de migración.

## ADR-03. Red: VPC CNI frente a Cilium (chaining o sustitución completa)

Estado: _lo completa el ingeniero_
Fecha: _lo completa el ingeniero_

**Contexto.** Responder antes de elegir:

- si se necesitan políticas en L7 (HTTP, gRPC, Kafka) o por nombres DNS, y quién las escribirá;
- si se necesita observabilidad de flujos entre pods al nivel de Hubble;
- si importan las direcciones reales de los pods en la VPC, security groups for pods y Flow Logs
  por pod;
- si la escasez de IPv4 no se puede resolver con otros medios;
- si el equipo está preparado para hacerse cargo de las actualizaciones del CNI y su
  compatibilidad con la versión del clúster.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
| VPC CNI con NetworkPolicy integrado | managed add-on, soporte de AWS, actualizaciones estándar, `NetworkPolicy` L3/L4 estándar y `ClusterNetworkPolicy` administrativo, direcciones VPC reales | sin reglas L7, sin políticas por FQDN, sin CRD de Cilium ni Hubble | se necesita aislamiento L3/L4 y el modelo de direcciones de la VPC es adecuado |
| Cilium en modo CNI chaining | `CiliumNetworkPolicy`, políticas L7 y DNS, Hubble, mientras que IPAM e integraciones de VPC siguen a cargo de VPC CNI | instalación propia de Cilium y su mantenimiento, un segundo modelo de CRD, formación del equipo | se necesitan políticas L7 o DNS, o Hubble, y el modelo de direcciones es adecuado |
| Cilium como sustitución completa (ENI IPAM o cluster-pool) | IPAM propio, overlay opcional y reducción de la escasez de IPv4, ClusterMesh, sustitución de kube-proxy por eBPF | las actualizaciones y la compatibilidad son responsabilidad propia, el soporte de AWS se reduce; con overlay se pierden las direcciones reales de los pods, SG for pods y las direcciones de pods en Flow Logs | se necesita overlay o red multiclúster, o requisitos que el modelo ENI no proporciona |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos: un límite explícito entre lo que cubre el soporte de AWS y lo que posee el
  equipo de plataforma.
- Qué coste tiene: no se puede cambiar el CNI con un interruptor, el CNI se asigna al pod al
  crearlo, por lo que la transición es blue/green mediante un nuevo pool de nodos o un nuevo
  clúster; el diagnóstico de fallos se traslada a las herramientas del CNI; también se prevé una
  ventana sin políticas al iniciar el pod (`NETWORK_POLICY_ENFORCING_MODE` en modo `standard`
  aplica default allow).

**Decisión.** _completar para el proyecto propio_

**Condiciones de revisión.** Apareció un requisito de políticas L7 o por nombres DNS; se necesitó
un mapa de flujos entre pods; la escasez de IPv4 dejó de resolverse con los medios del capítulo 7;
se necesitó una Pod Network común para varios clústeres; iptables kube-proxy pasó a ser un cuello
de botella.

**Referencias.** [capítulo 8](08/es.md) - CNI alternativos, coste de transición, migración;
[capítulo 6](06/es.md) - direccionamiento de pods mediante ENI; [capítulo 7](07/es.md) -
escasez de direcciones; [capítulo 30](30/es.md) - políticas de red en producción.

## ADR-04. Autoescalado de nodos: Cluster Autoscaler frente a Karpenter

Estado: _lo completa el ingeniero_
Fecha: _lo completa el ingeniero_

**Contexto.** Responder antes de elegir:

- si el clúster usa Auto Mode o una pila propia (en Auto Mode la cuestión ya está resuelta,
  Karpenter está integrado);
- cuán heterogéneas son las cargas de trabajo y cuántos node group habrá que mantener;
- si se exige una respuesta rápida a picos de tráfico;
- si se necesita unificar los clústeres de otras nubes con una sola herramienta;
- si CA ya está instalado, está depurado y realmente causa problemas.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
| Cluster Autoscaler | funciona sobre Auto Scaling group, una forma común para muchos proveedores, operación conocida sin CRD nuevos | reacción a nivel de grupo, no de pod; el conjunto de tipos queda fijado en launch template; más lento por la capa ASG; elimina nodos vacíos, pero no consolida | clústeres simples y predecibles, unificación multicloud, instalación existente que funciona |
| Karpenter | llama a EC2 directamente, selecciona el tipo de instancia para pods concretos, consolidación activa, diversificación de tipos para spot | CRD propios `NodePool` y `EC2NodeClass`, propiedad de la versión y configuración del controlador, AWS-first | clústeres nuevos en EKS, cargas de trabajo heterogéneas, requisito de velocidad y empaquetado denso |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos: un mecanismo que responde de la aparición y eliminación de nodos, y un único
  lugar donde se establecen los límites de la flota.
- Qué coste tiene: mantener ambos a la vez es aceptable solo en conjuntos distintos de nodos y
  únicamente como modo de migración temporal; de lo contrario, compiten por las decisiones de
  scale-down. La migración se hace mediante nodos nuevos, no moviendo pods en un nodo vivo.

**Decisión.** _completar para el proyecto propio_

**Condiciones de revisión.** El zoológico de node group creció y dejó de ser gestionable; la
inactividad debida a un empaquetado deficiente se volvió visible en la factura; la respuesta a
picos de tráfico dejó de cumplir el SLO; el clúster se trasladó a Auto Mode; aparecieron
clústeres en otras nubes con el requisito de una herramienta única.

**Referencias.** [capítulo 11](11/es.md) - comparación de enfoques y lista de comprobación de
selección; [capítulo 12](12/es.md) - NodePool, consolidation, disruption budgets;
[capítulo 13](13/es.md) - spot; [capítulo 9](09/es.md) - relación con Auto Mode.

## ADR-05. GitOps para una flota de clústeres: hub-and-spoke frente a descentralización

Estado: _lo completa el ingeniero_
Fecha: _lo completa el ingeniero_

**Contexto.** Responder antes de elegir:

- cuántos clústeres hay actualmente en la flota y cuántos se esperan;
- si se requiere autonomía del clúster al perder el hub o la conexión con él;
- si se necesita un panel único de visión general para toda la flota;
- quién actualiza los agentes y si el equipo está preparado para la divergencia de sus versiones;
- cuánto cuesta el tráfico de reconciliación al cruzar los límites de clústeres.

**Alternativas consideradas.**

| Alternativa | Qué aporta | Qué coste tiene | Cuándo es adecuada |
|---|---|---|---|
| Hub-and-spoke | una instancia de Argo CD o Flux en el hub, sin necesidad de instalar un agente en cada clúster, ApplicationSet con generadores cluster y git mediante matrix despliega un conjunto de add-ons en toda la flota, vista unificada | el hub como dominio de fallo: las cargas de trabajo en el spoke funcionan, pero la aplicación de commits, self-heal y los rollbacks se detienen en toda la flota; la reconciliación por red añade latencia, coste de tráfico saliente y sensibilidad a la conectividad | flota pequeña o mediana, donde se valora la simplicidad operativa y una vista unificada |
| Sharding del hub | los clústeres se distribuyen entre réplicas de application-controller, el número de réplicas se duplica en `ARGOCD_CONTROLLER_REPLICAS` | permanece un solo dominio de fallo; la distribución basada en hash es desigual, round-robin es más uniforme | la flota superó un controlador, pero no se requiere autonomía de los clústeres |
| Descentralización | el hub despliega solo la base y un agente local, después el clúster extrae por sí mismo desde Git y sigue siendo autónomo si pierde el hub | hay tantos agentes como clústeres, hay que actualizarlos y configurarlos, no existe un panel único y las versiones de los agentes divergen | flota grande o requisito estricto de autonomía |
| argocd-agent | una instancia central de Argo CD ve los `Application` de todos los clústeres, pero un agente desde el spoke realiza la sincronización | proyecto `argoproj-labs`, de incubación y no parte del núcleo de Argo CD; la topología sigue siendo hub-and-spoke | se acepta usar un proyecto de incubación a cambio del flujo inverso |

**Consecuencias de la decisión aceptada.**

- Qué obtenemos: una respuesta clara a la pregunta «qué ocurrirá con la entrega si el hub no
  está disponible».
- Qué coste tiene: la frontera entre IaC y GitOps sigue siendo obligatoria en cualquier topología:
  la infraestructura (VPC, clúster, node groups, IAM) se gestiona mediante Terraform, mientras
  que los add-ons y las cargas de trabajo pasan por GitOps; mezclarlos causa o bien la recreación
  del clúster para modificar un Deployment, o bien el problema del huevo y la gallina con un
  agente que vive en ese mismo clúster.

**Decisión.** _completar para el proyecto propio_

**Condiciones de revisión.** La flota creció tanto que un solo controlador ya no puede gestionarla;
apareció el requisito de continuar la reconciliación al perder el hub; el coste del tráfico
saliente de reconciliación se volvió apreciable; argocd-agent salió de incubación.

**Referencias.** [capítulo 44](44/es.md) - topologías de flota, sección 44.6;
[capítulo 32](32/es.md) - flota de clústeres; [capítulo 4](04/es.md) - IaC y Terraform;
[capítulo 31](31/es.md) - coste de tráfico; [capítulo 38](38/es.md) - migración blue/green.

## Lo que aquí no se resuelve deliberadamente

El curso no considera arquitectónicas algunas bifurcaciones: la tecnología tiene en ellas un valor
aproximadamente equivalente y decide el contexto de la empresa. La elección entre Argo CD y Flux
es una cuestión de qué sabe usar ya el equipo y qué interfaz necesita, no de las propiedades de
las herramientas. La elección entre Prometheus propio y un servicio managed depende de quién
mantiene la guardia y cuánto cuesta el almacenamiento, no de la arquitectura de recopilación de
métricas. Lo mismo ocurre con la elección del registro de imágenes, la herramienta de secretos y
la distribución de cuentas: son límites organizativos. La lista consolidada de lo que se debe
comprobar antes de pasar a producción se reúne en el [capítulo 48](48/es.md).