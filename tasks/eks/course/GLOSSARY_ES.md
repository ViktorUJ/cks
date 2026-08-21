[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glosario del curso EKS

[Índice del curso](README_ES.md)

Referencia alfabética unificada de los términos del curso. Los términos se conservan en inglés cuando AWS y Kubernetes los usan en inglés; las descripciones están en español. La columna «Capítulos» indica dónde se explica cada término. Busque en la página con Ctrl+F.

| Término | Descripción | Capítulos |
|--------|-------------|-----------|
| **ABAC / RBAC** | Acceso por etiquetas mediante `aws:PrincipalTag` frente a acceso por roles y políticas con acciones y recursos concretos. | [0.2](00-2-iam/es.md) |
| **Access entry** | Entrada de acceso del clúster que asocia un principal IAM con `username` y `kubernetesGroups`; `STANDARD` para personas y servicios, y tipos `EC2_LINUX`, `EC2_WINDOWS`, `FARGATE_LINUX`, `HYBRID_LINUX` o `EC2` para nodos. | [01](01/es.md), [05](05/es.md), [47](47/es.md) |
| **access entry de tipo `EC2_LINUX`** | Entrada que autoriza el ARN del rol de nodo en el clúster. | [45](45/es.md) |
| **access point** | Entrada a un subdirectorio de EFS con permisos e identidad POSIX propios; base del aprovisionamiento dinámico y el aislamiento de directorios. | [24](24/es.md) |
| **Access policy** | Política AWS administrada de permisos Kubernetes asociada a una access entry; contiene verbs y resources, no permisos IAM, y no se edita. | [05](05/es.md), [47](47/es.md) |
| **Access scope** | Ámbito de una access policy: `cluster` o `namespace` con una lista. | [05](05/es.md) |
| **ACM (AWS Certificate Manager)** | Certificados que viven en el balanceador; la clave no se exporta y la renovación es automática. | [27](27/es.md), [29](29/es.md) |
| **actions / conditions** | Anotaciones de acciones personalizadas (redirect, fixed-response, weighted forward) y condiciones de enrutamiento adicionales. | [27](27/es.md) |
| **Admission webhook** | Manejador externo invocado por apiserver antes de guardar el objeto en etcd; mutating lo modifica y validating solo lo admite o rechaza. | [22](22/es.md) |
| **ADOT** | AWS Distro for OpenTelemetry: distribución OTel de AWS con SDK, agentes y Collector. | [36](36/es.md) |
| **ALIAS** | Registro Route 53 hacia un recurso AWS, por ejemplo ELB; funciona en el apex del dominio y no se cobra como consulta independiente. | [29](29/es.md) |
| **Allocatable** | Recursos disponibles para pods tras `kube-reserved`, `system-reserved` y el umbral de evicción; es lo que usa el scheduler. | [14](14/es.md) |
| **`allowVolumeExpansion`** | Indicador de StorageClass que permite ampliar un volumen mediante el crecimiento del PVC. | [23](23/es.md) |
| **Amazon EKS** | Kubernetes administrado en AWS: AWS opera el control plane y usted opera los nodos y su entorno. | [01](01/es.md) |
| **Amazon Managed Grafana (AMG)** | Grafana administrado; conecta AMP como data source y usa IAM Identity Center para el acceso de usuarios. | [33](33/es.md) |
| **Amazon Managed Service for Prometheus (AMP)** | Backend administrado compatible con Prometheus: workspace, remote-write, PromQL y retención en AWS. | [33](33/es.md) |
| **amazon-cloudwatch-observability** | Add-on EKS administrado que instala CloudWatch agent y habilita Container Insights with enhanced observability. | [33](33/es.md) |
| **AMI (Amazon Machine Image)** | Plantilla de disco de una instancia; para nodos se emplea una AMI optimizada para EKS, con `kubelet`, `containerd` y bootstrap compatibles. | [0.4](00-4-ec2/es.md), [10](10/es.md) |
| **API Priority and Fairness** | Mecanismo Kubernetes que reparte la cuota de solicitudes concurrentes; al agotarse, el cliente recibe `429`. | [02](02/es.md) |
| **app-of-apps** | `Application` padre que despliega un conjunto de aplicaciones hijas. | [44](44/es.md) |
| **Application** | CRD de Argo CD que une una fuente Git con un clúster y namespace de destino. | [44](44/es.md) |
| **Application Load Balancer (ALB)** | Balanceador L7 HTTP/HTTPS con rutas por host y path, terminación TLS, WAF y autenticación; LBC lo crea desde Ingress. | [27](27/es.md) |
| **ApplicationSet** | Controlador Argo CD que genera `Application` desde una plantilla con generadores cluster, git o matrix. | [44](44/es.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`, dirección de un recurso. | [0.1](00-1-aws/es.md) |
| **`AssumeRoleWithWebIdentity`** | Operación STS que intercambia un web identity token por credenciales temporales de un rol IAM. | [16](16/es.md) |
| **auditID** | Identificador único de solicitud en el audit log; se comparte entre todos los stage de una operación. | [21](21/es.md) |
| **`authenticationMode`** | Modo de autenticación del clúster: `CONFIG_MAP`, `API_AND_CONFIG_MAP` o `API`; solo progresa hacia `API`. | [04](04/es.md), [05](05/es.md), [47](47/es.md) |
| **`authenticationSource`** | Origen de credenciales del volumen: `driver`, el rol común del controlador, o `pod`, el rol de ServiceAccount del pod. | [25](25/es.md) |
| **Availability Zone (AZ)** | Conjunto aislado de centros de datos de una región; dominio de fallo básico para distribuir réplicas. | [0.1](00-1-aws/es.md), [40](40/es.md) |
| **AWS Backup** | Servicio centralizado de copias de seguridad para EKS, EBS, EFS, S3 y otros recursos con planes y almacenes comunes. | [41](41/es.md) |
| **aws cli v2** | CLI principal de AWS; se configura en `~/.aws/config` y selecciona acceso con `--profile` o `AWS_PROFILE`. | [0.5](00-5-tools/es.md) |
| **AWS Control Tower** | Landing zone lista para usar de AWS con controls, detección de drift y account factory. | [0.1](00-1-aws/es.md) |
| **`aws eks get-token`** | Complemento `exec` de kubeconfig que genera un token STS presigned para entrar al clúster. | [47](47/es.md) |
| **AWS Gateway API Controller** | Controlador `aws-application-networking-k8s`, con GatewayClass `amazon-vpc-lattice`, que traduce Gateway API a objetos VPC Lattice. | [28](28/es.md) |
| **AWS Load Balancer Controller (Gateway API)** | Implementación con `controllerName` `gateway.k8s.aws/alb` para ALB L7 y `gateway.k8s.aws/nlb` para NLB L4. | [28](28/es.md) |
| **AWS Load Balancer Controller (LBC)** | Controlador que crea NLB para Service LoadBalancer y ALB para Ingress; se instala con Helm y requiere roles IAM. | [26](26/es.md) |
| **AWS Organizations** | Gestión multiaccount: jerarquía OU, SCP compartidas y facturación consolidada. | [0.1](00-1-aws/es.md), [32](32/es.md) |
| **AWS PrivateLink** | Acceso privado a servicios AWS o de otras cuentas mediante interface endpoint. | [31](31/es.md) |
| **AWS RAM (Resource Access Manager)** | Servicio para compartir recursos, como subnets, Transit Gateway y reglas Route 53 Resolver, con cuentas y la organización. | [0.1](00-1-aws/es.md), [32](32/es.md) |
| **`aws sts get-caller-identity`** | Comando «quién soy»: cuenta, ARN y userId. | [0.5](00-5-tools/es.md) |
| **AWS X-Ray** | Backend administrado de trazas: almacenamiento, service map, desglose de latencia y búsqueda. | [36](36/es.md) |
| **`aws-auth` ConfigMap** | Mecanismo heredado de mapeo en `kube-system` con `mapRoles` y `mapUsers`. | [05](05/es.md), [45](45/es.md), [47](47/es.md) |
| **aws-for-fluent-bit** | Imagen Fluent Bit compilada por AWS con complementos de salida a servicios AWS integrados. | [34](34/es.md) |
| **`aws-vault`** | Almacenamiento de credenciales en keychain y ejecución de comandos en una sesión temporal. | [0.5](00-5-tools/es.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | Elimina el SNAT de nodo del egress de pods con `true`; el tráfico a Internet pasa entonces solo por NAT gateway. | [07](07/es.md) |
| **`AWSTraceHeader`** | Atributo de sistema SQS para la cabecera de traza X-Ray; transporta el contexto por una frontera asíncrona. | [36](36/es.md) |
| **backend-protocol-version** | Protocolo de aplicación del target group: `HTTP1`, `HTTP2` o `GRPC`; permite a ALB usar gRPC y HTTP/2 hacia los pods. | [27](27/es.md) |
| **backup plan** | Plan de backup: calendario, retention, lifecycle y asociación de recursos. | [41](41/es.md) |
| **backup vault** | Almacén de recovery points con clave KMS y política de acceso; aquí se habilita Vault Lock. | [41](41/es.md) |
| **BackupStorageLocation (BSL)** | Ubicación de backups Velero, normalmente un bucket S3. | [42](42/es.md) |
| **bake period** | Pausa entre actualizar el control plane y los nodos; estos quedan en N-1 y el rollback sigue disponible. | [39](39/es.md) |
| **Basic / Enhanced scanning** | Modos de escaneo CVE de ECR: basic para paquetes SO y enhanced mediante Amazon Inspector para SO y lenguajes. | [20](20/es.md) |
| **behavior / stabilizationWindowSeconds** | Sección HPA que suaviza velocidad y oscilaciones del escalado mediante ventanas de estabilización y policies. | [35](35/es.md) |
| **bin packing** | Empaquetado de pods en nodos según sus requests. | [14](14/es.md) |
| **blue/green cluster** | Clúster nuevo en la versión objetivo junto al antiguo, con migración de cargas y cambio de tráfico. | [03](03/es.md), [38](38/es.md) |
| **bootstrap.sh** | Script de configuración de kubelet en AL2 desde user data. | [45](45/es.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | Campo de acceso al crear el clúster; con `true`, valor predeterminado, el creador recibe permisos de administrador. | [04](04/es.md), [05](05/es.md) |
| **Bottlerocket** | SO mínimo para contenedores: raíz de solo lectura, actualización por imagen y administración por API en vez de SSH abierto. | [10](10/es.md) |
| **Burstable (serie T)** | Fracción base de CPU más CPU credits; no es apropiado para nodos de producción. | [0.4](00-4-ec2/es.md) |
| **Capacity** | Capacidad total de una instancia en CPU, memoria y pods. | [14](14/es.md) |
| **Capacity Blocks** | Reserva de capacidad GPU o Trainium para entrenamiento. | [0.4](00-4-ec2/es.md) |
| **capacity type** | Tipo de capacidad del nodo, `spot` u `on-demand`; etiquetas `karpenter.sh/capacity-type` y `eks.amazonaws.com/capacityType`. | [13](13/es.md) |
| **CapacityProvisioned** | Anotación del pod con la combinación real de vCPU y memoria tras el redondeo; determina el coste. | [15](15/es.md) |
| **cert-manager** | Controlador que emite certificados dentro del clúster como `Secret`; la fuente se define con ClusterIssuer o Issuer. | [29](29/es.md) |
| **CFS throttling** | Ralentización de un contenedor al superar su CPU limit. | [14](14/es.md) |
| **chargeback** | El coste real se imputa al presupuesto del equipo. | [43](43/es.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | CRD de Cilium con reglas L7 y FQDN y ámbito de clúster. | [08](08/es.md), [30](30/es.md) |
| **CloudTrail** | Registro de llamadas API AWS; para EKS registra operaciones sobre el clúster como recurso AWS, no eventos internos de Kubernetes. | [21](21/es.md) |
| **CloudWatch Application Signals** | APM sobre OTel, con SLO, latencia y errores; se habilita mediante `amazon-cloudwatch-observability`. | [36](36/es.md) |
| **CloudWatch Logs** | Almacén de logs AWS con log groups y log streams; se consulta con Logs Insights. | [34](34/es.md) |
| **CloudWatch Logs Insights** | Lenguaje de consultas de logs con `fields`, `filter`, `sort` y `stats`; herramienta principal para audit logs. | [21](21/es.md) |
| **Cluster Autoscaler (CA)** | Autoscaler de nodos sobre Auto Scaling group: ajusta `desiredSize` por pods no programables y subutilización. | [11](11/es.md) |
| **cluster creator admin** | Principal IAM que creó el clúster y recibe automáticamente acceso administrativo. | [47](47/es.md) |
| **Cluster endpoint** | Dirección de Kubernetes API del clúster; el endpoint público se restringe por CIDR y el privado es accesible desde la VPC. | [01](01/es.md), [02](02/es.md) |
| **Cluster insights** | Comprobaciones automáticas EKS: `UPGRADE_READINESS` para upgrade y `ROLLBACK_READINESS` para rollback durante 7 días. | [03](03/es.md), [38](38/es.md) |
| **Cluster security group** | Grupo creado automáticamente para el clúster, asociado a sus interfaces y a nodos managed node groups. | [02](02/es.md), [45](45/es.md) |
| **cluster version rollback** | Reversión del control plane EKS al minor anterior tras un upgrade in-place, dentro de 7 días y conservando etcd, cargas y volúmenes. | [03](03/es.md), [39](39/es.md) |
| **ClusterIssuer / Issuer** | Objetos cert-manager que describen la fuente de certificados para todo el clúster o para un namespace. | [29](29/es.md) |
| **ClusterMesh** | Unión de Pod Network de varios clústeres Cilium mediante `clustermesh-apiserver`; requiere `cluster-id` únicos y PodCIDR no solapados. | [08](08/es.md) |
| **CMK (customer managed key)** | Clave KMS propia que permite controlar su política y auditar descifrados en CloudTrail. | [18](18/es.md) |
| **CNI chaining** | Modo donde VPC CNI asigna direcciones e interfaces y Cilium añade políticas y observabilidad; `aws-node` se mantiene. | [08](08/es.md), [30](30/es.md) |
| **`cni-metrics-helper`** | Componente que recoge `awscni_*` de pods `aws-node` y envía agregados a CloudWatch. | [06](06/es.md) |
| **composite recovery point** | Punto compuesto de EKS que agrupa el estado del clúster y backups de volúmenes como una unidad. | [41](41/es.md) |
| **Compute Savings Plans** | Compromiso horario de gasto durante 1 o 3 años a cambio de descuento, flexible entre familias, región y Fargate/Lambda. | [43](43/es.md) |
| **Compute SP / EC2 Instance SP** | Plan flexible para EC2, Fargate y Lambda / plan con mayor descuento para una familia en una región. | [0.4](00-4-ec2/es.md) |
| **configurationValues** | Campo del add-on para configuración declarativa sin editar manifiestos manualmente. | [37](37/es.md) |
| **connection draining** | Drenaje de conexiones activas al desregistrar un target; `deregistration_delay.timeout_seconds` es 300 por defecto. | [40](40/es.md) |
| **conntrack** | Tabla de conexiones del kernel del nodo; si se llena, se descartan conexiones nuevas. | [46](46/es.md) |
| **Consolidated billing** | Factura única de la organización; descuentos por volumen y Savings Plans se aplican a todas las cuentas. | [0.1](00-1-aws/es.md) |
| **Consolidation** | Compactación voluntaria para reducir coste, con políticas `WhenEmpty` y `WhenEmptyOrUnderutilized` y el parámetro `consolidateAfter`. | [11](11/es.md), [12](12/es.md) |
| **Container Insights** | Monitorización de EKS con CloudWatch: el agente recoge métricas de nodos y pods, dashboards y alarmas. | [33](33/es.md) |
| **ContainerResource** | Métrica HPA de utilización de un solo contenedor, útil cuando un sidecar distorsiona la métrica de la aplicación. | [35](35/es.md) |
| **context propagation** | Paso de `trace id` entre servicios mediante cabeceras W3C Trace Context para que la traza no se corte. | [36](36/es.md) |
| **continuous profiling** | Recopilación continua de hotspots de CPU y memoria en código; por ejemplo CodeGuru Profiler, Pyroscope o Parca. | [36](36/es.md) |
| **Control plane** | API server, scheduler, controller manager y etcd; en EKS viven en la cuenta AWS, fuera de su VPC, y no aparecen en `kubectl get pods -n kube-system`. | [01](01/es.md) |
| **control plane logging** | Entrega de logs EKS `api`, `audit`, `authenticator`, `controllerManager` y `scheduler` a CloudWatch Logs. | [34](34/es.md) |
| **core add-ons** | `vpc-cni`, `kube-proxy` y `coredns`: núcleo obligatorio instalado en cada clúster. | [37](37/es.md) |
| **cost allocation** | Distribución del coste AWS a objetos Kubernetes, como namespace, Deployment o label, por consumo o requests. | [43](43/es.md) |
| **cost allocation tags** | Etiquetas AWS para desglosar la factura; las etiquetas personalizadas se activan en Billing. | [43](43/es.md) |
| **Cost and Usage Report** | Facturación detallada AWS en S3; Athena permite contrastar la asignación de OpenCost/Kubecost con la factura. | [43](43/es.md) |
| **Cost Anomaly Detection** | Servicio AWS de detección ML de aumentos anómalos de gasto, con alertas por email o SNS. | [43](43/es.md) |
| **crash-consistent / application-consistent** | Snapshot sin detener escrituras / snapshot coordinado a nivel de aplicación; AWS Backup para EKS solo ofrece el primero. | [41](41/es.md) |
| **Cross-account ENI** | Interfaces que EKS crea en sus subnets para conectar el control plane con nodos, kubelet API, webhooks y OIDC. | [02](02/es.md) |
| **cross-AZ traffic** | Transferencia de datos entre zonas de disponibilidad; suele cobrarse en ambas direcciones. | [31](31/es.md) |
| **cross-zone load balancing** | Modo que distribuye tráfico entre targets de todas las zonas; nivela carga pero aumenta tráfico cross-AZ. | [31](31/es.md) |
| **Custom networking** | Modo donde ENI secundarias y direcciones de pod proceden de la subnet y security groups de `ENIConfig`, seleccionadas por `ENI_CONFIG_LABEL_DEF`. | [07](07/es.md) |
| **custom.metrics.k8s.io** | API de métricas personalizadas de objetos del clúster para HPA. | [35](35/es.md) |
| **Data Firehose** | Búfer y enrutador administrado de flujos hacia S3, OpenSearch y otros destinos. | [34](34/es.md) |
| **Data plane** | Sus nodos y todo lo que se ejecuta en ellos. | [01](01/es.md) |
| **Delegated administrator** | Cuenta de organización que administra GuardDuty/Security Hub y ve los findings de todos los miembros. | [0.1](00-1-aws/es.md), [21](21/es.md) |
| **`deletionProtection`** | Indicador que prohíbe eliminar el clúster. | [04](04/es.md) |
| **deprecated / removed API** | Un `apiVersion` se declara obsoleto y después se elimina; tras ello, los manifiestos no se aplican. | [38](38/es.md) |
| **describe-addon-versions** | Operación EKS API con versiones de add-on, compatibilidad con minor Kubernetes y `defaultVersion`. | [37](37/es.md) |
| **`describe-target-health`** | Comando que muestra estado y causa de los targets de un target group. | [46](46/es.md) |
| **Digest** | Hash `sha256` del contenido de una imagen; un identificador inmutable que garantiza desplegar el artefacto construido. | [20](20/es.md) |
| **Disruption budget** | Límite a la tasa de interrupciones voluntarias, por número o proporción de nodos, ventanas según `schedule` y `duration`, y razones `reasons`. | [12](12/es.md) |
| **DNS-01** | Método ACME para verificar la propiedad de un dominio mediante un registro TXT; cert-manager lo crea en Route 53. | [29](29/es.md) |
| **Drift** | Diferencia de un nodo respecto al estado deseado, por nueva AMI, selectores o `requirements`; precede a consolidation. | [12](12/es.md) |
| **Dual-stack** | VPC y subnets con IPv4 e IPv6 (`/56` y `/64`); IPv6 elimina la escasez de direcciones para pods. | [0.3](00-3-vpc/es.md) |
| **EBS / instance store** | Volumen de red en una AZ / NVMe local efímero. | [0.4](00-4-ec2/es.md) |
| **EBS CSI driver** | `aws-ebs-csi-driver`, add-on administrado con provisioner `ebs.csi.aws.com` que gestiona volúmenes EBS. | [23](23/es.md) |
| **EC2NodeClass** | CRD `karpenter.k8s.aws/v1` con configuración AWS: AMI, rol IAM, subnets, SG, discos e IMDS. | [12](12/es.md) |
| **ECR** | Registro administrado de imágenes OCI de AWS, privado por cuenta-región en `<account-id>.dkr.ecr.<region>.amazonaws.com` o público en `public.ecr.aws`. | [20](20/es.md) |
| **EFS** | Amazon Elastic File System, NFS regional administrado con capacidad elástica y modo ReadWriteMany. | [24](24/es.md) |
| **EFS CSI driver** | `aws-efs-csi-driver`, add-on administrado con provisioner `efs.csi.aws.com` sobre un sistema de archivos existente. | [24](24/es.md) |
| **EKS audit log** | Log de control plane `audit`, con eventos JSON Kubernetes: quién, verb, recurso, origen y resultado. | [21](21/es.md) |
| **EKS authenticator** | Webhook del control plane que valida un token STS presigned y asigna una identidad IAM a un sujeto Kubernetes. | [47](47/es.md) |
| **EKS Auto Mode** | Modo en que AWS gestiona nodos appliance, escalado Karpenter y red, DNS, EBS CSI y ELB integrados. | [01](01/es.md), [09](09/es.md) |
| **EKS Cluster State** | Manifiestos de objetos Kubernetes, como Secret, ConfigMap, StatefulSet, PVC, RBAC y CRD, más configuración del clúster. | [41](41/es.md) |
| **EKS Pod Identity** | Entrega de un rol IAM a un pod mediante agente de nodo y API EKS, sin proveedor OIDC ni trust policy específica del clúster. | [17](17/es.md), [47](47/es.md) |
| **EKS Pod Identity Agent** | Add-on `eks-pod-identity-agent` como `DaemonSet` que entrega credenciales temporales por un endpoint local. | [17](17/es.md) |
| **AMI optimizada para EKS** | Imagen AWS con componentes de nodo compatibles; familias AL2023, Bottlerocket, Windows y AL2 en retirada. | [10](10/es.md) |
| **eksctl** | CLI oficial de EKS, imperativa y basada en CloudFormation. | [0.5](00-5-tools/es.md) |
| **enableNetworkPolicy** | Parámetro del add-on VPC CNI que habilita enforcement de NetworkPolicy estándar. | [30](30/es.md) |
| **Encryption at rest** | Cifrado de capas ECR: SSE-S3 por defecto u opcionalmente SSE-KMS con la clave `aws/ecr` o una clave propia; se fija al crear el repositorio. | [20](20/es.md) |
| **endpoint service** | Publicación de un servicio propio detrás de NLB como destino PrivateLink para consumidores de otras VPC y cuentas. | [31](31/es.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | Indicadores booleanos de acceso al endpoint, con valores predeterminados `true` y `false`. | [02](02/es.md) |
| **enforcer** | Componente CNI que convierte NetworkPolicy en filtros de tráfico reales; EKS no lo incluye hasta habilitarlo. | [30](30/es.md) |
| **Enhanced subnet discovery** | Subnets con etiqueta `kubernetes.io/role/cni=1` sin `ENIConfig`. | [07](07/es.md) |
| **ENI** | Elastic network interface; el número de ENI y direcciones IPv4 por ENI depende del tipo de instancia. | [0.3](00-3-vpc/es.md), [06](06/es.md) |
| **Envelope encryption** | Cifrado con dos claves: DEK cifra los datos y KEK KMS cifra la DEK; EKS lo usa para secretos etcd. | [18](18/es.md) |
| **ephemeral ports** | Rango alto `1024-65535` para tráfico de respuesta; debe permitirse explícitamente en NACL. | [46](46/es.md) |
| **eviction threshold** | Reserva de memoria por debajo de la cual kubelet expulsa pods. | [14](14/es.md) |
| **exec plugin de kubeconfig** | Sección `exec` que llama a `aws eks get-token`; no deja token persistente y `client-go` guarda en caché las credenciales hasta `status.expirationTimestamp`. | [0.5](00-5-tools/es.md) |
| **Expander** | Estrategia Cluster Autoscaler para elegir node group: `least-waste`, `priority`, `most-pods` o `random`. | [11](11/es.md) |
| **Extended support** | Fase posterior a standard support: la versión sigue admitida, con mayor tarifa horaria; está activa por defecto. | [03](03/es.md), [38](38/es.md) |
| **External Secrets Operator (ESO)** | Controlador que lee un secreto AWS y crea un `Secret` nativo mediante `SecretStore`/`ClusterSecretStore` y `ExternalSecret`. | [18](18/es.md) |
| **external-dns** | Controlador que sincroniza registros DNS del proveedor con objetos Kubernetes; en AWS usa Route 53. | [29](29/es.md) |
| **external.metrics.k8s.io** | API de métricas externas, como colas o tópicos, para HPA tipo External. | [35](35/es.md) |
| **externalTrafficPolicy** | Política Service: `Cluster`, reenvío a cualquier nodo con SNAT, o `Local`, solo pods locales y conservación de IP cliente. | [26](26/es.md) |
| **`failed to assign an IP address to container`** | VPC CNI no pudo dar una IP al pod porque faltan direcciones en el nodo o subnet. | [46](46/es.md) |
| **failurePolicy** | Reacción ante webhook inaccesible: `Fail` detiene admission e `Ignore` deja pasar el objeto. | [22](22/es.md) |
| **Fargate** | Ejecución de un pod en una micro-VM dedicada sin nodos; no admite DaemonSet, privilegios, `HostNetwork`, GPU ni acceso al nodo. | [09](09/es.md) |
| **fargate-scheduler** | Scheduler EKS junto a kube-scheduler que dirige a Fargate los pods que coinciden con un perfil. | [15](15/es.md) |
| **Fargate profile** | Objeto de clúster con selectores, pod execution role y subnets privadas que determina qué pods usan Fargate; solo se recrea. | [15](15/es.md) |
| **Finding** | Hallazgo GuardDuty, enviado a Security Hub y EventBridge para alertas y respuesta. | [21](21/es.md) |
| **Fluent Bit** | Forwarder ligero de logs en C, desplegado como DaemonSet; lee, enriquece y envía registros. | [34](34/es.md) |
| **Forbidden (403)** | Fallo de autorización: RBAC no permite la acción. | [47](47/es.md) |
| **game day** | Ejercicio que prueba de forma práctica DR y escenarios de incidentes. | [48](48/es.md) |
| **Gatekeeper** | Policy engine sobre OPA con reglas Rego y modelo `ConstraintTemplate` más `Constraint`. | [22](22/es.md) |
| **Gateway** | Punto de entrada con listeners de protocolo, puerto y TLS; pertenece al equipo de plataforma. | [28](28/es.md) |
| **Gateway API** | Estándar Kubernetes de gestión de tráfico, sucesor de Ingress, con recursos tipados y roles separados. | [28](28/es.md) |
| **gateway endpoint** | Tipo de VPC endpoint para S3 y DynamoDB mediante una entrada route table; es gratuito. | [25](25/es.md), [31](31/es.md) |
| **GatewayClass** | Plantilla de implementación con `controllerName`; define qué controlador procesa un Gateway. | [28](28/es.md) |
| **GitOps** | Modelo donde Git describe el estado deseado y un agente reconcilia continuamente el clúster. | [44](44/es.md) |
| **GitOps Toolkit** | Conjunto de controladores Flux: source, kustomize, helm, image y otros. | [44](44/es.md) |
| **Golden image** | Imagen personalizada reproducible construida sobre una AMI optimizada con image builder. | [10](10/es.md) |
| **graceful node shutdown** | Función kubelet que termina pods respetando grace period durante el apagado del SO. | [40](40/es.md) |
| **Grafana Loki** | Almacén de logs que indexa solo etiquetas del flujo, comprime chunks en object storage y consulta con LogQL. | [34](34/es.md) |
| **`granted` (`assume`)** | Cambio rápido de perfiles SSO y acceso a la consola. | [0.5](00-5-tools/es.md) |
| **Graviton** | Procesadores AWS arm64, con sufijo `g`, que requieren imágenes multi-arch. | [0.4](00-4-ec2/es.md) |
| **GuardDuty EKS Protection** | Análisis de EKS audit logs para amenazas mediante un flujo GuardDuty independiente. | [21](21/es.md) |
| **GuardDuty Runtime Monitoring** | Observación eBPF de procesos, red y archivos mediante `aws-guardduty-agent`; no admite Fargate ni Hybrid Nodes. | [21](21/es.md) |
| **Hard multi-tenancy** | Tenants en clústeres o cuentas separados; límite fuerte a cambio de mayor complejidad. | [22](22/es.md) |
| **HashiCorp Vault** | Almacén externo de secretos, alternativa a Secrets Manager, con autenticación Kubernetes, JWT/OIDC o AWS IAM auth. | [18](18/es.md) |
| **head-based y tail-based sampling** | Decisión de registrar al inicio de la petición / en gateway tras ensamblar la traza. | [36](36/es.md) |
| **helmfile** | Descripción declarativa de releases Helm, versiones y values en un solo archivo. | [0.5](00-5-tools/es.md) |
| **hop limit (`httpPutResponseHopLimit`)** | Número de saltos de red para la respuesta IMDS; con 1, el pod no alcanza IMDS y el nodo sí. | [19](19/es.md) |
| **hosted zone** | Contenedor Route 53 de registros DNS de un dominio, público o privado asociado a VPC. | [29](29/es.md) |
| **HPA (HorizontalPodAutoscaler)** | Controlador que cambia las réplicas de un Deployment según una métrica. | [35](35/es.md) |
| **HTTPRoute** | Reglas hacia backend por host, path y cabeceras; referencia Gateway mediante `parentRefs`. | [28](28/es.md) |
| **hub-and-spoke** | Topología con Transit Gateway central y VPC de equipos conectadas como spokes. | [32](32/es.md) |
| **Hubble** | Subsistema de observabilidad Cilium con mapa de flujos y verdict por flujo. | [08](08/es.md), [30](30/es.md) |
| **IAM Access Analyzer** | Encuentra entidades externas de confianza en políticas resource-based y trust policy. | [0.2](00-2-iam/es.md) |
| **IAM auth policy** | Política IAM para autorizar tráfico entre servicios; en el controlador es el recurso `IAMAuthPolicy`. | [28](28/es.md) |
| **IAM database authentication** | Acceso a RDS o Aurora con token temporal `aws rds generate-db-auth-token` en lugar de contraseña. | [18](18/es.md) |
| **IAM Identity Center** | Inicio de sesión único y provisión de acceso mediante permission sets. | [0.1](00-1-aws/es.md) |
| **IAM OIDC identity provider** | Objeto IAM que registra la URL issuer del clúster y al que apuntan trust policies de roles. | [16](16/es.md) |
| **IAM role** | Identidad sin claves permanentes, asumida temporalmente. | [0.2](00-2-iam/es.md) |
| **IAM user / group** | Identidad de larga duración y conjunto de tales identidades; se evitan en producción. | [0.2](00-2-iam/es.md) |
| **idle capacity** | Diferencia entre capacidad de nodos pagada y realmente consumida; indica requests excesivos o mal bin packing. | [43](43/es.md) |
| **image automation** | Controladores Flux que confirman nuevos tags de imágenes de vuelta a Git. | [44](44/es.md) |
| **IMDS** | Instance Metadata Service en `169.254.169.254`, fuente de metadatos y credenciales del rol de nodo; IMDSv1 no usa token e IMDSv2 usa `PUT` más token. | [0.2](00-2-iam/es.md), [0.4](00-4-ec2/es.md), [19](19/es.md) |
| **Parámetro immutable** | Parámetro de clúster que no cambia tras crearlo: `ipFamily`, `serviceIpv4Cidr`, VPC, nombre o rol IAM. | [04](04/es.md) |
| **In-place upgrade** | Actualización del mismo clúster al minor siguiente: control plane, add-ons y luego nodos. | [03](03/es.md), [38](38/es.md) |
| **in-tree cloud provider** | Código AWS integrado en Kubernetes que crea Classic Load Balancer para Service LoadBalancer. | [26](26/es.md) |
| **in-tree provisioner** | `kubernetes.io/aws-ebs` integrado y deprecated, sin `gp3` ni snapshots; el `gp2` predeterminado EKS aún lo usa. | [23](23/es.md) |
| **IngressClass alb** | Clase con controlador `ingress.k8s.aws/alb`; LBC procesa Ingress con `ingressClassName: alb`. | [27](27/es.md) |
| **IngressGroup** | Unión de varios Ingress por `group.name` en un ALB común; `group.order` define prioridad. | [27](27/es.md) |
| **INPUT / FILTER / OUTPUT** | Tres secciones de un pipeline Fluent Bit: lectura, procesamiento y envío. | [34](34/es.md) |
| **`InsufficientCidrBlocks`** | Error EC2 API por no haber bloques contiguos aunque haya direcciones libres. | [07](07/es.md) |
| **Interface endpoint** | VPC endpoint basado en PrivateLink: ENI en subnet, con tarifa horaria y por datos. | [31](31/es.md) |
| **Internet Gateway** | Puerta de enlace gratuita a Internet para direcciones públicas. | [0.3](00-3-vpc/es.md) |
| **involuntary disruption** | Interrupción no controlada, como fallo de nodo/AZ, OOM o spot; se mitiga con distribución, no con PDB. | [40](40/es.md) |
| **ipamd** | Demonio de `aws-node` que administra el pool de direcciones del nodo y crea ENI con EC2 API. | [06](06/es.md) |
| **`ipFamily`** | Familia de direcciones del clúster, definida solo en su creación. | [07](07/es.md) |
| **IRSA** | IAM Roles for Service Accounts: entrega de rol IAM a un pod a través de `ServiceAccount` y federación OIDC. | [0.2](00-2-iam/es.md), [16](16/es.md), [47](47/es.md) |
| **Karpenter** | Autoscaler de nodos que crea instancias EC2 directamente para pods no programables y selecciona tipos permitidos. | [11](11/es.md) |
| **KEDA** | Capa de escalado por eventos que alimenta métricas a HPA y lo administra. | [35](35/es.md) |
| **`kms:CreateGrant`** | Permiso necesario para montar un volumen con CMK propia; EBS cifra mediante grants y se requiere también en la key policy. | [23](23/es.md) |
| **krew** | Gestor de plugins con índice, `search`, `install` y `upgrade`; admite índices propios. | [0.5](00-5-tools/es.md) |
| **kube-prometheus-stack** | Chart Helm con Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter y kube-state-metrics. | [33](33/es.md) |
| **`kube-reserved` / `system-reserved`** | Recursos que kubelet reserva para Kubernetes y el SO. | [14](14/es.md) |
| **kube-state-metrics** | Componente que expone como métricas el estado de objetos Kubernetes: Pending, réplicas y reinicios. | [33](33/es.md) |
| **Kubecost** | Producto basado en OpenCost con UI, informes y recomendaciones; EKS ofrece un bundle optimizado. | [43](43/es.md) |
| **`kubectl plugin list`** | Lo que kubectl detecta en `PATH`. | [0.5](00-5-tools/es.md) |
| **`kubeProxyReplacement`** | Modo Cilium donde eBPF balancea Service/NodePort en lugar de kube-proxy; `true` habilita el reemplazo. | [08](08/es.md) |
| **Kustomization / HelmRelease** | CRD Flux que indica qué aplicar desde una fuente y dónde. | [44](44/es.md) |
| **Kyverno** | Policy engine donde las políticas son recursos YAML `ClusterPolicy`/`Policy` con reglas validate, mutate, generate y verifyImages; la reacción es `Enforce`/`Audit`. | [22](22/es.md) |
| **Landing zone** | Estructura multiaccount preconfigurada para management, servicios compartidos, entornos y equipos. | [0.1](00-1-aws/es.md), [32](32/es.md) |
| **Launch template** | Plantilla versionada de instancia: AMI, tipo, disco, SG, user data e IMDS; un managed node group siempre la usa. | [10](10/es.md) |
| **Launch template / Auto Scaling group** | Plantilla de lanzamiento versionada / grupo de instancias con `min`, `desired` y `max` en subnets AZ. | [0.4](00-4-ec2/es.md) |
| **Lifecycle policy** | Reglas de eliminación automática de imágenes por antigüedad o cantidad. | [20](20/es.md) |
| **limits** | Límite superior de consumo de un contenedor. | [14](14/es.md) |
| **log group / log stream** | Grupo, normalmente por aplicación, y flujo, normalmente por pod, en CloudWatch Logs. | [34](34/es.md) |
| **Managed / inline policy** | Política reutilizable y versionada / política integrada en un rol. | [0.2](00-2-iam/es.md) |
| **Managed add-on (EKS managed add-on)** | Componente de clúster mantenido por AWS, como VPC CNI, CoreDNS, kube-proxy o CSI, administrado por EKS API. | [0.5](00-5-tools/es.md), [01](01/es.md), [37](37/es.md) |
| **managed collector (scraper)** | Recolector AMP administrado sin agente que extrae métricas EKS y las escribe al workspace mediante remote-write. | [33](33/es.md) |
| **managed fields / server-side apply** | Mecanismo con el que un add-on declara y aplica sus campos; base para resolver conflictos. | [37](37/es.md) |
| **Managed node group** | Grupo EC2 gestionado por EKS: AWS mantiene ASG y launch template; usted mantiene el SO y contenido del nodo. | [01](01/es.md), [09](09/es.md) |
| **Management account** | Cuenta raíz pagadora; no se ejecutan cargas en ella. | [0.1](00-1-aws/es.md) |
| **`matchLabelKeys`** | Claves de etiquetas de pod añadidas a `labelSelector`; con `pod-template-hash`, el skew se calcula por revisión Deployment. | [40](40/es.md) |
| **max-pods** | Límite de pods por nodo: `ENI * (IP por ENI - 1) + 2`, limitado en managed node groups a 110 o 250. | [0.4](00-4-ec2/es.md), [06](06/es.md), [46](46/es.md) |
| **maxSkew** | Diferencia admitida de pods entre el dominio más lleno y el más vacío. | [40](40/es.md) |
| **`memory_limiter`** | Procesador Collector que limita memoria y rechaza datos en el umbral antes de caer en `OOMKilled`. | [36](36/es.md) |
| **metric_relabel_configs** | Sección scrape config, en ServiceMonitor `metricRelabelings`, que descarta métricas de alta cardinalidad (`drop` por `__name__`) y labels (`labeldrop`) antes de escribir y hacer remote-write. | [33](33/es.md) |
| **Metrics API (`metrics.k8s.io`)** | API Kubernetes de métricas de recursos actuales, fuente de `kubectl top` y HPA por resource metrics. | [33](33/es.md), [35](35/es.md) |
| **metrics-server** | Componente que recoge CPU y memoria de kubelet y los expone por Metrics API; no conserva historial. | [33](33/es.md) |
| **mount target** | Interfaz de red EFS en la subnet de una AZ; entrada para nodos de esa zona. | [24](24/es.md) |
| **Mountpoint for Amazon S3** | Cliente que expone objetos de bucket mediante interfaz de archivos; base del CSI driver. | [25](25/es.md) |
| **Mountpoint S3 CSI driver** | `aws-mountpoint-s3-csi-driver`, add-on administrado con provisioner `s3.csi.aws.com`; solo aprovisionamiento estático. | [25](25/es.md) |
| **must have** | Elemento sin el cual la salida a producción es peligrosa y debe bloquearse. | [48](48/es.md) |
| **NACL** | Filtro stateless a nivel de subnet; sus reglas de entrada y salida son independientes. | [46](46/es.md) |
| **namespace restore** | Restauración puntual de hasta cinco namespaces en un clúster existente, sin recursos cluster-scoped salvo PV relacionados. | [42](42/es.md) |
| **NAT Gateway** | Servicio AWS administrado de traducción de direcciones que da salida a Internet a subnets privadas. | [0.3](00-3-vpc/es.md), [31](31/es.md) |
| **`ndots:5`** | Opción resolv.conf de pods que hace probar search domains para nombres. | [46](46/es.md) |
| **nested (child) recovery point** | Punto anidado dentro de un composite recovery point: estado del clúster o volumen individual. | [41](41/es.md) |
| **Network ACL** | Filtro stateless de subnet, con allow y deny por números de regla. | [0.3](00-3-vpc/es.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | Aplicación de políticas al inicio de pod: `standard`, default allow con ventana sin políticas, o `strict`, default deny. | [08](08/es.md), [30](30/es.md) |
| **NetworkPolicy** | Objeto Kubernetes que declara ingress y egress permitidos para pods; no bloquea nada sin enforcer. | [30](30/es.md) |
| **nice to have** | Elemento que aumenta la madurez y puede completarse una vez en producción. | [48](48/es.md) |
| **NLB (Network Load Balancer)** | Balanceador L4 TCP/UDP de alto rendimiento y IP estáticas; LBC lo crea desde Service LoadBalancer. | [26](26/es.md) |
| **node instance role** | Rol IAM asumido por un nodo EC2; kubelet lo usa para llamar a AWS API. | [45](45/es.md) |
| **Node Termination Handler (NTH)** | Componente AWS para manejar interrupciones en nodos managed y self-managed sin Karpenter. | [13](13/es.md) |
| **nodeadm** | Inicializador de nodos en AL2023 y Bottlerocket que usa manifiesto YAML `NodeConfig` (`apiVersion: node.eks.aws/v1alpha1`); reemplaza `bootstrap.sh`. | [10](10/es.md), [45](45/es.md) |
| **NodeClaim** | Solicitud Karpenter de un nodo concreto que vincula `NodePool` y el `Node` real. | [12](12/es.md) |
| **NodeCreationFailure** | Health issue de managed node group: los nodos no se conectaron al clúster 15 minutos después de iniciar. | [45](45/es.md) |
| **NodeLocal DNSCache** | DNS de caché local de nodo que reduce carga en CoreDNS y throttling por ENI. | [46](46/es.md) |
| **NodePool** | CRD `karpenter.sh/v1` que define límites de nodos: `requirements`, `limits`, `weight`, labels/taints y disruption policy. | [12](12/es.md) |
| **NodePool y NodeClass** | Objetos que describen qué nodos crear y cómo; en Auto Mode los predeterminados son inmutables. | [09](09/es.md) |
| **non-destructive restore** | Modo que no sobrescribe objetos existentes sino que los omite; las omisiones se ven por SNS. | [42](42/es.md) |
| **NotReady con kubelet activo** | Normalmente el CNI no está listo y los pods no reciben IP. | [45](45/es.md) |
| **OIDC issuer URL** | Endpoint OIDC público del clúster (`oidc.eks.<region>.amazonaws.com/id/`) con claves públicas para firmar projected tokens. | [16](16/es.md) |
| **On-demand / Spot** | Pago por uso / capacidad con descuento que puede interrumpirse con aviso de dos minutos. | [0.4](00-4-ec2/es.md) |
| **OOMKilled** | El kernel mata un contenedor por superar su memory limit. | [14](14/es.md) |
| **OpenCost** | Estándar y motor abierto, neutral respecto a proveedores, para asignar costes desde Prometheus y precios AWS. | [43](43/es.md) |
| **OpenSearch Service** | OpenSearch administrado para búsqueda de texto completo y dashboards; se cobra por clúster. | [34](34/es.md) |
| **OpenTelemetry (OTel)** | Estándar CNCF de API, SDK y protocolo comunes que separa instrumentación y backend. | [36](36/es.md) |
| **OpenTelemetry Collector** | Recolector: receivers reciben, processors procesan y exporters envían telemetría a backends. | [36](36/es.md) |
| **OpenTelemetry Operator** | Operador que habilita auto-instrumentación inyectando el agente en el pod. | [36](36/es.md) |
| **OpenTofu** | Fork abierto de terraform compatible con módulos del curso; se selecciona con `terraform_binary = "tofu"`. | [0.5](00-5-tools/es.md) |
| **OTLP** | Protocolo para transferir telemetría de aplicación a collector y entre collectors. | [36](36/es.md) |
| **OU** | Grupo de cuentas al que se aplican políticas. | [0.1](00-1-aws/es.md) |
| **ownership** | Responsabilidad asignada sobre un dominio o elemento de checklist. | [48](48/es.md) |
| **Permissions boundary** | Techo de permisos de un rol o usuario; no concede permisos. | [0.2](00-2-iam/es.md) |
| **Placement group** | Control de colocación de instancias: `cluster`, `partition` o `spread`. | [0.4](00-4-ec2/es.md) |
| **`placementGroupSelector`** | Campo `NodeClass` que elige placement group por nombre o id; el pod la elige por `nodeSelector` y la etiqueta `eks.amazonaws.com/placement-group-id`. | [09](09/es.md), [12](12/es.md) |
| **Platform version** | Nivel patch y capacidades del control plane EKS dentro de un minor Kubernetes, formato `eks.<n>`, actualizado por AWS. | [01](01/es.md), [02](02/es.md) |
| **pluto / kube-no-trouble (kubent)** | Herramientas para localizar API obsoletas: pluto en Git/Helm y kubent en un clúster activo. | [38](38/es.md) |
| **Pod execution role** | Rol IAM con el que `kubelet` Fargate registra el pod y obtiene imágenes ECR; también escribe logs mediante el router integrado. | [15](15/es.md) |
| **Pod Identity association** | Registro EKS API que asocia `clúster + namespace + ServiceAccount` a un rol IAM; se crea con `aws eks create-pod-identity-association`. | [17](17/es.md), [37](37/es.md) |
| **pod readiness gate** | Condición adicional de disponibilidad del pod; LBC mantiene `target-health.elbv2.k8s.aws` en falso hasta que el target sea `healthy`. | [40](40/es.md) |
| **Pod Security Admission (PSA)** | Controlador admission integrado que aplica Pod Security Standards en namespace mediante labels; sustituye Pod Security Policies. | [19](19/es.md) |
| **Pod Security Standards** | Perfiles privileged, baseline y restricted, este último estricto para producción. | [19](19/es.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | `strict` sin source NAT frente a `standard`, donde tráfico fuera de VPC usa primary ENI y reglas SG del nodo. | [46](46/es.md) |
| **PodDisruptionBudget (PDB)** | Objeto que limita pods expulsados simultáneamente en interrupciones voluntarias mediante `minAvailable`/`maxUnavailable`. | [40](40/es.md) |
| **`pods.eks.amazonaws.com`** | Service principal en trust policy de Pod Identity, común a clústeres y cuentas; EKS Auth API emite las credenciales mediante `AssumeRoleForPodIdentity`. | [17](17/es.md) |
| **Policy** | JSON con `Version`, `Statement`, `Effect`, `Action`, `Resource` y `Condition`; puede ser identity-based o resource-based. | [0.2](00-2-iam/es.md) |
| **Policy engine** | Admission webhook con reglas propias, como Kyverno o Gatekeeper, que valida o modifica objetos antes de etcd. | [22](22/es.md) |
| **`pollingInterval` y `cooldownPeriod`** | Periodo de sondeo KEDA, por defecto `30 s`, y espera antes de bajar a cero, por defecto `300 s`; este último solo aplica a scale-to-zero. | [35](35/es.md) |
| **Prefix delegation** | Modo donde un slot ENI usa un prefijo `/28` de 16 direcciones; requiere Nitro y `ENABLE_PREFIX_DELEGATION`. | [07](07/es.md), [46](46/es.md) |
| **preserve_client_ip** | Atributo target group NLB que controla conservar la IP de origen en modo `ip`. | [26](26/es.md) |
| **preStop** | Hook ejecutado antes de SIGTERM, usado para pausar antes de detenerse. | [40](40/es.md) |
| **Principal** | Quien realiza la solicitud: usuario, rol o servicio AWS. | [0.2](00-2-iam/es.md) |
| **private / public endpoint** | Modo de acceso al API server del clúster. | [45](45/es.md) |
| **Private hosted zone** | Zona Route 53 creada por EKS y asociada a su VPC para resolver el nombre del endpoint a una dirección privada. | [02](02/es.md) |
| **Projected service account token** | JWT compatible OIDC con identidad SA, audience `sts.amazonaws.com` y vida limitada, montado en el pod para intercambiar en STS. | [16](16/es.md) |
| **prometheus-adapter** | Adaptador que publica métricas Prometheus en custom/external API. | [35](35/es.md) |
| **provisioningMode: efs-ap** | Modo StorageClass donde el driver crea un access point por PVC. | [24](24/es.md) |
| **`publicAccessCidrs`** | Lista CIDR autorizada para el endpoint público; por defecto `0.0.0.0/0`. | [02](02/es.md) |
| **Pull through cache** | Regla ECR que guarda bajo demanda imágenes de un registro externo, como `registry.k8s.io`, en ECR privado. | [20](20/es.md) |
| **modelo pull** | El agente del clúster obtiene cambios desde Git; push usa un pipeline externo. | [44](44/es.md) |
| **Clase QoS** | `Guaranteed`, `Burstable` o `BestEffort`; define el orden de evicción ante falta de memoria. | [14](14/es.md) |
| **ReadWriteMany (RWX)** | Access mode donde muchos pods en muchos nodos montan simultáneamente el volumen en escritura. | [24](24/es.md) |
| **Rebalance recommendation** | Señal temprana de mayor riesgo de retirada que llega antes del aviso de dos minutos. | [13](13/es.md) |
| **recovery point** | Punto de recuperación, resultado de un backup job correcto. | [41](41/es.md) |
| **ReferenceGrant** | Recurso Gateway API en namespace del recurso de destino que permite referencias cross-namespace mediante `backendRefs` y `certificateRefs`. | [28](28/es.md) |
| **Replication configuration** | Reglas ECR que copian imágenes a otras regiones y cuentas; para cross-account, el destino autoriza `ecr:CreateRepository` y `ecr:ReplicateImage`. | [20](20/es.md) |
| **Repository creation template** | Plantilla de cifrado, lifecycle, immutability y policy para repositorios que ECR crea bajo pull through cache; sin ella reciben `MUTABLE` y `SSE-S3` por defecto. | [20](20/es.md) |
| **Repository policy / registry policy** | Políticas resource-based para un repositorio y todo el registry; admiten `aws:PrincipalOrgID`. | [20](20/es.md), [32](32/es.md) |
| **requests** | Recursos con los que se empaqueta y decide el autoscaler; reserva del pod. | [14](14/es.md) |
| **resolveConflicts** | Cómo actúa un add-on ante campos en conflicto: `NONE`, `OVERWRITE` o `PRESERVE`. | [37](37/es.md) |
| **Resource Modifiers** | ConfigMap Velero con parches JSON para objetos durante restore mediante `--resource-modifier-configmap`. | [42](42/es.md) |
| **ResourceQuota / LimitRange** | Límite total de un namespace / valores predeterminados y límites por contenedor. | [22](22/es.md) |
| **restore hook** | Init container o comando exec que Velero ejecuta al restaurar un pod. | [42](42/es.md) |
| **restore job** | Tarea de AWS Backup iniciada por `start-restore-job` y seguida con `list-restore-jobs`/`describe-restore-job`. | [42](42/es.md) |
| **retention policy** | Plazo de retención de logs en un log group; por defecto no expiran. | [34](34/es.md) |
| **right-sizing** | Ajuste de requests/limits al consumo real para compactar nodos. | [14](14/es.md), [43](43/es.md) |
| **rollback readiness** | Preparación para revertir versión: se conocen ventana y procedimiento. | [48](48/es.md) |
| **rollback readiness insights** | Cluster insights `ROLLBACK_READINESS` que comprueba preparación de rollback con estados PASSING/WARNING/ERROR/UNKNOWN. | [39](39/es.md) |
| **Usuario root** | Propietario de la cuenta con permisos ilimitados; solo se usa en configuración inicial. | [0.1](00-1-aws/es.md) |
| **Route 53 Resolver** | DNS integrado de VPC en «CIDR más 2», upstream de CoreDNS. | [0.3](00-3-vpc/es.md) |
| **Route table** | Tabla de rutas de subnet; una subnet pública y privada difieren solo en su ruta predeterminada. | [0.3](00-3-vpc/es.md) |
| **RPO** | Volumen aceptable de pérdida de datos, definido por la frecuencia de backup. | [42](42/es.md) |
| **RTO** | Tiempo objetivo para recuperar el servicio después de un incidente. | [42](42/es.md) |
| **S3 Express One Zone** | Clase de almacenamiento zonal de baja latencia e IOPS alto para directory buckets, que admite `append`. | [25](25/es.md) |
| **S3 Object Lock** | Protección WORM de bucket S3 que vuelve inmutables versiones durante retention y protege backups Velero. | [42](42/es.md) |
| **sampling** | Registrar una fracción de trazas, no todas, para controlar volumen y coste. | [36](36/es.md) |
| **sampling rules** | Reglas X-Ray que determinan fracción de solicitudes registradas por reservoir y fixed rate. | [36](36/es.md) |
| **Savings Plans / RI** | Descuento de 30-70 % a cambio de compromiso de 1 o 3 años. | [0.4](00-4-ec2/es.md) |
| **scale-to-zero** | Reducir un Deployment a cero réplicas en reposo; KEDA puede hacerlo, HPA no. | [35](35/es.md) |
| **ScaledJob** | CRD KEDA que escala el número de Job paralelos para unidades de trabajo. | [35](35/es.md) |
| **ScaledObject** | CRD KEDA que describe objetivo de escalado y triggers para Deployment. | [35](35/es.md) |
| **scaler** | Fuente de métricas KEDA, por ejemplo `aws-sqs-queue`, `aws-cloudwatch`, `prometheus`, `kafka` o `cron`. | [35](35/es.md) |
| **Schedule** | Objeto Velero de backup periódico con cron; define RPO. | [42](42/es.md) |
| **SCP (Service Control Policy)** | Política restrictiva para OU o cuenta: fija el máximo de permisos sin concederlos. | [0.1](00-1-aws/es.md), [0.2](00-2-iam/es.md) |
| **Secondary CIDR** | Bloque IPv4 adicional de una VPC; EKS suele usar `100.64.0.0/10`. | [07](07/es.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | Driver que monta secretos AWS como archivos en volumen de nodo mediante `SecretProviderClass`, con sync opcional en `Secret`. | [18](18/es.md) |
| **Security group** | Firewall stateful en ENI, solo allow; otra SG puede ser el origen. | [0.3](00-3-vpc/es.md), [46](46/es.md) |
| **`SecurityGroupPolicy`** | Recurso que asigna SG a pods por selector; un pod con branch ENI deja de heredar SG del nodo. | [46](46/es.md) |
| **self-heal** | Reversión automática del drift al estado de Git. | [44](44/es.md) |
| **self-managed add-on** | Componente instalado con Helm o manifiesto; el ingeniero asume todo su ciclo de vida y compatibilidad. | [37](37/es.md) |
| **Self-managed node** | Instancia EC2 que usted crea y une mediante access entry `EC2_LINUX`; todo el ciclo de vida es suyo. | [09](09/es.md) |
| **service map** | Mapa de servicios y relaciones con latencia y proporción de errores en las aristas. | [36](36/es.md) |
| **Service Network** | Límite VPC Lattice de un conjunto de servicios; las VPC consumidoras se asocian para acceder. | [28](28/es.md) |
| **Service Quotas** | Límites de servicios por cuenta y región, aumentables por solicitud. | [0.1](00-1-aws/es.md) |
| **`serviceIpv4Cidr`** | Rango de direcciones Service, virtual y sin relación con la VPC. | [06](06/es.md) |
| **ServiceMonitor, PodMonitor** | CRD Prometheus Operator que declaran los endpoints que se deben extraer. | [33](33/es.md) |
| **Session tags** | Etiquetas de sesión que Pod Identity añade a STS para ABAC; usan `aws:PrincipalTag/kubernetes-namespace` y `aws:PrincipalTag/eks-cluster-name`, y requieren `sts:TagSession` en trust policy. | [17](17/es.md) |
| **shared costs** | Costes comunes del clúster, como control plane, namespaces de sistema e idle, repartidos por regla o mostrados aparte. | [43](43/es.md) |
| **Shared responsibility** | AWS responde por la seguridad de la nube y usted por la seguridad en la nube. | [0.1](00-1-aws/es.md), [01](01/es.md) |
| **shared services account** | Cuenta con recursos compartidos, como ECR, zonas DNS privadas y observabilidad, para otras cuentas. | [32](32/es.md) |
| **shared VPC** | Modelo donde el propietario comparte subnets mediante RAM y otras cuentas ejecutan allí recursos, incluidos nodos EKS. | [32](32/es.md) |
| **showback** | Se muestra a los equipos su coste sin mover dinero. | [43](43/es.md) |
| **SNAT** | Sustitución de IP origen por IP de nodo para egress de pods; se deshabilita con `AWS_VPC_K8S_CNI_EXTERNALSNAT`. | [06](06/es.md) |
| **Soft multi-tenancy** | Tenants en un clúster mediante namespace, RBAC, cuotas, políticas de red y políticas; comparten control plane y núcleo. | [22](22/es.md) |
| **span** | Operación individual de una traza, como procesamiento, llamada o consulta, con tiempo y atributos. | [36](36/es.md) |
| **split-horizon DNS** | Mismo nombre con respuestas distintas fuera y dentro de VPC mediante zonas pública y privada. | [29](29/es.md) |
| **Spot interruption notice** | Aviso de interrupción dos minutos antes de detener o terminar la instancia. | [13](13/es.md) |
| **Instancia Spot** | Capacidad EC2 sobrante con descuento que AWS puede recuperar para demanda on-demand. | [13](13/es.md) |
| **Spot pool** | Combinación de tipo de instancia y zona de disponibilidad; la capacidad se recupera por pools. | [13](13/es.md) |
| **ssl-redirect** | Anotación que activa redirección HTTP a HTTPS al puerto listener indicado. | [27](27/es.md) |
| **SSM Session Manager** | Acceso a instancia sin SSH mediante agente SSM. | [45](45/es.md) |
| **Staging labels** | Etiquetas de versiones de secreto en Secrets Manager: `AWSCURRENT`, `AWSPENDING` y `AWSPREVIOUS`. | [18](18/es.md) |
| **Stakater Reloader** | Controlador que hace rolling restart de Deployment al cambiar un `Secret` o `ConfigMap` montado. | [18](18/es.md) |
| **Standard support** | Fase de soporte de una versión minor EKS, aproximadamente 14 meses, sin cargo adicional por versión. | [03](03/es.md), [38](38/es.md), [48](48/es.md) |
| **State** | Archivo de correspondencia entre código Terraform y recursos reales; se guarda en S3 con versionado y bloqueo. | [0.5](00-5-tools/es.md), [04](04/es.md) |
| **stdout/stderr** | Flujos estándar de salida del contenedor; por convención la aplicación escribe logs allí, no en archivos internos. | [34](34/es.md) |
| **STS** | Servicio de credenciales temporales: `sts:AssumeRole` y `sts:AssumeRoleWithWebIdentity`. | [0.2](00-2-iam/es.md) |
| **Subnet CIDR reservation** | Reserva de un bloque contiguo dentro de una subnet para prefijos. | [07](07/es.md) |
| **subnet IP exhaustion** | La subnet no tiene direcciones libres para ENI y pods. | [46](46/es.md) |
| **sync waves** | Orden de aplicación de recursos Argo CD por oleadas dentro de las fases sync. | [44](44/es.md) |
| **Tag immutability** | Modo de repositorio `IMMUTABLE` que prohíbe sobrescribir un tag; `MUTABLE` lo permite. | [20](20/es.md) |
| **target EKS cluster** | Clúster existente de destino del restore, o uno creado por AWS Backup con `newCluster=true`. | [42](42/es.md) |
| **target-type** | Tipo target NLB: `instance` por NodePort o `ip` directamente al pod; `ip` requiere VPC CNI y es obligatorio en Fargate. | [26](26/es.md), [27](27/es.md) |
| **`terminationGracePeriod`** | Límite de drenaje de nodo; con él, drift progresa incluso ante PDB bloqueantes y `do-not-disrupt`. | [12](12/es.md) |
| **terminationGracePeriodSeconds** | Tiempo entre SIGTERM y SIGKILL para terminar un pod, 30 por defecto. | [40](40/es.md) |
| **terragrunt** | Envoltura terraform con backend común, `env.hcl`, `dependency`, `run-all` y módulos DRY. | [0.5](00-5-tools/es.md) |
| **Thanos** | Componentes para retención Prometheus en object storage: `sidecar`, `store gateway`, `compactor`, `querier` y `ruler`. | [33](33/es.md) |
| **throughput mode** | Modo de rendimiento EFS: Elastic, Bursting o Provisioned. | [24](24/es.md) |
| **topology aware routing** | Preferencia por endpoints de la zona cliente mediante `trafficDistribution: PreferClose` en Service. | [31](31/es.md) |
| **topologySpreadConstraints** | Campo de pod para distribuir réplicas entre dominios con `maxSkew`, `topologyKey`, `whenUnsatisfiable` y `minDomains`. | [40](40/es.md) |
| **trace** | Recorrido completo de una solicitud por servicios con un `trace id` común. | [36](36/es.md) |
| **Transit Gateway** | Router hub regional con enrutamiento transitivo entre VPC, VPN y Direct Connect; se comparte por RAM. | [32](32/es.md) |
| **TriggerAuthentication** | CRD KEDA con parámetros de acceso del trigger; AWS usa provider `aws` con IRSA o Pod Identity. | [35](35/es.md) |
| **Trust policy** | Política de confianza de un rol con principal `Federated`, `sts:AssumeRoleWithWebIdentity` y condiciones `StringEquals` para `sub` y `aud`. | [0.2](00-2-iam/es.md), [16](16/es.md), [47](47/es.md) |
| **Registro TXT** | Mecanismo external-dns que marca sus registros con TXT; el propietario se define con `--txt-owner-id`. | [29](29/es.md) |
| **Unauthorized (401)** | Fallo de autenticación: la identidad no se probó o no se mapeó. | [47](47/es.md) |
| **`unhealthyPodEvictionPolicy`** | Campo PDB: `IfHealthyBudget` no expulsa pods no sanos con aplicación ya interrumpida; `AlwaysAllow` sí. | [40](40/es.md) |
| **upgrade insights** | Tipo de insights que señala preparación para upgrade y API que se eliminarán. | [38](38/es.md) |
| **Upgrade policy (`supportType`)** | Configuración `STANDARD` o `EXTENDED` que define el comportamiento al terminar standard support; solo se sale mediante upgrade. | [03](03/es.md) |
| **`useCachedMetrics` y `fallback`** | Caché de valor durante el sondeo y réplicas si la fuente no está disponible; reducen throttling y `<unknown>` en `TARGETS`. | [35](35/es.md) |
| **User data** | Script o configuración ejecutada al primer inicio de instancia; arranca bootstrap y configura `kubelet`. | [0.4](00-4-ec2/es.md), [10](10/es.md) |
| **ValidatingAdmissionPolicy** | Validación CEL integrada en apiserver desde Kubernetes 1.30+, sin webhook externo, con `ValidatingAdmissionPolicyBinding` y las reacciones `Deny`/`Warn`/`Audit`. | [22](22/es.md) |
| **Vault Lock** | Protección WORM del vault contra eliminar backups, con modos governance y compliance. | [41](41/es.md) |
| **Velero** | Backup/restore nativo de Kubernetes; objetos en S3 y volúmenes con CSI snapshots o File System Backup. | [42](42/es.md) |
| **velero-plugin-for-aws** | Plugin Velero oficial para AWS: object store S3 y volume snapshotter EBS. | [42](42/es.md) |
| **Version skew** | Diferencia permitida por política upstream entre kubelet y API server; exige actualizar control plane antes que nodos. | [03](03/es.md), [37](37/es.md) |
| **version skew policy** | Regla Kubernetes: los nodos no pueden ser más nuevos que control plane; dicta el orden de rollback. | [38](38/es.md), [39](39/es.md) |
| **VersionRollback** | Tipo de actualización devuelto por `update-cluster-version` durante rollback. | [39](39/es.md) |
| **VictoriaLogs** | Base de logs sin dependencias, con almacenamiento columnar, LogsQL e ingesta por Elasticsearch bulk, Loki push, OTLP y syslog; existe variante de clúster con `vlinsert`, `vlstorage` y `vlselect`. | [34](34/es.md) |
| **VictoriaMetrics** | Sustituto de almacenamiento de métricas con `vmagent`, `vmsingle` o clúster `vminsert`/`vmstorage`/`vmselect`, `vmalert`, `-retentionPeriod` y MetricsQL. | [33](33/es.md) |
| **volume node affinity conflict** | Evento scheduler cuando `nodeAffinity` del volumen señala una zona sin nodo adecuado. | [23](23/es.md) |
| **`volumeBindingMode`** | Momento de aprovisionar el volumen: `Immediate` al crear PVC o `WaitForFirstConsumer` al programar el pod. | [23](23/es.md) |
| **VolumeSnapshot / Content / Class** | Objetos de snapshots CSI: solicitud, snapshot AWS y clase. | [23](23/es.md) |
| **voluntary disruption** | Expulsión deliberada de pods, como drain, upgrade o consolidación; PDB la protege. | [40](40/es.md) |
| **VPC** | Red aislada en una región; el CIDR primario (`/16` ... `/28`) es inmutable y solo se amplía mediante secondary CIDR. | [0.3](00-3-vpc/es.md) |
| **VPC CNI** | Plugin de red AWS que asigna a pods direcciones privadas reales de subnets VPC; DaemonSet `aws-node`. | [06](06/es.md) |
| **VPC CNI network policy** | Implementación eBPF integrada de `NetworkPolicy`: controlador de control plane y `aws-network-policy-agent` en `aws-node`. | [08](08/es.md), [30](30/es.md) |
| **VPC endpoint** | Acceso privado a un servicio AWS: gateway para S3/DynamoDB o interface mediante PrivateLink. | [0.3](00-3-vpc/es.md), [31](31/es.md) |
| **VPC endpoint (PrivateLink)** | Punto de entrada privado a servicio AWS en VPC, obligatorio para ECR, S3, STS, EKS y más en nodos de datos privados. | [19](19/es.md) |
| **VPC Flow Logs** | Registro de flujos aceptados y rechazados; `action = REJECT` en Logs Insights sirve para SecOps y diagnóstico. | [0.3](00-3-vpc/es.md) |
| **VPC Lattice** | Servicio administrado de red de aplicaciones para conexión east-west entre VPC y cuentas sin sidecars ni peering. | [28](28/es.md) |
| **VPC peering** | Conexión directa uno a uno entre VPC; no es transitiva y requiere CIDR no solapados. | [32](32/es.md) |
| **wafv2-acl-arn** | Anotación para asociar Web ACL AWS WAF v2 a ALB y filtrar solicitudes. | [27](27/es.md) |
| **warm pool** | Reserva de direcciones IPv4 ya asignadas en el nodo para iniciar pods rápidamente. | [06](06/es.md) |
| **`WARM_PREFIX_TARGET`** | Reserva de prefijos por nodo; `WARM_IP_TARGET` y `MINIMUM_IP_TARGET` tienen prioridad. | [07](07/es.md) |
| **workspace** | Almacén aislado de métricas AMP con endpoint remote-write y API compatible con Prometheus propios. | [33](33/es.md) |
| **X-Amzn-Trace-Id** | Cabecera X-Ray con `Root`, `Parent` y `Sampled`; ADOT la mapea a W3C `traceparent` conservando el `trace id`. | [36](36/es.md) |
| **ZoneId (`euc1-az1`)** | Nombre estable de zona de disponibilidad, igual en todas las cuentas. | [0.1](00-1-aws/es.md) |
| **add-on `adot`** | Add-on EKS administrado que despliega ADOT Operator para gestionar collectors. | [36](36/es.md) |
| **Cuenta** | Espacio aislado de recursos y unidad de facturación; su número de 12 dígitos participa en ARN y trust policy. | [0.1](00-1-aws/es.md) |
| **Dirección privada secundaria** | Dirección IPv4 adicional de una ENI de nodo que se asigna a un pod. | [06](06/es.md) |
| **Diversificación** | Muchos tipos de instancia en varias AZ para que retirar un pool no elimine una fracción crítica de nodos. | [13](13/es.md) |
| **Dominio de preparación** | Eje operativo, como control plane, nodos, seguridad, red, almacenamiento u observabilidad, que se comprueba por separado. | [48](48/es.md) |
| **Drift** | Diferencia entre estado real y el descrito en código o Git. | [04](04/es.md), [44](44/es.md) |
| **dependencia entre stacks** | Paso de outputs de un stack a inputs de otro, mediante el bloque Terragrunt `dependency`. | [04](04/es.md) |
| **Instancia EC2** | Máquina virtual; para EKS es un nodo con containerd y kubelet. | [0.4](00-4-ec2/es.md) |
| **caché local** | Caché Mountpoint en volumen de nodo, `cache: emptyDir`/`ephemeral`, que acelera lecturas repetidas; `metadata-ttl` define la de metadatos. | [25](25/es.md) |
| **Escalado de nodos frente a escalado de pods** | Niveles distintos: CA y Karpenter escalan nodos; HPA, VPA y KEDA escalan pods. | [11](11/es.md) |
| **Micro-VM** | Máquina virtual dedicada a un pod con kernel, CPU, memoria e interfaz propios; límite de aislamiento Fargate. | [15](15/es.md) |
| **Object storage** | Modelo clave-valor: objeto inmutable de bytes y metadatos bajo una cadena clave, actualizado por completo con `PutObject`. | [25](25/es.md) |
| **ventana de rollback (7 días)** | Periodo posterior a upgrade en que rollback está disponible; luego no lo están ni este ni sus insights. | [39](39/es.md) |
| **Plugin kubectl** | Archivo `kubectl-<nombre>` en `PATH`, disponible como `kubectl <nombre>`. | [0.5](00-5-tools/es.md) |
| **Subnet** | Parte del CIDR VPC situada en una AZ. | [0.3](00-3-vpc/es.md) |
| **Reemplazo completo** | `aws-node` se elimina y Cilium es el único CNI con IPAM propio: ENI IPAM o cluster-pool. | [08](08/es.md) |
| **prefix** | Parte de una clave anterior a `/` con la que Mountpoint emula un directorio; S3 no tiene directorios reales. | [25](25/es.md) |
| **upgrade forzado** | Elevación automática de versión al terminar extended support; ese clúster no puede revertirse. | [38](38/es.md) |
| **Provider** | Plugin terraform, como `aws`, `kubernetes` o `helm`. | [0.5](00-5-tools/es.md) |
| **entrega progresiva** | Despliegue canary o blue-green de aplicaciones, por ejemplo Argo Rollouts o Flagger. | [44](44/es.md) |
| **Checklist de producción** | Lista sistemática de preparación por dominios; cada elemento está cerrado o marcado como riesgo conocido. | [48](48/es.md) |
| **Profile** | Conjunto nombrado de parámetros, como región, rol y SSO. | [0.5](00-5-tools/es.md) |
| **Región** | Ubicación geográfica, como `eu-central-1`, a la que pertenecen los recursos. | [0.1](00-1-aws/es.md) |
| **modo external** | Valor de anotación `aws-load-balancer-type` que entrega la reconciliación Service al LBC externo, no al provider in-tree. | [26](26/es.md) |
| **Modos de acceso EBS** | `ReadWriteOnce` para un nodo y `ReadWriteOncePod` para un pod; `ReadWriteMany` solo es posible como Multi-Attach `io2` con `volumeMode: Block` en una AZ; el acceso de archivos compartido usa EFS o FSx. | [23](23/es.md) |
| **reconciliación** | Ciclo continuo que compara el estado deseado en Git con el real en el clúster. | [44](44/es.md) |
| **aprovisionamiento estático** | PV definido manualmente con `bucketName`; el driver no ofrece aprovisionamiento dinámico ni crea buckets. | [25](25/es.md) |
| **Stack** | Unidad de infraestructura aplicable independientemente con su propio state. | [0.5](00-5-tools/es.md), [04](04/es.md) |
| **Estrategia de rotación** | `single user`, con ventana breve de riesgo, o `alternating users`, con dos usuarios y credenciales válidas en todo momento. | [18](18/es.md) |
| **Estrategia Spot** | Selección de pool: `capacity-optimized(-prioritized)` frente a `lowest-price`; las estrategias de capacidad se interrumpen menos. | [0.4](00-4-ec2/es.md) |
| **Tag** | Par clave/valor; los controladores EKS localizan recursos por tags y cost allocation tags activos desglosan la factura. | [0.1](00-1-aws/es.md) |
| **Tipo de instancia** | `familia + generación + sufijo . tamaño`, por ejemplo `m7g.xlarge`. | [0.4](00-4-ec2/es.md) |
| **Tipos de logs de control plane** | `api`, `audit`, `authenticator`, `controllerManager` y `scheduler`; se escriben en CloudWatch Logs solo al habilitarlos. | [02](02/es.md) |
| **Capacidad EKS administrada para Argo CD** | Argo CD como EKS Capability: controladores en control plane AWS, destinos solo EKS por ARN y acceso con EKS access entries. | [44](44/es.md) |
| **filtro kubernetes** | FILTER Fluent Bit que añade namespace, pod, contenedor, labels y annotations a los registros. | [34](34/es.md) |
| **sharding de Argo CD** | Distribución de clústeres conectados entre réplicas de application-controller. | [44](44/es.md) |
| **`--force`** | Flag que omite comprobaciones insights ERROR/WARNING/UNKNOWN, no las precondiciones de rollback. | [39](39/es.md) |
| **/var/log/containers** | Directorio de nodo con enlaces a archivos de logs de contenedores; punto de donde el recolector los obtiene. | [34](34/es.md) |
