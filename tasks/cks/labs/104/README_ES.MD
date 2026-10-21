[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 104 - Restricción del acceso a la Kubernetes API: RBAC, ServiceAccount y anonymous-auth

## Objetivo

En este laboratorio de CKS restringirás el acceso a la Kubernetes API según el principio de mínimo
privilegio. La práctica abarca un RBAC namespaced mínimo, los modernos tokens de
ServiceAccount de corta duración, un Pod sin API-token, la eliminación de permisos
excesivos obsoletos y la desactivación del acceso anónimo al API server.

Trabaja solo con los objetos indicados en las tareas. El namespace `security-104` y
el binding deliberadamente peligroso `legacy-operator-admin` ya han sido preparados por el script de arranque, igual que
los fixtures de las tareas 10-12: el Secret `legacy-config`, los namespace `rbac-a`/`rbac-b` y el
namespace `development`. Es una configuración didáctica, y no un ejemplo para producción.

## Threat model

Supongamos que un atacante ya ejecuta código en un Pod e intenta usar la identity del workload o la ausencia de authentication para avanzar hacia la Kubernetes API. En ese caso importa no solo el acceso inicial, sino también el blast radius tras el compromise.

La tarea 1 cierra un RBAC scope excesivo, la tarea 2 - un token de larga duración, y la tarea 3 - un acceso innecesario a la API desde un Pod. Esto reduce las posibilidades de usar la identity del workload tras el compromise.

La tarea 4 elimina los permisos wildcard cluster-wide, y la tarea 5 - el anonymous access. Cada uno de estos caminos por separado puede ampliar el blast radius hasta la Kubernetes API.

La tarea 6 cierra un camino de fuga aparte: un secret pasado mediante una environment variable pasa a formar parte del entorno del proceso y puede ser leído desde `/proc/1/environ` por cualquier proceso con acceso a `exec` en el contenedor, y también puede acabar en los application logs, en un crash dump o en otra salida de diagnóstico si el propio programa o la herramienta de diagnóstico imprime el entorno. `kubectl describe pod` para `env`/`envFrom` con `secretKeyRef` muestra solo la referencia al Secret y su clave (`<set to the key ... in secret ...>`), y no el valor resuelto: no confundas esa referencia con una fuga del propio valor. Un volume mount con `defaultMode: 0400` no elimina el acceso del proceso autorizado del contenedor al valor, pero saca el secret del entorno del proceso y limita los permisos de archivo de lectura únicamente al propietario.

La tarea 7 cierra los caminos ocultos de RBAC privilege escalation: `impersonate`, `bind`/`escalate` y la CSR approval no amplían directamente la lista de recursos disponibles, sino que permiten actuar en nombre de otro o concederse uno mismo permisos más amplios: es una categoría de riesgo aparte respecto del wildcard `*` de la tarea 4. La tarea 8 cierra una protección sistémica, y no puntual: el automount a nivel de namespace/default SA funciona incluso para un Pod en el que el desarrollador olvidó desactivar explícitamente el token.

La tarea 9 muestra que la prevención (tareas 1-8) y la detección son capas distintas y complementarias. Incluso si los caminos concretos de escalada están cerrados en la tarea 7, para un incidente futuro hace falta una forma de ver un **cambio peligroso de RBAC** (por ejemplo, una concesión errónea o malintencionada de `cluster-admin` a alguien) sin un `kubectl get` manual constante: el audit log proporciona forensic evidence reproducible sobre quién inició exactamente el cambio, y no solo una instantánea del estado actual de RBAC.

ATT&CK T1528 (Steal Application Access Token) y T1613 dan contexto a este escenario: las tareas no modelan un ataque aparte, sino que limitan las consecuencias de un workload ya comprometido.

Las tareas 10-12 cubren tres workflow básicos, frecuentes en el examen, y no amenazas nuevas: la tarea 10 - reutilización segura de un secret existente sin hardcodear caso por caso los valores en los manifests; la tarea 11 - reparación puntual de un Role excesivo y un RBAC-binding cross-namespace correcto, donde es fácil equivocarse con el scope; la tarea 12 - un onboarding completo de un nuevo usuario mediante certificado, desde la private key hasta un acceso verificable, y no solo el análisis de un kubeconfig ya preparado.

## Compruébate antes de empezar

Antes de abrir `check_result`, asegúrate de que responderías con seguridad a estas preguntas. Si no, vuelve al [capítulo 10](../../course/10/es.md) (RBAC), al [capítulo 11](../../course/11/es.md) (ServiceAccounts) y al [capítulo 12](../../course/12/es.md) (restricción del acceso a la API).

<details>
<summary>1. ¿En qué se diferencian `Role`+`RoleBinding` de `ClusterRole`+`ClusterRoleBinding` en el contexto de la tarea 1?</summary>

`Role` actúa solo en un namespace, pero su `RoleBinding` PUEDE referirse a un sujeto (por ejemplo, un ServiceAccount) de CUALQUIER otro namespace: Kubernetes admite oficialmente un `subjects[].namespace` distinto del namespace del propio `RoleBinding`. Lo que permanece fijo es el SCOPE de los permisos concedidos: los permisos actúan solo en el namespace donde se creó el `RoleBinding`, con independencia de dónde esté el sujeto. `RoleBinding` también puede referirse a un `ClusterRole` (y no solo a un `Role`): en ese caso se obtienen los permisos de una plantilla cluster-wide, pero concedidos únicamente en el namespace del `RoleBinding` concreto. `ClusterRole`+`ClusterRoleBinding` da acceso a todo el clúster. La tarea 1 exige un acceso **namespaced** mínimo, por eso `Role`, y no `ClusterRole`; de lo contrario el scope es más amplio de lo necesario.
</details>

<details>
<summary>2. ¿Por qué un bound projected token (tarea 2) se considera más seguro que un legacy Secret-based token?</summary>

Un bound projected token es de corta duración (se define con `expirationSeconds`), caduca automáticamente y lo rota el kubelet, y está ligado a un Pod concreto: al eliminar el Pod, el token deja de ser válido. Un legacy Secret-token no tiene expiration, se guarda como un `Secret` normal en etcd y sigue siendo válido indefinidamente, aunque el Pod ya no exista.
</details>

<details>
<summary>3. ¿Cuál es la diferencia entre lo que aporta `automountServiceAccountToken: false` a nivel de Pod y a nivel de ServiceAccount?</summary>

A nivel de ServiceAccount es un baseline: el valor se aplica a todos los Pod que usan ese SA, si el Pod no lo redefine explícitamente. A nivel de Pod es un override: el campo explícito en el Pod spec tiene prioridad sobre el valor del SA. La tarea 8 comprueba específicamente el baseline a nivel de SA/namespace, y las tareas 2-3 - la configuración explícita a nivel de un Pod concreto.
</details>

<details>
<summary>4. ¿Por qué `impersonate`/`bind`/`escalate` (tarea 7) no pertenecen a la misma clase de riesgo que el wildcard `*` (tarea 4)?</summary>

El wildcard `*` en `resources`/`verbs` amplía directamente la **lista de operaciones y recursos disponibles**. `impersonate`/`bind`/`escalate` no dan acceso a nuevos recursos por sí mismos: dan la posibilidad de **actuar en nombre de otro** (`impersonate`) o de **concederse a uno mismo permisos que originalmente no se tenían** (`bind`/`escalate`). Es una categoría aparte de privilege escalation, fácil de pasar por alto al auditar RBAC si solo se miran `verbs`/`resources` sin tener en cuenta estos tres verbos especiales.
</details>

## Infraestructura

El entorno se despliega mediante Terragrunt en AWS `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas |
| `ssh-keys` | claves para acceder a los nodos |
| `k8s-1` | clúster kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd y **Calico** |
| `worker` | máquina de trabajo con `kubectl` configurado y `check_result` |

El control-plane permite ejecutar Pods normales, por lo que no hace falta un nodo worker aparte.
Para la tarea 5 se necesitará acceso SSH al control-plane: es allí donde está el manifest
del static Pod del API server.

## Despliegue

```bash
TASK=104 make run_cks_task
```

Conéctate por SSH a la máquina de trabajo. El contexto `cluster1-admin@cluster1` ya está configurado.

```bash
time_left
check_result
```

## Tareas

---
| **1** | **RBAC mínimo para leer Pods** |
| :---: | :--- |
| Qué hacemos | En el namespace `security-104` crea un ServiceAccount `auditor`, un Role `pod-observer` y un RoleBinding `auditor-pod-observer`. El Role debe permitir **solo** `get`, `list`, `watch` del recurso `pods` de la core API. Vincúlalo únicamente al ServiceAccount `auditor`. |
| Criterios de aceptación | El Role contiene exactamente una regla para `pods` con los verbos `get`, `list`, `watch`; el RoleBinding se refiere a este Role y al ServiceAccount `auditor`; en nombre de `auditor` no se pueden eliminar `secrets`. |

<details>
<summary>💡 Pista para la tarea 1</summary>

Un error frecuente es añadir verbos de más (por ejemplo, `create` "por si acaso") o usar `ClusterRole` en lugar de `Role`. Compruébalo: `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` debe devolver `yes`, y `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. Si el Role y el RoleBinding están en namespaces distintos, el binding no surtirá efecto: el `RoleBinding` debe estar en el mismo namespace que el `Role`, y el sujeto en él debe coincidir exactamente en `name`/`namespace`.
</details>

---
| **2** | **Projected ServiceAccount token de corta duración** |
| :---: | :--- |
| Qué hacemos | Crea un ServiceAccount `api-client` y un Pod `token-client` en `security-104`. No uses un legacy Secret-token. Desactiva el automontaje normal del token y monta el token necesario mediante **exactamente un** projected `serviceAccountToken` source en `/var/run/secrets/tokens/api-token` con `path: api-token` y `expirationSeconds` de `600` a `3600` inclusive: no añadas ningún `serviceAccountToken` source adicional en el mismo (ni en otro) projected volume. **No indiques `audience`**, para que el kubelet solicite el identifier del API server por defecto. Si la aplicación necesita una audience propia, primero contrástala con `--api-audiences` (o con el default de `--service-account-issuer`) en el API server y solo después indícala explícitamente. |
| Criterios de aceptación | El Pod usa `api-client`, tiene `automountServiceAccountToken: false` y contiene **exactamente un** projected `serviceAccountToken` source en toda la especificación del Pod: sin audience fijada rígidamente, con el path indicado y `expirationSeconds` en el rango `600`-`3600` (ambos límites incluidos). Un TokenReview, ejecutado desde el contexto admin para el token montado, devuelve `authenticated: true` y el nombre `system:serviceaccount:security-104:api-client`; una comprobación RBAC aparte confirma que este ServiceAccount no puede eliminar `secrets`. |

<details>
<summary>💡 Pista para la tarea 2</summary>

No hace falta recordar de memoria la sintaxis exacta de `projected.sources[].serviceAccountToken`: en `kubernetes.io/docs` hay un ejemplo ya hecho: Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), sección **"serviceAccountToken projected volumes"**. El error más frecuente es indicar explícitamente `audience: kubernetes.default.svc`, suponiendo que es el valor estándar. Para un clúster kubeadm NO es un default garantizado: si indicas una audience que el API server no acepta mediante `--api-audiences`, TokenReview devolverá `authenticated: false`. Simplemente no indiques el campo `audience` en absoluto: entonces el kubelet solicitará el identifier del API server por defecto, que el servidor acepta con seguridad. Tampoco olvides `automountServiceAccountToken: false` en el propio Pod: de lo contrario Kubernetes añadirá además un volume de token normal (de estilo legacy) junto a tu projected volume. Otro error frecuente es elegir un `expirationSeconds` demasiado pequeño (por ejemplo `300`): la Kubernetes API exige un mínimo de `600` segundos para un `serviceAccountToken` projected volume; un valor menor no cumple el API contract, aunque el manifest se aplique sin un error explícito en la etapa de `kubectl apply`.
</details>

