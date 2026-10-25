[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission: restricted, audit/warn y read-only root filesystem

## Objetivo

En este laboratorio de CKS configurarás el **Pod Security Admission (PSA)** integrado mediante
los labels del namespace. Para el namespace de producción se habilitará `restricted` en modo
`enforce`, se comprobará la denegación de un Pod inseguro y se desplegará un Pod hardened que pase.
Para un namespace aparte habilitarás los modos de observación `audit` y `warn` del nivel
`baseline`. Para terminar, el root filesystem del contenedor pasará a read-only, y la única
escritura necesaria se permitirá en un `emptyDir`.

Trabaja solo con los objetos de las tareas. En el clúster se han creado de antemano los namespaces vacíos
`psa-restricted-107`, `psa-observe-107` y `psa-controller-107`; en ellos no hay PSA-labels ni workload.

## Compruébate antes de empezar

<details>
<summary>1. ¿En qué se diferencia `enforce` de `audit`/`warn` en Pod Security Admission?</summary>

`enforce` bloquea realmente la creación de un Pod que infringe el nivel de PSS elegido: el admission request termina con un error. `audit`/`warn` NO bloquean la petición: el Pod se crea igualmente, pero `audit` añade una annotation al audit log de kube-apiserver, y `warn` muestra al usuario una advertencia de texto en `kubectl apply`. Son niveles distintos de responsabilidad: `audit`/`warn` sirven para observar antes de habilitar el bloqueo real, `enforce` es la protección propiamente dicha.
</details>

<details>
<summary>2. ¿Por qué hay que fijar el label `*-version` junto con el nivel de PSS en el namespace?</summary>

Sin una versión fija (`enforce-version`), PSA usará la versión actual de Kubernetes en cada comprobación: si el clúster se actualiza, el conjunto de reglas de `restricted`/`baseline` puede cambiar sin que te des cuenta, y un Pod que pasaba ayer puede empezar a ser rechazado hoy sin que hayas hecho nada. Fijar la versión hace que el comportamiento sea predecible y reproducible con independencia de las futuras actualizaciones del clúster.
</details>

<details>
<summary>3. ¿Por qué la `ValidatingAdmissionPolicy` de la tarea 6 no duplica PSA, sino que lo complementa?</summary>

PSS `restricted` define un conjunto fijo y estandarizado de campos de seguridad (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` NO forma parte de ese conjunto: PSA no lo comprueba en absoluto. Es decir, un Pod puede ser totalmente compatible con `restricted` y aun así recibir silenciosamente un API-token montado que no necesita. Una `ValidatingAdmissionPolicy` custom cubre precisamente esa laguna, sin intentar sustituir ni duplicar lo que PSA ya hace.
</details>

## Infraestructura

El entorno se despliega mediante Terragrunt en AWS `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas |
| `ssh-keys` | claves SSH para acceder a las máquinas |
| `k8s-1` | clúster kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd y **Calico** |
| `worker` | máquina de trabajo con `kubectl`, el contexto `cluster1-admin@cluster1` y `check_result` |

El control-plane admite Pods normales, por lo que no hace falta un nodo worker de Kubernetes
aparte. Todas las tareas se realizan en la máquina de trabajo.

## Despliegue

```bash
TASK=107 make run_cks_task
```

Conéctate por SSH a la máquina de trabajo y comprueba el acceso al clúster:

```bash
time_left
kubectl get nodes
check_result
```

## Tareas

---
| **1** | **Enforce restricted con versión fijada** |
| :---: | :--- |
| Qué hacemos | En el namespace `psa-restricted-107` establece `pod-security.kubernetes.io/enforce=restricted` y `pod-security.kubernetes.io/enforce-version=v1.36`. Asegúrate de que PSA realmente rechaza un Pod inseguro: un server-side dry-run de un Pod con `hostNetwork: true` en este namespace debe terminar con un error que contenga `violates PodSecurity`. No cambies los labels de los namespaces del sistema. |
| Criterios de aceptación | Ambos enforce-label tienen los valores exactos; el Pod inseguro no pasa el admission en `psa-restricted-107`; los namespaces del sistema `kube-system`, `kube-public` y `kube-node-lease` no reciben labels `pod-security.kubernetes.io/*` en el marco de este laboratorio. |

<details>
<summary>💡 Pista para la tarea 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36`: ambos labels se aplican al instante, PSA no requiere reiniciar nada. Compruébalo mediante `kubectl apply --dry-run=server` con `hostNetwork: true`: precisamente `--dry-run=server` (no `client`), porque los admission controllers, incluido PSA, funcionan solo en el server-side.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Primero el baseline: ANTES de establecer los labels, asegúrate de que el mismo manifest inseguro
pasa (de lo contrario no está claro si el denial lo causa tu enforce label u otra cosa):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

Establece ambos labels y luego repite EL MISMO manifest: ahora debe haber un error
de admission con el texto `violates PodSecurity`:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **Hardened Pod que pasa restricted** |
| :---: | :--- |
| Qué hacemos | Crea un Pod `restricted-app` en `psa-restricted-107` con `busybox:1.36`, que no se ejecute como root y que no termine de inmediato. Establece a nivel de Pod `runAsNonRoot: true`, `runAsUser: 1000` y `seccompProfile: RuntimeDefault`. En el securityContext del container prohíbe el privilege escalation, elimina la capability `ALL`, deja explícitamente `privileged: false` y establece `seccompProfile: RuntimeDefault`. |
| Criterios de aceptación | El Pod es aceptado por PSA y está en ejecución; funciona como UID 1000/non-root, y ningún container/init/ephemeral container redefine el `runAsUser: 1000` a nivel de Pod; seccomp es `RuntimeDefault`; escalation y privileged están prohibidos; las capabilities `ALL` están eliminadas. |

<details>
<summary>💡 Pista para la tarea 2</summary>

Si el Pod recibe un admission rejection, lee con atención el mensaje de error: normalmente nombra el campo EXACTO que falta (por ejemplo, "container has no capabilities.drop"). Un detalle importante sobre la semántica de PSS `restricted` en Kubernetes 1.36: exige un `seccompProfile` admisible efectivo (no necesariamente duplicado literalmente): el perfil a nivel de Pod (`spec.securityContext.seccompProfile.type`) puede ser heredado por los contenedores que no tienen definido el suyo, y a la inversa, basta con el campo a nivel de container si está indicado explícitamente en TODOS los contenedores, incluso sin un perfil a nivel de Pod. Es decir, el propio PSS no exige literalmente AMBOS niveles a la vez. **En este laboratorio pedimos deliberadamente que indiques `RuntimeDefault` explícitamente tanto en el Pod como en el contenedor**, no porque lo exija PSS, sino para que practiques con ambos niveles de configuración. Del mismo modo, `runAsUser: 1000` es una decisión explícita de hardening propia de este laboratorio: PSS `restricted` prohíbe el UID `0`, pero no exige concretamente `1000` (cualquier valor distinto de cero o la ausencia total del campo es admisible para el propio PSS).
</details>

---
| **3** | **Modos de observación baseline** |
| :---: | :--- |
| Qué hacemos | En el namespace `psa-observe-107` habilita ambos modos de PSA: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. No añadas `enforce`: este es un namespace para la observación gradual antes del bloqueo. |
| Criterios de aceptación | Están presentes los cuatro labels audit/warn con el nivel `baseline` y la versión `v1.36`; el enforce-label no está. |

<details>
<summary>💡 Pista para la tarea 3</summary>

Cuatro labels separados: es fácil olvidar uno de ellos (sobre todo el `-version` de uno de los modos). Comprueba los cuatro a la vez: `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Baseline: ANTES de establecer los labels, el manifest infractor debe pasar sin advertencia de PSA
(el namespace aún no se observa):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

Establece los cuatro labels y luego repite EL MISMO manifest: ahora `kubectl apply`
debe mostrar `Warning: ... would violate PodSecurity "baseline:v1.36"`, y el comando
igualmente debe terminar con éxito (exit 0), y no con un error:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit no bloquean el legacy workload** |
| :---: | :--- |
| Qué hacemos | Crea en `psa-observe-107` un Pod `baseline-audit-sample` con `busybox:1.36`, que funcione con `hostNetwork: true` y ejecute `sleep 3600`. En `kubectl apply` registra la advertencia de PSA sobre la infracción de baseline: el Pod debe crearse, porque `warn` y `audit` por sí solos no prohíben la petición. |
| Criterios de aceptación | `baseline-audit-sample` existe, tiene `hostNetwork: true` y fue admitido por la API; en el namespace sigue sin haber enforce-mode. |

<details>
<summary>💡 Pista para la tarea 4</summary>

Si el Pod NO se creó, comprueba que no hayas establecido por accidente el label `enforce` en la tarea 3 en lugar de solo `audit`/`warn`. El Warning de PSA aparece directamente en la salida de `kubectl apply` (`Warning: would violate PodSecurity "baseline:v1.36"`), no hace falta buscarlo en un log aparte.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Esta tarea en realidad repite el self-check de la tarea 3, pero con un Pod permanente. Tras
crear `baseline-audit-sample`, asegúrate de que realmente existe y está
`Running`/`Pending` (no fue rechazado):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

Compara con el namespace `psa-restricted-107` (tarea 1): el mismo manifest inseguro allí
DEBE ser rechazado, y aquí, aceptado. La diferencia está precisamente en el label `enforce`, que está
en un namespace y no está en el otro:

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **Read-only root filesystem con un emptyDir escribible** |
| :---: | :--- |
| Qué hacemos | Completa `restricted-app`: en el contenedor habilita `readOnlyRootFilesystem: true`. Crea un volume `writable-tmp` de tipo `emptyDir` (se recomienda `medium: Memory`, para que los archivos temporales no vayan al disco del nodo) y móntalo en `/tmp` sin `readOnly: true`. El contenedor solo puede escribir en este volumen temporal; no uses `hostPath`. Demuestra ambos resultados con una llamada en vivo dentro del Pod: un intento de escritura en la raíz del contenedor (por ejemplo, `touch /root-write-test.txt`) debe terminar con el error `Read-only file system`, y la escritura en `/tmp/test.txt` debe tener éxito. Al cambiar campos inmutables del Pod, elimina y vuelve a crear `restricted-app` con el mismo nombre. |
| Criterios de aceptación | El contenedor tiene read-only root filesystem; el `emptyDir` con el nombre `writable-tmp` está montado en `/tmp` como writable; para los regular containers este es el único `volumeMount` declarativo writable, y todos los `volumeMounts` adicionales son read-only; los ajustes hardened de la tarea 2 se conservan; el intento de escritura en vivo en la raíz del contenedor devuelve `Read-only file system`, y la escritura en `/tmp/test.txt` termina con éxito y con contenido legible. |

<details>
<summary>💡 Pista para la tarea 5</summary>

`readOnlyRootFilesystem` es uno de los campos que no se pueden cambiar en un Pod ya existente (immutable field): `kubectl apply` con un securityContext modificado devolverá un error. Elimina el Pod (`kubectl delete pod restricted-app`) y créalo de nuevo con el mismo nombre, en lugar de intentar actualizar el existente in situ.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: exigir `automountServiceAccountToken: false`** |
| :---: | :--- |
| Qué hacemos | • PSA `restricted` ya exige `allowPrivilegeEscalation: false`, que `capabilities.drop` contenga `ALL`, non-root y seccomp: la tarea 2 muestra precisamente eso.<br/>• Pero PSS `restricted` **no comprueba** `automountServiceAccountToken`: un Pod que no necesita la Kubernetes API puede recibir silenciosamente un ServiceAccount token montado y pasar PSA por completo. Es un control aparte, no cubierto por PSS, por lo que aquí procede precisamente una `ValidatingAdmissionPolicy` custom, y no duplicar el PSA integrado.<br/>• Crea una `ValidatingAdmissionPolicy` `require-no-automount-token` con una expresión CEL que exija `automountServiceAccountToken == false` a nivel de Pod.<br/>• Aplica un `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, limitado por `matchResources.namespaceSelector` a `psa-restricted-107`, con `validationActions: [Deny]`.<br/>• Demuestra los tres estados con server-side dry-run: un Pod totalmente compatible con PSA (con todos los campos de la tarea 2: non-root, seccomp, drop ALL, escalation false) sin el campo debe recibir DENY de la pareja exacta policy+binding; `automountServiceAccountToken: false` debe recibir ALLOW; `automountServiceAccountToken: true` debe volver a recibir DENY de la misma pareja.<br/>• Tras crear la policy, los nuevos Pods en `psa-restricted-107` (incluido el `restricted-app` que se recrea) deben contener por sí mismos `automountServiceAccountToken: false`, de lo contrario la política los rechazará. |
| Criterios de aceptación | • **Objetos:** existen `ValidatingAdmissionPolicy require-no-automount-token` y su `ValidatingAdmissionPolicyBinding`, `validationActions` contiene `Deny`, el Binding hace match solo con `psa-restricted-107`. En el laboratorio existe exactamente un Binding para esta policy: `require-no-automount-token-binding`; no se crean Bindings adicionales de esta policy para otros namespaces.<br/>• **Tres estados:** el server-side dry-run de un Pod compatible con PSA sin `automountServiceAccountToken: false` es rechazado precisamente por la pareja `ValidatingAdmissionPolicy 'require-no-automount-token'` y `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` (no por el mensaje de PSA `violates PodSecurity` ni por otra policy); el Pod con `automountServiceAccountToken: false` es aceptado, y el Pod con `automountServiceAccountToken: true` es rechazado por la misma pareja exacta.<br/>• **Cobertura de todos los Pods:** la policy cubre todos los Pods seleccionados por sus `resourceRules` dentro de `psa-restricted-107`. No añadas `spec.matchConditions`, `matchConstraints.objectSelector` ni `matchConstraints.namespaceSelector` a la `ValidatingAdmissionPolicy`, ni `objectSelector` al Binding `matchResources`: reducen la coverage a una parte de los Pods, y un workload podrá quedar fuera de la comprobación por label o por condición de la petición.<br/>• **Namespace scope:** se define solo mediante el Binding `matchResources.namespaceSelector`, vinculado exactamente a `psa-restricted-107`; el selector no contiene condiciones sobre otras claves de namespace-label y por sí mismo limita sin ambigüedad el scope a este namespace.<br/>• **CEL:** la validation no contiene excepciones por nombre/labels/annotations del Pod, user/request, `namespaceObject`, `params`, `variables` ni otros campos: la decisión depende solo de `object.spec.automountServiceAccountToken` (es admisible cualquier forma CEL correcta, incluida la sintaxis optional `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` está ausente o vacío: sus propias CEL expressions pueden influir en el admission mediante `failurePolicy`, por lo que el admission control se define solo mediante `spec.validations`. No se usan `variables` ni `paramKind`.<br/>• **Resource scope:** `matchConstraints.resourceRules` limitan la policy exactamente a `core/v1 pods` para las operaciones `CREATE` y `UPDATE`, sin `resourceNames`; `scope` está ausente, es `*` o `Namespaced`, pero no `Cluster`; no se usan `excludeResourceRules`. El Binding no reduce el resource/operation scope mediante sus propias `resourceRules`/`excludeResourceRules`.<br/>• Esto permite demostrar el boolean contract completo con tres estados `missing / false / true`, y no con unos cuantos ejemplos de workload elegidos. |

<details>
<summary>💡 Pista para la tarea 6</summary>

El Pod de prueba de esta tarea debe ser TOTALMENTE compatible con PSA (todos los campos de la tarea 2), salvo la ausencia de `automountServiceAccountToken: false`: si el Pod de prueba infringe a la vez PSS y tu nueva policy, no podrás demostrar que ha actuado precisamente TU policy y no el PSA integrado. Un `ValidatingAdmissionPolicyBinding` sin `matchResources.namespaceSelector` se aplicará a TODO el clúster: limita obligatoriamente el scope EXACTAMENTE a un solo namespace `psa-restricted-107` (por ejemplo mediante `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`), y no mediante `matchExpressions` con varios valores, donde `psa-restricted-107` es solo uno de varios namespaces coincidentes: si tu selector hace match por accidente también con `psa-observe-107`, la misma regla empezará a actuar inesperadamente también allí.
</details>

<details>
<summary>🔍 Compruébate antes de `check_result`</summary>

Baseline: ANTES de crear VAP/Binding, el mismo Pod compatible con PSA, pero sin el automount opt-out,
debe pasar (PSA por sí mismo no lo rechaza, `automountServiceAccountToken` no forma parte
de PSS):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

Crea VAP + Binding y repite el manifest sin el campo: ahora la petición debe recibir
DENY precisamente de `ValidatingAdmissionPolicy 'require-no-automount-token'` mediante el binding
`require-no-automount-token-binding`, NO de PSA. Después comprueba ambos valores explícitos:
`false` debe pasar, y `true` debe recibir DENY de la misma pareja exacta.

```bash
kubectl apply -f require-no-automount-token.yaml   # tu VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# se espera: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Con el mismo manifest compatible con PSA, establece `automountServiceAccountToken: false`: la petición
debe pasar:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# se espera: pod/self-check-automount-false created (o server-side dry-run success)
```

Ahora establece `automountServiceAccountToken: true`: la petición debe volver a ser rechazada
por exactamente la misma policy y binding:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# se espera: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Por último, lo más importante (comprueba el LÍMITE del scope, y no solo el hecho del denial): el mismo
manifest (sin el automount opt-out), pero en el namespace `psa-observe-107`, debe PASAR; si
también es rechazado, significa que tu `namespaceSelector` hace match con más de un namespace:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# se espera: 0 (no denied); de lo contrario el scope del binding es demasiado amplio
```
</details>

---

| **7** | **Controller-driven admission denial: diagnóstico mediante ReplicaSet events** |
| :---: | :--- |
| Qué hacemos | En el namespace vacío `psa-controller-107` crea un Deployment `controller-app` (label `app=controller-app`, replicas=1) con un Pod template simple sin hardening (por ejemplo `busybox:1.36`, `sleep 3600`, sin `securityContext`): debe arrancar con éxito, PSA todavía no estorba. Después habilita `pod-security.kubernetes.io/enforce=restricted` y `enforce-version=v1.36` en este namespace (el Pod ya existente seguirá funcionando: PSA no toca los objetos ya creados). Elimina el Pod actual: el ReplicaSet intentará crear un reemplazo, y ahora el admission lo rechazará. Comprueba la causa mediante `kubectl -n psa-controller-107 describe rs` y `kubectl -n psa-controller-107 get events`: allí habrá un `FailedCreate` con el texto `violates PodSecurity "restricted:v1.36"`. Corrige el Pod template del Deployment (añade los mismos campos de hardening que en la tarea 2: non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) y espera a que el ReplicaSet cree con éxito un Pod nuevo que pase. |
| Criterios de aceptación | En el namespace está activo el enforce `restricted:v1.36`; el Pod template del Deployment cumple por completo el PSS `restricted`; tras eliminar el Pod actual, el ReplicaSet realmente crea un nuevo Pod Ready bajo el enforce-mode actual (no simplemente "el objeto existe": se comprueba mediante una eliminación en vivo y una nueva creación). |

<details>
<summary>💡 Pista para la tarea 7</summary>

El orden es importante: primero el Deployment sin hardening (pasa, PSA todavía no es enforce), luego el
label enforce=restricted en el namespace (el Pod existente no se verá afectado), luego `kubectl
delete pod -l app=controller-app`: es aquí donde el ReplicaSet se topará con el admission deny.
Si no eliminas el Pod a mano, no verás el rechazo en absoluto hasta que de forma natural
ocurra algún reschedule. Hay que corregir precisamente el `spec.template` del Deployment (`kubectl
edit deployment controller-app` o `kubectl apply` con el manifest corregido), y no el
label del namespace: revertir el enforce no es la solución de esta tarea.
</details>

---

## Comprobación

En la máquina de trabajo ejecuta:

```bash
check_result
```

La comprobación contiene Init y siete tareas independientes. Además ejecuta un
server-side dry-run de un Pod inseguro, por lo que la ausencia de un Pod "malo" permanente en el
namespace restricted es un resultado esperado y correcto. En la tarea 7 el checker elimina por sí mismo el
Pod actual `controller-app` y comprueba que el ReplicaSet realmente recrea un Pod Ready;
no acepta como prueba el texto de los events.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD)

## Eliminación

```bash
TASK=107 make delete_cks_task
```

## Nota sobre la versión de PSA y la observabilidad de audit

El laboratorio fija deliberadamente los PSA labels en `v1.36`, ya que el propio clúster de laboratorio funciona
con Kubernetes 1.36.0. A fecha de 2026-09-06, el blueprint oficial de CKS está orientado a Kubernetes
`v1.35`; por eso esta es una configuración didáctica **forward-looking**, y no una afirmación sobre la versión del
examen. Para prepararte para el examen actual, sustituye los sufijos `*-version` por `v1.35` y
contrasta el comportamiento con la documentación de esa versión.

El modo `audit` añade al **audit event de kube-apiserver** la annotation
`pod-security.kubernetes.io/audit-violations` para el Pod infractor. La infraestructura de laboratorio
no configura ni proporciona un audit-log sink, por lo que aquí no se puede leer esta annotation mediante `kubectl`. La
evidencia observable en la tarea 4 es la advertencia de PSA
(`Warning: ... would violate PodSecurity "baseline"`) durante el server-side admission y la creación
exitosa del Pod sin `enforce`; el audit mode está explicado, pero su log annotation no se comprueba
en este laboratorio.
