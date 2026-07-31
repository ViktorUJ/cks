[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md)

# Glosario del curso CKA + CKAD

[← Índice del curso](README_ES.md) · [CKA](CKA_ES.md) · [CKAD](CKAD_ES.md)

Referencia alfabética única de los términos del curso. El término va en inglés (como en
Kubernetes), la descripción en español y en la columna «Capítulos» se indica dónde se trata
el término (con enlaces a los capítulos). Búsqueda en la página - Ctrl+F.

| Término | Descripción | Capítulos |
|---------|-------------|-----------|
| **A record / AAAA record** | registro DNS nombre → IPv4 / nombre → IPv6. | [0.2](00-2-dns/es.md) |
| **accessModes** | modos de acceso: RWO, ROX, RWX, RWOP. | [25](25/es.md) |
| **activeDeadlineSeconds** | tiempo máximo de ejecución de la tarea. | [10](10/es.md) |
| **Adapter** | contenedor que transforma la salida de la aplicación al formato necesario. | [22](22/es.md) |
| **admin.conf** | kubeconfig del administrador después de init. | [35](35/es.md) |
| **Admission control** | comprobación/modificación de la petición después de authn+authz. | [21](21/es.md) |
| **aggregation layer** | extensión de la API mediante un extension-apiserver propio (p. ej. metrics-server). | [41](41/es.md) |
| **APIService** | objeto que registra una API agregada (`metrics.k8s.io` y otras). | [41](41/es.md) |
| **allow logic** | las políticas solo permiten; no existe una prohibición como regla aparte. | [34](34/es.md) |
| **allowPrivilegeEscalation** | permitir/prohibir la escalada de privilegios. | [20](20/es.md) |
| **allowVolumeExpansion** | si se permite ampliar el volumen. | [25](25/es.md), [26](26/es.md) |
| **Ambassador** | contenedor intermediario para las conexiones salientes de la aplicación. | [22](22/es.md) |
| **Annotation** | par clave-valor para datos adicionales, no para selección. | [06](06/es.md) |
| **API deprecation** | declarar una versión de API obsoleta con su posterior eliminación. | [29](29/es.md) |
| **apiVersion** | versión del grupo de API del objeto (alpha/beta/estable). | [29](29/es.md) |
| **Application container** | contenedor principal del Pod con la carga útil. | [04](04/es.md) |
| **apply** | crear o actualizar el objeto según el manifiesto (idempotente, 3-way merge). | [03](03/es.md) |
| **args** | sustituye el CMD de la imagen (argumentos). | [17](17/es.md) |
| **Authn** | determinar quién envía la petición. | [21](21/es.md) |
| **Authz** | comprobar que el emisor tiene permiso (RBAC). | [21](21/es.md) |
| **automountServiceAccountToken** | si se monta el token de la SA en el Pod. | [21](21/es.md) |
| **averageUtilization** | porcentaje medio de uso del recurso que se busca alcanzar. | [16](16/es.md) |
| **backendRefs** | servicios destino (con pesos para canary). | [33](33/es.md) |
| **backoffLimit** | número de reintentos en caso de fallo. | [10](10/es.md) |
| **Bare pod** | Pod creado directamente, sin controlador; no se recupera. | [04](04/es.md) |
| **base** | manifiestos de origen comunes. | [43](43/es.md) |
| **Base image** | imagen base (`FROM`) con la que empieza la construcción. | [23](23/es.md) |
| **base64** | codificación de los valores de un Secret; NO es cifrado. | [19](19/es.md) |
| **behavior** | ajuste fino de la velocidad de scale up/down. | [16](16/es.md) |
| **Binding** | vinculación de un PV adecuado con un PVC (uno a uno). | [25](25/es.md) |
| **Blue** | versión actual en funcionamiento; **Green** - la nueva, preparada para la conmutación. | [09](09/es.md) |
| **Blue/Green** | dos entornos completos (el actual y el nuevo) con conmutación instantánea del tráfico. | [09](09/es.md) |
| **bootstrap token** | token temporal para el join de nodos (vive ~24 horas). | [35](35/es.md) |
| **bridge (cni0)** | conmutador software del nodo que conecta los Pods que hay en él. | [0.7](00-7-netns/es.md), [30](30/es.md) |
| **CA** | autoridad de certificación; raíz de confianza, firma los certificados. | [0.3](00-3-tls/es.md), [39](39/es.md) |
| **Calico / Cilium / Flannel** | plugins CNI populares. | [30](30/es.md), [40](40/es.md) |
| **Canary** | publicación de la nueva versión para una pequeña parte del tráfico con incremento gradual. | [09](09/es.md) |
| **CIDR** | notación `dirección/N`, donde `N` - número de bits de red; más N - red más pequeña. | [0.1](00-1-net/es.md), [30](30/es.md) |
| **CNAME** | registro DNS: alias que apunta a otro nombre. | [0.2](00-2-dns/es.md) |
| **capabilities** | permisos individuales sacados de la «omnipotencia» de root (drop/add). | [20](20/es.md) |
| **cgroups** | controladores del kernel que limitan los recursos del contenedor (cpu, memory, pids, io); base de requests/limits. | [0.4](00-4-containers/es.md), [14](14/es.md) |
| **cgroup v1 / v2** | versión antigua (una jerarquía por controlador) / moderna (jerarquía única) de cgroups; v2 por defecto desde Fedora 31, Ubuntu 22.04, Debian 11, RHEL 9 (cgroup v2 en K8s GA desde 1.25). | [0.4](00-4-containers/es.md) |
| **cgroup driver** | quién configura los cgroups (`systemd` o `cgroupfs`); kubelet y runtime deben coincidir (`SystemdCgroup=true`). | [0.4](00-4-containers/es.md), [35](35/es.md) |
| **cert-manager** | operador de emisión y renovación automática de certificados. | [32](32/es.md) |
| **cert-manager / Prometheus Operator** | operadores populares. | [41](41/es.md) |
| **change-cause** | anotación con el motivo del cambio para el historial. | [08](08/es.md) |
| **Chart** | paquete: plantillas de manifiestos + values + metadatos. | [42](42/es.md) |
| **CKA** | Certified Kubernetes Administrator, examen de administración del clúster. | [01](01/es.md) |
| **CKAD** | Certified Kubernetes Application Developer, examen de ejecución de aplicaciones. | [01](01/es.md) |
| **Client certificate** | credencial del usuario; CN → nombre, O → grupo. | [39](39/es.md) |
| **Cluster Autoscaler** | cambia el número de nodos del clúster. | [16](16/es.md) |
| **Karpenter** | selecciona y arranca nodos del tipo necesario para los Pods en Pending (más flexible que Cluster Autoscaler). | [16](16/es.md) |
| **Cluster API** | gestión declarativa del ciclo de vida de los clústeres. | [35](35/es.md), [35B](35-3-design/es.md) |
| **managed / self-managed** | el control plane lo mantiene el proveedor (EKS/GKE/AKS) / lo mantienes tú. | [35B](35-3-design/es.md) |
| **node pool** | grupo de nodos del mismo tipo (perfil, zona, spot/on-demand). | [35B](35-3-design/es.md) |
| **IaC** | infraestructura como código (Terraform/OpenTofu, Ansible). | [35B](35-3-design/es.md) |
| **GitOps** | git como fuente de verdad del estado del clúster (Argo CD/Flux). | [35B](35-3-design/es.md) |
| **cluster-admin / admin / edit / view** | ClusterRole integrados. | [38](38/es.md) |
| **Cluster-scoped object** | a nivel de clúster (Node, PV, StorageClass, ClusterRole). | [06](06/es.md) |
| **ClusterIP** | tipo por defecto: IP virtual interna, accesible solo dentro del clúster. | [07](07/es.md) |
| **ClusterRole** | permisos sobre el clúster / sobre recursos cluster-scoped / para reutilizar. | [38](38/es.md) |
| **ClusterRoleBinding** | vinculación de un rol a un sujeto en todo el clúster. | [38](38/es.md) |
| **CNCF** | Cloud Native Computing Foundation, organización que está detrás de Kubernetes y de estas certificaciones. | [01](01/es.md) |
| **CNI** | interfaz y plugin de la red de Pods (Calico, Cilium y otros). | [02](02/es.md), [30](30/es.md), [40](40/es.md) |
| **command** | sustituye el ENTRYPOINT de la imagen (qué ejecutar). | [17](17/es.md) |
| **completions** | cuántas finalizaciones correctas se necesitan. | [10](10/es.md) |
| **componentstatuses** | estado general de los componentes (en desuso). | [45](45/es.md) |
| **concurrencyPolicy** | política cuando se solapan ejecuciones de un CronJob (Allow/Forbid/Replace). | [10](10/es.md) |
| **Conditions** | estados del nodo (Ready, MemoryPressure, DiskPressure, PIDPressure). | [45](45/es.md) |
| **ConfigMap** | objeto con configuración no secreta (claves-valores o ficheros). | [18](18/es.md) |
| **configMapGenerator / secretGenerator** | generación de ConfigMap/Secret (con hash en el nombre). | [43](43/es.md) |
| **configMapKeyRef** | tomar una sola clave del ConfigMap en una variable de entorno. | [18](18/es.md) |
| **container runtime** | entorno de ejecución de contenedores (containerd), se comunica por CRI. | [02](02/es.md) |
| **containerd / CRI-O** | implementaciones de CRI (runtimes). | [40](40/es.md) |
| **context** | conjunto cluster + user + namespace. | [39](39/es.md) |
| **Context (kubeconfig)** | conjunto clúster + usuario + namespace; se cambia con `use-context`. | [03](03/es.md) |
| **Control plane** | capa de gestión del clúster (el cerebro): apiserver, etcd, scheduler, controller-manager. | [02](02/es.md) |
| **Controller** | programa con un bucle de reconciliación (lleva la realidad al spec). | [41](41/es.md) |
| **cordon** | marcar el nodo como unschedulable (los Pods nuevos ya no van aquí). | [36](36/es.md) |
| **cordon / drain** | marcar el nodo unschedulable / desalojar de él los Pods (capítulo 36). | [13](13/es.md), [36](36/es.md) |
| **CoreDNS** | servidor DNS del clúster (Deployment en kube-system detrás del Service kube-dns). | [31](31/es.md) |
| **Corefile** | configuración de CoreDNS (en el ConfigMap `coredns`). | [31](31/es.md) |
| **CrashLoopBackOff** | el contenedor se cae y se reinicia en bucle. | [04](04/es.md), [44](44/es.md) |
| **containerd / CRI-O** | container runtime de alto nivel con los que trabaja el kubelet. | [0.4](00-4-containers/es.md), [40](40/es.md) |
| **CRD** | definición de un nuevo tipo de objetos en la API. | [41](41/es.md) |
| **CreateContainerConfigError** | falta el ConfigMap/Secret al que hace referencia el Pod. | [44](44/es.md) |
| **CRI** | interfaz kubelet ↔ entorno de ejecución. | [0.4](00-4-containers/es.md), [40](40/es.md) |
| **crictl** | CLI para trabajar con los contenedores a través de CRI en el nodo. | [40](40/es.md), [45](45/es.md) |
| **CronJob** | crea Jobs según una programación cron. | [10](10/es.md) |
| **CSI** | estándar de conexión de almacenamiento a Kubernetes. | [26](26/es.md), [40](40/es.md) |
| **CSI driver** | implementación de CSI (el provisioner del StorageClass). | [40](40/es.md) |
| **CSR** | solicitud de firma de certificado a través de la API del clúster. | [39](39/es.md) |
| **certSANs** | nombres/direcciones adicionales en el certificado del apiserver (p. ej. el DNS del balanceador para HA). | [35](35/es.md) |
| **certificatesDir** | directorio de la PKI del clúster (por defecto `/etc/kubernetes/pki`). | [35](35/es.md) |
| **Custom Resource** | instancia del tipo definido por un CRD. | [41](41/es.md) |
| **custom-columns** | tabla de salida propia. | [47](47/es.md) |
| **DaemonSet** | controlador que mantiene un Pod en cada nodo (adecuado). | [11](11/es.md) |
| **data / binaryData** | datos de texto / binarios del ConfigMap. | [18](18/es.md) |
| **Declarative approach** | gestión mediante manifiestos (`kubectl apply -f`). | [01](01/es.md), [03](03/es.md) |
| **default / kube-system / kube-public / kube-node-lease** | namespaces del sistema. | [06](06/es.md) |
| **default deny** | política que bloquea todo en una dirección (sin reglas de permiso). | [34](34/es.md) |
| **default SA** | ServiceAccount por defecto en cada namespace. | [21](21/es.md) |
| **Default StorageClass** | clase por defecto para los PVC sin clase explícita. | [26](26/es.md) |
| **default-deny + DNS** | trampa: la política de egress corta la resolución (capítulo 34). | [34](34/es.md), [46](46/es.md) |
| **Deployment** | controlador por encima de ReplicaSet: réplicas + actualizaciones + rollbacks + historial. | [05](05/es.md) |
| **Desired state** | lo que has descrito en el manifiesto. | [01](01/es.md) |
| **Destructive operations** | etcd restore, drain: revisar con especial cuidado. | [48](48/es.md) |
| **distroless / scratch** | imágenes base mínimas sin nada superfluo / vacía. | [23](23/es.md) |
| **dnsConfig** | ajuste puntual del DNS del Pod (incluido `options ndots`), funciona con cualquier dnsPolicy. | [31](31/es.md) |
| **dnsPolicy** | cómo obtiene el Pod el DNS (ClusterFirst y otros). | [31](31/es.md) |
| **Dockerfile** | instrucciones de construcción de la imagen. | [0.4](00-4-containers/es.md), [23](23/es.md) |
| **Downward API** | acceso del Pod a información sobre sí mismo (`fieldRef`, `resourceFieldRef`). | [17](17/es.md) |
| **drain** | desalojar los Pods del nodo (de forma ordenada) y llevarlos a otros. | [36](36/es.md) |
| **Dynamic provisioning** | creación automática del PV a petición de un PVC. | [26](26/es.md) |
| **eBPF** | tecnología del kernel de Linux sobre la que está construido Cilium. | [30](30/es.md) |
| **EmptyDir** | volumen del Pod para intercambiar ficheros entre contenedores. | [22](22/es.md), [24](24/es.md) |
| **encryption at rest** | cifrado de los Secret en etcd. | [19](19/es.md) |
| **External CA mode** | en `pki/` solo está `ca.crt` sin la clave: kubeadm genera el CSR, la firma y la renovación corren de tu cuenta. | [35](35/es.md) |
| **endpoint 2379** | puerto de cliente de etcd. | [37](37/es.md) |
| **Endpoints** | lista de direcciones de los Pods detrás del Service; vacía = no vinculado (capítulo 7). | [07](07/es.md), [46](46/es.md) |
| **Endpoints / EndpointSlice** | lista de IP de los Pods listos detrás del Service. | [07](07/es.md) |
| **ENTRYPOINT/CMD** | qué ejecutar y con qué argumentos, definido en la imagen. | [17](17/es.md) |
| **env** | variables de entorno del contenedor. | [17](17/es.md) |
| **envFrom + configMapRef** | todas las claves del ConfigMap como variables de entorno. | [18](18/es.md) |
| **Ephemeral volume** | vive lo mismo que el Pod (sobrevive al reinicio del contenedor, pero no a la eliminación del Pod). | [24](24/es.md) |
| **ephemeral container** | contenedor temporal para depurar un Pod en marcha (`kubectl debug`). | [04](04/es.md), [29](29/es.md) |
| **etcd** | almacén clave-valor distribuido con todo el estado del clúster. | [02](02/es.md), [37](37/es.md) |
| **etcdctl** | CLI para trabajar con etcd; para los snapshots hace falta `ETCDCTL_API=3`. | [37](37/es.md) |
| **Events** | cronología de las acciones sobre el objeto en la salida de `describe`/`get events`. | [29](29/es.md), [44](44/es.md) |
| **eviction** | desalojo de Pods por parte del kubelet cuando faltan recursos en el nodo. | [14](14/es.md) |
| **exec** | ejecutar un comando/shell dentro del contenedor. | [29](29/es.md) |
| **exec form** | comando como lista, sin shell (lo correcto para las señales). | [17](17/es.md) |
| **expandtab** | ajuste de vim (espacios en lugar de tabuladores) para YAML. | [0.8](00-8-vim/es.md), [47](47/es.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | herramientas de protección real de los secretos. | [19](19/es.md) |
| **ExternalName** | alias DNS (CNAME) hacia un dominio externo. | [07](07/es.md) |
| **FailedScheduling** | evento del planificador cuando el Pod está en Pending. | [44](44/es.md) |
| **failureThreshold / successThreshold** | número de fallos/éxitos para cambiar de estado. | [27](27/es.md) |
| **filters** | transformaciones (rewrite, redirect, cabeceras). | [33](33/es.md) |
| **Flat network** | cualquier Pod ve a cualquier otro por IP directamente, sin NAT. | [30](30/es.md) |
| **Fluent Bit/Fluentd** | agentes de recogida de logs (normalmente DaemonSet). | [28](28/es.md) |
| **Service FQDN** | `<service>.<namespace>.svc.cluster.local`. | [31](31/es.md) |
| **fsGroup** | grupo propietario de los volúmenes montados (nivel de Pod). | [20](20/es.md) |
| **Gateway** | punto de entrada: listeners (puertos, protocolos, TLS); pertenece al operador del clúster. | [33](33/es.md) |
| **Gateway API** | estándar moderno de enrutado del tráfico en Kubernetes. | [33](33/es.md) |
| **FQDN** | nombre de dominio completo con todos los niveles (p. ej. `backend.default.svc.cluster.local`). | [0.2](00-2-dns/es.md), [31](31/es.md) |
| **GatewayClass** | implementación (controlador) de Gateway API, análogo de StorageClass. | [33](33/es.md) |
| **globalDefault** | PriorityClass que se aplica a los Pods sin prioridad explícita. | [15](15/es.md) |
| **HA (high availability)** | tolerancia a fallos del control plane: varios nodos, el fallo de uno no tumba la gestión. | [35A](35-2-ha/es.md) |
| **--control-plane-endpoint** | dirección estable del control plane (balanceador) para HA; se indica en `kubeadm init`. | [35A](35-2-ha/es.md), [35](35/es.md) |
| **stacked / external etcd** | etcd en los propios nodos de control plane (por defecto) / en nodos aparte. | [35A](35-2-ha/es.md) |
| **quorum (etcd)** | mayoría de nodos de etcd necesaria para escribir (raft); de ahí el número impar (3/5). | [35A](35-2-ha/es.md), [37](37/es.md) |
| **leader election** | elección de la instancia activa de scheduler/controller-manager en HA (las demás quedan en reserva). | [35A](35-2-ha/es.md) |
| **SPOF** | punto único de fallo; HA lo elimina. | [35A](35-2-ha/es.md) |
| **--upload-certs / certificate-key** | transferencia de los certificados del control plane al hacer join de los nodos HA. | [35A](35-2-ha/es.md) |
| **Handshake (TLS)** | procedimiento de establecimiento de la conexión TLS (validación del certificado, acuerdo de clave). | [0.3](00-3-tls/es.md) |
| **Headless Service** | `clusterIP: None`, el DNS devuelve directamente las IP de los Pods. | [07](07/es.md), [11](11/es.md) |
| **Helm** | gestor de paquetes para Kubernetes. | [42](42/es.md) |
| **helm install/upgrade/rollback/uninstall** | ciclo de vida del release. | [42](42/es.md) |
| **helm template** | render local del chart a manifiestos (para revisarlos). | [42](42/es.md) |
| **hostPath** | montaje de un directorio del nodo en el Pod (arriesgado, para tareas de sistema). | [24](24/es.md) |
| **HPA** | cambia el número de réplicas según las métricas. | [16](16/es.md) |
| **httpGet / tcpSocket / exec / grpc** | formas de hacer la comprobación. | [27](27/es.md) |
| **HTTPRoute** | reglas de enrutado HTTP hacia los servicios; pertenece al desarrollador. | [33](33/es.md) |
| **IgnoredDuringExecution** | la regla se comprueba al planificar, pero no desaloja un Pod ya en marcha. | [12](12/es.md) |
| **Image** | sistema de ficheros empaquetado de la aplicación + dependencias + metadatos de arranque. | [23](23/es.md) |
| **ImagePullBackOff/ErrImagePull** | no se consigue descargar la imagen. | [44](44/es.md) |
| **imagePullPolicy** | cuándo descargar la imagen (IfNotPresent/Always/Never). | [23](23/es.md) |
| **imagePullSecrets** | secreto para acceder a un registro de imágenes privado. | [19](19/es.md) |
| **immutable** | ConfigMap inmutable (solo se puede recrear). | [18](18/es.md) |
| **Imperative approach** | gestión de los objetos con comandos (`kubectl run`, `create`). | [01](01/es.md), [03](03/es.md) |
| **Ingress controller** | aplicación que ejecuta las reglas de Ingress (nginx, Traefik, ALB). | [32](32/es.md) |
| **Ingress resource** | declaración de las reglas de enrutado L7 (hosts, rutas, TLS). | [32](32/es.md) |
| **ingress2gateway** | utilidad de conversión automática de Ingress a recursos de Gateway API (da un borrador, requiere revisión). | [33](33/es.md) |
| **IngressClass** | qué controlador atiende este Ingress (`ingressClassName`). | [32](32/es.md) |
| **Init container** | contenedor que se ejecuta antes de los principales y está obligado a terminar. | [22](22/es.md) |
| **initialDelaySeconds** | retardo antes de la primera comprobación. | [27](27/es.md) |
| **IP address** | dirección numérica de un dispositivo en la red (IPv4 - 32 bits, cuatro octetos). | [0.1](00-1-net/es.md) |
| **ipBlock** | permiso por rango de IP (tráfico externo). | [34](34/es.md) |
| **iptables / IPVS modes** | formas de implementar los servicios; IPVS escala mejor. | [31](31/es.md) |
| **Job** | controlador de tarea puntual; vigila que los Pods terminen correctamente. | [10](10/es.md) |
| **journalctl -u kubelet** | logs del kubelet, fuente principal de las causas de NotReady. | [45](45/es.md) |
| **JSONPath** | lenguaje de selección de campos de la respuesta de la API (`-o jsonpath=...`). | [03](03/es.md), [47](47/es.md) |
| **KEDA** | autoescalado event-driven por eventos externos (incluso hasta cero). | [16](16/es.md) |
| **kube-apiserver** | punto de entrada único por el que pasan todas las peticiones; el único que escribe en etcd. | [02](02/es.md) |
| **list-watch** | seguimiento de los cambios: LIST + flujo WATCH (sin sondear la API). | [02](02/es.md) |
| **informer** | caché local de objetos del controlador, sincronizada mediante watch. | [02](02/es.md) |
| **resourceVersion** | versión del objeto; permite continuar el watch y es la base del bloqueo optimista. | [02](02/es.md) |
| **optimistic locking** | la escritura con una versión obsoleta se rechaza (409 Conflict) → reintento. | [02](02/es.md) |
| **kube-controller-manager** | conjunto de controladores (bucles de reconciliación). | [02](02/es.md) |
| **kube-proxy** | implementa los servicios mediante iptables/IPVS en el nodo. | [02](02/es.md), [07](07/es.md), [31](31/es.md) |
| **kube-scheduler** | asigna los Pods a los nodos. | [02](02/es.md), [12](12/es.md) |
| **kubeadm** | herramienta oficial de instalación del clúster (init/join/upgrade). | [35](35/es.md) |
| **kubeadm certs renew** | renovar los certificados del clúster. | [39](39/es.md) |
| **kubeadm init** | inicialización del control plane. | [35](35/es.md) |
| **kubeadm join** | incorporación de un nodo al clúster. | [35](35/es.md) |
| **kubeadm reset** | limpieza del estado de kubeadm en el nodo. | [36](36/es.md) |
| **kubeadm upgrade plan / apply / node** | plan / aplicación (primer CP) / actualización del nodo. | [36](36/es.md) |
| **kubeconfig** | fichero (`~/.kube/config`) con clústeres, usuarios y contextos. | [03](03/es.md), [39](39/es.md) |
| **kubectl** | utilidad principal de línea de comandos para trabajar con el clúster. | [01](01/es.md), [03](03/es.md) |
| **kubectl apply -k** | aplicar un directorio de Kustomize. | [43](43/es.md) |
| **kubectl certificate approve** | aprobar un CSR (firmarlo con la CA). | [39](39/es.md) |
| **kubectl debug** | inyectar un contenedor de depuración / copiar el Pod / depurar el nodo. | [29](29/es.md) |
| **kubectl explain** | documentación integrada de los campos de los objetos. | [03](03/es.md) |
| **kubectl kustomize / kustomize build** | render sin aplicar. | [43](43/es.md) |
| **kubectl logs** | ver los logs del Pod/contenedor. | [28](28/es.md) |
| **kubectl top** | mostrar el consumo de recursos (hace falta metrics-server). | [28](28/es.md) |
| **kubelet** | agente del nodo, arranca y controla los Pods; servicio del sistema. | [02](02/es.md) |
| **Kubernetes** | sistema de orquestación de contenedores: lleva el estado real del clúster al deseado. | [01](01/es.md) |
| **kustomization.yaml** | fichero que describe los recursos y las transformaciones. | [43](43/es.md) |
| **Kustomize** | herramienta de adaptación de manifiestos aplicando parches, sin plantillas. | [43](43/es.md) |
| **Label** | par clave-valor para seleccionar y vincular objetos. | [06](06/es.md) |
| **Labels** | pares clave-valor en los objetos, con los que trabajan los selectores. | [05](05/es.md) |
| **Layer** | conjunto de cambios del sistema de ficheros; las capas se cachean y se reutilizan. | [23](23/es.md) |
| **Layered troubleshooting** | análisis de la red de abajo arriba: CNI → DNS → Endpoints → política → entrada. | [46](46/es.md) |
| **LimitRange** | valores por defecto y límites de recursos para un objeto concreto del namespace. | [14](14/es.md) |
| **limits** | techo de consumo; se comprueba en tiempo de ejecución. | [14](14/es.md) |
| **liveness** | si el contenedor está vivo; fallo → reinicio. | [27](27/es.md) |
| **LoadBalancer** | balanceador externo de la nube delante del Service. | [07](07/es.md) |
| **localhost** | red común del Pod, a través de la cual los contenedores se ven entre sí. | [22](22/es.md) |
| **Manifest** | fichero YAML con la descripción de un objeto de Kubernetes. | [01](01/es.md) |
| **matchLabels / matchExpressions** | dos formas de selector. | [06](06/es.md) |
| **maxSurge** | cuántos Pods se pueden crear por encima del número deseado durante el despliegue. | [08](08/es.md) |
| **maxUnavailable** | cuántos Pods se pueden perder temporalmente durante el despliegue. | [08](08/es.md) |
| **medium: Memory** | colocar el emptyDir en RAM (tmpfs). | [24](24/es.md) |
| **metrics-server** | recoge CPU/memoria de los Pods; necesario para HPA y `kubectl top`. | [16](16/es.md), [28](28/es.md) |
| **Mi/Gi vs M/G** | unidades de memoria binarias (1024) frente a decimales (1000). | [14](14/es.md) |
| **Microsegmentation** | separación fina del tráfico entre Pods/servicios. | [34](34/es.md) |
| **milli-CPU** | milésima parte de un core (`500m` = medio core). | [14](14/es.md) |
| **minReplicas/maxReplicas** | límites inferior y superior del número de réplicas. | [16](16/es.md) |
| **Mirror Pod** | reflejo del static pod en la API; se ve, pero no se elimina con kubectl. | [15](15/es.md) |
| **Mock exam** | ensayo con cronómetro y corrección automática. | [48](48/es.md) |
| **mTLS** | TLS mutuo: ambas partes presentan certificado. | [0.3](00-3-tls/es.md), [39](39/es.md) |
| **Multi-stage build** | construcción en una imagen, en la final solo queda el resultado. | [23](23/es.md) |
| **Mutating / Validating admission** | controladores que modifican / que validan. | [21](21/es.md) |
| **Namespace** | sección del clúster; los nombres de los objetos son únicos dentro de él. | [06](06/es.md) |
| **Namespaced object** | vive en un namespace (Pod, Deployment, Service, ...). | [06](06/es.md) |
| **namespaceSelector** | selección de Pods por las etiquetas del namespace. | [34](34/es.md) |
| **NAT** | sustitución de direcciones en la puerta de enlace para que el tráfico privado salga al exterior. | [0.1](00-1-net/es.md) |
| **netshoot** | imagen con herramientas de red para depurar. | [46](46/es.md) |
| **NetworkPolicy** | reglas de qué Pod puede comunicarse con cuál (firewall a nivel de Pods). | [34](34/es.md) |
| **Node** | máquina (VM o física) que forma parte del clúster. | [02](02/es.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl (específico del CKA). | [48](48/es.md) |
| **nodeAffinity** | selección flexible de nodos; `required` (estricta) y `preferred` (blanda). | [12](12/es.md) |
| **NodeLocal DNSCache** | caché DNS local en cada nodo. | [31](31/es.md) |
| **nodeName** | asignación rígida del nodo saltándose el planificador. | [12](12/es.md) |
| **NodePort** | abre un puerto (30000-32767) en todos los nodos para el acceso externo. | [07](07/es.md) |
| **nodeSelector** | selección rígida y simple del nodo por sus etiquetas. | [12](12/es.md) |
| **NoExecute** | no planificar y desalojar los Pods ya en marcha que no tengan toleration. | [13](13/es.md) |
| **NoSchedule** | no planificar Pods nuevos sin toleration (los antiguos se quedan). | [13](13/es.md) |
| **NotReady** | estado del nodo cuando el kubelet no informa de su disponibilidad. | [45](45/es.md) |
| **ndots** | umbral de puntos en el nombre: por debajo de él el nombre se prueba primero con los sufijos search (por defecto `ndots:5` → consultas de más para los nombres externos). | [31](31/es.md) |
| **namespaces (Linux)** | aislamiento de lo que ve el proceso: PID, NET, MNT, UTS, IPC, USER (no confundir con el namespace de Kubernetes). | [0.4](00-4-containers/es.md) |
| **network namespace** | pila de red aislada del proceso/contenedor (interfaces, IP y rutas propias). | [0.7](00-7-netns/es.md), [40](40/es.md) |
| **nslookup/dig** | comprobación de la resolución DNS desde dentro del Pod. | [46](46/es.md) |
| **OCI** | estándar abierto del formato de imágenes y contenedores (compatibilidad Docker ↔ containerd). | [0.4](00-4-containers/es.md) |
| **OLM** | Operator Lifecycle Manager, mecanismo de instalación/actualización de operadores. | [41](41/es.md) |
| **OOMKilled** | el contenedor ha sido matado por superar el límite de memoria. | [04](04/es.md), [14](14/es.md), [44](44/es.md) |
| **Operator** | controlador + conocimiento del dominio sobre cómo gestionar la aplicación. | [41](41/es.md) |
| **operator Equal/Exists** | coincidencia por valor / solo por clave. | [13](13/es.md) |
| **Orchestration** | gestión automática del ciclo de vida de los contenedores (arranque, reinicio, escalado, ubicación). | [01](01/es.md) |
| **overlay** | conjunto de cambios sobre el base para un entorno concreto. | [43](43/es.md) |
| **Overlay network** | red con encapsulado de paquetes entre nodos (VXLAN). | [30](30/es.md) |
| **parallelism** | cuántos Pods arranca el Job a la vez. | [10](10/es.md) |
| **parentRefs** | vinculación del Route al Gateway. | [33](33/es.md) |
| **Partial credit** | se puntúa lo hecho parcialmente. | [47](47/es.md) |
| **patches** | cambios puntuales de campos (strategic merge / JSON6902). | [43](43/es.md) |
| **pathType** | forma de comparar la ruta: Prefix / Exact / ImplementationSpecific. | [32](32/es.md) |
| **pause container** | contenedor auxiliar que mantiene el network namespace del Pod. | [40](40/es.md) |
| **Pending** | el Pod no está planificado (recursos/taints/affinity/PVC). | [44](44/es.md) |
| **periodSeconds** | intervalo entre comprobaciones. | [27](27/es.md) |
| **PersistentVolume** | objeto que representa un «trozo de almacenamiento» en el clúster. | [25](25/es.md) |
| **PersistentVolumeClaim** | solicitud de almacenamiento por parte de la aplicación (tamaño, modo). | [25](25/es.md) |
| **Phase** | etapa principal de la vida del Pod: Pending, Running, Succeeded, Failed, Unknown. | [04](04/es.md) |
| **cluster PKI** | conjunto de CA y certificados en `/etc/kubernetes/pki/`, se crea con `kubeadm init`. | [35](35/es.md), [39](39/es.md) |
| **front-proxy-ca** | CA para el aggregation layer (extensiones del API server). | [35](35/es.md) |
| **sa.key / sa.pub** | par de claves para firmar los tokens de ServiceAccount. | [35](35/es.md), [21](21/es.md) |
| **pluto / kubent** | herramientas para buscar APIs obsoletas en los manifiestos/el clúster. | [29](29/es.md), [36](36/es.md) |
| **kubepug (kubectl deprecations)** | comprobación de la API contra la versión objetivo de K8s (clúster y ficheros). | [29](29/es.md) |
| **kubeconform** | validador de manifiestos según los esquemas de la versión objetivo de K8s (CI). | [29](29/es.md) |
| **Popeye** | sanitizador del clúster; encuentra, entre otras cosas, APIs obsoletas. | [29](29/es.md) |
| **Pod** | unidad mínima de ejecución: envoltorio alrededor de uno o varios contenedores con red y volúmenes comunes. | [04](04/es.md) |
| **Pod CIDR / Service CIDR** | rangos de direcciones de los Pods / de las IP virtuales de los servicios; no deben solaparse. | [0.1](00-1-net/es.md), [30](30/es.md) |
| **Pod connectivity** | si los Pods pueden comunicarse por IP (nivel de CNI, capítulo 30). | [30](30/es.md), [46](46/es.md) |
| **Pod Security Admission** | política integrada con los niveles privileged/baseline/restricted. | [20](20/es.md) |
| **podAffinity** | colocar el Pod cerca de otros Pods según sus etiquetas. | [12](12/es.md) |
| **podAntiAffinity** | colocar el Pod lejos de otros Pods según sus etiquetas. | [12](12/es.md) |
| **PodDisruptionBudget** | mínimo de Pods disponibles durante un desalojo voluntario. | [36](36/es.md) |
| **podSelector** | a qué Pods se aplica la política / a quién se permite. | [34](34/es.md) |
| **policyTypes** | direcciones: Ingress (entrante) y/o Egress (saliente). | [34](34/es.md) |
| **port / targetPort / nodePort** | puerto del Service / puerto en los Pods / puerto en los nodos. | [07](07/es.md) |
| **port-forward** | reenvío del puerto del Pod/Service a la máquina local. | [29](29/es.md), [46](46/es.md) |
| **Preemption** | eliminación de Pods de menor prioridad para colocar uno de prioridad más alta. | [15](15/es.md) |
| **PreferNoSchedule** | evitar de forma blanda planificar aquí. | [13](13/es.md) |
| **pressure-taints** | taints automáticos cuando faltan recursos en el nodo (capítulo 13). | [13](13/es.md), [45](45/es.md) |
| **PriorityClass** | objeto con la prioridad numérica de los Pods. | [15](15/es.md) |
| **privileged** | contenedor privilegiado (≈ root en el nodo); peligroso. | [20](20/es.md) |
| **Probe** | comprobación de salud del contenedor que ejecuta el kubelet. | [27](27/es.md) |
| **Progressive delivery** | canary/blue-green automatizados según métricas (Argo Rollouts, Flagger). | [09](09/es.md) |
| **projected** | volumen que combina varias fuentes (secret/configMap/downwardAPI). | [24](24/es.md) |
| **Prometheus / Grafana** | recogida/almacenamiento de métricas y visualización (monitorización de verdad). | [28](28/es.md) |
| **provisioner** | driver CSI que crea los volúmenes reales. | [26](26/es.md) |
| **PTR** | registro DNS inverso: IP → nombre. | [0.2](00-2-dns/es.md) |
| **QoS class** | Guaranteed / Burstable / BestEffort; orden de desalojo cuando falta memoria. | [14](14/es.md) |
| **Quorum** | mayoría de nodos de etcd necesaria para funcionar (HA). | [37](37/es.md) |
| **raft** | protocolo de consenso con el que se ponen de acuerdo los nodos de etcd. | [02](02/es.md) |
| **RBAC** | control de acceso basado en roles (capítulo 38). | [21](21/es.md), [38](38/es.md) |
| **readiness** | si está listo para recibir tráfico; fallo → se quita de Endpoints (sin reinicio). | [27](27/es.md) |
| **readOnlyRootFilesystem** | sistema de ficheros raíz solo de lectura. | [20](20/es.md) |
| **ReadWriteMany** | lectura-escritura desde varios nodos (hace falta un FS de red). | [25](25/es.md) |
| **ReadWriteOnce** | lectura-escritura desde un solo nodo (¡no desde un solo Pod!). | [25](25/es.md) |
| **reclaimPolicy** | destino del PV tras eliminar el PVC: Retain / Delete. | [25](25/es.md) |
| **Reconciliation loop** | ciclo continuo en el que los controladores eliminan la diferencia entre el estado deseado y el real. | [01](01/es.md) |
| **Recreate** | estrategia de «matar todo y luego crear»; con parada de servicio. | [08](08/es.md) |
| **Registry** | almacén de imágenes (por defecto Docker Hub); el privado requiere imagePullSecret. | [0.4](00-4-containers/es.md), [23](23/es.md) |
| **Release** | instancia instalada de un chart (con historial de revisiones). | [42](42/es.md) |
| **replicas** | número deseado de Pods. | [05](05/es.md) |
| **ReplicaSet** | controlador que mantiene el número indicado de Pods según el selector. | [05](05/es.md) |
| **ReplicationController** | predecesor obsoleto de ReplicaSet. | [05](05/es.md) |
| **Repository** | almacén de charts. | [42](42/es.md) |
| **requests** | mínimo garantizado de recursos; se usa al planificar. | [14](14/es.md) |
| **required vs preferred** | regla de ubicación estricta (obligatoria) frente a blanda (si es posible) en affinity. | [12](12/es.md) |
| **ResourceQuota** | límite total de recursos y de número de objetos por namespace. | [14](14/es.md) |
| **restartPolicy** | política de reinicio de los contenedores: Always, OnFailure, Never. | [04](04/es.md) |
| **Return to context** | después de trabajar en el nodo, continuar en la máquina de partida. | [48](48/es.md) |
| **Revision** | versión fijada de la plantilla del Deployment en el historial. | [08](08/es.md) |
| **revisionHistoryLimit** | cuántos ReplicaSet antiguos conservar para el rollback. | [08](08/es.md) |
| **Role** | permisos dentro de un namespace. | [38](38/es.md) |
| **RoleBinding** | vinculación de un rol a un sujeto en el namespace. | [38](38/es.md) |
| **roleRef** | a qué rol hace referencia el binding. | [38](38/es.md) |
| **rollback** | vuelta a la revisión anterior (`rollout undo`). | [08](08/es.md) |
| **RollingUpdate** | estrategia de sustitución gradual de los Pods sin parada de servicio (por defecto). | [08](08/es.md) |
| **rollout** | proceso de despliegue de una nueva versión del Deployment. | [08](08/es.md) |
| **Routed network** | red que conoce directamente las rutas hacia los Pods (BGP). | [30](30/es.md) |
| **rules** | qué se permite y sobre qué. | [38](38/es.md) |
| **runAsNonRoot** | prohibición de ejecutar como root. | [20](20/es.md) |
| **runAsUser / runAsGroup** | UID/GID del proceso del contenedor. | [20](20/es.md) |
| **runc** | herramienta de bajo nivel que arranca contenedores a través del kernel. | [0.4](00-4-containers/es.md), [40](40/es.md) |
| **Scheduler Profiles** | varias configuraciones dentro de un mismo planificador. | [15](15/es.md) |
| **schedulerName** | qué planificador coloca el Pod. | [15](15/es.md) |
| **scope** | ámbito del CRD: en un namespace o en todo el clúster. | [41](41/es.md) |
| **search domains** | sufijos en resolv.conf que completan los nombres cortos. | [0.2](00-2-dns/es.md), [31](31/es.md) |
| **Secret** | objeto para datos sensibles (contraseñas, tokens, claves, certificados). | [19](19/es.md) |
| **secretKeyRef / secretRef** | conexión de una clave/de todo el Secret en env. | [19](19/es.md) |
| **SecurityContext** | ajustes de seguridad a nivel de Pod/contenedor. | [20](20/es.md) |
| **selector** | cómo encuentra el controlador «sus» Pods (por etiquetas). | [05](05/es.md), [06](06/es.md) |
| **Selector switch** | cambio del `selector` del Service para pasar el tráfico al instante a otra versión (base del blue/green). | [09](09/es.md) |
| **SSH** | acceso seguro al nodo por red; `exit` - volver atrás. | [0.5](00-5-linux/es.md) |
| **sudo** | ejecutar un comando como root; `sudo -i` - convertirse en root durante la sesión. | [0.5](00-5-linux/es.md) |
| **systemd / systemctl** | sistema de gestión de servicios (kubelet, containerd) y su comando. | [0.5](00-5-linux/es.md), [45](45/es.md) |
| **Service** | dirección estable y balanceo delante de un grupo de Pods elegidos por selector. | [07](07/es.md) |
| **ServiceAccount** | identidad del Pod/proceso para acceder a la API. | [21](21/es.md) |
| **shell form** | comando a través de `sh -c` (necesario para variables y pipes). | [17](17/es.md) |
| **Sidecar** | contenedor auxiliar en el mismo Pod (capítulo 22). | [04](04/es.md), [22](22/es.md) |
| **snapshot restore** | despliegue del snapshot en un nuevo directorio de datos. | [37](37/es.md) |
| **snapshot save** | creación de una copia de seguridad de etcd en un fichero. | [37](37/es.md) |
| **stabilization window** | ventana de espera antes de reducir las réplicas. | [16](16/es.md) |
| **Stable identity** | nombres de Pod predecibles (`db-0`, `db-1`) que sobreviven a la recreación. | [11](11/es.md) |
| **startup** | si el arranque ha terminado; bloquea las demás sondas hasta que pasa. | [27](27/es.md) |
| **Stateful** | aplicación con estado; necesita identidad y almacenamiento propio. | [05](05/es.md) |
| **StatefulSet** | controlador para aplicaciones con estado: nombres estables, orden, almacenamiento propio por Pod. | [11](11/es.md) |
| **Stateless** | aplicación sin estado único; los Pods son intercambiables. | [05](05/es.md) |
| **Static Pod** | Pod que el kubelet arranca directamente desde un manifiesto en `/etc/kubernetes/manifests/`, sin la participación del planificador. | [02](02/es.md), [15](15/es.md), [45](45/es.md) |
| **staticPodPath** | carpeta que vigila el kubelet (normalmente `/etc/kubernetes/manifests/`). | [15](15/es.md) |
| **stdout/stderr** | salida estándar del contenedor, de donde Kubernetes toma los logs. | [28](28/es.md) |
| **StorageClass** | plantilla de creación de volúmenes: provisioner, parámetros, política de reclaim. | [26](26/es.md) |
| **stringData** | campo para valores en texto claro (se codifican automáticamente). | [19](19/es.md) |
| **subjects** | a quién se dan los permisos: User, Group, ServiceAccount. | [38](38/es.md) |
| **suspend** | pausa temporal del CronJob. | [10](10/es.md) |
| **swapoff** | desactivación del swap (requisito de Kubernetes). | [35](35/es.md) |
| **Taint** | marca-restricción en el nodo (`clave=valor:efecto`) que repele los Pods. | [13](13/es.md) |
| **Task weight** | proporción de puntos, pista sobre la prioridad. | [47](47/es.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | enrutado para otros protocolos. | [33](33/es.md) |
| **template** | plantilla del Pod con la que se crean las réplicas. | [05](05/es.md) |
| **Three pillars of observability** | logs, métricas, trazas. | [28](28/es.md) |
| **Three-pass strategy** | estrategia de tiempo: fáciles → difíciles → revisión. | [47](47/es.md), [48](48/es.md) |
| **throttling** | frenado del contenedor al superar el límite de CPU. | [14](14/es.md) |
| **TLS** | protocolo de cifrado y autenticación del tráfico (la «S» de HTTPS). | [0.3](00-3-tls/es.md) |
| **TLS termination** | descifrado de HTTPS en el Ingress; certificado desde un Secret de tipo tls. | [0.3](00-3-tls/es.md), [32](32/es.md) |
| **Toleration** | «pase» del Pod que le permite estar en un nodo con taint. | [13](13/es.md) |
| **tolerationSeconds** | cuánto aguanta el Pod en un nodo con NoExecute antes del desalojo. | [13](13/es.md) |
| **topologyKey** | etiqueta del nodo que define la «zona de vecindad» (hostname, zone). | [12](12/es.md) |
| **topologySpreadConstraints** | distribución uniforme de los Pods por topología (`maxSkew`). | [12](12/es.md) |
| **troubleshooting domain** | 30% del CKA, el de más peso; arreglar aplicaciones/clúster/red. | [48](48/es.md) |
| **TTL** | tiempo de vida del registro DNS en la caché (en segundos). | [0.2](00-2-dns/es.md) |
| **ttlSecondsAfterFinished** | autoeliminación del Job finalizado pasado el tiempo indicado. | [10](10/es.md) |
| **type** | propósito del Secret (Opaque, tls, dockerconfigjson y otros). | [19](19/es.md) |
| **uncordon** | devolver el nodo al pool de planificación. | [36](36/es.md) |
| **updateStrategy** | estrategia de actualización de DaemonSet/StatefulSet (rolling). | [11](11/es.md) |
| **valueFrom** | rellenar la variable desde una fuente (campo del Pod, recursos, CM/Secret). | [17](17/es.md) |
| **Values** | parámetros para sustituir en las plantillas. | [42](42/es.md) |
| **VAR** | referencia a una variable declarada antes dentro del manifiesto. | [17](17/es.md) |
| **veth pair** | dos interfaces virtuales conectadas - el «cable» entre el network namespace del Pod y el del nodo. | [0.7](00-7-netns/es.md), [30](30/es.md) |
| **Version skew** | diferencia de versiones admitida entre los componentes; el kubelet no más nuevo que el apiserver. | [36](36/es.md) |
| **Volume** | almacenamiento declarado a nivel de Pod y montado en los contenedores. | [24](24/es.md) |
| **Volume mount** | las claves del ConfigMap se convierten en ficheros dentro de un directorio. | [18](18/es.md) |
| **volumeBindingMode** | cuándo crear/vincular el volumen (Immediate / WaitForFirstConsumer). | [26](26/es.md) |
| **volumeClaimTemplates** | plantilla del StatefulSet que crea un PVC para cada Pod. | [11](11/es.md), [26](26/es.md) |
| **volumes / volumeMounts** | declaración del volumen / su montaje en el contenedor. | [24](24/es.md) |
| **VPA** | cambia los requests/limits de los Pods. | [16](16/es.md) |
| **webhook** | validación/modificación externa de los objetos (Kyverno, OPA, mesh). | [21](21/es.md) |
| **YAML** | formato de manifiestos legible por humanos; el anidamiento se marca con la indentación (solo espacios). | [0.6](00-6-yaml/es.md), [03](03/es.md) |
| **whenUnsatisfiable** | modo de topologySpread: `DoNotSchedule` (estricto, → Pending) o `ScheduleAnyway` (blando, admitiendo desequilibrio). | [12](12/es.md) |
| **Worker node** | nodo de trabajo en el que se ejecutan los Pods de las aplicaciones. | [02](02/es.md) |
| **Ingress annotations** | ajustes específicos del controlador (rewrite, timeout y otros). | [32](32/es.md) |
| **Asymmetric cryptography** | par de claves relacionadas: la privada (secreta) y la pública (abierta). | [0.3](00-3-tls/es.md) |
| **Subnet mask** | qué parte de la dirección corresponde a la red y qué parte al host. | [0.1](00-1-net/es.md) |
| **Octet** | uno de los cuatro números de una dirección IPv4 (8 bits, 0-255). | [0.1](00-1-net/es.md) |
| **Port** | número 0-65535 que indica la aplicación en el dispositivo; el par «IP + puerto» = servicio. | [0.1](00-1-net/es.md) |
| **Private / public key** | clave secreta del propietario (no se transmite) / clave pública (se reparte a todos). | [0.3](00-3-tls/es.md) |
| **Resolver** | componente que realiza las consultas DNS en nombre de la aplicación (en el clúster - CoreDNS). | [0.2](00-2-dns/es.md), [31](31/es.md) |
| **Certificate** | clave pública + datos del propietario + firma de la CA. | [0.3](00-3-tls/es.md), [39](39/es.md) |
| **Ingress → Gateway API migration** | división de un Ingress en Gateway (entrada) + HTTPRoute (reglas). | [33](33/es.md) |
| **Native sidecar** | init container con `restartPolicy: Always`. | [22](22/es.md) |
| **etcd certificates** | CA/cert/key en `/etc/kubernetes/pki/etcd/`. | [37](37/es.md) |
| **Kubernetes network model** | requisitos de la red: IP propia para el Pod, comunicación sin NAT, red plana. | [30](30/es.md) |
| **PV/PVC statuses** | Available, Bound, Pending, Released. | [25](25/es.md) |
| **Tag / digest** | versión de la imagen / hash inmutable del contenido. | [23](23/es.md) |

## Parámetros, flags y códigos

Los flags de los comandos, los alias auxiliares y los códigos de respuesta se han
separado de la lista alfabética principal de términos.

| Parámetro / código | Descripción | Capítulos |
|--------------------|-------------|-----------|
| **$do / $now** | helpers `--dry-run=client -o yaml` / eliminación rápida. | [47](47/es.md) |
| **--control-plane-endpoint** | dirección común del control plane (para HA). | [35](35/es.md) |
| **--data-dir** | directorio de datos de etcd (en el restore - uno nuevo). | [37](37/es.md) |
| **--from-file / --from-env-file** | fichero completo en una sola clave / línea a línea en claves. | [18](18/es.md) |
| **--ignore-daemonsets** | en el drain, no tocar los Pods de DaemonSet (están atados al nodo). | [36](36/es.md) |
| **--pod-network-cidr** | rango de direcciones de los Pods (se acuerda con el CNI). | [35](35/es.md) |
| **--previous** | logs del contenedor anterior (el que se cayó). | [28](28/es.md) |
| **--set / -f** | sustitución de values en la CLI / mediante un fichero. | [42](42/es.md) |
| **401 vs 403** | no autenticado (certificado) vs sin permisos (RBAC). | [39](39/es.md) |
| **`--dry-run=client -o yaml`** | generar el YAML sin crear nada. | [03](03/es.md) |