---
| **3** | **Pod sin token de la Kubernetes API** |
| :---: | :--- |
| Qué hacemos | Crea un ServiceAccount `no-token-sa` con `automountServiceAccountToken: false` y un Pod `no-token` en `security-104` con ese ServiceAccount. En el propio Pod establece también explícitamente `automountServiceAccountToken: false`. Usa cualquier imagen segura de larga duración, por ejemplo `busybox:1.36` con `sleep 3600`. No montes aparte a mano ningún Secret con el token del ServiceAccount: el Pod no debe tener en absoluto ningún API-token, ni mediante automount ni mediante un legacy Secret montado explícitamente. |
| Criterios de aceptación | En el ServiceAccount y en el Pod el automontaje está desactivado; el Pod usa `no-token-sa`; en su especificación no hay un volumen de token de ServiceAccount añadido automáticamente ni un Secret montado a mano del tipo `kubernetes.io/service-account-token`; el intento de leer `/var/run/secrets/kubernetes.io/serviceaccount/token` dentro del contenedor termina con un error (el archivo no existe), mientras que el propio `kubectl exec` debe ejecutarse con éxito. |

<details>
<summary>💡 Pista para la tarea 3</summary>

La diferencia con la tarea 8: aquí basta con desactivar el automount en el SA o en el Pod, pero la tarea exige **ambos** niveles a la vez (defence in depth), y no solo uno de ellos. Compruébalo: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` no debe contener nada parecido a `kube-api-access-*`. Si el volumen aun así apareció, comprueba que desactivaste el automount ANTES de crear el Pod, y no después (cambiar el SA no afecta a los Pod ya creados). Un automount desactivado no impide montar a mano un `Secret` antiguo (legacy) con `type: kubernetes.io/service-account-token` mediante `volumes[].secret`: si lo haces, el Pod formalmente no tiene un volumen automounted, pero de hecho recibirá igualmente un API-token válido. La tarea exige la ausencia total del token, y no solo la ausencia de automount.
</details>

---
| **4** | **Eliminar los permisos cluster-wide excesivos** |
| :---: | :--- |
| Qué hacemos | En el clúster se han dejado deliberadamente el ClusterRole `legacy-operator-admin` con permisos wildcard y un ClusterRoleBinding con el mismo nombre para el ServiceAccount `legacy-operator` de `security-104`. Elimina **ambos** objetos. No sustituyas el acceso wildcard por otro ClusterRole amplio. |
| Criterios de aceptación | `legacy-operator-admin` no existe ni como ClusterRole ni como ClusterRoleBinding; el ServiceAccount `legacy-operator` ya no puede leer `secrets` en `security-104`. |

<details>
<summary>💡 Pista para la tarea 4</summary>

Eliminar solo el `ClusterRoleBinding` sin eliminar el `ClusterRole` deja en el clúster una plantilla peligrosa: alguien podría crear más tarde un nuevo binding hacia ella. Elimina ambos objetos. Compruébalo con dos comandos separados: `kubectl get clusterrole legacy-operator-admin` y `kubectl get clusterrolebinding legacy-operator-admin`; ambos deben devolver `NotFound`.
</details>

---
| **5** | **Desactivar el anonymous access al API server** |
| :---: | :--- |
| Qué hacemos | • Crea en el control-plane el archivo `/etc/kubernetes/authentication-config.yaml` con un `AuthenticationConfiguration` que desactive el anonymous access a todos los endpoint, excepto `/livez`, `/readyz` y `/healthz`: son precisamente estas rutas las que kubeadm usa para los HTTPS liveness/readiness/startup probes del static Pod del API server, y un `--anonymous-auth=false` completo rompe los propios probes, y no solo el acceso del atacante.<br/>• Conecta el archivo mediante un `hostPath` volume y el argumento `--authentication-config=<ruta-en-el-contenedor>` en `/etc/kubernetes/manifests/kube-apiserver.yaml`, y **elimina** el `--anonymous-auth=true` existente: ambas formas de configurar el anonymous access se excluyen mutuamente, y kube-apiserver no arrancará si se indican las dos. El kubelet reiniciará el static Pod automáticamente.<br/>• Espera a que el API server esté listo (el Pod permanece Running/Ready) y asegúrate de que una petición no autenticada a `/version` recibe `401`, y a `/livez` y `/readyz` - `200`.<br/>• Además, comprueba que el `--authorization-mode` efectivo contiene `Node,RBAC` y **no** contiene `AlwaysAllow` (una authentication sin una authorization restrictiva carece de sentido).<br/>• Audita los ClusterRoleBinding cuyos subjects sean `system:anonymous`/el grupo `system:unauthenticated`: en el clúster se ha dejado deliberadamente un binding peligroso (lab-owned) de este tipo, `lab104-unintended-anonymous-access`; elimínalo junto con su ClusterRole. **No toques** el binding estándar de kubeadm `system:public-info-viewer`: también está vinculado a `system:unauthenticated`, pero da acceso solo a los non-resource URL `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`; es una parte normal del bootstrap (default Kubernetes RBAC), y no un hallazgo para esta tarea.<br/>• Esta es una capa distinta del `AuthenticationConfiguration` de esta misma tarea: `anonymous.conditions` allí permite deliberadamente la identity anónima solo en `/livez`/`/readyz`/`/healthz`; `/version` no es accesible de forma anónima precisamente porque la petición a él no recibe en absoluto una anonymous identity en la etapa de authentication, y no se llega a la authorization mediante `system:public-info-viewer`, ni siquiera con esa lista más amplia de non-resource URL. |
| Criterios de aceptación | • El static Pod del API server usa `--authentication-config`, que apunta a un `AuthenticationConfiguration` con `anonymous.enabled: true` y `conditions` que incluyen exactamente `/livez`, `/readyz`, `/healthz`.<br/>• El argumento `--anonymous-auth` no está.<br/>• El Pod kube-apiserver permanece `Running`/`Ready` tras el reinicio.<br/>• Un `GET /version` no autenticado devuelve `401`.<br/>• `GET /livez` y `GET /readyz` no autenticados devuelven `200`.<br/>• Una petición autenticada a `/readyz` (con credentials válidas) también funciona.<br/>• El `--authorization-mode` efectivo contiene `Node,RBAC` y no contiene `AlwaysAllow`.<br/>• El ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` están eliminados.<br/>• El estándar `system:public-info-viewer` ha quedado intacto.<br/>• El grupo `system:unauthenticated` no puede leer `pods`/`secrets`/`configmaps` en ningún namespace. |

