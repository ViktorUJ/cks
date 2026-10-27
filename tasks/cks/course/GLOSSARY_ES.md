[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md) · [日本語版](GLOSSARY_JP.md)

# Glosario del curso CKS

[← Contenido del curso](README_ES.md) · [Hoja de referencia](CHEATSHEET_ES.md) · [Índice de solución de problemas (RU)](TROUBLESHOOTING_INDEX_RU.md)

Referencia alfabética de términos de CKS. Los términos se conservan en inglés y las explicaciones están en español. «Capítulos» enlaza con el desarrollo de cada concepto; «Laboratorio/Tarea» indica aplicaciones prácticas confirmadas y queda vacío para términos puramente teóricos. Los ejemplos listos para usar están en la [hoja de referencia](CHEATSHEET_ES.md).

| Término | Descripción | Capítulos | Laboratorio/Tarea |
|--------|----------|-------|--------------|
| **4C** | Un modelo de las capas de Nube, Clúster, Contenedor y Código para evaluar la seguridad de Kubernetes. | [02](02/es.md) | |
| **Admission control** | Una etapa de procesamiento de solicitudes del servidor API después de la autenticación y autorización, antes de que el objeto se almacene en etcd. | [01](01/es.md), [20](20/es.md) | labs/107 (Tarea 6) |
| **Admission policy** | Una regla que permite, modifica o rechaza una solicitud Kubernetes API. | [01](01/es.md), [20](20/es.md) | labs/107 (Tarea 6), labs/108 |
| **Admission scan** | Una verificación en la creación de cargas de trabajo que utiliza resultados de análisis o certificaciones asociadas. | [28](28/es.md) | |
| **Admission verification** | Verificación obligatoria del origen o firma de la imagen antes de que el servidor API persista en un Pod. | [26](26/es.md) | labs/111 (Tarea 9a) |
| **aescbc** | Un proveedor de cifrado de datos Kubernetes API que utiliza AES-CBC con relleno PKCS#7; su clave se almacena en una configuración protegida. No tiene autenticación de texto cifrado incorporada (sin HMAC/AEAD) y se considera una opción débil/heredada en comparación con `aesgcm` o KMS v2 porque CBC es vulnerable a ataques de padding-oracle. | [21](21/es.md) | labs/109 (Tarea 2) |
| **aesgcm** | Un proveedor AEAD AES-GCM para cifrado de datos API; Las claves requieren una rotación programada. | [21](21/es.md) | |
| **allow-list / allowlist** | Una lista explícita de acciones, fuentes o destinos permitidos; todo lo que no figura en la lista se niega. | [12](12/es.md), [15](15/es.md), [17](17/es.md) | labs/112 (Tarea 9) |
| **anonymous authentication** | Asignación de una solicitud sin credenciales a `system:anonymous`; generalmente deshabilitado para API y kubelet. | [12](12/es.md) | labs/104 (Tarea 5) |
| **AppArmor** | MAC Linux basada en rutas que limita las operaciones de proceso a las permitidas por un perfil. | [03](03/es.md), [16](16/es.md) | labs/106 (Tareas 1-2) |
| **apparmor_parser** | Una utilidad para verificar, cargar, reemplazar y descargar perfiles AppArmor. | [16](16/es.md) | labs/106 (Tarea 1) |
| **Artifact** | Resultado de un build, como una imagen OCI, un SBOM, un chart o información de provenance. | [25](25/es.md) | labs/111 |
| **Artifact repository** | Almacén controlado de artefactos: registry, repositorio de paquetes o repositorio de charts. | [25](25/es.md) | |
| **attack surface** | Todas las interfaces, componentes y puntos de entrada a través de los cuales es posible un ataque o una mala configuración. | [02](02/es.md), [14](14/es.md), [24](24/es.md) | labs/105 |
| **Attribution** | Asociar un evento con un proceso, contenedor, Pod, identidad, nodo y hora. | [30](30/es.md) | labs/112 (Tarea 6) |
| **audience** | El destinatario previsto de un token ServiceAccount; un servicio debería aceptar sólo tokens con su propia audiencia. | [11](11/es.md) | labs/104 (Tarea 2) |
| **audit / enforce / warn** | Modos PSA independientes: registrar una infracción, rechazar un Pod o devolver una advertencia. | [19](19/es.md), [31](31/es.md) | labs/107 (Tareas 1, 3-4) |
| **audit backend** | Un backend de archivos local o un backend de webhook que recibe eventos seleccionados por una política de auditoría. | [32](32/es.md) | labs/112 (Tareas 4, 8) |
| **audit event** | Un registro de servidor API de una solicitud Kubernetes API. | [32](32/es.md) | labs/112 (Tarea 4) |
| **audit policy** | Reglas ordenadas que definen el nivel de auditoría y las etapas de eventos excluidos. | [32](32/es.md) | labs/112 (Tarea 4) |
| **auditID** | Un identificador que vincula todas las etapas de auditoría de una única solicitud API. | [32](32/es.md) | |
| **Base image** | La imagen de una instrucción `FROM` que proporciona el sistema de archivos inicial de una etapa de compilación. | [24](24/es.md) | labs/111 (Tarea 3) |
| **Bound ServiceAccount token** | Un token TokenRequest API de corta duración vinculado a ServiceAccount y Pod. | [11](11/es.md) | labs/104 (Tarea 2) |
| **BPF filter** | Un programa de filtro ejecutado por el kernel para una llamada al sistema en modo de filtro seccomp. | [17](17/es.md) | labs/106 (Tareas 4-5) |
| **break-glass access** | Acceso privilegiado temporal controlado para una emergencia o incidente. | [10](10/es.md), [15](15/es.md) | |
| **Build context** | Los archivos enviados a un constructor; `.dockerignore` reduce este conjunto. | [24](24/es.md) | |
| **CAP_SYS_ADMIN** | Una capacidad Linux excesivamente amplia que resulta peligrosa para cargas de trabajo normales. | [03](03/es.md) | labs/106 (Tarea 5) |
| **capability** | Un privilegio individual Linux extraído de poderes de raíz; una línea de base segura elimina `ALL` y restaura solo lo que se necesita. | [03](03/es.md), [18](18/es.md) | labs/107 (Tarea 2) |
| **CEL** | Lenguaje de expresión común, utilizado por el ValidatingAdmissionPolicy integrado. | [20](20/es.md) | labs/107 (Tarea 6), labs/108, labs/111 (Tarea 9a), labs/112 (Tarea 9) |
| **cgroup** | Un grupo de procesos con límites y contabilidad para CPU, memoria, PIDs y otros recursos. | [03](03/es.md) | |
| **CI gate** | Una verificación obligatoria que bloquea la siguiente etapa del proceso en un código de salida distinto de cero. | [27](27/es.md), [28](28/es.md) | |
| **Cilium** | Una plataforma de seguridad y Kubernetes CNI basada en eBPF. | [06](06/es.md), [23](23/es.md) | labs/102, labs/110 (Tarea 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | Una política Cilium para todo el clúster; su amplio alcance requiere una implementación particularmente cuidadosa. | [06](06/es.md) | |
| **CiliumNetworkPolicy (CNP)** | Un recurso de política Cilium con espacio de nombres y reglas L3/L4/L7. | [06](06/es.md) | labs/102 (Tarea 3) |
| **cipher suite** | Un conjunto de algoritmos criptográficos TLS compatibles con el certificado y los clientes. | [09](09/es.md) | labs/103 (Tarea 5) |
| **CIS Kubernetes Benchmark** | Recomendaciones de CIS para la configuración segura de componentes y nodos de Kubernetes. | [01](01/es.md), [07](07/es.md) | labs/103 (Tareas 1, 7) |
| **CKS** | Especialista en seguridad certificado Kubernetes, una práctica certificación de seguridad Kubernetes. | [01](01/es.md), [33](33/es.md) | |
| **Clair** | Un escáner de vulnerabilidades basado en servicios e indexador para imágenes de contenedores. | [28](28/es.md) | |
| **complain** | Un modo AppArmor que registra infracciones de políticas sin bloquearlas. | [16](16/es.md) | |
| **condition** | Una expresión booleana Falco sobre campos de eventos que determina si se activa una regla. | [29](29/es.md) | labs/112 (Tareas 3, 7, 9) |
| **Constraint** | Una instancia de plantilla Gatekeeper con parámetros, alcance coincidente y una acción. | [20](20/es.md) | |
| **ConstraintTemplate** | Una plantilla Rego y un esquema de parámetros para un nuevo tipo de restricción Gatekeeper. | [20](20/es.md) | |
| **container escape** | Escapar del aislamiento esperado del contenedor para acceder al nodo u otros recursos del inquilino. | [03](03/es.md) | |
| **Container runtime sandbox** | Un tiempo de ejecución que agrega un límite de aislamiento entre una carga de trabajo y el kernel del host. | [22](22/es.md) | labs/110 (Tareas 1-3) |
| **Confidential computing / TEE** | Un área CPU aislada por hardware (Intel SGX, AMD SEV) que protege los datos en memoria incluso del hipervisor y del proveedor de la nube; Kubernetes lo expone a través de un `RuntimeClass` especial (contenedores confidenciales), mientras que la garantía del hardware se encuentra fuera del Kubernetes API. | [30](30/es.md) | |
| **context** | Una combinación con nombre de clúster, usuario y espacio de nombres en kubeconfig. | [33](33/es.md) | |
| **Correlation** | Vincular eventos de diferentes fuentes en una única línea de tiempo de incidente. | [30](30/es.md) | labs/112 (Tarea 6) |
| **Cosign** | Una herramienta Sigstore para firmar y verificar artefactos OCI. | [26](26/es.md) | labs/111 (Tareas 7, 9a, 9c) |
| **CRI** | Interfaz de tiempo de ejecución del contenedor; `crictl` accede al tiempo de ejecución a través de un socket CRI. | [14](14/es.md), [30](30/es.md) | labs/112 (Tarea 6) |
| **CRI socket** | El punto final de comunicación en tiempo de ejecución kubelet, como `/run/containerd/containerd.sock`. | [14](14/es.md) | |
| **CVE** | Un identificador de una vulnerabilidad conocida públicamente. | [13](13/es.md), [28](28/es.md) | labs/111 (Tarea 1) |
| **CycloneDX** | Un formato OWASP para inventario de componentes y análisis de seguridad en un SBOM. | [25](25/es.md), [28](28/es.md) | labs/111 (Tarea 7) |
| **daemon.json** | El archivo de configuración del demonio Docker, normalmente `/etc/docker/daemon.json`. | [14](14/es.md) | |
| **DaemonSet** | Una carga de trabajo Kubernetes que mantiene un agente Pod en cada nodo seleccionado. | [29](29/es.md) | |
| **defense in depth** | Capas de protección independientes que reducen el impacto de un fallo de control. | [01](01/es.md), [02](02/es.md) | labs/104 (Tarea 3) |
| **deny-list** | Una política cuya acción predeterminada permite llamadas al sistema mientras que se niegan llamadas al sistema específicas. | [17](17/es.md) | |
| **Digest** | El identificador SHA-256 inmutable de un artefacto o manifiesto de imagen en particular, a diferencia de una etiqueta mutable. | [09](09/es.md), [24](24/es.md), [25](25/es.md), [26](26/es.md) | labs/111 (Tareas 3-5, 9c) |
| **distroless** | Una imagen de tiempo de ejecución mínima sin administrador de paquetes y generalmente sin shell. | [24](24/es.md), [31](31/es.md) | labs/111 (Tarea 7) |
| **docker group** | Un grupo con acceso al socket Docker que debe tratarse como equivalente a raíz. | [14](14/es.md) | labs/105 (Tarea 6) |
| **Docker socket** | `/var/run/docker.sock`, el demonio local Docker API; El acceso es casi equivalente a root en el host. | [14](14/es.md) | labs/105 (Tarea 6) |
| **drop-in** | Un archivo de configuración independiente que amplía una configuración base, por ejemplo systemd o SSH. | [15](15/es.md) | |
| **eBPF** | Un mecanismo de kernel Linux para programas restringidos; Cilium lo usa para la ruta de datos y Falco para eventos. | [06](06/es.md), [29](29/es.md) | labs/112 (Tarea 1) |
| **egress policy** | Una NetworkPolicy que especifica las conexiones salientes Pod permitidas. | [04](04/es.md), [05](05/es.md) | labs/101 (Tareas 2, 4, 6) |
| **encryption at rest** | Cifrado de datos almacenados en etcd, en disco, en instantáneas y en copias de seguridad. | [21](21/es.md) | labs/109 |
| **EncryptionConfiguration** | La configuración del proveedor de cifrado leída por kube-apiserver. | [21](21/es.md) | labs/109 (Tarea 2) |
| **enforce** | Un modo AppArmor o PSA que realmente bloquea las infracciones de políticas. | [16](16/es.md), [19](19/es.md) | labs/106 (Tarea 1), labs/107 (Tarea 1) |
| **Entity** | Un grupo de direcciones Cilium predefinido, como `world`, `cluster` o `host`. | [06](06/es.md) | |
| **envelope encryption** | Cifrar un objeto con un DEK, que a su vez está protegido por un KEK externo. | [21](21/es.md) | |
| **evidence** | Un artefacto verificable que confirma un resultado: un objeto, registro, perfil, informe del escáner o prueba de red API. | [33](33/es.md) | |
| **exemption** | Una omisión estrecha de PSA para un espacio de nombres, nombre de usuario o RuntimeClass de confianza; no otorga ningún permiso RBAC. | [19](19/es.md) | |
| **Exfiltration** | Transferencia no autorizada de datos a través de un límite de confianza. | [02](02/es.md), [30](30/es.md) | |
| **failurePolicy** | La acción del servidor API cuando un webhook/política no está disponible o se producen errores: generalmente `Fail` o `Ignore`. | [20](20/es.md) | labs/107 (Tarea 6) |
| **Falco** | Un motor de reglas de eventos de seguridad en tiempo de ejecución que utiliza eventos del kernel y metadatos de contenedor/Kubernetes. | [29](29/es.md), [30](30/es.md) | labs/112 (Tareas 1-3, 6-7, 9) |
| **Falco rule override** | Un cambio local en una condición de regla Falco o excepciones sin editar el conjunto de reglas del proveedor. | [29](29/es.md), [30](30/es.md) | labs/112 (Tarea 7) |
| **falco_rules.local.yaml** | El archivo preferido para anulaciones locales y reglas Falco personalizadas. | [29](29/es.md), [30](30/es.md) | labs/112 (Tareas 3, 7, 9) |
| **False positive** | Un hallazgo inaplicable a un recurso en particular; requiere una excepción limitada y documentada. | [27](27/es.md) | |
| **fixed version** | La versión del componente en la que el proveedor arregló un CVE. | [13](13/es.md), [28](28/es.md) | |
| **footprint** | Los paquetes, procesos, puertos, sockets y configuración que aumentan la superficie de ataque de un nodo. | [14](14/es.md) | labs/105 (Tareas 1-2) |
| **Gatekeeper** | Un motor de políticas OPA basado en Kubernetes con el modelo `ConstraintTemplate` y `Constraint`. | [20](20/es.md), [26](26/es.md) | |
| **Grype** | Un escáner del ecosistema Anchore para imágenes de contenedores y SBOM. | [28](28/es.md) | |
| **gVisor** | Un tiempo de ejecución de espacio aislado con un kernel de espacio de usuario; su tiempo de ejecución OCI y su controlador CRI a menudo se denominan `runsc`. | [03](03/es.md), [22](22/es.md) | labs/110 (Tareas 1-3) |
| **handler** | El nombre del tiempo de ejecución en la configuración CRI; debe coincidir con `RuntimeClass.spec.handler`. | [22](22/es.md) | labs/110 (Tarea 1) |
| **Hardware root of trust** | Una cadena de confianza criptográfica basada en un dispositivo físico (TPM/vTPM), utilizada para verificar la integridad de la cadena de arranque del nodo (BIOS/UEFI → gestor de arranque → kernel → tiempo de ejecución); La verificación se encuentra fuera del Kubernetes API. | [30](30/es.md) | |
| **host endpoint** | Un punto final de red de nodos, en lugar de un Pod normal en el plano de datos CNI. | [05](05/es.md) | |
| **host firewall** | Filtrado de tráfico en el propio nodo, por ejemplo con `ufw`, `iptables` o `nftables`. | [15](15/es.md) | labs/105 (Tarea 3) |
| **host namespace** | Un espacio de nombres de nodo compartido por Pod a través de `hostPID`, `hostNetwork` o `hostIPC`. | [18](18/es.md) | labs/101 (Tarea 7) |
| **Host PID** | El proceso contenedor PID en el espacio de nombres del nodo PID, necesario para `/proc` y `strace`. | [30](30/es.md) | labs/112 (Tarea 6) |
| **HSM (Hardware Security Module)** | Un dispositivo físico de almacenamiento de claves criptográficas (por ejemplo, para una clave privada de CA kube-apiserver o una clave maestra de KMS) que impide la extracción por software de la clave privada. | [21](21/es.md), [30](30/es.md) | |
| **Hubble** | Observabilidad de los flujos de red Cilium. | [06](06/es.md) | labs/102 (Tarea 5) |
| **identity** | Un identificador de punto final Cilium derivado de una etiqueta; distinto del proveedor `identity`. | [06](06/es.md), [21](21/es.md) | labs/102 |
| **ImagePolicyWebhook** | Un complemento de admisión que delega decisiones de imágenes a un backend externo a través de `ImageReview`. | [26](26/es.md) | |
| **IMDS** | Metadatos de instancia Service, el punto final de metadatos de instancia del proveedor de la nube. | [05](05/es.md) | labs/101 (Tarea 5) |
| **IMDSv2** | La variante de AWS IMDS que requiere un token temporal para las solicitudes de metadatos. | [05](05/es.md) | |
| **Immutable infrastructure** | Un enfoque que reemplaza un artefacto de producción con una nueva versión verificada en lugar de cambiarlo en tiempo de ejecución. | [02](02/es.md), [31](31/es.md) | |
| **include** | Una directiva que carga un archivo externo: SSH `Include`, AppArmor `#include` o `include:` en configuración de verificación. | [15](15/es.md), [16](16/es.md), [27](27/es.md) | labs/105 (Tarea 5) |
| **Ingress** | Tráfico que ingresa a un Pod, o al objeto Kubernetes API que enruta un HTTP/HTTPS externo a un Service; el contexto determina el significado. | [04](04/es.md), [08](08/es.md) | labs/101 (Tarea 2), labs/103 (Tarea 4) |
| **IngressClass** | Selección de una implementación Ingress, como el controlador NGINX Ingress. | [08](08/es.md) | |
| **Inner packet** | El flujo original de Pod a Pod es visible antes del cifrado o después del descifrado. | [23](23/es.md) | labs/110 (Tarea 5) |
| **ipBlock** | Una regla de entrada/salida para un CIDR o IP individual; `except` excluye direcciones y subredes. | [04](04/es.md), [05](05/es.md) | labs/101 (Tarea 6) |
| **IPsec ESP** | Una carga útil protegida a nivel de IP que proporciona confidencialidad e integridad entre asociaciones de seguridad. | [23](23/es.md) | |
| **Kata Containers** | Un tiempo de ejecución que lanza un entorno limitado Pod en una máquina virtual ligera con un kernel invitado. | [03](03/es.md), [22](22/es.md) | |
| **KEK/DEK** | Clave de cifrado de clave y clave de cifrado de datos en cifrado de sobre. | [21](21/es.md) | |
| **kernel module** | Un módulo de kernel cargable, unidireccional Falco captura eventos. | [29](29/es.md) | labs/105 (Tarea 7) |
| **Keyless signing** | Firmar con un certificado de corta duración después de la autenticación OIDC en lugar de una clave de firma local persistente. | [26](26/es.md) | labs/111 (Tarea 7) |
| **Kill chain** | La secuencia de fases de ataque desde el acceso inicial a un objetivo, como la exfiltración. | [02](02/es.md), [30](30/es.md) | labs/112 (Tarea 6) |
| **kube-bench** | Una herramienta de verificación de configuración que utiliza perfiles de referencia CIS Kubernetes. | [07](07/es.md), [33](33/es.md) | labs/103 (Tareas 1, 7) |
| **kube-linter** | Un linter de gráficos Kubernetes YAML y Helm con comprobaciones de mejores prácticas. | [27](27/es.md) | labs/111 (Tarea 2) |
| **kubelet** | El agente de nodo Kubernetes; su punto final seguro generalmente escucha en el puerto `10250`. | [05](05/es.md), [07](07/es.md) | labs/103 (Tarea 2), labs/105 (Tarea 8) |
| **kubesec** | Un escáner de manifiesto Kubernetes que informa una puntuación y controles de seguridad. | [27](27/es.md) | labs/111 (Tareas 2, 4) |
| **Kyverno** | Un motor de políticas nativo Kubernetes con reglas YAML: `validate`, `mutate`, `generate` y `verifyImages`. | [20](20/es.md), [26](26/es.md), [31](31/es.md) | labs/108, labs/111 (Tarea 9a), labs/112 (Tarea 9) |
| **L3/L4** | La capa de red y el protocolo/puerto de transporte en una política Cilium. | [06](06/es.md) | labs/102 (Tarea 2) |
| **L7** | La capa de protocolo, como el método/ruta HTTP o DNS (el filtrado Kafka Cilium está en desuso). | [06](06/es.md) | labs/102 (Tarea 3) |
| **lateral movement** | Un atacante que pasa de una carga de trabajo comprometida a otros sistemas, datos o identidades. | [02](02/es.md), [04](04/es.md) | |
| **least privilege** | Otorgar a una identidad solo los permisos, el alcance y la duración mínimos necesarios. | [02](02/es.md), [10](10/es.md), [15](15/es.md) | labs/104 (Tarea 1) |
| **legacy annotation** | Una anotación beta obsoleta de AppArmor, leída para la migración pero no utilizada para el nuevo Pods. | [16](16/es.md) | |
| **level** | El detalle de los datos en un evento de auditoría: `None`, `Metadata`, `Request` o `RequestResponse`. | [32](32/es.md) | labs/112 (Tarea 4) |
| **Linkerd identity** | Una identidad Linkerd mTLS, generalmente derivada de una ServiceAccount. | [23](23/es.md) | |
| **live-restore** | Un modo Docker que mantiene los contenedores en ejecución cuando se reinicia el demonio. | [14](14/es.md) | |
| **Localhost** | El tipo Kubernetes para un perfil AppArmor/seccomp precargado en un nodo. | [16](16/es.md), [17](17/es.md) | labs/106 (Tareas 2, 4) |
| **localhostProfile** | Una ruta de perfil JSON relativa a la raíz kubelet seccomp. | [17](17/es.md) | labs/106 (Tarea 4) |
| **MAC** | Control de acceso obligatorio, una política de acceso que se aplica además de UID/GID y bits de modo. | [03](03/es.md), [16](16/es.md) | |
| **macro** | Un fragmento con nombre reutilizable de una condición Falco. | [29](29/es.md) | labs/112 (Tarea 7) |
| **mTLS** | TLS en el que tanto el cliente como el servidor presentan certificados. | [23](23/es.md) | labs/110 (Tarea 6) |
| **Multi-stage build** | Un Dockerfile con etapas de compilación y tiempo de ejecución separadas conectadas por `COPY --from=`. | [24](24/es.md) | |
| **Mutating admission webhook** | Un webhook que agrega o modifica un objeto antes de la validación. | [20](20/es.md) | labs/108 (Tarea 5) |
| **namespace** | Una vista aislada de un recurso del núcleo para un grupo de procesos; distinto de un espacio de nombres Kubernetes. | [03](03/es.md) | labs/106 (Tarea 6) |
| **namespaceSelector** | Seleccionar espacios de nombres Kubernetes por etiquetas para una regla NetworkPolicy entre espacios de nombres. | [04](04/es.md) | labs/101 (Tarea 6) |
| **network namespace** | Aislamiento de las interfaces, rutas y pila de red de un proceso. | [03](03/es.md) | |
| **no_new_privs** | Un indicador del kernel que impide privilegios adicionales a través de `exec`; habilitado por `allowPrivilegeEscalation: false`. | [18](18/es.md) | |
| **Node authorizer** | Un autorizador para acciones de identidad kubelet en los objetos Node y Pod que necesita. | [12](12/es.md) | |
| **Node encryption** | Protección del tráfico entre nodos; no es equivalente a la identidad de una carga de trabajo particular. | [23](23/es.md) | labs/110 (Tareas 4-5) |
| **NodeRestriction** | Un complemento de admisión que restringe aún más kubelet a su nodo y al Pods asignado a él. | [12](12/es.md) | |
| **Notary Project / Notation** | Un ecosistema de firma OCI con política de confianza X.509; La aplicación de Kubernetes requiere integración de admisión. | [26](26/es.md) | |
| **OCI** | Un estándar abierto para formatos de artefactos e imágenes de contenedores utilizados por registros y herramientas de firma. | [25](25/es.md), [26](26/es.md) | labs/111 |
| **OPA** | Open Policy Agent, un motor de políticas que ejecuta reglas declarativas Rego. | [20](20/es.md), [27](27/es.md) | |
| **Outer packet** | Un paquete cifrado entre las IP de los nodos de la red física. | [23](23/es.md) | labs/110 (Tarea 5) |
| **partial credit** | Crédito por partes independientes y correctamente completadas de una tarea. | [33](33/es.md) | |
| **PeerAuthentication** | Una política mTLS entrante Istio; `STRICT` rechaza el texto sin formato. | [23](23/es.md) | labs/110 (Tarea 6) |
| **Performance-based** | Un formato de examen que requiere resultados en un entorno de trabajo en lugar de seleccionar respuestas de prueba. | [01](01/es.md), [33](33/es.md) | |
| **PID namespace** | Aislamiento de la lista de procesos y proceso PIDs. | [03](03/es.md) | |
| **Pod UID** | El inmutable UID de una instancia específica de Pod, más confiable que su nombre para la correlación. | [30](30/es.md) | |
| **podSelector** | Seleccionando Pods por etiquetas dentro del espacio de nombres NetworkPolicy. | [04](04/es.md) | labs/101 (Tareas 2, 6) |
| **PolicyReport** | Un informe de los resultados de la verificación de políticas, cuando el motor de políticas instala este API. | [31](31/es.md) | |
| **private key** | La parte secreta de un par de claves asimétricas; utilizado de acuerdo con el protocolo/herramienta para la identidad TLS (capítulos 07-08) o una clave de firma Cosign (laboratorio 111). Ambos requieren acceso restringido, normalmente `0600`. | [07](07/es.md), [08](08/es.md) | labs/111 (Tarea 9a) |
| **profiling** | Procesar puntos finales de diagnóstico de rendimiento; deshabilite con `--profiling=false` a menos que sea necesario. | [07](07/es.md), [12](12/es.md) | labs/103 (Tarea 3) |
| **projected volume** | Un volumen que combina tokens, ConfigMaps, API descendente y otras fuentes en archivos Pod. | [11](11/es.md) | labs/104 (Tarea 2) |
| **provenance** | Metadatos sobre el origen, las entradas, el constructor y el proceso de compilación (certificación) de un artefacto. El origen verificable es independiente de la verificación simple de la firma: `cosign sign`/`verify` demuestra una firma/identidad, no todo el historial de compilación; Sigstore proporciona `cosign attest`/`verify-attestation` para la procedencia. | [09](09/es.md), [25](25/es.md), [26](26/es.md) | |
| **provider** | Un mecanismo que cifra y descifra recursos API específicos. | [21](21/es.md) | labs/109 (Tarea 2) |
| **PSA** | Admisión de seguridad Pod, el controlador de admisión de validación incorporado para PSS. | [19](19/es.md), [31](31/es.md) | labs/107 (Tareas 1, 3-4) |
| **PSP** | PodSecurityPolicy, el predecesor PSA eliminado en Kubernetes 1.25. | [19](19/es.md) | |
| **PSS** | Estándares de seguridad Pod: los perfiles predefinidos `privileged`, `baseline` y `restricted`. | [19](19/es.md) | labs/107 |
| **purl** | URL del paquete, un identificador del paquete que incluye su ecosistema y versión. | [25](25/es.md) | |
| **re-encryption** | Reescribir objetos API antiguos mediante un nuevo proveedor o clave de cifrado. | [21](21/es.md) | labs/109 (Tarea 2) |
| **read-only kubelet port** | Un puerto kubelet heredado no autenticado que debe deshabilitarse con `0`. | [07](07/es.md), [09](09/es.md), [12](12/es.md) | labs/103 (Tarea 2) |
| **read-only root filesystem** | Un modo que evita cambios en la capa de imagen; las escrituras permitidas van a los volúmenes. | [18](18/es.md), [31](31/es.md), [33](33/es.md) | labs/107 (Tarea 5), labs/112 (Tarea 5) |
| **Registry allowlist** | Una política que permite imágenes solo de identidades de registro/repositorio enumeradas explícitamente. Especificar coincidencia exacta versus prefijo: el laboratorio 112 muestra que el prefijo/`startsWith` puede admitir imitaciones (`library/busybox-evil` para `library/busybox`), por lo que utiliza coincidencia exacta. | [26](26/es.md) | labs/112 (Tarea 9) |
| **release cadence** | La frecuencia de lanzamientos menores y de parches. | [13](13/es.md) | |
| **remediation** | Eliminar un riesgo actualizando un artefacto, dependencia o imagen base y verificando el resultado. | [28](28/es.md) | |
| **Rendered manifest** | El YAML final después de `helm template` o `kustomize build`, que se analizará antes de la implementación. | [27](27/es.md) | |
| **RoleBinding** | Un enlace de espacio de nombres de un Role o ClusterRole a un sujeto, como ServiceAccount. | [10](10/es.md), [11](11/es.md) | labs/104 (Tarea 1) |
| **Rootless Podman** | Un modo Podman donde un usuario normal realiza la compilación/ejecución, en lugar de un demonio raíz. | [24](24/es.md) | |
| **rotation** | Cambiar el nombre y eliminar archivos de registro antiguos por tamaño, recuento o antigüedad. | [21](21/es.md), [32](32/es.md) | labs/112 (Tarea 4) |
| **rule** | Un detector denominado Falco con una condición, salida y prioridad. | [29](29/es.md) | labs/112 (Tareas 3, 7, 9) |
| **runtime detection** | Detectar comportamiento sospechoso de un proceso en ejecución mediante llamadas al sistema/eBPF y metadatos de tiempo de ejecución. | [01](01/es.md), [29](29/es.md), [30](30/es.md) | labs/112 |
| **Runtime mutation** | Cambiar el sistema de archivos o la configuración de un contenedor en ejecución. | [31](31/es.md) | labs/112 (Tarea 5) |
| **runtime overhead** | Se corrigió CPU/memoria adicional contabilizada por el programador para Pods de un RuntimeClass elegido. | [22](22/es.md) | |
| **RuntimeClass** | Un recurso Kubernetes con ámbito de clúster que selecciona un controlador CRI y restricciones de programación y gastos generales opcionales. | [19](19/es.md), [22](22/es.md) | labs/110 (Tarea 1) |
| **RuntimeDefault** | Un perfil proporcionado por el tiempo de ejecución del contenedor elegido para AppArmor o seccomp. | [16](16/es.md), [17](17/es.md), [18](18/es.md) | labs/106 (Tarea 3), labs/107 (Tarea 2) |
| **sandbox pool** | Nodos dedicados con runtime, label, taint y capacidad preparados. | [22](22/es.md) | labs/110 |
| **sandboxed runtime** | Un tiempo de ejecución con un límite de aislamiento más fuerte, como gVisor o Kata Containers. | [03](03/es.md), [22](22/es.md) | labs/110 (Tareas 1-3) |
| **SCMP_ACT_ERRNO** | Una acción seccomp que devuelve un error para una llamada al sistema sin ejecutarla. | [17](17/es.md) | labs/106 (Tarea 4) |
| **SCMP_ACT_LOG** | Una acción seccomp que permite una llamada al sistema y solicita el registro del kernel. | [17](17/es.md) | |
| **seccomp** | Un mecanismo Linux que filtra las llamadas al sistema de un proceso. | [03](03/es.md), [17](17/es.md), [18](18/es.md) | labs/106 (Tareas 3-5, 7) |
| **SECCOMP audit record** | Un registro de kernel/auditoría de un evento relacionado con seccomp. | [17](17/es.md) | |
| **Secret mount** | Montar temporalmente una credencial para un comando de compilación sin escribirla en la capa final. | [24](24/es.md) | |
| **security advisory** | Aviso principal del proveedor sobre las versiones afectadas, las condiciones de explotación, la mitigación y una versión reparada. | [13](13/es.md) | |
| **SecurityContext** | Kubernetes campos que definen la identidad y restricciones de un proceso o Pod. | [18](18/es.md), [33](33/es.md) | labs/106, labs/107 (Tarea 2) |
| **self-signed certificate** | Un certificado firmado por su propia clave en lugar de una CA confiable; adecuado para pruebas pero no confiable de forma predeterminada. | [08](08/es.md) | labs/103 (Tarea 4) |
| **SELinux** | MAC basado en etiquetas con aplicación de tipos, que complementa los permisos de acceso ordinarios. | [03](03/es.md) | |
| **ServiceAccount (SA)** | Una identidad con espacio de nombres para Pods y procesos en Kubernetes API. | [11](11/es.md), [23](23/es.md) | labs/104 (Tareas 2-3) |
| **severity** | Clase de gravedad de un hallazgo: `LOW`, `MEDIUM`, `HIGH` o `CRITICAL`. | [28](28/es.md) | labs/111 (Tarea 1) |
| **SHA-256 checksum** | Un resumen de archivo de 256 bits que verifica la igualdad byte por byte con un artefacto publicado. | [09](09/es.md) | labs/103 (Tarea 6) |
| **shim** | Un proceso containerd o binario que conecta containerd con un tiempo de ejecución particular. | [22](22/es.md) | labs/110 (Tarea 1) |
| **Sidecar** | Un proxy u otro contenedor auxiliar junto con una aplicación que intercepta o sirve el tráfico. | [23](23/es.md) | labs/110 (Tarea 6) |
| **SLSA** | Un modelo de madurez para las prácticas de seguridad de la cadena de suministro de software. | [25](25/es.md) | |
| **Software supply chain** | La ruta del código fuente, las dependencias, los sistemas de compilación y los artefactos hacia una carga de trabajo en ejecución. | [25](25/es.md) | labs/111 |
| **SPDX** | Un estándar abierto que describe paquetes, licencias y sus relaciones en un SBOM. | [25](25/es.md), [28](28/es.md) | labs/111 (Tarea 6) |
| **SSRF** | Falsificación de solicitudes del lado del servidor, una vulnerabilidad que hace que un servidor solicite una dirección elegida por el atacante. | [05](05/es.md) | labs/101 (Tarea 5) |
| **stage** | La etapa de creación de eventos de auditoría: `RequestReceived`, `ResponseStarted`, `ResponseComplete` o `Panic`. | [32](32/es.md) | labs/112 (Tarea 4) |
| **static analysis** | Comprobación de Dockerfiles, manifiestos y políticas sin ejecutar una carga de trabajo. | [27](27/es.md) | labs/111 (Tarea 2) |
| **static Pod** | Un Pod de un manifiesto local de nodo, administrado por kubelet sin programación a través de Kubernetes API. | [07](07/es.md), [09](09/es.md), [12](12/es.md), [32](32/es.md), [33](33/es.md) | labs/103, labs/104 (Tarea 5), labs/112 (Tarea 4) |
| **sudoers** | Una política de comandos que un usuario puede ejecutar como otro usuario; editar con `visudo`. | [15](15/es.md) | |
| **SUID/SGID** | Bits de archivos especiales que ejecutan un programa con el UID efectivo del propietario o el GID del grupo. | [15](15/es.md) | |
| **support window** | Las versiones compatibles reciben parches de seguridad. | [13](13/es.md) | |
| **Syft** | Una herramienta que genera SBOM a partir de imágenes, sistemas de archivos o archivos. | [25](25/es.md) | labs/111 (Tarea 7) |
| **syscall** | Una llamada al sistema a través de la cual un proceso solicita una operación del kernel. | [03](03/es.md), [17](17/es.md), [29](29/es.md) | labs/106 (Tareas 4-5) |
| **system:unauthenticated** | El grupo del sujeto anónimo; Las fijaciones requieren la misma revisión que las de `system:anonymous`. | [12](12/es.md) | |
| **systemd unit** | Una definición de un servicio, socket, temporizador u otra entidad administrada por systemd. | [14](14/es.md) | labs/105 (Tarea 1) |
| **TLS minimum version** | La versión mínima de TLS que un servidor negociará con un cliente. | [09](09/es.md) | labs/103 (Tarea 5) |
| **TLS Secret** | Un `kubernetes.io/tls` Secret que contiene `tls.crt` y `tls.key`. | [08](08/es.md) | labs/103 (Tarea 4) |
| **TLS termination** | Completar el protocolo de enlace TLS y descifrar el tráfico en un controlador de ingreso. | [08](08/es.md) | labs/103 (Tarea 4) |
| **toFQDNs** | Una regla de salida Cilium que utiliza nombres DNS y respuestas observadas de DNS. | [06](06/es.md) | labs/102 (Tarea 4) |
| **TokenRequest API** | Un API que emite tokens ServiceAccount de corta duración. | [11](11/es.md) | labs/104 (Tarea 2) |
| **Transparent encryption** | Cifrado de ruta de datos sin aplicación, Service o cambios de URL; Cilium lo aplica en nodos. | [23](23/es.md) | labs/110 (Tarea 4) |
| **triage** | Clasificar rápidamente un hallazgo o evento por fuente, riesgo, alcance y próxima acción. | [33](33/es.md) | |
| **Trivy** | Un escáner de imágenes, SBOM, sistemas de archivos, secretos y configuración/IaC. | [28](28/es.md), [33](33/es.md) | labs/111 (Tareas 1, 5, 8) |
| **Unconfined** | Sin filtro seccomp para un contenedor; una excepción temporal, no una línea de base. | [17](17/es.md) | labs/106 (Tarea 5) |
| **Unix socket** | Un punto final IPC del sistema de archivos local; sus permisos determinan quién puede acceder a un demonio API. | [14](14/es.md) | labs/105 (Tarea 6) |
| **userns-remap** | Una función de demonio Docker (`dockerd --userns-remap`) que reasigna el contenedor UID/GID en el host dentro del propio Docker; separado de los espacios de nombres de usuario Kubernetes Pod (`hostUsers: false`) probado en el laboratorio 106. | [14](14/es.md) | |
| **Validating admission webhook** | Un webhook que permite o rechaza un objeto. | [20](20/es.md) | |
| **ValidatingAdmissionPolicy** | Validación CEL incorporada en el servidor API sin un webhook externo; aplicado a través de una encuadernación. | [20](20/es.md) | labs/107 (Tarea 6) |
| **version skew** | La diferencia de versión permitida entre los componentes Kubernetes; kubelet no debe ser más nuevo que el servidor API. | [13](13/es.md) | |
| **webhook collector** | Un terminal HTTPS que recibe eventos de auditoría para almacenamiento y análisis centralizados. | [32](32/es.md) | labs/112 (Tarea 8) |
| **WireGuard** | Un protocolo VPN con pares de claves de pares; la clave pública identifica al par permitido. | [23](23/es.md) | labs/110 (Tareas 4-5) |
| **Workload identity** | Una identidad de carga de trabajo verificable criptográficamente, generalmente vinculada a ServiceAccount/espacio de nombres en una malla. | [23](23/es.md) | labs/110 (Tarea 6) |
| **Writable layer** | Una capa mutable agregada por el tiempo de ejecución sobre capas de imágenes de solo lectura. | [31](31/es.md) | |
| **Zero trust** | Rechazar la confianza implícita basada en la red, el espacio de nombres o la ubicación. | [02](02/es.md) | |
