[Русская версия](GLOSSARY_RU.md) · [English version](GLOSSARY.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glosario del curso KCSA

Los términos ingleses se conservan en su forma original porque son necesarios para leer los enunciados y las opciones de KCSA. La descripción explica su significado en español, pero no sustituye la práctica de los términos en MCQ (multiple choice question, pregunta de opción múltiple) en inglés.

| Término | Descripción | Confusión habitual | Capítulos |
|---|---|---|---|
| `4C model` | Modelo de las capas Cloud, Cluster, Container y Code para analizar la protección cloud native. | No se limita únicamente a la infraestructura cloud. | [03](03/es.md) |
| `ABAC` | Autorización basada en atributos de la solicitud y del sujeto. | No es RBAC con roles. | [10](10/es.md) |
| `Access control` | Restricción del acceso a un recurso según reglas e identidad. | Es más amplio que solo authentication. | [10](10/es.md) |
| `admission` | Etapa de comprobación o modificación de una solicitud a la API después de authentication y authorization. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [07](07/es.md) |
| `Admission control` | Etapa de la API posterior a authentication y authorization que admite o modifica un objeto. | No confirma la identity ni concede permisos. | [11](11/es.md), [17](17/es.md) |
| `Admission policy` | Regla declarativa para comprobar objetos durante admission. | No equivale a audit policy. | [17](17/es.md) |
| `Admission webhook` | Webhook externo que participa en mutating o validating admission. | No es un webhook de red de la aplicación. | [17](17/es.md) |
| `Alert` | Señal que requiere atención o respuesta según una regla. | No sustituye los logs y las métricas primarios. | [18](18/es.md) |
| `Allowlist` | Lista explícita de fuentes, acciones u objetos permitidos. | No equivale a la ausencia de reglas deny. | [09](09/es.md), [17](17/es.md) |
| `Anomaly detection` | Detección de una desviación respecto al comportamiento esperado. | Una anomalía por sí misma no demuestra un ataque. | [18](18/es.md) |
| `API server` | Componente que recibe solicitudes de Kubernetes API y coordina el acceso al estado. | No almacena el estado en lugar de etcd. | [07](07/es.md) |
| `Artifact` | Resultado del desarrollo o la compilación, por ejemplo un image, paquete o SBOM. | No tiene por qué ser un container image. | [06](06/es.md), [17](17/es.md) |
| `Attack surface` | Conjunto de puntos a través de los cuales se puede atacar un sistema. | No es una única vulnerabilidad encontrada. | [02](02/es.md), [16](16/es.md) |
| `Attack vector` | Ruta o método concreto para realizar un ataque. | Es más específico que attack surface. | [15](15/es.md), [16](16/es.md) |
| `audit` | Modo PSA que registra las infracciones en la auditoría sin rechazar la solicitud. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `Audit backend` | Ubicación configurada para almacenar o transmitir eventos de audit de API Server. | API Server crea los eventos; el backend los almacena o recibe. | [14](14/es.md) |
| `audit event` | Registro de `kube-apiserver` sobre el procesamiento de una solicitud a Kubernetes API. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [14](14/es.md) |
| `audit level` | Nivel de detalle de un evento Kubernetes audit, por ejemplo `Metadata` o `RequestResponse`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [20](20/es.md) |
| `Audit logging` | Registro de eventos de solicitudes a Kubernetes API. | No sustituye runtime detection de procesos. | [14](14/es.md) |
| `Audit policy` | Configuración que define qué eventos de API y con qué detalle registrar. | No es admission policy. | [14](14/es.md) |
| `auditID` | Identificador que vincula los eventos de distintas etapas de una misma solicitud. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [14](14/es.md) |
| `Authentication` | Establecimiento de quién realiza una solicitud. | No responde si la acción está permitida. | [10](10/es.md) |
| `Authorization` | Comprobación de si un sujeto ya conocido puede realizar una acción. | No establece identity. | [10](10/es.md) |
| `Authorization mode` | Mecanismo configurado para decidir sobre permisos de API. | No equivale a un método de authentication. | [10](10/es.md) |
| `Availability` | Disponibilidad de datos o de un servicio para un usuario autorizado. | No equivale a confidentiality ni integrity. | [02](02/es.md), [16](16/es.md) |
| `Backup` | Copia de datos para recuperarse tras una pérdida o corrupción. | El backup también debe protegerse como los datos originales. | [07](07/es.md), [12](12/es.md) |
| `Base64` | Codificación reversible de bytes para una representación textual. | No es encryption. | [12](12/es.md) |
| `baseline` | Perfil que bloquea rutas frecuentes de escalada de privilegios. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `Baseline profile` | Nivel PSS que bloquea configuraciones peligrosas conocidas manteniendo la compatibilidad. | No equivale al restricted profile más estricto. | [11](11/es.md) |
| `Bearer token` | Token cuya presentación concede los derechos de su poseedor. | No equivale a una contraseña que se pueda colocar con seguridad en código. | [10](10/es.md) |
| `bind` | Permiso RBAC especial para vincular Role/ClusterRole sin tener que poseer todos los permissions del rol vinculado. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [10](10/es.md) |
| `blast radius` | Alcance de las consecuencias cuando se compromete un componente. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `Bound ServiceAccount token` | Token de corta duración vinculado a un ServiceAccount y a un Pod. | No equivale al antiguo token Secret de larga duración. | [10](10/es.md) |
| `Build provenance` | Provenance con datos sobre la compilación del artefacto. | No equivale a una firma ni a un SBOM. | [17](17/es.md), [19](19/es.md) |
| `CA` | Autoridad de certificación en la que se confía para emitir o verificar certificados. | No es una clave privada. | [18](18/es.md) |
| `capability` | Privilegio Linux individual que se puede conceder o revocar independientemente de UID 0. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [09](09/es.md) |
| `CEL` | Common Expression Language - lenguaje de expresiones integrado en Kubernetes API para condiciones y reglas sin ejecutar código arbitrario. | No es un lenguaje de propósito general para código arbitrario. | [17](17/es.md) |
| `Certificate` | Documento con una clave pública e identidad, firmado por un CA de confianza. | No contiene la clave privada. | [18](18/es.md) |
| `Certificate authority` | Nombre completo de CA como parte confiable de PKI. | No equivale a cualquier certificado TLS. | [18](18/es.md) |
| `CIA triad` | Tres objetivos de seguridad: confidentiality, integrity y availability. | No es un modelo de amenazas ni un control. | [02](02/es.md), [15](15/es.md) |
| `Cilium` | CNI y conjunto de herramientas de red que pueden aplicar NetworkPolicy. | No es el propio recurso API NetworkPolicy. | [13](13/es.md) |
| `CIS Kubernetes Benchmark` | Conjunto de recomendaciones para una configuración segura de Kubernetes. | Es un framework de recomendaciones, no un control listo para usar. | [05](05/es.md), [19](19/es.md) |
| `CKS` | Certified Kubernetes Security Specialist, certificación práctica performance-based sobre seguridad de Kubernetes. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `Cloud` | Capa externa del modelo 4C: infraestructura, IAM y servicios del proveedor. | No es idéntica a un Kubernetes cluster. | [03](03/es.md), [04](04/es.md) |
| `Cloud IAM` | Gestión de identidades y permisos para recursos cloud. | No sustituye Kubernetes RBAC. | [04](04/es.md) |
| `Cluster-admin` | ClusterRole integrada con permisos ilimitados sobre todos los recursos del clúster. | No debe usarse como identity cotidiana. | [10](10/es.md), [16](16/es.md) |
| `ClusterRole` | Conjunto de acciones API permitidas sin límite de namespace, para recursos de clúster o todos los namespace a la vez. | No equivale a Role, que está limitado a un namespace. | [10](10/es.md) |
| `ClusterRoleBinding` | Vínculo de un subject con ClusterRole a nivel de todo el clúster. | No equivale a RoleBinding, que solo actúa en un namespace. | [10](10/es.md) |
| `CNI` | Estándar y plugins para conectar contenedores a la red de Kubernetes. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [09](09/es.md), [13](13/es.md) |
| `Code` | Capa 4C con código fuente, dependencias y prácticas de desarrollo. | No equivale a un image ya compilado. | [03](03/es.md), [06](06/es.md) |
| `Compliance` | Conformidad con requisitos aplicables respaldada por evidence verificable. | No garantiza la ausencia de todos los riesgos. | [19](19/es.md) |
| `Confidentiality` | Protección de datos frente a su divulgación a partes no autorizadas. | No equivale a integrity ni availability. | [02](02/es.md), [12](12/es.md) |
| `Container` | Proceso aislado con una imagen y restricciones de runtime. | No equivale a un Pod, que puede contener varios contenedores. | [03](03/es.md), [09](09/es.md) |
| `container escape` | Salida de un proceso desde el aislamiento del contenedor hacia recursos del nodo de trabajo. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `Container image` | Plantilla inmutable de archivos y metadatos para ejecutar un contenedor. | No equivale a un container en ejecución. | [06](06/es.md), [17](17/es.md) |
| `Container registry` | Servicio para almacenar y distribuir container images. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `Container runtime` | Capa de software que ejecuta contenedores en un nodo mediante CRI. | No equivale a kubelet. | [08](08/es.md) |
| `context` | Selección de cluster, user y namespace que usa `kubectl`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [09](09/es.md) |
| `Control` | Medida concreta que reduce la probabilidad de un riesgo o sus consecuencias. | No equivale a un framework, que estructura las medidas. | [05](05/es.md), [19](19/es.md) |
| `Control plane` | Conjunto lógico de componentes que gestionan el estado de Kubernetes. | No equivale a un worker node. | [07](07/es.md) |
| `Controller Manager` | Componente que ejecuta controladores para llevar el estado al deseado. | No elige el nodo para un Pod. | [07](07/es.md) |
| `CRI` | Interfaz de Kubernetes entre kubelet y container runtime. | No es CNI ni CSI. | [08](08/es.md) |
| `CronJob` | Recurso Kubernetes que crea Job según una programación. | Puede ser usado por un atacante para persistir en el clúster, no solo para su finalidad prevista. | [16](16/es.md) |
| `CVE` | Identificador de una vulnerabilidad conocida públicamente. | CVE no equivale a explotación demostrada. | [06](06/es.md), [16](16/es.md) |
| `Data flow` | Ruta de transferencia de datos entre participantes de un sistema. | No equivale a trust boundary, aunque la cruza. | [15](15/es.md) |
| `Default deny` | Política inicial que prohíbe el tráfico no permitido de forma explícita. | No equivale a prohibir todo acceso a la API. | [13](13/es.md) |
| `default-deny` | Enfoque en el que se prohíbe el tráfico en la dirección elegida hasta que una política explícita lo permita. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [13](13/es.md) |
| `Defense in depth` | Combinación de capas de protección independientes. | No significa duplicar el mismo control. | [02](02/es.md), [05](05/es.md) |
| `Denial of Service` | Interrupción de la disponibilidad mediante agotamiento o sobrecarga de recursos. | No equivale a cualquier funcionamiento lento del sistema. | [16](16/es.md) |
| `Deployment` | Recurso Kubernetes para gestionar ReplicaSet y actualizaciones de Pod. | No es una frontera de seguridad independiente. | [02](02/es.md), [09](09/es.md) |
| `Detection` | Detección de un evento o desviación ya observados. | No evita un objeto antes de su creación. | [14](14/es.md), [18](18/es.md) |
| `Digest` | Identificador criptográfico del contenido concreto de un artefacto. | No demuestra el autor, la seguridad ni el origen. | [06](06/es.md), [17](17/es.md) |
| `distractor` | Opción de respuesta plausible pero incorrecta. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [20](20/es.md) |
| `Distroless` | Runtime image mínimo sin shell ni package manager habituales. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `DNS` | Servicio de resolución de nombres para servicios y direcciones externas. | No es un mecanismo de network segmentation. | [09](09/es.md) |
| `DoS` | Denegación de servicio por agotamiento o sobrecarga de recursos. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `Egress` | Tráfico de red saliente desde el Pod seleccionado. | No equivale al tráfico ingress hacia un Pod. | [13](13/es.md), [18](18/es.md) |
| `Encryption` | Protección criptográfica de datos mediante una clave. | No equivale a encoding reversible. | [04](04/es.md), [12](12/es.md) |
| `Encryption at rest` | Cifrado de datos almacenados, por ejemplo en etcd. | No protege una lectura de API por un sujeto con permisos. | [07](07/es.md), [12](12/es.md) |
| `Encryption in transit` | Cifrado de datos mientras se transmiten por la red. | No sustituye authorization ni segmentation. | [04](04/es.md), [18](18/es.md) |
| `EncryptionConfiguration` | Configuración de API Server para cifrar recursos API en etcd. | No es una política RBAC. | [12](12/es.md) |
| `Endpoint` | Dirección o punto de acceso de red a un servicio o componente. | No equivale a Kubernetes EndpointSlice en todos los contextos. | [04](04/es.md), [09](09/es.md) |
| `enforce` | Modo PSA que rechaza un `Pod` que infringe las reglas. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `envelope encryption` | Enfoque donde los datos se cifran con una clave de datos, protegida a su vez por una clave KMS. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [12](12/es.md) |
| `escalate` | Permiso RBAC especial para crear o modificar Role/ClusterRole con permissions que superan los permissions propios del caller. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [10](10/es.md) |
| `Etcd` | Almacén de estado del Kubernetes control plane. | No es API Server. | [07](07/es.md), [12](12/es.md) |
| `Evidence` | Prueba verificable del funcionamiento de un control o proceso. | No equivale al propio requisito de compliance. | [14](14/es.md), [19](19/es.md) |
| `Exploit` | Código o técnica que aprovecha una vulnerabilidad. | No toda vulnerability tiene un exploit conocido. | [16](16/es.md) |
| `External Secrets Operator` | Operador que sincroniza secretos desde un almacenamiento externo. | Tras la sincronización permanecen los riesgos de Kubernetes Secret. | [12](12/es.md) |
| `Falco` | Herramienta de runtime detection del comportamiento de contenedores y nodos. | No sustituye audit logging de solicitudes API. | [16](16/es.md), [18](18/es.md) |
| `Firewall` | Control de red que filtra tráfico en una frontera definida. | No equivale a NetworkPolicy dentro de Kubernetes. | [04](04/es.md) |
| `FQDN` | Nombre de dominio completo de un destino de red. | No es una dirección IP ni una identity. | [09](09/es.md), [18](18/es.md) |
| `Framework` | Estructura para evaluar riesgos, requisitos o cobertura de controls. | No es por sí mismo un control técnico. | [05](05/es.md), [19](19/es.md) |
| `Grafana` | Herramienta para visualizar paneles y alert basados en datos de observabilidad. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [18](18/es.md) |
| `gVisor` | Sandbox runtime que añade aislamiento entre el workload y el kernel del nodo. | No sustituye PSS, RBAC ni NetworkPolicy. | [05](05/es.md) |
| `hard multi-tenancy` | Aislamiento de tenants con fronteras sólidas, a menudo de infraestructura. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [05](05/es.md) |
| `Hash` | Resultado de una función hash utilizado para verificar la identidad de los datos. | No es una firma con verificación de autor. | [06](06/es.md), [17](17/es.md) |
| `HIPAA` | Régimen de protección de información médica en EE. UU. | No es un recurso Kubernetes. | [19](19/es.md) |
| `hostPath` | Volumen que monta una ruta del sistema de archivos del nodo de trabajo en un `Pod`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [09](09/es.md) |
| `Hubble` | Herramienta para observar flujos de red de Cilium. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [18](18/es.md) |
| `Identity` | Representación del sujeto en cuyo nombre se realiza una acción. | No equivale a un conjunto de permisos. | [10](10/es.md), [18](18/es.md) |
| `Image digest` | Digest que fija el contenido concreto de un image. | No equivale a un tag mutable. | [06](06/es.md), [17](17/es.md) |
| `Image policy` | Regla de admisión de un image según su origen, firma o propiedades. | No es un informe de scanner. | [17](17/es.md) |
| `image registry` | Almacén de container images y metadata relacionada. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [17](17/es.md) |
| `Image tag` | Etiqueta legible por personas de una imagen, que puede cambiarse. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `impersonate` | Permiso Kubernetes clásico para impersonation de otra identity; en v1.36 también existe beta ConstrainedImpersonation con verbs más restringidos. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [10](10/es.md) |
| `Incident response` | Preparación y acciones para detectar, contener y recuperarse tras un incidente. | No se limita a recopilar logs. | [14](14/es.md), [16](16/es.md) |
| `Ingress` | Tráfico de red entrante hacia el Pod seleccionado. | No equivale al objeto Ingress para enrutamiento HTTP. | [13](13/es.md), [18](18/es.md) |
| `Integrity` | Propiedad de los datos de mantenerse exactos y sin cambios no autorizados. | No equivale a confidentiality. | [02](02/es.md), [19](19/es.md) |
| `iptables` | Modo para implementar el redireccionamiento de tráfico de `Service` en `kube-proxy`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [08](08/es.md) |
| `IPVS` | Modo de balanceo de `Service` en `kube-proxy` que queda obsoleto desde Kubernetes v1.35. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [08](08/es.md) |
| `Isolation` | Limitación de la influencia de un sujeto o workload sobre otro. | Es más amplia que una sola network segmentation. | [05](05/es.md), [13](13/es.md) |
| `KCNA` | Kubernetes and Cloud Native Associate, certificación introductoria amplia sobre cloud native. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate, certificación conceptual sobre seguridad cloud native y Kubernetes. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `kill chain` | Modelo de secuencia de etapas de un ataque, desde el acceso inicial hasta el impacto. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md), [19](19/es.md) |
| `KMS` | Servicio o plugin para gestionar claves de cifrado. | No es el encryption provider de datos propiamente dicho. | [12](12/es.md) |
| `KMS v2` | API recomendada actual para integrar API Server con KMS; KMS v1 está deprecated desde v1.28 y desactivado de forma predeterminada desde v1.29. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [12](12/es.md) |
| `kube-apiserver` | Nombre completo del proceso API Server como componente del control plane. | No equivale a kubelet API ni kube-proxy. | [07](07/es.md) |
| `kube-bench` | Herramienta que compara la configuración de componentes Kubernetes con comprobaciones CIS Benchmark. | No evalúa la lógica de negocio de la aplicación ni sustituye una auditoría completa. | [05](05/es.md), [19](19/es.md) |
| `Kube-proxy` | Componente de nodo que configura reglas del kernel (`iptables`, `nftables`, IPVS) para enrutar a `Service`; no es en sí un userspace traffic proxy. | No aplica NetworkPolicy; no reenvía paquetes por sí mismo, lo hace el kernel. | [08](08/es.md) |
| `Kubeconfig` | Archivo con la dirección del clúster, CA de confianza y credenciales del cliente. | No es una configuración inocua sin secretos. | [09](09/es.md) |
| `Kubelet` | Agente de nodo que ejecuta Pod mediante container runtime. | No es scheduler. | [08](08/es.md) |
| `Kubelet API` | Interfaz HTTPS de Kubelet para operaciones y diagnóstico en el nodo. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [08](08/es.md) |
| `Kubernetes API` | Interfaz para gestionar recursos del clúster mediante API Server. | No equivale a kubelet API. | [07](07/es.md), [10](10/es.md) |
| `L3/L4/L7` | Niveles de control: red IP, puertos de transporte y protocolo de aplicación. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [13](13/es.md) |
| `lateral movement` | Movimiento de un atacante desde un recurso comprometido hacia otro recurso. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md), [16](16/es.md) |
| `Least privilege` | Concesión únicamente de los permisos mínimos necesarios. | No significa cero permisos para todos. | [02](02/es.md), [10](10/es.md) |
| `level` | Cantidad de datos de un evento: `None`, `Metadata`, `Request` o `RequestResponse`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [14](14/es.md) |
| `LimitRange` | Límites y valores predeterminados para contenedores en un namespace. | No define el presupuesto agregado del namespace, como ResourceQuota. | [11](11/es.md), [16](16/es.md) |
| `Log backend` | Receptor o almacén de logs. | No es por sí mismo la fuente de todos los eventos. | [14](14/es.md), [18](18/es.md) |
| `Logging` | Recopilación de registros discretos de eventos. | No equivale a monitoring ni a observability completa. | [14](14/es.md), [18](18/es.md) |
| `MCQ` | Multiple choice question - pregunta de opción múltiple, formato del examen KCSA. | No es lo mismo que una tarea hands-on en CKS. | [01](01/es.md), [20](20/es.md) |
| `Metric` | Medición numérica de un estado o comportamiento a lo largo del tiempo. | No contiene el contexto completo de un log. | [18](18/es.md) |
| `MITM` | Man-in-the-middle, interceptación o suplantación de un intercambio de red. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `MITRE ATT&CK` | Base de tácticas y técnicas del comportamiento de atacantes. | No es un preventive control. | [15](15/es.md), [19](19/es.md) |
| `MITRE ATT&CK for Containers` | Base de tácticas y técnicas que describen el comportamiento de atacantes en un entorno de contenedores. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md) |
| `mock exam` | Examen de práctica que imita el formato y el límite de tiempo. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [20](20/es.md) |
| `Monitoring` | Observación de indicadores y umbrales conocidos del sistema. | Es más limitado que observability. | [18](18/es.md) |
| `most appropriate` | Indicación de elegir la respuesta más directa y adecuada entre las aceptables por su significado. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [20](20/es.md) |
| `mTLS` | TLS con verificación mutua de las partes de la conexión. | No define una allowlist de flujos de red. | [18](18/es.md) |
| `Multi-stage build` | Compilación con un builder stage independiente y un final stage mínimo. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `multi-tenancy` | Uso de una plataforma por varios equipos u organizaciones con separación de acceso y recursos. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [13](13/es.md) |
| `multiple choice` | Pregunta con opciones de respuesta en la que se debe elegir la opción más correcta. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `Mutating admission webhook` | Webhook que puede modificar un objeto antes de almacenarlo. | No equivale a validating webhook, que solo acepta o rechaza. | [17](17/es.md) |
| `MutatingAdmissionPolicy` | Declarative admission policy integrada en CEL que modifica objetos API coincidentes sin un webhook independiente. | No equivale a un mutating admission webhook externo. | [17](17/es.md) |
| `Namespace` | Área lógica de Kubernetes para recursos, permisos y cuotas. | Por sí mismo no es un muro de red. | [05](05/es.md), [13](13/es.md) |
| `Network segmentation` | Separación de rutas de red entre zonas o workload. | No es idéntica a la isolation general. | [13](13/es.md), [18](18/es.md) |
| `NetworkPolicy` | Recurso API que describe el ingress y egress permitidos de un Pod. | No sustituye kube-proxy, RBAC ni TLS. | [13](13/es.md) |
| `nftables` | Modo de `kube-proxy`; en Linux compatible se recomienda como reemplazo de IPVS deprecated. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [08](08/es.md) |
| `Node` | Máquina de trabajo o control-plane de Kubernetes. | No equivale a un Pod. | [07](07/es.md), [08](08/es.md) |
| `Node authorization` | Mecanismo de autorización de solicitudes API desde kubelet. | No es un objeto Node. | [08](08/es.md), [10](10/es.md) |
| `Observability` | Capacidad de comprender el estado del sistema mediante logs, métricas y traces. | No se reduce a un único panel de monitoring. | [18](18/es.md) |
| `OIDC` | Protocolo de identificación para que API Server confíe en un issuer externo. | No es una autorización OAuth genérica de Kubernetes. | [10](10/es.md) |
| `OPA` | Policy engine de propósito general, usado con frecuencia mediante Gatekeeper. | No es una ValidatingAdmissionPolicy integrada. | [17](17/es.md) |
| `OpenID Connect` | Nombre completo de OIDC como capa de identificación sobre OAuth 2.0. | No sustituye una decisión RBAC. | [10](10/es.md) |
| `OWASP Kubernetes Top 10` | Catálogo de clases de riesgo Kubernetes frecuentes de OWASP (Open Worldwide Application Security Project, proyecto abierto de seguridad de aplicaciones web). | No es una lista de campos YAML obligatorios. | [05](05/es.md) |
| `PeerAuthentication` | Recurso Istio que define el modo de aceptación de mTLS para un service mesh o una parte de él. | `STRICT` requiere mTLS, pero no sustituye authorization ni NetworkPolicy. | [18](18/es.md) |
| `performance-based` | Formato que evalúa una acción práctica completada en un entorno, no solo una respuesta seleccionada. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `persistence` | Capacidad de un atacante de conservar acceso tras eliminarse el punto de entrada inicial. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `PKI` | Infraestructura de claves, certificados y cadenas de confianza. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [18](18/es.md) |
| `Pod` | Unidad desplegable más pequeña de Kubernetes con uno o varios contenedores. | No equivale a un container individual. | [09](09/es.md), [11](11/es.md) |
| `Pod Security Admission` | Mecanismo admission integrado para aplicar Pod Security Standards. | No es el PSP eliminado. | [11](11/es.md) |
| `Pod Security Standards` | Conjunto de niveles privileged, baseline y restricted para configuraciones de Pod. | No equivale a un admission plugin concreto. | [11](11/es.md) |
| `Policy` | Regla que define un comportamiento deseado o permitido. | No toda policy se enforce técnicamente por sí misma. | [13](13/es.md), [17](17/es.md) |
| `policy engine` | Mecanismo que aplica reglas a objetos API, a menudo en la ruta de admission. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [05](05/es.md) |
| `Private key` | Clave criptográfica secreta para firma o autenticación. | No debe publicarse junto con un certificate. | [09](09/es.md), [18](18/es.md) |
| `privileged` | Modo de contenedor con privilegios muy amplios respecto al host. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [09](09/es.md), [11](11/es.md) |
| `proctored` | Examen con supervisión del cumplimiento de reglas por parte de un proctor. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `proctoring` | Procedimiento controlado de realización del examen con supervisión conforme a las reglas del proveedor. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [20](20/es.md) |
| `Prometheus` | Sistema para recopilar y almacenar métricas. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [18](18/es.md) |
| `Provenance` | Registro del origen de un artefacto, sus fuentes y su proceso de creación. | No equivale a digest, signature ni SBOM. | [17](17/es.md), [19](19/es.md) |
| `PSA` | Pod Security Admission, controlador admission integrado que aplica PSS. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `PSP` | Mecanismo PodSecurityPolicy eliminado desde Kubernetes v1.25. | No es el reemplazo actual de PSA. | [11](11/es.md) |
| `PSS` | Pod Security Standards, los tres perfiles de seguridad estándar de `Pod`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `Public key` | Parte pública de un par de claves para verificar una firma o cifrar. | No debe almacenarse como private key. | [18](18/es.md) |
| `RBAC` | Autorización basada en roles y vinculaciones de sujetos a permisos. | No es authentication. | [10](10/es.md) |
| `RCE` | Remote code execution, ejecución de código remota mediante una vulnerabilidad. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [16](16/es.md) |
| `Registry` | Registro para almacenar y entregar container images. | No confirma automáticamente la seguridad de un image. | [06](06/es.md), [17](17/es.md) |
| `ResourceQuota` | Límite del consumo agregado de recursos en un namespace. | No define container bounds, como LimitRange. | [13](13/es.md), [16](16/es.md) |
| `restricted` | Perfil estricto de least privilege para workloads de aplicaciones. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `Risk` | Combinación de la probabilidad de un evento no deseado y sus consecuencias. | No equivale a threat ni vulnerability. | [15](15/es.md), [19](19/es.md) |
| `Role` | Conjunto de acciones API permitidas dentro de un namespace. | No concede permisos sin RoleBinding. | [10](10/es.md) |
| `Role / ClusterRole` | Conjunto de reglas en un namespace / a nivel de clúster. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [10](10/es.md) |
| `RoleBinding` | Vínculo de un subject con Role o ClusterRole en un namespace. | No es la autenticación en sí. | [10](10/es.md) |
| `RoleBinding / ClusterRoleBinding` | Vinculación de un rol a un usuario, grupo o `ServiceAccount`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [10](10/es.md) |
| `Runtime class` | Selección de una clase runtime para ejecutar un Pod. | No es runtime detection. | [05](05/es.md), [09](09/es.md) |
| `Runtime detection` | Detección del comportamiento de procesos después de iniciar un workload. | No sustituye audit logging de solicitudes API. | [16](16/es.md), [18](18/es.md) |
| `runtime socket` | Socket Unix mediante el que un cliente gestiona container runtime. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [08](08/es.md) |
| `Sandbox` | Frontera de ejecución reforzada para un workload no confiable. | No sustituye least privilege. | [05](05/es.md) |
| `SAST` | Análisis estático de código sin ejecutar la aplicación. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `SBOM` | Inventario de componentes y dependencias de un artefacto de software. | No equivale a signature ni provenance. | [06](06/es.md), [17](17/es.md) |
| `SCA` | Análisis de dependencias y de sus riesgos conocidos. | No equivale a un runtime scanner. | [06](06/es.md) |
| `Scheduler` | Componente que elige un nodo para un Pod nuevo. | No ejecuta contenedores en el nodo. | [07](07/es.md) |
| `Secret` | Objeto Kubernetes API para datos pequeños sensibles. | Base64 en `data` no es encryption. | [12](12/es.md) |
| `Secret scanning` | Búsqueda de credentials y otros secretos en código, historial y artefactos. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `SecurityContext` | Configuración de privilegios y restricciones de un proceso o Pod. | No sustituye PSS, RBAC ni NetworkPolicy. | [09](09/es.md), [11](11/es.md) |
| `Segmentation` | División del sistema en zonas con interacciones limitadas. | Es una forma de isolation, no su sinónimo completo. | [13](13/es.md), [15](15/es.md) |
| `Service identity` | Identidad de servicio: cuenta de un componente o workload con la que accede a la API. | No es la identidad de un operador humano. | [07](07/es.md) |
| `Service mesh` | Capa de infraestructura para connectivity de servicios, identity y con frecuencia mTLS. | No sustituye NetworkPolicy. | [18](18/es.md) |
| `ServiceAccount` | Identidad Kubernetes para procesos en Pod. | No concede permisos sin RBAC. | [10](10/es.md), [12](12/es.md) |
| `Shared responsibility` | Distribución de las responsabilidades de protección entre proveedor y cliente. | No significa que el proveedor proteja el workload del cliente. | [04](04/es.md) |
| `SIEM` | Sistema para centralizar y correlacionar eventos de security. | No es la fuente de eventos audit de API Server. | [14](14/es.md), [18](18/es.md) |
| `Signature` | Prueba criptográfica que vincula datos con una clave de firma. | No equivale a digest, SBOM ni provenance. | [06](06/es.md), [17](17/es.md) |
| `SLSA` | Framework de requisitos para la cadena de suministro con tracks Build y Source independientes. | No es un nombre universal para reproducible build. | [17](17/es.md), [19](19/es.md) |
| `SLSA v1.2` | Marco de requisitos con tracks Build y Source independientes; el nivel se indica junto con el track. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [17](17/es.md), [19](19/es.md) |
| `snapshot` | Copia de seguridad coherente del estado de `etcd` en un momento concreto. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [07](07/es.md) |
| `SOC 2` | Evaluación de controls de una organización de servicios según Trust Services Criteria. | No es un Kubernetes security standard. | [19](19/es.md) |
| `soft multi-tenancy` | Separación de equipos confiables en un clúster compartido mediante controls lógicos. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [05](05/es.md) |
| `Software supply chain` | Ruta del código, las dependencias, la compilación y la entrega hasta runtime. | No se limita a container registry. | [06](06/es.md), [17](17/es.md) |
| `SPIFFE` | Estándar de identidades de workload para sistemas distribuidos. | No es por sí mismo un certificado TLS. | [18](18/es.md) |
| `stage` | Momento de procesamiento de una solicitud: `RequestReceived`, `ResponseStarted`, `ResponseComplete` o `Panic`. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [14](14/es.md) |
| `STRIDE` | Framework de modelado de amenazas por seis categorías. | No es un registro de ataques reales. | [15](15/es.md), [19](19/es.md) |
| `Subject` | Usuario, grupo o ServiceAccount en cuyo nombre actúa una solicitud. | No equivale a Role ni permission. | [10](10/es.md) |
| `Supply chain` | Cadena de creación y entrega de un artefacto de software. | No equivale a una sola etapa de compilación. | [17](17/es.md), [19](19/es.md) |
| `Syscall` | Llamada del sistema de un proceso al kernel del SO. | No es una llamada Kubernetes API. | [16](16/es.md), [18](18/es.md) |
| `Tag` | Referencia legible por personas a una versión de image. | Puede ser mutable y no equivale a digest. | [06](06/es.md) |
| `Threat` | Posible causa o escenario de un evento no deseado. | No equivale a vulnerability ni a un risk evaluado. | [15](15/es.md), [16](16/es.md) |
| `Threat model` | Descripción de los activos, fronteras, flujos y amenazas de un sistema. | No es una lista de CVE. | [15](15/es.md), [19](19/es.md) |
| `TLS` | Protocolo de cifrado y autenticación de una conexión. | No sustituye NetworkPolicy ni authorization. | [07](07/es.md), [18](18/es.md) |
| `TLS termination` | Punto donde un componente termina TLS y descifra la conexión. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [18](18/es.md) |
| `Token` | Credencial presentada para authentication. | No equivale automáticamente a acceso RBAC restringido. | [10](10/es.md) |
| `Trace` | Recorrido vinculado de una solicitud a través de servicios distribuidos. | No equivale a un único registro log. | [18](18/es.md) |
| `Trust boundary` | Lugar donde cambian la confianza, los permisos o el control de datos. | No coincide necesariamente con un namespace. | [15](15/es.md) |
| `Trusted image` | Image con origen verificable y un conjunto de controles de confianza. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [06](06/es.md) |
| `Trusted registry` | Registry al que una política permite proporcionar images. | No demuestra la ausencia de CVE en un image. | [06](06/es.md), [17](17/es.md) |
| `ValidatingAdmissionPolicy` | Declarative admission policy integrada en CEL para validation de objetos API; de ámbito cluster, se aplica mediante `ValidatingAdmissionPolicyBinding` independiente. | No se encuentra «en un namespace»; el alcance del namespace se define mediante binding/`matchResources`. | [17](17/es.md) |
| `version-light` | Característica de un examen en el que importan los conceptos clave y no la vinculación a una versión de Kubernetes. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [01](01/es.md) |
| `Vulnerability` | Debilidad que puede aprovechar una threat o un exploit. | No equivale a threat ni risk. | [06](06/es.md), [16](16/es.md) |
| `Vulnerability scanner` | Herramienta que busca vulnerabilidades conocidas según datos de componentes. | No evita el comportamiento de runtime. | [06](06/es.md), [17](17/es.md) |
| `warn` | Modo PSA que muestra una advertencia al cliente sin rechazar la solicitud. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [11](11/es.md) |
| `Webhook` | Manejador HTTP invocado por Kubernetes u otro componente. | No todo webhook está relacionado con admission. | [10](10/es.md), [17](17/es.md) |
| `webhook backend` | Backend que envía eventos audit a un collector HTTPS o SIEM. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [14](14/es.md) |
| `Workload` | Aplicación en ejecución y el recurso Kubernetes que la gestiona. | No equivale a un único container image. | [03](03/es.md), [09](09/es.md) |
| `Zero trust` | Enfoque sin confianza implícita en la red, identity o ubicación. | No significa prohibir todas las interacciones. | [02](02/es.md), [18](18/es.md) |
| `frontera de confianza` | Punto de transición entre participantes o contextos con distintos niveles de confianza. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md) |
| `modelo de amenazas` | Descripción de activos, participantes, flujos, fronteras de confianza, amenazas y controles de un sistema. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md) |
| `flujo de datos` | Transferencia de una solicitud, estado o datos entre componentes. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [15](15/es.md) |
| `identidad de servicio (service identity)` | Cuenta de un componente con la que accede a Kubernetes API. | Aclare el término según el contexto; no lo sustituya por un concepto cercano. | [07](07/es.md) |