<details>
<summary>💡 Pista para la tarea 5</summary>

No edites el objeto Pod con `kubectl edit pod`: el kubelet vigila el archivo de manifest y devolverá al estado original cualquier cambio hecho a través de la API. Edita precisamente el archivo `/etc/kubernetes/manifests/kube-apiserver.yaml` en el disco del nodo. Tras guardar, espera: el kubelet no detecta el cambio del archivo al instante, y el API server no estará disponible unos segundos durante el reinicio del static Pod; no te asustes si `curl` justo después de guardar el archivo no devuelve nada.

Un simple `--anonymous-auth=false` aquí **no sirve**: kubeadm `release-1.36` genera el static Pod de kube-apiserver con HTTPS liveness/readiness/startup probes precisamente en `/livez` y `/readyz`, y los HTTP probes del kubelet no transmiten client credentials; con el anonymous access completamente desactivado, esas peticiones reciben `401`, el kubelet considera el contenedor no sano y puede reiniciar kube-apiserver en bucle, lo que rompe no solo esta tarea, sino también la posterior tarea 9. El camino correcto es un `AuthenticationConfiguration` con `anonymous.enabled: true` y `anonymous.conditions` que limiten el anonymous access únicamente a las rutas de health necesarias:

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` y `--anonymous-auth` no se pueden indicar a la vez: kube-apiserver no arrancará si ambos argumentos están presentes en el manifest. Asegúrate de haber eliminado `--anonymous-auth=true` por completo, y no de haber cambiado simplemente el valor a `false`.

Para auditar los ClusterRoleBinding anónimos: `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. Verás como mínimo DOS
bindings: el estándar `system:public-info-viewer` (no lo toques) y el lab-owned
`lab104-unintended-anonymous-access` (elimínalo junto con su ClusterRole
`lab104-anonymous-debug-access`). Se pueden distinguir por el nombre del ClusterRole al que
se refieren: `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` mostrará `system:public-info-viewer`: es un ClusterRole
limitado a non-resource URL, y no a resources normales.
</details>

