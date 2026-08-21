[Русская версия](SCORECARD_RU.md) · [Eng version](SCORECARD.md) · [Version française](SCORECARD_FR.md) · [Deutsche Version](SCORECARD_DE.md) · [ქართული ვერსია](SCORECARD_GE.md) · [繁體中文版](SCORECARD_TW.md) · [日本語版](SCORECARD_JP.md)

# Matriz de madurez de EKS: cuestionario de preparación

[Índice del curso](README_ES.md) · [Capítulo 48](48/es.md) · [Glosario](GLOSSARY_ES.md)

Este es el formulario de trabajo del capítulo 48: los mismos dominios de preparación, pero como un cuestionario que el equipo completa y transforma en una lista de deuda técnica. No hay contenido nuevo aquí.

## Cómo completarlo

- Recorra los ocho dominios en orden, sin omitir ninguno: cada dominio es un eje independiente de operación, y la fortaleza de uno no compensa la debilidad de otro.
- Responda cada punto con honestidad: sí o no. «Parcialmente», «casi» y «configurado, pero no comprobado» cuentan como no.
- Complételo en equipo, no una sola persona: quienes son responsables de red, seguridad y costes ven carencias distintas, y «parece listo» se desmonta precisamente al cruzar opiniones.
- El objetivo no es la puntuación. Solo sirve para ver el nivel; el resultado del cuestionario es una lista de lo pendiente, con responsables y fechas.
- Marque cada punto pendiente como riesgo conocido con una tarea; no lo omita en silencio solo para que el formulario parezca verde.
- Repítalo una vez por trimestre y tras cambios importantes: las versiones envejecen, las cargas crecen, y lo que ayer estaba «cerrado» hoy ya es una carencia.
- El formulario vive en el repositorio junto a la IaC, para que sus cambios sean visibles en el pull request.

## Escala de niveles

El cuestionario tiene 51 puntos en total. Cada punto cerrado vale un punto.

| Nivel | Puntos | Qué significa | Qué hacer después |
|---|---|---|---|
| Nivel 1. Inestable y manual | 0-20 | El clúster funciona mientras nada se rompa: mucho se hizo con clics, y la recuperación y los límites de seguridad no se han comprobado | Cerrar los puntos bloqueantes y toda la columna «must have» antes de habilitar tráfico de producción |
| Nivel 2. Gestionable | 21-33 | Existe la base: el clúster está definido como código, y acceso y cómputo se han considerado, pero las comprobaciones y la observabilidad dependen de personas concretas | Completar seguridad y operación: auditoría, retention, alertas y plan de actualizaciones |
| Nivel 3. Repetible y observable | 34-44 | Las prácticas están consolidadas y son repetibles: se han realizado actualización, backup y restore, y los incidentes se localizan mediante runbook | Completar la prioridad «importante en las primeras semanas» y asignar ownership a cada dominio |
| Nivel 4. Resiliencia autónoma | 45-51 | La preparación no se degrada entre lanzamientos: DR se ha comprobado en ejercicios, los costes y el tráfico están bajo control, y GitOps es la fuente de verdad | Mantener el nivel: cuestionario trimestral, game day y mejora de «nice to have» |

Si queda abierto un punto bloqueante, el nivel no puede ser superior al segundo, sin importar cuántos puntos se hayan obtenido en total. La regla se explica en «Cálculo y qué hacer con el resultado».

## 1. Clúster y control plane

La base. Si la versión ya no tiene soporte o las subredes están en una sola AZ, lo demás no importa.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | La versión de Kubernetes está dentro del standard support | Una versión sin soporte es un riesgo que no puede mitigarse con configuración | [38](38/es.md) |
| [ ] | Hay un plan de actualización de versiones, no una reacción un mes antes de que termine el soporte | Una actualización presionada por la fecha se hace sin ventana de reversión | [38](38/es.md) |
| [ ] | El endpoint access está pensado: público o privado, source ranges adecuados a la necesidad | El modo de acceso a la API determina la superficie de ataque del clúster | [02](02/es.md) |
| [ ] | Las subredes del clúster están en tres AZ y el plan de IP cubre el crecimiento de pods | Una AZ es un único punto de fallo; la falta de IP detiene la programación de pods | [06](06/es.md) |
| [ ] | El clúster se creó desde código (Terraform o eksctl), no con clics en la consola | Un clúster manual no se puede recrear durante DR ni revisar en un pull request | [04](04/es.md) |
| [ ] | Los recursos tienen etiquetas: equipo, entorno, cost allocation | Sin etiquetas no se pueden distribuir costes y propiedad entre equipos | [43](43/es.md) |

