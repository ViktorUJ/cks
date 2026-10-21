[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 - análisis de imágenes, correcciones estáticas y supply-chain evidence

## Objetivo

En este laboratorio de CKS reunirás artefactos de evidence reproducibles para una aplicación
contenedorizada: informes de vulnerabilidades y de analizadores estáticos, correcciones seguras
del `Dockerfile` y del manifest del workload, dos SBOM, la búsqueda de versiones de dependencias y la verificación de
la firma de la imagen. El resultado no es simplemente la salida de un terminal: cada informe debe estar
guardado en el lugar indicado y ser apto para una auditoría.

Esta es una tarea de CKS sobre security tooling y supply chain, y no un ejercicio de CKA. La mayoría de los
artefactos se analizan localmente en el worker; la única excepción es la tarea 4, donde
hay que aplicar un Deployment hardened para comprobar Ready/Available y un HTTP smoke test.

## Threat model

El laboratorio modela la confianza en la supply chain a través de varias amenazas independientes. El código
malicioso o las debilidades conocidas en la image las detectan los escáneres Trivy, kubesec,
kube-linter y Hadolint en los niveles correspondientes de la imagen, el Dockerfile y los manifests.

Los secrets y tokens olvidados por accidente en un layer requieren una comprobación aparte: secret
scanning (por ejemplo, Trivy secret scanning) e inspection del history de la imagen (`docker history`,
extracción de capas). El SBOM resuelve otra tarea: el inventario de componentes y versiones de
paquetes; ayuda a la supply-chain investigation (por ejemplo, a encontrar una biblioteca vulnerable),
pero no es un mecanismo fiable para buscar secrets en el historial de capas y no sustituye al secret
scanning. Incluso si la configuración de trabajo ya no contiene el secret, este puede seguir
accesible en el historial de capas.

La amenaza de mutable-tag tampering consiste en que, tras el despliegue, detrás de la misma referencia con etiqueta, sin modificar,
se puede colocar otra imagen maliciosa. Precisamente por eso el digest pinning es importante en
las tareas 3–5: fija el contenido concreto de la imagen, y no solo su nombre y etiqueta.

La verificación de la firma en la tarea 7 demuestra que un digest concreto está firmado por una
key/identity de confianza (signature integrity), mientras que el Trivy scan de la tarea 1 no detecta
vulnerabilidades conocidas que entren en su detection coverage con la vulnerability DB actual
(el propio Trivy documenta un trade-off en favor de la precision, en el que son posibles false
negatives: "0 findings" no es igual a una formal proof de ausencia de vulnerabilidades). Son ejes distintos de
protección: ninguno sustituye al otro, ya que vulnerability != signature. La firma
NO es lo mismo que provenance/attestation
(por ejemplo, build metadata de estilo SLSA sobre de qué y cómo se construyó el artifact): `cosign
verify` confirma la autenticidad de la firma, y no el historial completo de la build; para attestation
Sigstore ofrece comandos aparte `cosign attest`/`cosign verify-attestation`, no
utilizados en este laboratorio.

La `cosign verify` local (tarea 7) por sí sola no es enforcement: demuestra la
firma de una image reference concreta en el momento de la comprobación, pero no impide que alguien ejecute una
imagen sin firmar o firmada de otro modo con un `kubectl apply` directo, esquivando el CI. Solo la
comprobación admission-time (tarea 9a-9c) convierte la firma en una condición obligatoria para admitir un
Pod en el clúster: esa es la diferencia entre «hemos comprobado la firma» y «el clúster no ejecutará una
imagen sin firmar».

La prueba de esta propiedad requiere cuidado: un nuevo `kubectl apply` de un Deployment ya
existente no crea un nuevo Pod si el template no ha cambiado, por lo que
`Running` puede significar «un Pod antiguo, creado antes de la policy», y no «la policy admitió
precisamente esta imagen» (la tarea 9b comprueba `creationTimestamp` explícitamente). Del mismo modo, el DENY
de unsigned demuestra la propiedad solo si el digest comprobado realmente existe y es pullable en el
mismo repository que la imagen firmada (tarea 9c); de lo contrario el admission puede rechazar
por un manifest ausente en el registry, y no por la ausencia de firma.

## Compruébate antes de empezar

<details>
<summary>1. ¿Por qué el SBOM no es un mecanismo fiable para buscar secrets olvidados en un image layer?</summary>

El SBOM resuelve la tarea de inventario de COMPONENTES y versiones de paquetes (qué está instalado, qué versión): es un análisis estructural de los metadatos del gestor de paquetes, y no una búsqueda de cadenas/secrets arbitrarios en el contenido de los archivos de las capas. Un secret dejado, por ejemplo, en una variable de entorno ENV o en un archivo temporal durante la build, puede permanecer en el historial de capas incluso después de que la capa final ya no lo contenga: para eso hace falta una herramienta aparte (secret scanning, `docker history`, extracción de capas), y no SBOM.
</details>

<details>
<summary>2. ¿Cuál es la diferencia entre lo que demuestra el Trivy scan (tarea 1) y lo que demuestra la firma de Cosign (tarea 9a-9c)?</summary>

En el momento de la comprobación, con la vulnerability DB actual y la lógica de detección de Trivy, el escaneo NO DETECTÓ vulnerabilidades conocidas que entren en su detection coverage: eso trata de la calidad/seguridad del contenido de la imagen en la medida en que Trivy es capaz de verlo. La propia documentación de Trivy describe directamente un trade-off en favor de la precision (minimización de false positives), en el que son posibles false negatives; es decir, "0 findings" no equivale a la prueba formal de la ausencia total de vulnerabilidades. La firma de Cosign demuestra SIGNATURE INTEGRITY: que un digest concreto está firmado por una clave/identity de confianza, es decir, que alguien autorizado confirmó que este es precisamente el artifact que debe desplegarse. Esto NO es lo mismo que provenance/attestation (el historial completo de la build: de qué, por quién y cómo se construyó el artifact): para attestation en Sigstore hay comandos aparte (`cosign attest`/`cosign verify-attestation`), no usados en este laboratorio. Una imagen puede ser completamente segura (0 CVE) y a la vez no estar firmada, o estar firmada, pero contener una vulnerabilidad desconocida. Son dos ejes independientes de protección.
</details>

<details>
<summary>3. ¿Por qué `cosign verify` local en CI no impide que alguien despliegue una imagen sin firmar mediante `kubectl apply`?</summary>

`cosign verify`, ejecutado localmente (por ejemplo, en un CI pipeline), es simplemente un comando que comprueba la firma y devuelve el resultado a quien lo invocó. No está integrado en el camino del admission de la Kubernetes API: nada impide que alguien con acceso al clúster simplemente ejecute `kubectl apply` con CUALQUIER imagen, esquivando el CI por completo. Solo la comprobación admission-time (tarea 9a-9c), integrada en el propio clúster como policy, convierte la firma en una condición OBLIGATORIA de admisión: esa es la diferencia entre "hemos comprobado" y "el clúster físicamente no la dejará pasar".
</details>

## Infraestructura

El entorno lo crea Terragrunt en AWS `eu-central-1`.

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.111.0.0/16` con subredes públicas |
| `ssh-keys` | acceso al nodo |
| `k8s-1` | kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd y **Calico** |
| `worker` | estación de trabajo para el análisis, `kubectl`, `check_result` y security tools |

Infraestructura de estilo CKA: el único nodo control-plane está permitido para workload y
marcado con `cks.io/lab=111`. Los comandos principales y las security tools se ejecutan en el worker.
El clúster de Kubernetes se usa como target environment para comprobar el workload hardened y
la signature policy admission-time: la tarea 4 despliega `catalog`, y las tareas 9b/9c
realizan los admission probes positive/negative.

En el worker están disponibles de antemano exactamente estas versiones fijas:

| Herramienta | Versión | Finalidad |
|---|---:|---|
| Trivy | `0.74.0` | CVE y lista de paquetes de la imagen |
| kubesec | `2.14.0` | security score del YAML de Kubernetes |
| kube-linter | `0.8.3` | policy lint del YAML de Kubernetes |
| Hadolint | `2.12.0` | lint del Dockerfile |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (formato nativo de `bom`) |
| Cosign | `3.1.3` | signing y verification de la firma de una imagen OCI |

Helm e `install-kyverno` también están disponibles en el worker, pero Kyverno deliberadamente **no está instalado**:
su instalación forma parte de la tarea 9, como en el laboratorio 108. `install-kyverno` fija Kyverno
`1.19`/chart `3.9.0`; la support matrix oficial upstream para esta versión es Kubernetes
`1.33-1.35`, mientras que este clúster está en `1.36`. Es una excepción lab-specific consciente, fuera del
rango probado (igual que el precedente del laboratorio 108), y no un soporte oficial
garantizado; al actualizar Kyverno, retira esta excepción.

## Requisitos previos y limitaciones

**podman y el registry en el banco de pruebas ya están configurados.** Para construir y publicar imágenes usa `podman`
(herramienta de la lista del examen; rootless, como el usuario `ubuntu`). Las tareas 3 y 9c exigen construir y
**publicar** una imagen en un registry accesible tanto desde el worker como desde el clúster (la referencia inmutable
`repo@sha256:...` se toma del registry, un image ID local no sirve). Ese registry,
`registry:2` en el control-plane, lo levantó el bootstrap:

- dirección: `<IP del control-plane>:5000`, está anotada en `/etc/cks111/registry` en el worker;
- el protocolo es HTTP normal dentro de la VPC: podman en el worker y containerd en el nodo están configurados para él como
  insecure registry (el flag `--tls-verify=false` no hace falta), y en la `ImageValidatingPolicy` para Kyverno hace falta
  `credentials.allowInsecureRegistry: true`;
- los datos se guardan en un PV local del nodo (`/var/lib/cks111-registry`), por lo que sobreviven al
  reinicio del Pod del registry;
- el digest de la imagen publicada obtenlo de `podman push --digestfile`, y la presencia del manifest
  compruébala con una petición a `/v2/` (en el registry no hay herramientas solo-HTTPS como `docker buildx imagetools`);
- la secuencia detallada de comandos está en el paso «0. Preparación» de la [solución](worker/files/solutions/1_ES.MD).

**Límite de Docker Hub.** Los pull anónimos desde una misma IP tienen un límite (unas 100 peticiones cada 6 horas).
Para que `check_result` no choque con él, el bootstrap descarga una sola vez las imágenes del laboratorio a una caché local
(`nginx:1.27.3-alpine` y los candidatos para las tareas 1b/1c), y Trivy y Syft en los escaneos repetidos toman la
imagen de esa caché por la misma referencia `nombre@sha256:...`, sin acudir a Docker Hub. `bom` sabe
leer la imagen solo desde el registry, por lo que sigue haciendo varias peticiones por ejecución.
Si aun así Docker Hub devuelve `TOOMANYREQUESTS`, espera (la ventana del límite es deslizante) o ejecuta
`podman login docker.io` con tu propia cuenta.

**Cosign y la contraseña de la clave.** `cosign generate-key-pair` y `cosign sign --key` piden la contraseña de
la clave; para un par didáctico se puede dejar vacía (`export COSIGN_PASSWORD=""`), para que los comandos
no esperen una entrada.

**`trivy sbom` y un SBOM sin SO (tarea 8).** El SPDX de `bom` para una imagen multi-arch no contiene
información sobre el SO: Trivy escribe `Detected OS family="none"` y no encuentra vulnerabilidades (`Results` vacío).
Por eso en la tarea 8 se escanea el CycloneDX de la tarea 7: en él hay un componente `operating-system`,
y `trivy sbom` da un `Results` no vacío.

## Despliegue

```bash
TASK=111 make run_cks_task
```

Conéctate al worker y elige el contexto:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

Inicialmente `Dockerfile` y `deployment.yaml` son deliberadamente inseguros. Crea los artefactos de trabajo
solo en `/var/work/tests/artifacts/<número>/`.

## Tareas

`nginx:1.27.3-alpine` es un mutable tag, y no una referencia fijada. Primero obtén el registry manifest digest canónico de `Metadata.RepoDigests[0]` del JSON de Trivy y usa la immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (en adelante `$IMAGE`). Para tu propia hardened image, primero construye y publica la image en un registry accesible para el clúster, y luego usa su manifest digest; un image ID local y un layer DiffID no son un registry manifest digest.

---
| **1** | **Trivy: informe de vulnerabilidades de la imagen** |
| :---: | :--- |
| Qué hacemos | • Escanea la `$IMAGE` inmutable con Trivy, incluidas las vulnerabilidades de OS y de bibliotecas.<br/>• Guarda el JSON estructurado en `/var/work/tests/artifacts/1/trivy-report.json`. |
| Criterios de aceptación | • **Archivo:** no vacío, el JSON lo analiza `jq`, contiene `Results` y la immutable reference de la imagen analizada.<br/>• **Comprobación nueva:** el checker repite por sí mismo `trivy image` para la misma imagen y exige que este escaneo nuevo coincida con éxito por `ArtifactName`.<br/>• Un JSON escrito a mano, pero sintácticamente válido, no pasa. |

<details>
<summary>💡 Pista para la tarea 1</summary>

`$IMAGE` se construye en dos pasos: primero escaneas `nginx:1.27.3-alpine` (un tag normal) y sacas `Metadata.RepoDigests[0]` de ESE primer informe JSON, luego reconstruyes el comando con `nginx:1.27.3-alpine@sha256:<digest>` y escaneas ya la referencia inmutable: precisamente este segundo informe es el que hay que guardar como final. No uses `ImageID`/`DiffID` de la salida de Trivy como sustituto del registry digest: son identificadores LOCALES, que no coinciden con el manifest digest en el registry.
</details>

---
| **1b** | **Multi-image CVE triage: encontrar la imagen que contiene una CVE concreta** |
| :---: | :--- |
| Qué hacemos | • Abre `~/cks-111/candidates.txt`: allí hay tres immutable image reference (`CANDIDATE_1/2/3`) y el `TARGET_CVE` objetivo, definidos individualmente para tu instancia del laboratorio durante el bootstrap.<br/>• Escanea **las tres** imágenes con Trivy y encuentra cuál de ellas realmente contiene `TARGET_CVE`.<br/>• Guarda el informe JSON precisamente de esa imagen en `/var/work/tests/artifacts/1b/target-scan.json`.<br/>• La línea `OFFENDING_IMAGE=<referencia completa de esta imagen>` guárdala en `/var/work/tests/artifacts/1b/answer.txt`. |
| Criterios de aceptación | • **Respuesta:** `answer.txt` indica precisamente el `CANDIDATE_N` cuyo escaneo real de Trivy contiene `TARGET_CVE`.<br/>• **Informe:** `target-scan.json` es la salida genuina de Trivy para esa misma imagen (el checker repite el escaneo por sí mismo y compara). |

<details>
<summary>💡 Pista para la tarea 1b</summary>

`TARGET_CVE` es distinta en cada instancia del laboratorio: se calcula durante el provisioning a partir de la vulnerability DB de Trivy en vivo, y no está fijada de antemano, así que en este archivo está tu propia respuesta. No adivines por el nombre de la etiqueta ("la más antigua, seguramente es la vulnerable"): escanea realmente las tres y encuentra la coincidencia exacta de `VulnerabilityID` dentro del JSON. Un comando por imagen: `trivy image --format json "$ref" | tee scan.json`, luego `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json`: `null` significa que esa CVE concreta no está precisamente en esa imagen (en ella pueden perfectamente estar otras CVE: eso no se comprueba).
</details>

---
| **1c** | **Análisis de las imágenes de workload por nivel CRITICAL** |
| :---: | :--- |
| Qué hacemos | • En el namespace `cks-111` ya hay desplegados 4 Deployment (label `cks.io/task=1c`), cada uno con una sola image immutable fijada por digest.<br/>• Obtén las image references de estos Deployments LIVE (no adivines por el nombre del tag), escanea **las 4** imágenes con Trivy con `--severity CRITICAL` y cuenta el número de `VulnerabilityID` CRITICAL únicas de cada una.<br/>• Determina el Deployment con el mayor número de CRITICAL ("el más vulnerable") y los dos Deployment con el menor número ("los dos menos vulnerables"). Anota sus nombres en `/var/work/tests/artifacts/1c/ranking.txt` como `MOST_VULNERABLE=<deployment-name>`, `LEAST_VULNERABLE_1=<deployment-name>`, `LEAST_VULNERABLE_2=<deployment-name>`.<br/>• Para la imagen del Deployment más vulnerable genera un CycloneDX SBOM **precisamente de Trivy** (`trivy image --format cyclonedx`) en `1c/cyclonedx.json`.<br/>• Después remedia: deja `replicas > 0` solo en los dos Deployment menos vulnerables, y los otros dos (incluido el más vulnerable) escálalos a `replicas: 0`. |
| Criterios de aceptación | • **Ranking:** el checker repite por sí mismo el escaneo CRITICAL de Trivy de las 4 live images y calcula el ranking de nuevo: `ranking.txt` debe coincidir con ese escaneo nuevo, y no con uno obsoleto/adivinado.<br/>• **SBOM:** `cyclonedx.json` es un documento CycloneDX válido precisamente de Trivy, referido a la imagen del Deployment realmente más vulnerable.<br/>• **Remediation:** exactamente 2 Deployment (los menos vulnerables según el escaneo nuevo) tienen `replicas > 0`, los otros 2, `replicas: 0`. |

<details>
<summary>💡 Pista para la tarea 1c</summary>

Obtén las image references con un comando del tipo `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...`: no intentes adivinar por el nombre del Deployment qué imagen es "más nueva" o "más segura". El comando para contar: `trivy image --scanners vuln --severity CRITICAL --format json <ref>`, luego `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`. Para CycloneDX usa precisamente `trivy image --format cyclonedx --output <file> <ref>`, no Syft (Syft ya se usa en la tarea 7 para otra imagen, aquí se exige explícitamente Trivy). El escalado se hace mediante `kubectl scale deployment/<name> -n cks-111 --replicas=0` (o `--replicas=1` para los que se conservan).
</details>

---
| **2** | **Informes iniciales del análisis estático** |
| :---: | :--- |
| Qué hacemos | • ANTES de las correcciones (sin tocar ninguno de estos tres archivos después de empezar la tarea 3) guarda los resultados: Hadolint en `2/hadolint-before.txt`, kubesec JSON en `2/kubesec-before.json`, kube-linter JSON en `2/kube-linter-before.json`.<br/>• Ejecútalos directamente contra los `Dockerfile`/`deployment.yaml` iniciales ORIGINALES.<br/>• No ocultes los errores mediante `\|\| true` en los archivos de informes: un exit code distinto de cero del linter es lo esperado. |
| Criterios de aceptación | • **Artefactos:** existen los tres; Hadolint contiene findings, kubesec contiene `scoring`, kube-linter es un objeto JSON de KubeLinter válido con los campos `Reports` y `Summary`; antes de las correcciones `Reports` contiene findings.<br/>• **Contraste con el baseline:** el checker compara el contenido de los tres artefactos con su propio baseline, tomado durante el provisioning contra los archivos iniciales originales ANTES de que se entregaran al estudiante.<br/>• Un informe escrito a mano, pero sintácticamente válido, no pasa. |

<details>
<summary>💡 Pista para la tarea 2</summary>

Un exit code distinto de cero del linter al detectar problemas es un comportamiento ESPERADO, y no un error de tu comando. Si envuelves la llamada en `|| true` solo para que el script no se detenga con `set -e`, asegúrate de que, aun así, la salida del comando se guarda en el archivo (mediante `tee` o una redirección ANTES de `|| true`), y no se pierde.
</details>

---
| **3** | **Corregir el Dockerfile según los findings** |
| :---: | :--- |
| Qué hacemos | • Corrige `/home/ubuntu/cks-111/Dockerfile`: fija la imagen base con la immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`.<br/>• No uses `ADD` con URL, no guardes un token en `ENV`, no instales `sudo`.<br/>• Añade un `USER` sin privilegios (uid distinto de `0`). Usa `COPY` y una instalación reproducible de paquetes solo si es necesario.<br/>• Añade `ARG CKS_SIGNATURE_TEST=signed` y `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` junto al resto de instrucciones: es el único punto de diferencia controlada de la imagen que hará falta en la tarea 9c, para garantizar un digest distinto sin cambiar las propiedades de seguridad comprobadas aquí.<br/>• Tras la corrección guarda la salida exitosa de Hadolint en `3/hadolint-after.txt`. |
| Criterios de aceptación | • **Dockerfile:** no hay `latest`, se ha eliminado el `ADD` remoto, no queda `API_TOKEN`/`TOKEN`, hay un `USER` non-root, hay `ARG CKS_SIGNATURE_TEST` y `LABEL cks.signature-test`.<br/>• **Hadolint:** el informe final no contiene `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

<details>
<summary>💡 Pista para la tarea 3</summary>

`ARG`/`LABEL` para `CKS_SIGNATURE_TEST` puede parecer no relacionado con los findings actuales de Hadolint: se añade aquí deliberadamente de antemano, para que la tarea 9c (mucho más adelante) pueda construir una imagen físicamente distinta mediante `--build-arg`, sin reescribir el Dockerfile otra vez. Añade estas dos líneas ahora, aunque su utilidad solo se aclare en la 9c.
</details>

---
| **4** | **Corregir el workload YAML según kubesec y kube-linter** |
| :---: | :--- |
| Qué hacemos | • Primero construye y publica la hardened image de la tarea 3, luego indica en `deployment.yaml` su immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` (no el nginx upstream).<br/>• A nivel de Pod añade `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`.<br/>• En el contenedor establece `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits de CPU y memory.<br/>• Para nginx monta un `emptyDir`/tmpfs writable en las rutas temp, pid/run, cache y config y prepara la config antes del arranque.<br/>• Elimina `privileged`, aplica el Deployment, confirma Ready/Available y una petición HTTP exitosa.<br/>• Guarda los nuevos informes `4/kubesec-after.json` y `4/kube-linter-after.json`. |
| Criterios de aceptación | • **Imagen:** el YAML usa una hardened image fijada por digest con `USER 101`, y no el nginx upstream.<br/>• **Manifest:** los campos necesarios, el init container `prepare-nginx-config` y los writable mounts están presentes; `privileged` está ausente.<br/>• **Funcionamiento:** el Deployment está Available y la petición HTTP tiene éxito.<br/>• **Informes:** ambos informes finales son JSON válido. |

<details>
<summary>💡 Pista para la tarea 4</summary>

`readOnlyRootFilesystem: true` requiere rutas writable para CADA directorio en el que nginx suele escribir: `/tmp`, `/var/run` (archivo PID), `/var/cache/nginx` (caché) y `/etc/nginx/conf.d` (si la config se genera al arrancar). Si omites aunque sea uno, el contenedor arrancará, pero fallará en el primer intento de nginx de escribir allí algo. El init container `prepare-nginx-config` hace falta para copiar la config por defecto a un volume writable aparte ANTES del arranque del contenedor principal: precisamente por eso se menciona aparte en los criterios de aceptación.
</details>

---
| **5** | **Búsqueda de versiones de paquetes** |
| :---: | :--- |
| Qué hacemos | • Usa Trivy en modo lista de todos los paquetes para `$IMAGE`.<br/>• Guarda el comando, la immutable image reference, el `nginx@sha256:<manifest-digest>` canónico de `Metadata.RepoDigests[0]` y como mínimo tres líneas `nombre=versión` en `/var/work/tests/artifacts/5/version-search.txt`.<br/>• No sustituyas la búsqueda por una lista manual: en la evidence debe estar la línea del comando con `trivy image --list-all-pkgs`. |
| Criterios de aceptación | • **Artefacto:** contiene el comando, la immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` de Trivy y como mínimo tres pares package/version.<br/>• **Comprobación nueva:** el checker repite por sí mismo `trivy image --list-all-pkgs` para la misma imagen y exige que `repo_digest=` y como mínimo tres pares `name=version` guardados coincidan con este escaneo nuevo.<br/>• Una lista escrita a mano, pero sintácticamente verosímil, no pasa. |

<details>
<summary>💡 Pista para la tarea 5</summary>

El flag se llama precisamente `--list-all-pkgs`, y no `--list-packages` ni una variante parecida: comprueba el nombre exacto del flag en `trivy image --help`, si el comando no funciona. Guarda la salida REAL del comando en el archivo (por ejemplo mediante `tee`), no reescribas a mano unas cuantas líneas package=version "de memoria": el test busca la línea con el propio comando como prueba de que los datos vinieron de la herramienta.
</details>

---
| **5b** | **Encontrar la versión de un paquete en las imágenes de workload y eliminar los contenedores problemáticos** |
| :---: | :--- |
| Qué hacemos | • En el namespace `cks-111` ya está desplegado el Deployment `pkg-audit-app` con tres contenedores (`c1`, `c2`, `c3`), cada uno con su propia image immutable fijada por digest.<br/>• Exactamente en dos de las tres images está presente un mismo paquete de una versión concreta: los `TARGET_PACKAGE`/`TARGET_VERSION` indicados para tu instancia del laboratorio se definen dinámicamente durante el provisioning, no hay valores fijos.<br/>• Obtén las tres image references del Deployment live, para cada una ejecuta `bom generate` (guarda cada SBOM por separado en `/var/work/tests/artifacts/5b/bom/`).<br/>• Determina qué dos contenedores realmente contienen el mismo package/version y anota el par encontrado en `5b/answer.txt` como `TARGET_PACKAGE=<name>` y `TARGET_VERSION=<version>`.<br/>• Elimina PRECISAMENTE estos dos contenedores offending del Deployment (mediante `kubectl edit`/`kubectl apply` de un manifest corregido) de modo que quede solo el contenedor "limpio", y el Deployment siga `Available`. |
| Criterios de aceptación | • **Respuesta:** `answer.txt` nombra el package/version real, presente precisamente en dos de las tres images originales (no adivinado). Estas dos imágenes tienen muchos paquetes en común: sirve cualquier par `name=version` que no esté en la tercera imagen.<br/>• **SBOM:** en `5b/bom/` hay al menos una salida genuina de `bom generate` que confirma este hallazgo.<br/>• **Comprobación independiente:** el checker ejecuta de forma independiente `bom generate` para las candidate images originales (guardadas durante el provisioning) y contrasta tu respuesta con esa ejecución independiente.<br/>• **Deployment:** el Deployment final contiene solo el contenedor "limpio" y sigue `Available`. |

<details>
<summary>💡 Pista para la tarea 5b</summary>

El comando es `bom generate --format json --output <file> --image <ref>` para CADA una de las tres image references por separado. Compara los SBOM por parejas: un paquete se considera "offending" si el mismo par `name`/`versionInfo` aparece en el SBOM de dos contenedores, pero está ausente (o tiene otra versión) en el tercero. No intentes adivinar por el nombre/tag de la imagen: algunas parejas de imágenes pueden parecer "similares", pero la coincidencia real de un paquete solo se determina comparando los SBOM reales. Al editar el Deployment, elimina el contenedor entero de `spec.template.spec.containers`, y no simplemente cambies su image.
</details>

---
| **6** | **SPDX SBOM mediante bom** |
| :---: | :--- |
| Qué hacemos | • Genera un SPDX JSON SBOM con la herramienta `bom` precisamente para la `$IMAGE` inmutable (el mismo `tag@digest` que se usó en la tarea 1, y no el bare tag `nginx:1.27.3-alpine`); guárdalo en `/var/work/tests/artifacts/6/bom.spdx.json`.<br/>• En el archivo `6/bom-command.txt` anota el comando ejecutado con el `--image $IMAGE` exacto. |
| Criterios de aceptación | • **SBOM:** JSON válido, tiene `spdxVersion`, contiene el array `packages`; uno de los paquetes top-level a los que se refiere `documentDescribes` identifica EL MISMO manifest digest que `$IMAGE` de la tarea 1 (mediante `versionInfo`/`name`).<br/>• **Comando:** `bom-command.txt` contiene la `$IMAGE` inmutable exacta y usa `bom generate`.<br/>• Un SBOM de otra imagen (no relacionada con la `$IMAGE` de la tarea 1) no pasa, aunque `bom-command.txt` esté falsificado.<br/>• **Comprobación nueva:** el checker además regenera por sí mismo el SBOM con el mismo `bom` para la misma imagen y exige que el conjunto de paquetes (`name`/`versionInfo`) de tu SBOM coincida con esa ejecución nueva: un documento SPDX mínimo escrito a mano con un solo paquete top-level no pasa. |

<details>
<summary>💡 Pista para la tarea 6</summary>

El comando `bom generate -o <output.json> -i <image>`: obligatoriamente con el flag `-o` para indicar el archivo de salida, de lo contrario la salida irá a stdout. El formato de salida de `bom` es su PROPIO SPDX JSON, que difiere en los detalles del SPDX que puede generar Syft: no confundas estas dos herramientas distintas al generar un mismo formato del estándar.
</details>

---
| **7** | **CycloneDX SBOM mediante Syft y verificación con Cosign** |
| :---: | :--- |
| Qué hacemos | • Genera un CycloneDX JSON SBOM de Syft para la misma `$IMAGE` inmutable (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) de la tarea 1 y guárdalo en `7/syft.cdx.json`.<br/>• Después verifica la firma de la imagen pública `gcr.io/distroless/static-debian13:nonroot` mediante Cosign keyless y guarda la salida exitosa completa en `7/cosign-verify.txt`.<br/>• Para Distroless usa el issuer `https://accounts.google.com` y la identity `keyless@distroless.iam.gserviceaccount.com`. |
| Criterios de aceptación | • **Syft SBOM:** `bomFormat: CycloneDX`, `components` no vacío, `metadata.component.type == "container"` y `metadata.component.version` igual al manifest digest de la misma `$IMAGE` de la tarea 1: un SBOM de otra imagen (bare tag, alpine, busybox, etc.) no pasa.<br/>• **Cosign:** un comando real `cosign verify` para `gcr.io/distroless/static-debian13:nonroot` (es el tag soportado vigente; `gcr.io/distroless/static:nonroot` sin el sufijo `-debian13` se considera deprecated según el README oficial de Distroless y ya no se actualiza) con el issuer/identity indicados termina con exit code `0`, y la salida completa está guardada en `7/cosign-verify.txt`.<br/>• **Comprobación nueva:** el checker además regenera por sí mismo el SBOM con el mismo Syft para la misma imagen y exige que el conjunto de componentes (`name`/`version`) de tu SBOM coincida con esa ejecución nueva: un documento CycloneDX mínimo escrito a mano con un solo componente top-level no pasa. |

<details>
<summary>💡 Pista para la tarea 7</summary>

Syft genera CycloneDX mediante el flag `-o cyclonedx-json` (no lo confundas con la salida SPDX de la misma herramienta). Para la keyless verification de Distroless NO hace falta ninguna clave ni `cosign generate-key-pair`: usa `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` con las cadenas issuer/identity EXACTAS indicadas en la tarea: una errata en cualquiera de ellas dará un error de verificación.
</details>

---
| **8** | **`trivy sbom`: escanear un archivo SBOM ya hecho en busca de vulnerabilidades** |
| :---: | :--- |
| Qué hacemos | • El CycloneDX SBOM de la tarea 7 (`7/syft.cdx.json`) describe la composición de la image y su SO, pero por sí mismo no contiene conclusiones sobre vulnerabilidades.<br/>• Escanea precisamente este archivo SBOM (no la image directamente) con la herramienta `trivy sbom` y guarda el JSON estructurado en `/var/work/tests/artifacts/8/sbom-scan.json`.<br/>• El comando debe aceptar explícitamente el archivo SBOM como entrada, y no volver a escanear `$IMAGE`; guarda su texto en `/var/work/tests/artifacts/8/sbom-scan-command.txt`. |
| Criterios de aceptación | • **Archivo:** no vacío, el JSON lo analiza `jq`, `ArtifactType` = `cyclonedx`, `Results` no vacío y contiene las vulnerabilidades encontradas.<br/>• **Comando:** `sbom-scan-command.txt` contiene el comando `trivy sbom` con la ruta a `7/syft.cdx.json`.<br/>• **Comprobación nueva:** el checker repite por sí mismo `trivy sbom` sobre este archivo. |

<details>
<summary>💡 Pista para la tarea 8</summary>

El comando es `trivy sbom <ruta-al-archivo-sbom>`, y NO `trivy image <ruta-al-archivo>`: son subcomandos distintos con distinta lógica de entrada. Si pasas por accidente la ruta del archivo SBOM a `trivy image`, Trivy intentará interpretarla como un nombre de image reference y terminará con un error o con un comportamiento inesperado.
</details>

---
| **9a** | **Kyverno: instalar y crear una `ImageValidatingPolicy` de trusted signature** |
| :---: | :--- |
| Qué hacemos | • Instala Kyverno mediante `install-kyverno` y espera a que el `admission controller` esté listo.<br/>• Genera un par de claves local `cosign generate-key-pair` (un par didáctico, no una production key).<br/>• Firma tu **propia** hardened image de la tarea 4 (`$HARDENED_IMAGE`, no el nginx upstream) con tu private key y guarda la salida de `cosign sign` en `9a/cosign-sign.txt`.<br/>• Crea una `ImageValidatingPolicy` `require-signed-catalog-images`, que compruebe `verifyImageSignatures` con tu public key para todos los Pod con una image en el repository de tu `$HARDENED_IMAGE`, incluidos los UPDATE de `pods/ephemeralcontainers` y todas las container lists, y **rechace** (`validationActions: [Deny]`) las imágenes unsigned/con firma no válida. |
| Criterios de aceptación | • **Kyverno:** instalado, su admission controller `Available`.<br/>• **Firma:** `9a/cosign-sign.txt` contiene la salida exitosa de la firma precisamente de `$HARDENED_IMAGE`; el comando real `cosign verify --key cosign.pub "$HARDENED_IMAGE"` termina con éxito.<br/>• **Policy:** la `ImageValidatingPolicy require-signed-catalog-images` aplicada existe, tiene `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, public key y `verifyImageSignatures`.<br/>• **Ámbito de acción:** sus `matchImageReferences` están limitadas precisamente a `$HARDENED_REPO:*` y `$HARDENED_REPO@*`, y no al prefijo inseguro `$HARDENED_REPO*`. |

<details>
<summary>💡 Pista para la tarea 9a</summary>

`cosign generate-key-pair` crea `cosign.key`/`cosign.pub` en el directorio actual: un par didáctico, no vinculado a ningún OIDC issuer, a diferencia de la keyless verification de la tarea 7. Guarda la private key fuera de `/home/ubuntu/cks-111`, porque ese directorio se reutiliza como Docker build context en la tarea 9c: un `cosign.key` dejado dentro acabará directamente en el sistema de archivos de la image publicada mediante `COPY . /usr/share/nginx/html`. `matchImageReferences` en la policy debe limitar su acción PRECISAMENTE a tu repository (`$HARDENED_REPO`), y no a todo el clúster: de lo contrario la policy bloqueará TODOS los Pod sin firma, incluidos los componentes de sistema de Kubernetes.
</details>

---
| **9b** | **Fresh signed ALLOW: un Pod nuevo tras crear la policy** |
| :---: | :--- |
| Qué hacemos | • La policy de la tarea 9a debe admitir el `$HARDENED_IMAGE` firmado, pero un nuevo `kubectl apply` de un Deployment ya existente **no demuestra** esto: si el template no cambió, puede que no se cree un nuevo ReplicaSet/Pod, y `Running` resultará ser simplemente un Pod antiguo, creado antes de la policy.<br/>• Crea un objeto **nuevo**, que no existía antes: `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`.<br/>• Guarda el `creationTimestamp` de este Pod, el `creationTimestamp` de la policy de 9a y el `status.phase`/condition `Ready` final en `9b/signed-admission-check.json`. |
| Criterios de aceptación | • **Pod:** `signed-admission-check` existe, usa precisamente `$HARDENED_IMAGE`; para él se ejecuta con éxito `cosign verify --key cosign.pub "$HARDENED_IMAGE"`, `status.phase` no es `Failed`, y la condición `Ready` llega a `True`.<br/>• **Artefacto:** `9b/signed-admission-check.json` contiene esta image y el `creationTimestamp` del Pod **posterior** al `creationTimestamp` de la `ImageValidatingPolicy require-signed-catalog-images`.<br/>• Esto demuestra el fresh post-policy admission precisamente de una image verificablemente firmada, y no un Pod antiguo que sobrevivió a la policy. |

<details>
<summary>💡 Pista para la tarea 9b</summary>

No reutilices el Deployment `catalog` de la tarea 4 para esta comprobación: usa literalmente un nuevo `kubectl run` con un nuevo nombre de Pod, como se indica en la tarea. Ambos timestamp (del Pod y de la policy) son cadenas ISO8601 en UTC, se pueden comparar lexicográficamente como cadenas normales (`"2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z"` en bash funciona correctamente para este formato).
</details>

---
| **9c** | **Signature-specific DENY: un digest unsigned que realmente existe en el mismo repository** |
| :---: | :--- |
| Qué hacemos | • Construye y publica un **segundo** tag en el mismo repository que `$HARDENED_IMAGE` (por ejemplo, `${HARDENED_TAG%:*}:unsigned-1.0`), sin firmarlo.<br/>• Esta imagen debe ser un **artifact físicamente distinto**, y no el mismo digest que el `$HARDENED_IMAGE` ya firmado: si construyes el mismo `Dockerfile`/context sin cambios, un reproducible/cached build puede dar un digest idéntico, y entonces el tag "unsigned" en realidad apuntará a un artifact ya firmado, y `cosign verify` pasará inesperadamente.<br/>• Introduce una diferencia controlada mediante un build-arg (por ejemplo `--build-arg CKS_SIGNATURE_TEST=unsigned-1` con el correspondiente `ARG`/`LABEL` en el Dockerfile) y guarda explícitamente la prueba `$UNSIGNED_DIGEST != $HARDENED_DIGEST` en `9c/digest-comparison.txt`.<br/>• Obtén el registry manifest digest del mismo modo que en la tarea 3 (`podman push --digestfile`), forma `$UNSIGNED_IMAGE` en el mismo repository.<br/>• Demuestra explícitamente que este digest **existe y es pullable** (una petición `GET /v2/catalog/manifests/<digest>` al registry tiene éxito) y **no tiene** una firma válida con tu clave (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` termina con un error); guarda ambas salidas en `9c/unsigned-exists.txt` y `9c/unsigned-not-signed.txt`.<br/>• Después crea un Pod `catalog-unsigned-probe` con esta `$UNSIGNED_IMAGE` y guarda el admission denial en `9c/admission-deny.txt`. |
| Criterios de aceptación | • **Artefacto:** `9c/digest-comparison.txt` contiene `hardened_digest=`, `unsigned_digest=` y `unsigned_image=` (una referencia `tag@digest` completa en el mismo repository que `$HARDENED_IMAGE`, con un digest genuinamente distinto).<br/>• **Comprobación del checker:** resuelve por sí mismo `unsigned_image` en el registry, confirma la ausencia de una firma válida mediante su propio `cosign verify`, crea SU nuevo Pod con esta imagen y exige el validation message único de su propia policy: `catalog image must have a valid release signature`.<br/>• Solo cuenta este mensaje, y no cualquier error de admission: un error genérico de admission/signature de otra policy no da PASS, y `manifest unknown`/los errores de registry lookup tampoco bastan.<br/>• Los archivos de evidence escritos a mano sin un admission control real no dan PASS: el checker no se fía de ningún archivo de texto, salvo `unsigned_image=` como indicador de la imagen real que hay que comprobar. |

<details>
<summary>💡 Pista para la tarea 9c</summary>

El orden de las pruebas aquí es importante para su fiabilidad: primero demuestra que `$UNSIGNED_IMAGE` EXISTE y es PULLABLE (de lo contrario, el denial posterior puede ser simplemente "manifest unknown", y no sobre la firma), luego demuestra la AUSENCIA de firma, y solo DESPUÉS de esto intenta crear el Pod. Si la comparación de digest en `digest-comparison.txt` muestra una coincidencia, consigue una diferencia real de content (por ejemplo, cambia el build-arg `CKS_SIGNATURE_TEST` a otro valor y reconstruye).
</details>

## Comprobación

```bash
check_result
```

La comprobación contiene `Init` y catorce tests de evaluación independientes (la tarea 9 está dividida en 9a/9b/9c). Comprueba el contenido de los archivos y el
JSON, y no solo la presencia de los nombres. Las peticiones externas al registry hacen falta para Trivy, SBOM y
Cosign; si el registry no está disponible temporalmente, repite precisamente el comando correspondiente.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=111 make delete_cks_task
```