---
| **6** | **Fuga de Secret mediante env en `/proc/1/environ`: paso a volume** |
| :---: | :--- |
| Qué hacemos | • El Pod `app-vulnerable` en `security-104` recibe `db-creds` mediante `envFrom.secretRef`: el valor está disponible para cualquiera que pueda hacer `kubectl exec` en el contenedor (`cat /proc/1/environ`) o leer los logs/describe si el env se imprime por accidente.<br/>• Confirma esta fuga: ejecuta `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` y guarda la salida (con `DB_PASSWORD`) en `/var/work/tests/artifacts/6/env-leak-before.txt`.<br/>• Recrea el Pod con el mismo nombre `app-vulnerable`: elimina `envFrom`/`env` con este secret, monta `db-creds` como volume `db-creds-vol` en `/etc/secrets` **read-only**, con `defaultMode: 0400`.<br/>• Confirma la ausencia de la variable `DB_PASSWORD` en el nuevo `/proc/1/environ` y guarda el `stat -L -c '%a'` del archivo montado en `/var/work/tests/artifacts/6/secret-file-mode.txt` (el flag `-L` es obligatorio: el secret se monta mediante una cadena de symlinks `..data`; sin `-L`, `stat` mostrará el modo del propio symlink, y no del archivo real). |
| Criterios de aceptación | `env-leak-before.txt` contiene el valor REAL de `DB_PASSWORD` del Secret `db-creds` (no simplemente la palabra `DB_PASSWORD`); el Pod final `app-vulnerable` no tiene `env`/`envFrom` que se refieran a `db-creds` y no tiene una segunda forma de montar el mismo Secret; el volume `db-creds-vol` está montado en `/etc/secrets` como `readOnly: true` con `defaultMode: 0400` (`256` decimal): el checker comprueba por sí mismo `stat -L -c %a` dentro del contenedor y exige exactamente `400`; `DB_PASSWORD` no está en `/proc/1/environ` del Pod final (con un `exec` ejecutado con éxito: un `exec` fallido no cuenta como prueba); el proceso de la aplicación, además, aún puede leer realmente el valor del secret desde `/etc/secrets/DB_PASSWORD` (positive control). |