## 2. Cómputo

Los nodos son responsabilidad completa de ingeniería: aquí se deciden tanto la resiliencia como la factura.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | La estrategia de nodos se eligió conscientemente: Auto Mode, Karpenter o managed node groups | Mantener el valor predeterminado implica consecuencias desconocidas para el precio y la resiliencia | [09](09/es.md) |
| [ ] | Se utiliza una mezcla de Spot para cargas tolerantes a fallos | Spot ahorra donde la carga sobrevive a una interrupción | [13](13/es.md) |
| [ ] | Los tipos de instancia del pool spot están diversificados | Spot sin diversificación no es ahorro, sino riesgo de perder toda la capacidad de una vez | [13](13/es.md) |
| [ ] | Los requests se establecen según los hechos (right-sizing), no «a ojo» | Los requests sobredimensionados pagan por aire; los infradimensionados rompen la carga | [14](14/es.md) |
| [ ] | Karpenter disruption y consolidation están configurados, y el drift no se ignora | Sin consolidation, el parque de nodos se dispersa; el drift acumula diferencias respecto al código | [12](12/es.md) |
| [ ] | La densidad de pods por nodo concuerda con los límites de ENI e IP | Exceder la densidad deja pods en `Pending` sin causa evidente | [14](14/es.md) |

## 3. Identidad y seguridad

El dominio más amplio y la fuente más frecuente de carencias silenciosas. Compruebe punto por punto.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | Los pods acceden a AWS mediante IRSA o Pod Identity, sin claves estáticas | Una clave de larga duración en un pod se filtra junto con la imagen o el log | [16](16/es.md) |
| [ ] | **Bloqueante.** El acceso al clúster no corresponde solo al cluster creator; existen access entries | Un clúster al que solo puede acceder una persona se pierde junto con esa persona | [05](05/es.md) |
| [ ] | Los secretos se obtienen de Secrets Manager o SSM (External Secrets, CSI), no de manifiestos | Un secreto en un manifiesto llega a git y a cada copia del repositorio | [18](18/es.md) |
| [ ] | Nodos y pods están reforzados: IMDSv2, hop limit, Pod Security Admission | El acceso a los metadatos del nodo desde un pod convierte el pod en los permisos del nodo | [19](19/es.md) |
| [ ] | Las imágenes se escanean en ECR y la base procede de fuentes de confianza | Una base vulnerable se propaga a todos los servicios de inmediato | [20](20/es.md) |
| [ ] | La auditoría del control plane está habilitada: api, audit, authenticator en los logs | La auditoría se habilita antes del incidente; después ya no habrá logs | [21](21/es.md) |
| [ ] | Las políticas de Kyverno o Gatekeeper bloquean patrones peligrosos de manifiestos | La revisión humana omite lo que una política detecta siempre | [22](22/es.md) |

## 4. Almacenamiento

Un dominio pequeño pero engañoso: los valores predeterminados de EBS y el backup de volúmenes sin comprobar golpean de repente.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | La StorageClass predeterminada usa gp3, no el obsoleto gp2 | gp2 sigue siendo el predeterminado por inercia y pierde en características y precio | [23](23/es.md) |
| [ ] | Se ha definido `volumeBindingMode: WaitForFirstConsumer` | De otro modo, el volumen nace en la AZ equivocada y el pod queda en `Pending` para siempre | [23](23/es.md) |
| [ ] | Los volúmenes persistentes se incluyen en el backup | Un volumen sin backup son datos que existen en una sola copia | [41](41/es.md) |
| [ ] | Las instantáneas de volúmenes se han validado restaurándolas, no solo creándolas | Una instantánea sin comprobar equivale a no tener instantánea | [41](41/es.md) |
| [ ] | La vinculación de EBS a una AZ se considera al migrar y programar cargas | Migrar manifiestos «tal cual» falla precisamente en los volúmenes | [23](23/es.md) |
| [ ] | El almacenamiento compartido se eligió conscientemente: EFS o FSx donde se necesita ReadWriteMany | EBS no ofrece ReadWriteMany, y la alternativa se decide en la fase de diseño | [24](24/es.md) |

