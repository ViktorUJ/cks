[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 108 - Admission policies con Kyverno

## Objetivo

En este laboratorio de CKS instalarás Kyverno y protegerás el namespace `policy-108` con reglas
de policy-as-code. La práctica abarca el validating admission: prohibición de la etiqueta `latest`, `runAsNonRoot`
obligatorio, allowlist de registry; en la etapa opcional, la mutation de un Pod durante el
admission. La tarea 6 compara este enfoque con otro mecanismo: el `ImagePolicyWebhook` integrado,
donde la decisión sobre la imagen la toma un backend HTTP(S) externo mediante la API
`ImageReview`, y no una expresión CEL dentro del clúster. La tarea final 7 es un tercer admission
engine, aparte: **Gatekeeper (OPA/Rego)**, donde arreglas una policy ya desplegada pero incompleta,
y no escribes CEL dentro de Kyverno. Trabaja solo con los objetos y nombres indicados
en las tareas.

## Compruébate antes de empezar

<details>
<summary>1. ¿Por qué prohibir solo la etiqueta explícita `:latest` no cubre todo el riesgo del mutable-tag?</summary>

Si la imagen se indica sin etiqueta en absoluto (por ejemplo, `nginx`), Docker/OCI por defecto la resuelve como `nginx:latest`: implicit latest. Una policy que compruebe solo la coincidencia literal de la cadena `:latest` dejará pasar esa imagen, aunque semánticamente es lo mismo que un `:latest` explícito. Una policy correcta debe rechazar tanto el latest explícito como el implícito, o bien exigir un versioned tag/digest explícito.
</details>

<details>
<summary>2. ¿Por qué una validating policy debe comprobar `ephemeralContainers` por separado de `containers`/`initContainers`?</summary>

`kubectl debug` añade un ephemeral container a un Pod YA existente mediante un subresource de la API aparte (`pods/ephemeralcontainers`), y no mediante un CREATE/UPDATE normal del Pod. Si la policy hace match solo con el recurso `pods` sin incluir explícitamente este subresource, un intento de añadir un ephemeral container sin comprobar/untrusted puede pasar de largo ante todas las validating policy escritas para los contenedores normales.
</details>

<details>
<summary>3. ¿Cuál es la diferencia esencial entre `ValidatingPolicy` y `MutatingPolicy` en Kyverno?</summary>

`ValidatingPolicy` solo comprueba la petición y la permite o la rechaza (Allow/Deny): el objeto no se modifica. `MutatingPolicy` MODIFICA el objeto antes de guardarlo (añade/cambia campos, por ejemplo un label): la petición igualmente pasa, pero con un contenido modificado. La tarea 5 usa mutation precisamente porque el objetivo es añadir un label automáticamente, y no rechazar el Pod.
</details>

## Infraestructura

El entorno se despliega con Terragrunt en AWS `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas |
| `ssh-keys` | claves de acceso a los nodos |
| `k8s-1` | clúster kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd y **Calico** |
| `worker` | máquina de trabajo con `kubectl`, Helm y `/usr/local/bin/install-kyverno` |

El control-plane permite Pods normales, por lo que no se crea un worker de Kubernetes aparte.
Kyverno deliberadamente **no está instalado** en el estado inicial: eso forma parte de la tarea 1. En la
máquina de trabajo se ha preparado un installer fijado, que no obliga a buscar el chart a mano.
El laboratorio fija Kyverno `1.19` (Helm chart `3.9.0`) y usa las API estables basadas en CEL
`policies.kyverno.io/v1`. Desde esta versión, los `Policy`/`ClusterPolicy` legacy de `kyverno.io/v1` están
deprecated y se consideran solo como migration material.

A diferencia de Kyverno, **Gatekeeper (OPA) para la tarea 7 ya está instalado** por el bootstrap
del clúster, junto con un `ConstraintTemplate` y un `Constraint` iniciales (deliberadamente incompletos).
Esto se ha hecho a propósito: la tarea 7 comprueba la capacidad de encontrar y completar Rego en un
`ConstraintTemplate` ya existente, y no de instalar un admission engine desde cero; esa parte
ya la practica la tarea 1 para Kyverno. La tarea 7 funciona en un namespace aparte
`gatekeeper-108`, aislado de las tareas 1-5 de Kyverno (`policy-108`), para que un Pod no pueda
ser rechazado a la vez por dos admission engine distintos.

## Despliegue

```bash
TASK=108 make run_cks_task
```

Conéctate por SSH a la máquina de trabajo. El contexto `cluster1-admin@cluster1` ya está configurado.

```bash
time_left
check_result
```

## Tareas

---
| **1** | **Instalar Kyverno** |
| :---: | :--- |
| Qué hacemos | • Instala Kyverno en el namespace `kyverno`.<br/>• Usa el comando preparado en el worker `/usr/local/bin/install-kyverno`; aplica el Helm chart fijado.<br/>• Espera a que el admission controller esté disponible. |
| Criterios de aceptación | • En el clúster existe el CRD `validatingpolicies.policies.kyverno.io`<br/>• La versión de Kyverno es `1.19.x`<br/>• Al menos un Deployment del namespace `kyverno` tiene una réplica disponible |

<details>
<summary>💡 Pista para la tarea 1</summary>

`/usr/local/bin/install-kyverno` ya está configurado para la versión fijada: no intentes instalar Kyverno con `helm install` a mano con otro chart, eso puede dar lugar a una versión incompatible de los CRD. Tras la instalación, espera: el Pod del admission controller debe pasar a `Available`, y eso no ocurre al instante.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

El primer comando debe devolver el propio CRD (no el error `NotFound`); la versión de la imagen debe
contener `v1.19.`; al menos un Deployment debe tener `AVAILABLE` mayor que `0`.
</details>

---
| **2** | **Prohibir imágenes con la etiqueta `latest`** |
| :---: | :--- |
| Qué hacemos | • Crea una `ValidatingPolicy` basada en CEL `deny-latest-tag` (`policies.kyverno.io/v1`) con `validationActions: [Deny]`.<br/>• Debe aplicarse a los Pod y al subresource `pods/ephemeralcontainers` del namespace `policy-108`.<br/>• Debe rechazar cualquier imagen en `containers`, `initContainers` o `ephemeralContainers` que sea un `:latest` explícito O un latest implícito (una imagen sin etiqueta y sin digest en absoluto). |
| Criterios de aceptación | • La policy existe y funciona en modo Deny<br/>• El admission rechaza tanto el `:latest` explícito como el latest implícito (untagged) en cada una de las tres listas de contenedores, incluida una imagen con un puerto de registry sin etiqueta (`registry.example:5000/app`), y acepta versioned trusted images e imágenes fijadas por digest en cada lista<br/>• En un UPDATE de un Pod existente, el cambio de `spec.containers[*].image` o `spec.initContainers[*].image` a `:latest` también es rechazado por esta policy (los campos image normales de un Pod admiten UPDATE in-place) |

<details>
<summary>💡 Pista para la tarea 2</summary>

`matchConstraints.resourceRules` debe cubrir tanto `pods` como el subresource
`pods/ephemeralcontainers` por separado; de lo contrario `kubectl debug` pasará de largo ante la policy. Para
la propia lógica CEL: descompón la cadena de la imagen en `registry/path` y `tag` por el último `:`
DESPUÉS de la última `/` (la presencia de `:` antes de la última `/` puede ser parte del puerto del registry, y
no de la etiqueta); si tras la descomposición no hay etiqueta en absoluto, es un latest implícito; si hay etiqueta, pero
es igual a `latest`, también es un caso prohibido; el digest (`@sha256:...`) es un caso aparte, siempre
permitido, al que la etiqueta no afecta en absoluto.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Antes de aplicar la policy, asegúrate de que el Pod infractor realmente pasa el admission
(baseline); de lo contrario no está claro si el denial lo causa tu policy u otra cosa:

```bash
# baseline: antes de aplicar la policy - debe pasar (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

Aplica la policy y luego repite EL MISMO manifest: ahora debe terminar con un error
de admission (exit distinto de 0), y el mensaje debe referirse a tu policy:

```bash
kubectl apply -f deny-latest-tag.yaml   # tu archivo de policy
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

Repite el mismo ciclo baseline→apply→probe→compare para: una imagen sin etiqueta en absoluto
(`registry.k8s.io/pause`), `registry.example:5000/app` (los dos puntos antes de la última `/` son el puerto del registry, y no la etiqueta), `:latest` en `initContainers`, y `:latest`/untagged mediante
`kubectl debug --image=...` en un Pod permitido ya en ejecución (subresource `pods/ephemeralcontainers`).
Por último, comprueba el positive control: un versioned tag debe pasar también
tras aplicar la policy, y no solo antes.
</details>

---
| **3** | **Exigir ejecución sin root** |
| :---: | :--- |
| Qué hacemos | • Crea una `ValidatingPolicy` basada en CEL `require-run-as-non-root` en modo Deny.<br/>• Para cada Pod en `policy-108`, el campo `spec.securityContext.runAsNonRoot` debe ser explícitamente igual a `true`.<br/>• A nivel de Pod y de todos los contenedores están prohibidos `runAsUser: 0` y `runAsNonRoot: false` a nivel de container: los ajustes del contenedor pueden sobrescribir el securityContext a nivel de Pod. |
| Criterios de aceptación | • La policy existe y es Deny<br/>• Un Pod con `runAsNonRoot: false` o sin este campo, `runAsUser: 0` a nivel de Pod, y también un contenedor con `runAsNonRoot: false` / `runAsUser: 0` en `containers`, `initContainers`, `ephemeralContainers` son rechazados precisamente por esta policy<br/>• Un `runAsNonRoot: true`, `runAsUser: 1000` explícito y seguro a nivel de container es aceptado |

<details>
<summary>💡 Pista para la tarea 3</summary>

Comprueba precisamente el valor EXPLÍCITO `true`, y no "la ausencia de `false`": una expresión CEL del tipo `object.spec.securityContext.runAsNonRoot == true` no pasará si el campo no está definido en absoluto (`null != true`), y eso aquí es lo que SE EXIGE: la tarea rechaza tanto un `false` explícito como un campo ausente: ambos casos deben ser denied, y no solo el `false` explícito.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

```bash
# baseline: antes de aplicar la policy, ambas variantes deben pasar
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Aplica la policy y repite ambos manifest: AMBOS deben terminar ahora con un error
de admission. Después comprueba el positive control: el mismo Pod, pero con
`runAsNonRoot: true` explícito, debe pasar también tras aplicar la policy.
</details>

---
| **4** | **Allowlist de container registry** |
| :---: | :--- |
| Qué hacemos | • Crea una `ValidatingPolicy` basada en CEL `allow-approved-registries` en modo Deny.<br/>• Para cada contenedor (`containers`, `initContainers`, `ephemeralContainers`) permite solo `registry.k8s.io/*` o `ghcr.io/cks-lab/*`.<br/>• Prohíbe el resto de los image registry. |
| Criterios de aceptación | • La policy existe y es Deny<br/>• Una untrusted image es rechazada en las tres listas<br/>• Ambos approved prefixes (`registry.k8s.io/` y `ghcr.io/cks-lab/`) se admiten en cada una de las tres listas<br/>• Un UPDATE normal de un Pod que cambie la imagen a un unapproved registry es rechazado por la propia policy<br/>• También se comprueban otros unapproved registry y host/path-lookalikes en las listas init/ephemeral |

<details>
<summary>💡 Pista para la tarea 4</summary>

`startsWith('registry.k8s.io/')` es la comprobación de prefijo más fiable, pero asegúrate de que ambos registry permitidos se comprueban mediante OR (sirve cualquiera de los dos), y no AND (ambos a la vez, lo cual es imposible para una sola imagen). Comprueba precisamente un ALLOWLIST (la imagen se admite SOLO si coincidió con uno de los dos prefijos), y no un denylist concretamente de `docker.io`: una policy escrita como "si es `docker.io` - deny, si no, allow" dejará pasar `quay.io`, imágenes unqualified y cualquier otro registry de terceros. Asegúrate también de que el prefijo se compara con la `/` FINAL (`registry.k8s.io/`, y no simplemente `registry.k8s.io`), de lo contrario un host de escritura parecida (`registry.k8s.io.evil.example`) puede pasar por una coincidencia case-insensitive o incompleta. Igual que en la tarea 2, no olvides `ephemeralContainers`: es el mismo patrón de comprobación de las tres listas de contenedores.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

```bash
# baseline: antes de aplicar la policy - un untrusted registry debe pasar
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

Aplica la policy y repite el mismo manifest: ahora debe ser denied. Es UN solo
valor untrusted concreto (`docker.io`), y no la prueba de un allowlist completo:
una policy que simplemente prohíba literalmente `docker.io`, pero deje pasar,
por ejemplo, una imagen unqualified (implicit Docker Hub sin un host explícito), `quay.io` o
un host de escritura parecida (`registry.k8s.io.evil.example`), también pasará esta ÚNICA
comprobación. Repite el mismo baseline→apply→probe→compare como mínimo para: una imagen
unqualified (`busybox:1.36` sin host en absoluto), otro registry externo explícito
(`quay.io/...`), un host/path de escritura parecida (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), una untrusted image en `initContainers`, y una imagen untrusted/trusted
mediante `kubectl debug` en un Pod permitido ya en ejecución. Por último, positive control: un Pod con AMBOS contenedores (main + init) de
`registry.k8s.io`/`ghcr.io/cks-lab` debe pasar; comprueba también `ghcr.io/cks-lab/*`
en los contenedores init y ephemeral, y no solo en `containers`.
</details>

---
| **5** | **Opcional: mutate de un label mediante Kyverno** |
| :---: | :--- |
| Qué hacemos | • Crea una `MutatingPolicy` basada en CEL `add-kyverno-managed-label` (`policies.kyverno.io/v1`), que añada a los Pod del namespace `policy-108` el label `security.cks.io/managed-by: kyverno`, si no está.<br/>• Usa mutation, y no validation.<br/>• No mutes Pod de otros namespace. |
| Criterios de aceptación | • Un server-side dry-run de un Pod con un registry permitido y `runAsNonRoot: true`, que aún NO tenga este label, lo recibe tras la mutation con el valor `kyverno`<br/>• Un Pod que YA tiene el label con otro valor conserva el valor original<br/>• Un Pod en `default` permanece sin este label<br/>• Esta etapa se muestra en `check_result`, pero se admite omitirla |

<details>
<summary>💡 Pista para la tarea 5</summary>

Esta etapa es opcional: si se te acabó el tiempo, puedes omitirla sin riesgo para el resto del laboratorio. El Pod de prueba para comprobar la mutation debe pasar ya las policy de las tareas 2-4 (trusted registry, non-root): si es rechazado por una de las policy anteriores, no verás el resultado de la mutation en absoluto. «Si no está» en la tarea no es solo un deseo: la mutation debe comprobar explícitamente la presencia del label y no tocar el objeto si ya está, de lo contrario la tarea no está cumplida, aunque un Pod sin label reciba el valor correcto.
</details>

---
| **6** | **ImagePolicyWebhook: backend externo en lugar de una CEL policy** |
| :---: | :--- |
| Qué hacemos | • En la máquina de trabajo ya está preparado `/opt/image-policy-backend/server.py`: un servidor HTTPS mínimo que implementa la API `ImageReview` (rechaza imágenes con la etiqueta `:latest` o sin etiqueta en absoluto).<br/>• Despliégalo como un Deployment en el namespace `image-policy`, detrás de un Service `image-policy-backend` en el puerto `8443`. El backend debe aceptar conexiones por TLS (el contrato upstream de `ImagePolicyWebhook` exige HTTPS, no se admite HTTP plano).<br/>• En `control-plane` (`ssh`, luego `sudo -i`) configura un `AdmissionConfiguration` para el plugin `ImagePolicyWebhook` (`defaultAllow: false`) y un kubeconfig que apunte a tu backend.<br/>• En el static manifest `kube-apiserver.yaml` **añade** `ImagePolicyWebhook` a la lista ya existente de `--enable-admission-plugins` (no sustituyas la lista completa; de lo contrario te arriesgas a desactivar plugins ya habilitados) y habilita `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`.<br/>• Tras la recuperación de la API, crea un Pod con `:latest`: debe ser rechazado; después un Pod con una etiqueta fijada: debe crearse. |
| Criterios de aceptación | • `image-policy-backend` Available<br/>• Kube-apiserver healthy con el plugin añadido (no sustituido) y `--runtime-config`<br/>• El kubeconfig del backend usa HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• Un Pod con `:latest` y latest implícito (incluido registry-port sin etiqueta) es rechazado precisamente por ImagePolicyWebhook en el namespace `default` - tanto en un Pod normal como en un init/ephemeral container<br/>• La annotation de usuario `alpha.image-policy.k8s.io/break-glass: "true"` no da ninguna excepción<br/>• El namespace `policy-108` está reservado para Kyverno de las tareas 2–4, para que dos mecanismos independientes de admission no enmascaren el rechazo uno del otro<br/>• Para ello el backend, según `ImageReview.spec.namespace == policy-108`, delega la decisión a Kyverno, y en todos los demás namespace ImagePolicyWebhook sigue funcionando<br/>• El Pod con una etiqueta fijada está creado y Running<br/>• El Service realmente pierde los Endpoints durante el backend outage, la API rechaza por la indisponibilidad de este endpoint (`defaultAllow: false`), y luego el Service selector y el admission se recuperan exactamente al estado original |

<details>
<summary>💡 Pista para la tarea 6</summary>

`ImagePolicyWebhook` es un mecanismo esencialmente distinto de Kyverno de las tareas 1-5: la decisión la toma un backend HTTPS externo mediante la API `ImageReview`, y no una expresión CEL dentro del clúster. Usa el `/opt/image-policy-backend/server.py` ya preparado desde la máquina de trabajo (por ejemplo, empaquétalo en un ConfigMap para el Deployment del backend; en `control-plane` solo hay que copiar el certificado CA para el kubeconfig del webhook): la tarea comprueba la comprensión del wiring del admission plugin, del contrato TLS y de la API ImageReview, y no la capacidad de escribir un servidor HTTP desde cero. Para TLS: primero crea el Service (para averiguar el `ClusterIP`), luego un certificado autofirmado con esa IP en el SAN (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), luego el Deployment, que monte tanto el código como el certificado. No sustituyas el `--enable-admission-plugins` existente por un valor nuevo completo: añade `ImagePolicyWebhook` separado por coma a los plugins ya habilitados (normalmente ya está `NodeRestriction`). Tampoco olvides `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`: sin habilitar explícitamente esta API no se llamará al backend en absoluto. El namespace `image-policy` no está creado de antemano: créalo tú mismo antes del Deployment/Service. Si te atascas en la secuencia detallada de recursos/rutas/flags, el orden de acciones de referencia está en la solución.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: completar el blocklist de Rego** |
| :---: | :--- |
| Qué hacemos | • En el clúster ya está instalado **Gatekeeper** (OPA), así como el `ConstraintTemplate` `k8sblockedregistries` y el `Constraint` `K8sBlockedRegistries/deny-bad-registries`, limitado a un namespace aparte `gatekeeper-108` (no `policy-108`: es un terreno de pruebas separado de las tareas 1-5 de Kyverno, para que Kyverno y Gatekeeper no rechacen el mismo Pod a la vez).<br/>• El Rego dentro del `ConstraintTemplate` ya contiene varios registry bloqueados (`untrusted-registry.example`, `docker-fake.test`), pero **deliberadamente no contiene** `very-bad-registry.test`.<br/>• Encuentra `ConstraintTemplate.spec.targets[].rego` y añade en él una regla para `very-bad-registry.test`, precisamente en el Rego, y no en los parámetros del `Constraint`.<br/>• `deny-bad-registries` ya es totalmente correcto y no usa `spec.parameters` en absoluto: no hace falta tocarlo. |
| Criterios de aceptación | • El `ConstraintTemplate k8sblockedregistries` y el Constraint original `K8sBlockedRegistries/deny-bad-registries` existen<br/>• El Rego conserva ambas reglas activas originales (`untrusted-registry.example`, `docker-fake.test`) y contiene la nueva regla activa para `very-bad-registry.test`<br/>• Un Pod con cada uno de estos tres registry en `gatekeeper-108` es rechazado precisamente por el Constraint `deny-bad-registries`<br/>• Un Pod con una imagen del `registry.k8s.io` de confianza pasa<br/>• El Constraint sigue siendo Pod-only, limitado a `gatekeeper-108`, sin parameters/selectors/exclusions<br/>• No se crea un Constraint adicional de este tipo |

<details>
<summary>💡 Pista para la tarea 7</summary>

Encuentra el ConstraintTemplate mediante `kubectl get constrainttemplate k8sblockedregistries -o yaml`. El Rego está en `spec.targets[].rego` como una cadena multilínea: es la que hay que editar (`kubectl edit constrainttemplate k8sblockedregistries`, o `get -o yaml` → edición → `apply`). El Rego existente declara los registry bloqueados mediante hechos separados del tipo `blocked_registry("untrusted-registry.example")`: añade una línea más así para `very-bad-registry.test`, sin eliminar ni sustituir las ya existentes. No lo confundas con `Constraint.spec.parameters`: en esta versión de la policy el Constraint no usa parameters en absoluto, allí no hay nada que editar.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Baseline: ANTES de la corrección, un Pod de `very-bad-registry.test` debe pasar (el Rego todavía
no lo cubre), y el ya bloqueado `untrusted-registry.example` debe ser rechazado:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

Completa el Rego, repite EL MISMO manifest (con un nombre nuevo, el Pod antiguo ya está
"creado" mediante dry-run y no se guarda): ahora se espera un error de admission de
Gatekeeper, que se refiera precisamente a `k8sblockedregistries`, para AMBOS registry:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

Comprueba el positive control: el registry de confianza debe pasar también tras la corrección:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## Comprobación

En la máquina de trabajo ejecuta:

```bash
check_result
```

La comprobación contiene Init y siete tests. Los primeros cuatro, el sexto y el séptimo son obligatorios. El quinto
test ejecuta la comprobación de la mutation, pero no hace fallar el laboratorio si la policy
opcional no está creada. Las tareas 2-4 y 7 usan `--dry-run=server`, por lo que las imágenes no se
descargan y los Pod no se quedan en el namespace; la tarea 6 comprueba el admission real (no dry-run)
mediante ImagePolicyWebhook, por lo que el Pod `webhook-pinned-ok` realmente se
crea.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD)

## Eliminación

```bash
TASK=108 make delete_cks_task
```

## Compatibilidad y semántica exacta de la prohibición de imágenes

El laboratorio fija Kubernetes 1.36.0 y Kyverno 1.19 para conocer las nuevas
API `policies.kyverno.io/v1`. Es una **forward-looking / unsupported combination**: Kyverno
1.19 se prueba oficialmente con Kubernetes 1.33–1.35, y no con 1.36. Antes de aplicarlo fuera del
laboratorio elige una matriz de versiones soportada y contrasta las release notes.

En la tarea 2, por «prohibición de `latest`» se entiende también la prohibición del `latest` implícito: `nginx`
sin tag ni digest es tan inadmisible como `nginx:latest`. Solo se permiten imágenes con una
etiqueta explícita distinta de `latest`, o con digest (`@sha256:...`). La tarea no da ya hecha la lógica CEL exacta
para este criterio; consulta la pista de la tarea 2 si necesitas un apoyo adicional.