<details>
<summary>💡 Pista para la tarea 6</summary>

`/proc/1/environ` en el paso de confirmación de la fuga no es la única forma de ver el valor
(el mismo resultado lo dará `kubectl exec ... -- env` o `echo $DB_PASSWORD`, porque
el container runtime por defecto da al proceso exec'ado el mismo entorno que al PID 1).
`/proc/1/environ` lee el entorno precisamente del PID 1 directamente a través de `/proc`, y no se apoya en
lo que haya heredado tu exec-shell concreto: es la misma técnica que se usa realmente
en el security-análisis para ver el entorno de cualquier proceso, y no solo del propio.

Un volume mount **no quita el acceso a quien ya tiene `kubectl exec`**: `cat
/etc/secrets/DB_PASSWORD` después de la corrección lee el valor con la misma facilidad con que `cat
/proc/1/environ` lo leía antes de la corrección, y es lo esperado (el positive control de la tarea
lo comprueba precisamente). La tarea no trata de cerrar el acceso exec: es imposible tanto para un archivo como para
una variable, si el proceso tiene derecho a leer el valor. La diferencia real está en los caminos de
fuga que actúan SIN un `exec` explícito:
- las variables de entorno las hereda automáticamente **cualquier** proceso hijo (`fork()`
  copia todo el env): una biblioteca de terceros, un plugin o un subprocess accidental dentro de la
  aplicación recibirá `DB_PASSWORD`, aunque el desarrollador no lo haya pensado; un archivo no se
  transmite así: el proceso hijo debe conocer explícitamente la ruta y abrirlo;
- los crash handlers y los error-loggers suelen imprimir todo el `environ` del proceso al
  fallar: eso irá a los logs automáticamente; el contenido de un archivo por sí solo no
  llegará a los logs mientras el código no lo lea y lo registre explícitamente;
- las variables de entorno no tienen modelo de permisos de acceso: las ve cualquier proceso en el namespace
  del contenedor; un archivo con `defaultMode: 0400` sí lo tiene: lo lee solo un proceso con el UID necesario.

```text
[FAIL] defaultMode del Secret Volume indicado incorrectamente.
💡 Indicaste defaultMode: 400 (decimal 400).
   YAML admite un literal octal con un cero inicial (0400), que Kubernetes
   interpreta como permisos Unix normales; sin el cero inicial, 400 se lee como el número
   decimal 400, y no como los permisos 0400 (que en decimal es 256).
```

Este es el error más frecuente de esta tarea: `defaultMode` es un campo numérico con POSIX mode bits, y
Kubernetes YAML admite para él tanto la notación octal como la decimal, a diferencia
de JSON, donde solo es válida la decimal. Si escribes `defaultMode: 400` (sin cero
inicial), Kubernetes lo interpretará como el **decimal** 400, y no como los habituales permisos Unix
`0400`. La forma correcta es escribir `defaultMode: 0400` (con el cero inicial, YAML
reconoce el literal octal) o indicar explícitamente el equivalente decimal `256`. Compruébalo:
`kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
debe devolver `256`, y `stat -L -c '%a' /etc/secrets/DB_PASSWORD` dentro del contenedor - `400`.
</details>

---
| **7** | **Auditoría y revocación de los caminos ocultos de RBAC privilege escalation (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| Qué hacemos | • El ClusterRole `build-agent-hidden-privesc` no contiene el wildcard `*` (es un camino aparte, ya eliminado en la tarea 4), pero da al ServiceAccount `build-agent` de `security-104` tres caminos realmente explotables de elevación de privilegios:<br/>• `impersonate` sobre `users`/`groups`/`serviceaccounts` - suplantación de identidad, incluido cluster-admin, si ese usuario es conocido por el atacante.<br/>• `create`/`update`/`bind`/`escalate` sobre `clusterroles` y `create`/`update` sobre `clusterrolebindings` - los verbs básicos permiten crear/modificar los propios objetos, y `bind`/`escalate` eluden la comprobación RBAC integrada, que de otro modo prohibiría conceder/vincular permisos más amplios que los propios (sin los básicos `create`/`update`, `bind`/`escalate` por sí solos no bastan para una escalada real).<br/>• `update` en `certificatesigningrequests/approval` + `approve` en el signer `kubernetes.io/kube-apiserver-client` - la posibilidad de aprobar un CSR con una identity arbitraria (pero este ClusterRole por sí solo no da `create certificatesigningrequests`: para llevar el ataque hasta la emisión de un certificado, la identity también necesita una posibilidad aparte de crear un CSR, por ejemplo mediante otro rol comprometido o una compromised automation que ya sepa enviar CSR).<br/>• Encuentra **todos** los ClusterRoleBinding cuyos ClusterRole permitan `impersonate`, `bind` o `escalate` (por ejemplo, mediante `kubectl get clusterrole -o json \| jq` por `rules[].verbs`), anótalos en `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`.<br/>• Elimina el ClusterRoleBinding `build-agent-hidden-privesc` **y** el ClusterRole `build-agent-hidden-privesc` (y, si encuentras otros no intencionados, también esos, pero no los ClusterRoleBinding de sistema `system:*`).<br/>• Confirma la revocación mediante `kubectl auth can-i` para TODOS los permisos encontrados: `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval`, y también `approve` en el signer `kubernetes.io/kube-apiserver-client`: todos deben devolver `no`. |
| Criterios de aceptación | • `dangerous-bindings-before.txt` contiene `build-agent-hidden-privesc` entre los encontrados como ClusterRoleBinding (y no el nombre del ClusterRole, si no coinciden).<br/>• El ClusterRoleBinding **y** el ClusterRole `build-agent-hidden-privesc` no existen tras la corrección.<br/>• `build-agent` no puede `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`.<br/>• `build-agent` no puede ejecutar `approve` en el signer `kubernetes.io/kube-apiserver-client`.<br/>• Los ClusterRoleBinding de sistema `system:*` no se han tocado. |

<details>
<summary>💡 Pista para la tarea 7</summary>

La CSR approval es una categoría aparte respecto de `impersonate`/`bind`/`escalate`: no entra en el mismo filtro `jq` por `verbs`, porque es una regla aparte sobre el recurso `certificatesigningrequests/approval` con el verb `update`, más `approve` sobre un `signer` concreto. Si filtras solo por `impersonate`/`bind`/`escalate`, encontrarás un camino, pero se te escapará el CSR: busca ambos por separado y, para cada uno, guarda precisamente el nombre del **ClusterRoleBinding**, y no del ClusterRole al que se refiere (en este laboratorio los nombres coinciden, pero en general no está garantizado). No elimines los `ClusterRoleBinding` de sistema con el prefijo `system:`: los necesitan los componentes core de Kubernetes para un `impersonate` legítimo (por ejemplo, `system:kube-controller-manager`).
</details>

---
| **8** | **Baseline a nivel de namespace: ServiceAccount `default` sin automount** |
| :---: | :--- |
| Qué hacemos | • La tarea 3 desactivaba el automount de forma puntual, dentro de un Pod concreto y de su propio ServiceAccount. Aquí hace falta un baseline a nivel de **namespace**.<br/>• Crea el namespace `security-104-baseline`, espera a que aparezca en él el ServiceAccount `default` creado automáticamente (la creación del ServiceAccount ocurre de forma asíncrona mediante un controller aparte, y no a la vez que el propio namespace).<br/>• Solo entonces establece `automountServiceAccountToken: false` en ese ServiceAccount: `kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`.<br/>• Crea en ese namespace un Pod `implicit-default-sa` con `busybox:1.36` (`sleep 3600`), **sin indicar** explícitamente ni `serviceAccountName` ni `automountServiceAccountToken`: debe usar implícitamente el SA `default` y heredar su valor.<br/>• Confirma que en la especificación del Pod final el campo `automountServiceAccountToken` está ausente (y no igual a `false`), no hay volumen de token, y el intento de leer el archivo del token dentro del contenedor termina precisamente con un error de ausencia del archivo (el propio `kubectl exec` debe ejecutarse con éxito). |
| Criterios de aceptación | • El ServiceAccount `default` en `security-104-baseline` tiene `automountServiceAccountToken: false`.<br/>• El Pod `implicit-default-sa` usa `serviceAccountName: default` (implícita o explícitamente).<br/>• En su especificación **no está** el campo `automountServiceAccountToken` (no establecido explícitamente ni en `true` ni en `false`).<br/>• No hay un volume `projected`/`secret` con el token del ServiceAccount añadido automáticamente ni un legacy `Secret` montado a mano del tipo `kubernetes.io/service-account-token`.<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` termina con éxito (exit code `0`), confirmando la ausencia del archivo precisamente mediante un exec exitoso, y no mediante un error arbitrario. |

<details>
<summary>💡 Pista para la tarea 8</summary>

El orden de las operaciones es crítico: si creas el Pod ANTES de que el `patch` se aplique al SA `default` del namespace, el Pod recibirá el token según el valor antiguo (default `true`). Tampoco parchees el SA `default` INMEDIATAMENTE después de `kubectl create namespace` sin comprobar: el ServiceAccount `default` lo crea un controller aparte y puede no existir aún en las primeras fracciones de segundo tras crear el namespace; espera a que aparezca (`kubectl get serviceaccount default -n security-104-baseline`) y solo después parchea. La tarea deliberadamente no indica `serviceAccountName` en el Pod: esto modela la situación real en la que el desarrollador simplemente se olvidó del ServiceAccount, y el baseline debe protegerlo por defecto. Un `automountServiceAccountToken: false` explícito EN EL PROPIO Pod demostraría solo una configuración puntual (como en la tarea 3): aquí hay que dejar el campo completamente sin indicar, para demostrar precisamente la herencia desde el SA/namespace.
</details>

---
| **9** | **Tarea de integración: detectar una escalada de RBAC mediante el audit log y localizarla** |
| :---: | :--- |
| Qué hacemos | • Esta tarea combina RBAC (este laboratorio) con el audit-logging (consulta el [capítulo 32](../../course/32/es.md)): sin el audit log, el propio hecho de un cambio peligroso de RBAC solo se vería post-hoc mediante `kubectl get`, y no como forensic evidence reproducible.<br/>• En el control-plane habilita un audit backend mínimo: crea `/etc/kubernetes/audit/policy.yaml` con una regla `RequestResponse` para `apiGroups: ["rbac.authorization.k8s.io"]`, los recursos `clusterroles` y `clusterrolebindings`, y un catch-all `Metadata` como fallback.<br/>• En el static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` añade `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` y los hostPath volume/volumeMount necesarios (crea los directorios de antemano). Espera a que la API se recupere.<br/>• En nombre del administrador (`cluster1-admin`) crea el ClusterRoleBinding `incident-simulated-escalation`, que vincule el ClusterRole `cluster-admin` al ServiceAccount `build-agent` de `security-104`: esto **no** es un intento de escalada por parte del propio `build-agent` (la tarea 7 ya le revocó los caminos reales de elevación de privilegios), sino un cambio peligroso de RBAC modelado por el administrador: un escenario real en el que alguien (un operador humano, un script, un CI/CD comprometido) concede por error o malintencionadamente `cluster-admin` a un ServiceAccount, y la tarea del ingeniero de SOC/security es detectar precisamente ese evento mediante el audit log, y no mediante un `kubectl get` manual constante.<br/>• Encuentra en el audit log el evento `create` de `clusterrolebindings` con ese nombre, con `requestObject.roleRef` a `cluster-admin` y `system:serviceaccount:security-104:build-agent` en `requestObject.subjects`, y guarda el evento completo (incluido `user.username`, el de quien realmente inició la petición) en `/var/work/tests/artifacts/9/audit-escalation-event.json`. No se trata solo de «asegurarse de que la audit-regla funciona»: la tarea real del ingeniero de SOC aquí es precisamente **extraer y guardar un registro concreto** como forensic evidence (el checker lee por sí mismo e independientemente el `audit.log` en el control-plane y contrasta el `auditID` de tu artefacto con el registro real: un JSON inventado, aunque sea parecido, no pasará).<br/>• Realiza el containment: elimina `incident-simulated-escalation` y confirma mediante `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent` que el acceso está revocado; guarda el `no` final en `/var/work/tests/artifacts/9/containment-result.txt` (`can-i` sin `-n`/`-A` comprueba solo el namespace actual de tu kubeconfig-contexto, y no todo el clúster: indica el namespace explícitamente). |
| Criterios de aceptación | • El static manifest de kube-apiserver contiene `--audit-policy-file` y `--audit-log-path`, el API server está healthy.<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` es un audit event JSON válido con `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation`, `requestObject.roleRef.name: cluster-admin` y el ServiceAccount `build-agent` de `security-104` entre los `requestObject.subjects`.<br/>• El ClusterRoleBinding `incident-simulated-escalation` no existe tras el containment.<br/>• `containment-result.txt` contiene `no`. |

<details>
<summary>💡 Pista para la tarea 9</summary>

La regla `RequestResponse` para `rbac.authorization.k8s.io` debe estar la PRIMERA en la lista de reglas de la policy: la regla más específica debe preceder al catch-all general `Metadata`; de lo contrario el catch-all interceptará el evento antes y obtendrás solo el nivel `Metadata` en lugar de `RequestResponse` con el cuerpo de la petición. Añade `omitStages: [RequestReceived]` a nivel de toda la policy: esa etapa aún no tiene `requestObject`/`responseStatus`, y el catch-all `Metadata` se aplica a absolutamente todas las peticiones del clúster, por lo que sin `omitStages` el `audit.log` crece el doble de rápido sin ningún beneficio adicional para esta tarea. Crea `incident-simulated-escalation` DESPUÉS de que el API server se haya reiniciado con el nuevo audit backend: de lo contrario, el evento simplemente no llegará al log. Esta tarea comprueba la detección del cambio peligroso de RBAC per se, y no que precisamente `build-agent` lo haya realizado: en el audit log el campo `user.username` mostrará al iniciador real (el administrador), y no a `build-agent`; `build-agent` figura en este evento solo como receptor de los permisos (`requestObject.subjects`). `audit-escalation-event.json` debe ser un registro **real**, copiado de `/var/log/kubernetes/audit/audit.log` (incluido su `auditID`): un JSON montado a mano con varias líneas coincidentes no pasará la comprobación, porque el self-check lee por sí mismo el log en el control-plane y contrasta el `auditID`. No olvides el containment: eliminar el `ClusterRoleBinding` por sí solo es la mitad de la tarea; la otra mitad es demostrar mediante `kubectl auth can-i` que el acceso está realmente revocado, y no que simplemente el objeto haya dejado de ser legible.
</details>

---
| **10** | **Decode, create and mount a Secret** |
| :---: | :--- |
| Qué hacemos | • En `security-104` ya existe un Secret Opaque `legacy-config` con dos claves: `SERVICE_USER` y `SERVICE_TOKEN`. Léelo a través de la API y decodifica ambos valores desde base64.<br/>• Crea un nuevo Secret generic `rehydrated-config` a partir de valores literal (`kubectl create secret generic ... --from-literal=...`), con LOS MISMOS nombres de clave y LOS MISMOS valores decodificados.<br/>• Crea un Pod `secret-workflow` con `busybox:1.36` (`sleep 3600`) que monte `rehydrated-config` como un volume **read-only** en `/etc/rehydrated`.<br/>• Confirma que ambos archivos dentro del contenedor realmente se leen y contienen los valores esperados. |
| Criterios de aceptación | • `rehydrated-config` existe y sus `SERVICE_USER`/`SERVICE_TOKEN` decodificados coinciden con los del `legacy-config` original.<br/>• El Pod `secret-workflow` monta precisamente este Secret en `/etc/rehydrated` con `readOnly: true`.<br/>• `kubectl exec` dentro del contenedor lee ambos archivos con el contenido correcto. |

<details>
<summary>💡 Pista para la tarea 10</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` te da
el valor real: no escribas una cadena arbitraria en el nuevo Secret, el checker vuelve a
decodificar el original por sí mismo y compara. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` codifica los valores
automáticamente: no hace falta hacer base64-encode por tu cuenta al crear con `--from-literal`.
No olvides `readOnly: true` en el volumeMount: un Secret montado pero writable no
pasa el criterio de aceptación literalmente por el flag, aunque el propio Pod funcione correctamente.
</details>

---
| **11** | **Repair existing Role and bind it to an SA from another namespace** |
| :---: | :--- |
| Qué hacemos | • En el namespace `rbac-a` ya existen el ServiceAccount `dev`, el Role `pod-role` y el RoleBinding `pod-role-binding`. El Role ahora permite `get`, `list`, `delete` sobre `pods`: `delete` aquí sobra (quítalo), y `watch` falta, aunque es necesario (añádelo). Corrige precisamente el Role existente, no crees uno nuevo.<br/>• Aparte, en el namespace `rbac-b` ya existe el ConfigMap `shared-config`. Crea en `rbac-b` un nuevo Role y RoleBinding que den al ServiceAccount `dev` **del namespace `rbac-a`** acceso `get`/`list` (y solo ese) sobre `configmaps` en `rbac-b`.<br/>• Crea un Pod en `rbac-a` con `serviceAccountName: dev`. |
| Criterios de aceptación | • El Role `pod-role` en `rbac-a` permite exactamente `get`, `list`, `watch` sobre `pods`.<br/>• `dev` no puede `delete pods` en `rbac-a`.<br/>• `dev` puede `get`/`list configmaps` en `rbac-b`, pero no puede `delete configmaps` y no puede leer `secrets` allí mismo.<br/>• En `rbac-a` existe un Pod que usa el ServiceAccount `dev`. |

<details>
<summary>💡 Pista para la tarea 11</summary>

`RoleBinding` puede referirse a un sujeto (`ServiceAccount`) de CUALQUIER otro namespace:
Kubernetes lo admite oficialmente mediante `subjects[].namespace`. Pero el propio `RoleBinding`,
y los permisos asociados a él, siempre actúan solo en el namespace donde se creó ÉL MISMO; por eso
el nuevo Role+RoleBinding hay que crearlo precisamente EN `rbac-b`, y no en `rbac-a`. Compruébalo:
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` debe
devolver `yes`, y `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **Client certificate user via CSR + namespaced RBAC** |
| :---: | :--- |
| Qué hacemos | • Crea un nuevo usuario de Kubernetes `john`, autenticado mediante un certificado de cliente: genera una private key y después un CSR (`openssl req -new`) con `CN=john`.<br/>• Envíalo como un `CertificateSigningRequest` de Kubernetes `john-csr` con `signerName: kubernetes.io/kube-apiserver-client`; aprueba el CSR (`kubectl certificate approve`).<br/>• Extrae el certificado emitido de `status.certificate` (base64-decode) y guárdalo junto con la private key en `/var/work/tests/artifacts/12/john.crt` y `.../john.key`.<br/>• En el namespace `development` (ya creado) crea un Role que permita `create`/`list`/`get` sobre `pods`, y un RoleBinding sobre el subject `{kind: User, name: john}`.<br/>• Monta para John un kubeconfig aparte (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`) y guárdalo como `/var/work/tests/artifacts/12/john.kubeconfig`; asegúrate de que `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` realmente funciona, y que la misma petición a otro namespace recibe `Forbidden`: esto demuestra un certificado operativo igual que una petición TLS directa, pero mediante el habitual `kubectl`, y no `curl`.<br/>• Confirma con comprobaciones `kubectl auth can-i --as=john` en vivo: John puede `create`/`list`/`get` pods en `development`, no puede `delete` allí mismo y no tiene los mismos permisos en otro namespace. |
| Criterios de aceptación | • `john-csr` usa el signer correcto y está `Approved`.<br/>• El certificado emitido tiene `CN=john` y se verifica realmente contra la CA de este clúster.<br/>• Role+RoleBinding en `development` dan a John exactamente `create`/`list`/`get` sobre `pods`.<br/>• John no puede `delete` pods allí mismo y no tiene acceso a otros namespace.<br/>• Los `john.crt`/`john.key` guardados son realmente aceptados por el API server en una petición TLS directa (y no solo mediante la impersonation `--as=john`).<br/>• El kubeconfig montado existe en la ruta `/var/work/tests/artifacts/12/john.kubeconfig`, y `kubectl --kubeconfig=<este archivo> get pods -n development` realmente funciona, mientras que la misma petición a otro namespace termina con `Forbidden`. |

<details>
<summary>💡 Pista para la tarea 12</summary>

No confundas esta tarea con Lab 114: allí analizas un certificado YA existente del
kubeconfig, y aquí hay que emitir desde cero una identity completamente nueva y realmente operativa.
El RBAC para un usuario basado en certificado se vincula mediante `subjects: [{kind: User, name:
john}]`, y no `ServiceAccount`: `User` en Kubernetes no tiene un objeto de API aparte, su
"existencia" se determina por completo por que el CN del certificado de cliente coincida con
el `name` en el binding. `--as=john` en `kubectl auth can-i` comprueba solo la lógica de RBAC
(impersonation), pero no demuestra que el certificado sea realmente válido: asegúrate aparte
de que `openssl verify` contra `/etc/kubernetes/pki/ca.crt` en el control-plane devuelve `OK`.
</details>

## Comprobación

En la máquina de trabajo ejecuta:

```bash
check_result
```

La comprobación contiene Init y doce tareas independientes. Tras modificar el API server,
algunos tests pueden esperar brevemente al reinicio del static Pod.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD)

## Eliminación

```bash
TASK=104 make delete_cks_task
```
