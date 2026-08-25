[Русская версия](COST_MODEL_RU.md) · [Eng version](COST_MODEL.md) · [Version française](COST_MODEL_FR.md) · [Deutsche Version](COST_MODEL_DE.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [繁體中文版](COST_MODEL_TW.md) · [日本語版](COST_MODEL_JP.md)

# Modelo de costes de un clúster EKS: plantilla de estimación

[Índice del curso](README_ES.md) · [Capítulo 43](43/es.md) · [Glosario](GLOSSARY_ES.md)

Esta es una hoja de trabajo para el capítulo 43: la misma estructura de costes, pero en forma de tabla y fórmulas con las que el ingeniero prepara la estimación de su clúster. No hay material nuevo aquí.

## Cómo usarla

- La hoja NO contiene precios. Las tarifas dependen de la región, cambian y quedan obsoletas más rápido que el curso, por lo que la columna «Tarifa (completar)» se deja vacía deliberadamente.
- Las tarifas se obtienen de AWS Pricing Calculator para tu región y se introducen en la columna vacía; para los datos reales de un clúster que ya está en ejecución, se usan los de Cost and Usage Report (capítulo 43).
- El valor de la plantilla no está en la precisión del número, sino en que la lista sea completa: evita olvidar una partida que aparecerá en la factura, pero que no se incluyó en la estimación.
- Haz la estimación dos veces: ANTES y DESPUÉS del right-sizing. La diferencia entre ambas ejecuciones es el efecto medido de la decisión de ingeniería, no una promesa de ahorro.
- Mantén las unidades iguales en toda la hoja (horas por mes, GB frente a GiB); de lo contrario, las filas no se pueden sumar entre sí.
- Vuelve a ejecutar la hoja después de cambiar el modelo de compra de nodos, añadir una AZ, habilitar nuevos tipos de logs o realizar cualquier cambio en la topología de egress.

## Partidas de coste

| Partida | De qué depende | Unidad | Tarifa (completar) | Capítulo |
|---|---|---|---|---|
| Control plane del clúster | número de clústeres, tiempo de ejecución | clúster-hora |  | [02](02/es.md) |
| Recargo por extended support | versión fuera de standard support | clúster-hora |  | [38](38/es.md) |
| Nodos EC2 | tipo de instancia, número de nodos, modelo de compra | instancia-hora |  | [09](09/es.md) |
| Recargo de gestión de Auto Mode | managed instances bajo Auto Mode | instancia-hora |  | [09](09/es.md) |
| Fargate: vCPU | CapacityProvisioned del pod, tiempo de vida | vCPU-hora |  | [15](15/es.md) |
| Fargate: memoria | CapacityProvisioned del pod, tiempo de vida | GB-hora |  | [15](15/es.md) |
| Volúmenes EBS | tipo de volumen, tamaño, IOPS y throughput aprovisionados | GiB-mes |  | [23](23/es.md) |
| Snapshots de EBS | volumen de datos capturados, periodo de retención | GiB-mes |  | [23](23/es.md) |
| NAT Gateway: funcionamiento | número de NAT (uno por AZ), tiempo de existencia | NAT-hora |  | [31](31/es.md) |
| NAT Gateway: procesamiento | egress de pods, pull de imágenes, llamadas a AWS API | GB |  | [31](31/es.md) |
| Tráfico cross-AZ | tráfico east-west entre zonas, consultas a una base de datos en otra AZ | GB |  | [31](31/es.md) |
| Tráfico saliente a Internet | respuestas a clientes, transferencias hacia fuera | GB |  | [31](31/es.md) |
| Interface endpoints (PrivateLink) | número de endpoints, volumen procesado | endpoint-hora y GB |  | [31](31/es.md) |
| Logs: recepción (ingestion) | volumen de logs de pods y control plane recibidos | GB |  | [34](34/es.md) |
| Logs: almacenamiento | volumen bajo la retención configurada | GB-mes |  | [34](34/es.md) |
| Balanceadores de carga (NLB, ALB) | número de balanceadores, volumen procesado | hora y volumen |  | [26](26/es.md) |

Los gateway endpoints para S3 y DynamoDB no necesitan una fila en esta tabla: son gratuitos, pero desvían volumen del NAT de pago y por ello afectan a la fila «NAT Gateway: procesamiento» (capítulo 31).

## Fórmulas generales

```text
Convenciones: HOURS son las horas del mes de cálculo, RATE_* es la tarifa de la tabla anterior,
todas las magnitudes de consumo se toman de métricas y facturación, no de planes de diseño.

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT: clústeres con una versión en extended support; es un RECARGO sobre la
# tarifa horaria normal del clúster, no la misma tarifa (capítulo 38).

nodes = suma por pools P: NODES[P] * HOURS[P] * RATE_INSTANCE[P, modelo de compra]
# modelo de compra: On-Demand, Spot, cobertura de Reserved o Savings Plans (capítulo 43).

auto_mode = nodes(pools de Auto Mode)                      # parte de EC2
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # recargo de gestión
# OBLIGATORIO: Reserved Instances y Savings Plans reducen SOLO la parte de EC2.
# El recargo de gestión de Auto Mode NO entra en estos descuentos y en la factura aparece
# como una partida independiente (capítulo 09). La tarifa horaria del control plane de EKS
# tampoco entra en Compute Savings Plans (capítulo 43).

fargate = suma por pods: VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV y MEM_PROV_GB son la combinación aprovisionada de la anotación CapacityProvisioned,
# es decir, requests redondeados hacia arriba, no los propios requests (capítulo 15).

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# BASELINE_COMPUTE se calcula DESPUÉS del right-sizing; de lo contrario, se compromete capacidad vacía.
# SPOT_SUSTAINED es la proporción de Spot que se logra de forma sostenida, no la prevista: Savings Plans
# no cubren Spot, el compromiso horario no se traslada entre horas y el consumo no cubierto se pierde
# cada hora, mientras que el fallback a On-Demand devuelve parte del consumo al compromiso
# (capítulos 43 y 13). El compromiso se revisa según utilization y coverage reales.

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# Dos partes independientes: la existencia del NAT y cada gigabyte procesado.

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# Se cobra en ambas direcciones: CROSS_AZ_GB incluye tanto la solicitud como la respuesta (capítulo 31).

storage = suma por volúmenes: SIZE_GIB * RATE_VOLUME[tipo]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# Se paga el tamaño aprovisionado del volumen, no lo ocupado dentro del sistema de archivos.

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB es el volumen recibido: normalmente es la partida principal (capítulo 34).

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## Lo que se suele olvidar

- **Recargo de Auto Mode.** En la factura es una partida independiente por encima de la tarifa de EC2, y los modelos de descuento no le afectan; al comparar Auto Mode con tu propia pila, calcúlalo de forma explícita (capítulo 09).
- **Extended support como recargo.** Un clúster con una versión obsoleta cuesta más por hora de ejecución, no lo mismo; en la estimación es un sumando independiente (capítulo 38).
- **Cross-AZ en ambas direcciones.** Un servicio de una zona que llama a una base de datos de otra paga por el intercambio, no solo por la solicitud; cuenta ambas direcciones (capítulo 31).
- **NAT cobra dos veces.** La tarifa por hora se aplica mientras el NAT existe y, de manera independiente, se cobra cada gigabyte procesado; normalmente se olvida la segunda parte (capítulo 31).
- **Los logs se pagan principalmente por la recepción.** Reducir la retención solo afecta al almacenamiento y ahorra poco; lo que importa es el intervalo de recopilación, los niveles de logging y el filtrado de series (capítulo 34).
- **Volúmenes y snapshots olvidados.** Se eliminó el PVC, pero quedó el volumen; los snapshots se acumulan durante años. Es una fuga silenciosa que solo se ve en la facturación (capítulo 23).
- **Balanceador tras un servicio eliminado.** El Service se eliminó fuera de Kubernetes, pero el NLB o ALB siguió existiendo y acumulando cargos (capítulo 26).
- **Capacidad inactiva.** Pagas por los requests reservados, no por lo usado: la diferencia entre requested y used es vacío pagado, multiplicado por las réplicas (capítulo 43).

## Orden de optimización

1. **Right-size y bin-pack**: ajusta los requests al consumo real y deja que consolidation densifique los nodos (capítulos 43, 14, 12).
2. **Compromiso sobre un baseline estabilizado**: Savings Plans para un volumen que se mantiene durante meses, solo después de reducirlo (capítulo 43).
3. **Spot para cargas flexibles**: las cargas interrumpibles se mueven a Spot con diversificación por tipos y zonas (capítulo 13).
4. **Tráfico, logs y almacenamiento**: gateway endpoint para S3, NAT por zonas, volumen de logs en el origen, volúmenes y snapshots (capítulos 31, 34, 23).

El orden es precisamente este porque cada paso siguiente se aplica a una base que el anterior redujo: comprometer o mover a Spot un volumen inflado equivale a fijar el pago por capacidad vacía.

## Límites de la plantilla

- La hoja no sustituye AWS Pricing Calculator para la previsión ni Cost and Usage Report para los datos reales: define la lista de partidas y las fórmulas, pero los números proceden de esas fuentes.
- Los servicios de aplicación fuera del clúster (bases de datos, colas, cachés, S3 para datos de aplicaciones) no se calculan aquí, aunque formen parte de la factura del producto.
- La asignación por equipos y namespace se realiza con la herramienta de asignación del capítulo 43, no con esta tabla: trata del clúster completo, no de cuánto gastó cada componente interno.
- La hoja muestra los costes compartidos (control plane, namespaces del sistema, capacidad inactiva) como filas del clúster; la regla para repartirlos entre equipos se elige por separado (capítulo 43).
- La hoja no modela los descuentos de acuerdos con AWS ni el orden de aplicación de los compromisos: solo se ven en la facturación real.