## 5. Red y tráfico

Los errores de este dominio son visibles desde fuera: un servicio inaccesible, egress abierto o tráfico por todas las AZ.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | Los balanceadores se crean mediante AWS Load Balancer Controller: NLB | Los balanceadores manuales divergen del estado del clúster | [26](26/es.md) |
| [ ] | Ingress funciona mediante ALB con un target-type elegido conscientemente | El tipo de destino determina la ruta del tráfico y el comportamiento durante drain | [27](27/es.md) |
| [ ] | Los certificados TLS usan ACM y HTTPS termina en el balanceador | Los certificados manuales caducan en el momento más inoportuno | [27](27/es.md) |
| [ ] | **Bloqueante.** NetworkPolicy con default-deny; el tráfico entre pods se permite explícitamente | Sin default-deny, un pod comprometido ve a todos sus vecinos | [30](30/es.md) |
| [ ] | Los registros DNS se gestionan mediante external-dns, no manualmente en Route 53 | Un registro manual sobrevive a la eliminación del servicio y apunta al vacío | [29](29/es.md) |
| [ ] | VPC endpoints para servicios AWS, NAT por AZ y tráfico de egress bajo control | El egress a través de un único NAT es tanto un punto de fallo como una partida de gasto | [31](31/es.md) |

## 6. Observabilidad

Sin este dominio, un incidente se depura a ciegas. Los datos no solo deben fluir, sino conservarse el tiempo necesario y generar alertas.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | metrics-server funciona | Sin él no funcionan ni `kubectl top` ni HPA | [33](33/es.md) |
| [ ] | Hay un backend de métricas: Prometheus o Container Insights | Se necesitan métricas con historial, no solo «ahora mismo» | [33](33/es.md) |
| [ ] | Los logs se exportan desde nodos y pods | Los logs que quedan en el nodo desaparecen junto con él | [34](34/es.md) |
| [ ] | La retention de logs se ha definido conscientemente | Retention sin plan implica logs perdidos durante el análisis o almacenamiento sobrante | [34](34/es.md) |
| [ ] | Hay alertas configuradas para síntomas clave, no solo dashboards | Un dashboard que nadie mira no sustituye una alerta | [33](33/es.md) |
| [ ] | Hay tracing (ADOT o X-Ray) donde importa la cadena de llamadas | En microservicios, la causa del fallo no está en el servicio donde se ve el síntoma | [36](36/es.md) |

## 7. Operación

El dominio que separa «el clúster funciona hoy» de «el clúster sobrevivirá a una actualización y a un fallo».

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | Hay un plan para actualizar el clúster y los add-ons, y se han eliminado las API obsoletas | Una API obsoleta detiene una actualización en el momento más inoportuno | [37](37/es.md) |
| [ ] | La rollback readiness está clara: se conocen la ventana y el orden de reversión | La reversión se diseña antes, no durante una actualización fallida | [39](39/es.md) |
| [ ] | PDB y topology spread protegen la disponibilidad durante drain y actualización | Sin ellos, una actualización de nodos elimina todas las réplicas de un servicio a la vez | [40](40/es.md) |
| [ ] | Los PDB no bloquean el drain indefinidamente (`maxUnavailable: 0` es una señal de alarma) | Ese PDB detiene la actualización y parece un drain bloqueado | [40](40/es.md) |
| [ ] | AWS Backup está configurado para el estado del clúster y los volúmenes persistentes | Hacer backup solo de volúmenes no restaura el propio clúster | [41](41/es.md) |
| [ ] | **Bloqueante.** El DR-restore se ha probado realmente en un game day | Un restore configurado pero nunca comprobado es esperanza, no backup | [42](42/es.md) |
| [ ] | El coste es visible por equipos y namespace (OpenCost o Kubecost) | Un coste invisible no se optimiza ni tiene responsable | [43](43/es.md) |
| [ ] | GitOps es la fuente de verdad para los manifiestos (Argo CD o Flux) | La divergencia entre el clúster y git significa que nadie conoce el estado | [44](44/es.md) |

## 8. Preparación para incidentes

El dominio final: cuando todo falle, no importa la arquitectura, sino la velocidad de localización.