## Trampas léxicas

- [Authentication](10/es.md) establece la identity, [authorization](10/es.md) comprueba el permiso y [admission control](11/es.md) evalúa la admisibilidad del objeto después de las dos primeras etapas.
- [Audit logging](14/es.md) se ocupa de los eventos API, mientras que [runtime detection](18/es.md) se ocupa del comportamiento del proceso tras el inicio.
- [Encryption](12/es.md) requiere una clave para proteger datos; [Base64](12/es.md), solo encoding reversible.
- [Digest](06/es.md) fija el contenido, [signature](17/es.md) vincula los datos con una clave, [SBOM](17/es.md) enumera componentes y [provenance](17/es.md) describe el origen.
- [Isolation](13/es.md) abarca varias fronteras; [segmentation](13/es.md) las divide en zonas y rutas.
- [Control](05/es.md) reduce el riesgo; [framework](19/es.md) ayuda a seleccionar y evaluar controls.
- [Vulnerability](16/es.md) es una debilidad, [threat](15/es.md) es un escenario posible y [risk](19/es.md) es una evaluación de probabilidad y consecuencias.
- [Logging](18/es.md) guarda eventos, [monitoring](18/es.md) sigue indicadores conocidos y [observability](18/es.md) permite explicar el estado mediante señales diversas.
- [CIA triad](02/es.md) combina [confidentiality](12/es.md), [integrity](19/es.md) y [availability](16/es.md).

[Índice y ruta de preparación](README_ES.md)