| Listo | Punto | Por qué importa | Capítulo |
|---|---|---|---|
| [ ] | Existe un runbook para un nodo que no se unió al clúster | Las causas varían (IAM, SG, user data, kubelet); el orden de comprobación ahorra horas | [45](45/es.md) |
| [ ] | Existe un runbook para fallos de red: ENI, SG y NACL, DNS, unhealthy targets | Un fallo de red parece igual aunque las causas sean diferentes | [46](46/es.md) |
| [ ] | Existe un runbook para acceso: 401 frente a 403, IRSA y Pod Identity, kubeconfig | Un error de acceso bloquea tanto el trabajo como el análisis del incidente | [47](47/es.md) |
| [ ] | El acceso SSM a los nodos funciona sin SSH directo; se puede entrar en el nodo | Configurar acceso al nodo cuando ya está averiado es demasiado tarde | [45](45/es.md) |
| [ ] | El logging del control plane está habilitado y se escriben logs de authenticator y API | Sin estos logs, no se puede reconstruir la causa de un fallo de acceso | [21](21/es.md) |
| [ ] | Los logs del control plane están disponibles para análisis y no se eliminan antes de tiempo | Los logs hacen falta durante el análisis, no durante la configuración | [34](34/es.md) |

## Cálculo y qué hacer con el resultado

Cuente así:

- Cada punto cerrado vale un punto, hasta un máximo de 51. Los dominios tienen la misma importancia: la red no importa más que el almacenamiento, y una puntuación alta en un dominio no cierra una carencia en otro.
- Hay tres puntos marcados como **bloqueantes**: DR-restore no se ha probado, solo una persona tiene acceso al clúster, y no hay NetworkPolicy default-deny en la red.
- Si queda abierto al menos un punto bloqueante, el nivel no puede ser superior al segundo, con cualquier suma de puntos. Un punto bloqueante no es «menos un punto», sino un alto para el tráfico de producción.

Después, convierta los puntos pendientes en una lista de deuda técnica con prioridad:

| Prioridad | Qué incluir | Qué hacer |
|---|---|---|
| Must have antes de producción | versión compatible, acceso no limitado a una persona, auditoría y logs de control plane, NetworkPolicy default-deny, secretos fuera de manifiestos, restore probado, PDB que no bloquean actualizaciones | cerrarlo antes de habilitar tráfico de producción: el primer incidente o intrusión cuesta más que retrasar el lanzamiento |
| Importante en las primeras semanas | right-sizing de requests, mezcla spot, retention de logs, alertas, plan de actualizaciones, VPC endpoints | crear tareas con responsables y fechas inmediatamente después del lanzamiento |
| Nice to have | tracing de microservicios, asignación detallada de costes, GitOps maduro para un parque de clústeres | mejorarlo iterativamente ya en producción, sin bloquear el lanzamiento |

La lista de deuda técnica se formula como tareas explícitas con responsable y fecha. La frase «más adelante, algún día» significa que el punto no está cerrado y aparecerá en el mismo sitio en la siguiente revisión.

Qué hacer después con el resultado:

- Asigne ownership a los dominios: red, seguridad y costes tienen una persona responsable de que sus puntos estén cerrados y no se degraden.
- Complete el formulario antes de cada puesta en producción: un nuevo clúster o servicio importante no entra en funcionamiento hasta que la prioridad «must have» esté completamente cerrada y explícita.
- Vincule el resultado a game days y actualizaciones: devuelva la comprobación de DR-restore y el plan de actualización al formulario como punto confirmado o fallido, no como una promesa.
- Compárelo con la revisión anterior: no interesa la suma de puntos, sino qué puntos se cerraron, cuáles volvieron a quedar abiertos y por qué.

## Limitaciones de este cuestionario

- No sustituye una revisión de arquitectura: los ejes de preparación son visibles, pero las decisiones de diseño no.
- Evalúa la existencia de una práctica, no su calidad: una auditoría habilitada y una auditoría útil otorgan el mismo punto; la diferencia solo se ve durante el análisis de un incidente.
- No cubre la capa de aplicación: el código de los servicios y los esquemas de datos quedan fuera del formulario.
- La puntuación no es comparable entre clústeres con fines diferentes: un clúster no productivo no necesita parte de los puntos, y una puntuación baja allí no significa nada malo.
