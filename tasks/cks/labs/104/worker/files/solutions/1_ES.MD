[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 104 - solución de referencia: RBAC, ServiceAccount token y anonymous API

> Ejecuta los comandos desde la máquina de trabajo, salvo que el paso indique otra cosa. El namespace
> `security-104` ya existe.
>
> En el examen, `k` (`alias k=kubectl`) y el bash-completion para él ya están configurados en el host SSH:
> no pierdas tiempo en configurarlos, simplemente usa `k` (consulta el capítulo 33.6).

## 1. Acceso mínimo de `auditor` solo a los Pods

En el examen, escribir a mano el YAML completo de un objeto RBAC típico es una pérdida de tiempo:
`kubectl create` genera ServiceAccount/Role/RoleBinding con un solo comando cada uno:

```bash
k create sa auditor -n security-104
k create role pod-observer -n security-104 --resource=pods --verb=get,list,watch
k create rolebinding auditor-pod-observer -n security-104 \
  --role=pod-observer --serviceaccount=security-104:auditor

k auth can-i list pods -n security-104 \
  --as=system:serviceaccount:security-104:auditor
k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:auditor # debe ser no
```

## 2. Projected token de ServiceAccount

El TokenRequest volume emite un token de corta duración; el automontaje normal está desactivado.
No fijamos `audience: kubernetes.default.svc`: para kubeadm no es necesariamente un valor que el API server acepte.
Si se omite `audience`, el kubelet usa el identifier del
API server por defecto. Se puede indicar una audience aparte solo después de comprobar
`--api-audiences` (o el default de `--service-account-issuer`) en el control-plane.
`expirationSeconds` debe estar en el rango `600`-`3600` inclusive: la Kubernetes API
rechaza como invalid cualquier valor menor de `600` segundos para un `serviceAccountToken`
projected source, con independencia de lo que diga el manifest.

La sintaxis exacta de `projected.sources[].serviceAccountToken` no hace falta recordarla de memoria en el examen:
en `kubernetes.io/docs` está en la sección Concepts → Storage →
[Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), bajo el
encabezado **"serviceAccountToken projected volumes"** (allí hay un ejemplo ya hecho de un Pod con ese
volume: toma la estructura de allí, no la escribas desde cero). `kubectl run` no sabe añadir
un volume así mediante flags: generamos el esqueleto del Pod con `--dry-run=client -o yaml` y
añadimos en `vim` solo los campos necesarios, copiados del ejemplo de la documentación:

```bash
k create sa api-client -n security-104
k run token-client -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > token-client.yaml
vim token-client.yaml
```

```yaml
# Añade al spec del Pod (containers/image/command ya los generó kubectl run):
spec:
  serviceAccountName: api-client              # añadir
  automountServiceAccountToken: false         # añadir
  containers:
  - name: token-client
    volumeMounts:                             # añadir
    - name: api-token                         # añadir
      mountPath: /var/run/secrets/tokens       # añadir
      readOnly: true                          # añadir
    ...
  volumes:                                    # añadir
  - name: api-token                           # añadir
    projected:                                # añadir
      sources:                                # añadir
      - serviceAccountToken:                  # añadir
          path: api-token                     # añadir
          expirationSeconds: 3600             # añadir
```

```bash
k apply -f token-client.yaml
k wait -n security-104 --for=condition=Ready po/token-client --timeout=120s
k exec -n security-104 token-client -- \
  ls -l /var/run/secrets/tokens/api-token
# el archivo existe: si el manifest coincide con el ejemplo de la documentación, el kubelet lo emitió

k auth can-i delete secrets -n security-104 \
  --as=system:serviceaccount:security-104:api-client
# no
```

Comprobamos no solo la presencia del archivo, sino que el projected token montado
realmente se autentica como el ServiceAccount esperado, enviándolo a `TokenReview`:

```bash
TOKEN=$(k exec -n security-104 token-client -- cat /var/run/secrets/tokens/api-token)

k create -o jsonpath='{.status.authenticated}{" "}{.status.user.username}{"\n"}' -f - <<EOF
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: $TOKEN
EOF
# true system:serviceaccount:security-104:api-client
```

Para el laboratorio esta comprobación es obligatoria: la presencia del archivo por sí sola no demuestra
que el projected token sea válido y se autentique como el ServiceAccount esperado. `TokenReview`
debe devolver `authenticated: true` y el username
`system:serviceaccount:security-104:api-client`.

En el examen no hace falta ejecutar `TokenReview` aparte, si el enunciado de la tarea no lo exige:
allí basta con crear rápidamente un projected token volume correcto y comprobar el resultado de la
forma que se necesite en la tarea concreta. Aquí `TokenReview` es una comprobación de verificación didáctica,
que a la vez se corresponde con el criterio de aceptación del laboratorio.

## 3. Pod sin token de la API

Desactivamos el automontaje tanto en el ServiceAccount como en el Pod: esto protege frente a posteriores
cambios de la plantilla o del ServiceAccount.

`kubectl create serviceaccount` no tiene un flag para `automountServiceAccountToken`: creamos
y parcheamos de inmediato:

```bash
k create sa no-token-sa -n security-104
k patch sa no-token-sa -n security-104 -p '{"automountServiceAccountToken":false}'
k run no-token -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > no-token.yaml
vim no-token.yaml
```

```yaml
# Añade al spec del Pod:
spec:
  serviceAccountName: no-token-sa       # añadir
  automountServiceAccountToken: false   # añadir
  containers:
  - name: no-token
    ...
```

```bash
k apply -f no-token.yaml
k wait -n security-104 --for=condition=Ready po/no-token --timeout=60s
k get po no-token -n security-104 -o jsonpath='{.spec.automountServiceAccountToken}'

# Confirmamos a nivel de runtime, y no solo a nivel de la especificación YAML: en el
# contenedor realmente no hay archivo de token.
k exec -n security-104 no-token -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - el archivo no existe, el propio exec se ejecutó con éxito
```

No montes tampoco aparte un legacy `Secret` con `type: kubernetes.io/service-account-token`:
incluso con el automount desactivado, un Secret así se puede montar a mano mediante
`volumes[].secret`, y entonces el Pod formalmente está "sin token" según el campo de automount, pero de hecho
sigue teniendo un token de API válido dentro del contenedor.

## 4. Eliminación de los permisos wildcard

Eliminamos tanto el binding (el sujeto deja de recibir acceso) como el propio ClusterRole (la plantilla
peligrosa no queda disponible para reutilizarse):

```bash
k delete clusterrolebinding legacy-operator-admin
k delete clusterrole legacy-operator-admin
k auth can-i get secrets -n security-104 \
  --as=system:serviceaccount:security-104:legacy-operator # debe ser no
```

## 5. Desactivación de anonymous-auth

Un simple `--anonymous-auth=false` aquí no sirve: kubeadm `release-1.36` genera el
static Pod de kube-apiserver con HTTPS liveness/readiness/startup probes en `/livez` y
`/readyz`, y los HTTP probes del kubelet no transmiten client credentials: con el
anonymous access completamente desactivado, esas peticiones recibirán `401`, y el kubelet empezará a considerar kube-apiserver
no sano (lo que a su vez rompe también la tarea 9, que depende de un API
server que funcione de forma estable). En su lugar usamos `AuthenticationConfiguration` con `anonymous.conditions`,
que limitan el anonymous access solo a tres rutas de health. En el examen no prefijes
cada comando con `sudo`: conviértete en root una sola vez (`sudo -i`), es más rápido:

```bash
ssh control-plane
sudo -i
cat > /etc/kubernetes/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

Editamos el static manifest: quitamos `--anonymous-auth=true` por completo (no se puede dejar
junto a `--authentication-config`: kube-apiserver se negará a arrancar si se indican ambos),
añadimos `--authentication-config` y también un `hostPath` volume/volumeMount para el nuevo
archivo de configuración: kube-apiserver lee `authentication-config.yaml` del sistema de
archivos del nodo, por lo que el archivo debe ser visible dentro del contenedor mediante un volumeMount, y no
solo estar en el host:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# En el array command:
# - elimina la línea "- --anonymous-auth=true"
# - añade una línea con la misma indentación que el resto de los argumentos:
#   - --authentication-config=/etc/kubernetes/authentication-config.yaml
# En los volumeMounts del contenedor (la misma indentación que los elementos vecinos):
#   - mountPath: /etc/kubernetes/authentication-config.yaml
#     name: authentication-config
#     readOnly: true
# En los volumes del Pod (la misma indentación que los elementos vecinos):
#   - hostPath:
#       path: /etc/kubernetes/authentication-config.yaml
#       type: File
#     name: authentication-config
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` fuerza la reconstrucción inmediata del static Pod: en el examen es más
rápido que esperar a que el kubelet detecte por sí mismo el cambio del archivo (normalmente segundos, pero no
está garantizado que sea instantáneo):

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS debe pasar a Running; si todavía no, espera un par de segundos y repite
```

Comprueba los tres comportamientos: `/version` rechaza las peticiones anónimas, y `/livez`/`/readyz`
las aceptan:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/version" # 401 - anonymous access cerrado
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/livez"   # 200 - el health probe funciona
curl -k -o /dev/null -s -w '%{http_code}\n' "$SERVER/readyz"  # 200 - el health probe funciona
```

Una petición autenticada a `/readyz` (mediante el kubectl context ya configurado)
sigue funcionando exactamente igual: `AuthenticationConfiguration.anonymous.conditions`
solo AMPLÍA el acceso de las peticiones anónimas a rutas concretas, pero no restringe el acceso
de los clientes ya autenticados:

```bash
k get --raw=/readyz # ok
```

Una autenticación sin una autorización restrictiva carece de sentido: comprueba que
`--authorization-mode` en el static Pod sigue siendo `Node,RBAC` y no contiene `AlwaysAllow`
(kubeadm lo establece por defecto, pero conviene asegurarse de que nada haya cambiado el flag):

```bash
k get po -n kube-system -l component=kube-apiserver \
  -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep authorization-mode
# --authorization-mode=Node,RBAC
```

Aparte, auditamos los ClusterRoleBinding cuyos subjects apuntan al usuario anónimo
o al grupo anónimo: en el clúster se ha dejado deliberadamente un binding lab-owned así:

```bash
k get clusterrolebinding -o json | jq -r \
  '.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name == "system:unauthenticated")] | length > 0) | .metadata.name'
# system:public-info-viewer
# lab104-unintended-anonymous-access
```

`system:public-info-viewer` es un binding estándar de kubeadm: también apunta a
`system:unauthenticated`, pero su ClusterRole permite un `GET` read-only solo a los
non-resource URL `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, y no a los
recursos normales de Kubernetes: es el default Kubernetes RBAC, una parte necesaria del bootstrap, no lo toques.
Esto no es lo mismo que `anonymous.conditions` de esta misma tarea: esa lista
limita en qué rutas la petición llega a recibir una anonymous identity en la etapa de
authentication (allí solo `/livez`/`/readyz`/`/healthz`): `/version` devuelve `401` a las peticiones anónimas
precisamente porque allí no se asigna una anonymous identity, y no porque a
`system:public-info-viewer` le falten permisos allí. `lab104-unintended-anonymous-access` es un
hallazgo lab-owned deliberado: su ClusterRole `lab104-anonymous-debug-access` da un
RBAC `get`/`list` completo sobre `pods`/`secrets`/`configmaps` en todo el clúster, es decir, CUALQUIER
petición anónima puede leerlos. Eliminamos ambos objetos, igual que en las tareas 4/7:

```bash
k delete clusterrolebinding lab104-unintended-anonymous-access
k delete clusterrole lab104-anonymous-debug-access
```

Confirmamos la revocación con un control negativo en nombre precisamente de la identity no autenticada
(`system:anonymous` + el grupo `system:unauthenticated`, y nada más) mediante
`SubjectAccessReview`: lo crea el contexto admin, por lo que no hace falta ampliar
artificialmente la lista de grupos:

```bash
for R in pods secrets configmaps; do
  for NS in $(k get ns -o jsonpath='{.items[*].metadata.name}'); do
    ALLOWED=$(k create -o jsonpath='{.status.allowed}' -f - <<EOF
apiVersion: authorization.k8s.io/v1
kind: SubjectAccessReview
spec:
  user: system:anonymous
  groups: ["system:unauthenticated"]
  resourceAttributes:
    namespace: $NS
    resource: $R
    verb: get
EOF
    )
    printf '%-12s %-24s %s\n' "$R" "$NS" "$ALLOWED"
  done
done
# para cada línea se espera false
```

No añadas `--as-group=system:authenticated` a `can-i --as=system:anonymous`: una petición real
no autenticada no pertenece a ese grupo, y la comprobación dejaría de reflejar la
verdadera anonymous identity. Comprobamos cada namespace por separado, porque
un RoleBinding actúa solo en su namespace: la ausencia de un binding cluster-wide no
demuestra la ausencia de uno local, y el criterio de aceptación prohíbe el acceso en cualquier namespace.

Al final ejecuta `check_result`.

## 6. Fuga de Secret mediante env en `/proc/1/environ`: paso a volume

`app-vulnerable` recibe `db-creds` mediante `envFrom`, por lo que el valor acaba en el
environment del proceso PID 1 del contenedor. Cualquiera que tenga derecho a `kubectl exec` en este
Pod puede leer el secret directamente de `/proc`, sin acceder a la Kubernetes API y sin RBAC
sobre `get secrets`:

```bash
mkdir -p /var/work/tests/artifacts/6
k exec -n security-104 app-vulnerable -- cat /proc/1/environ \
  | tr '\0' '\n' | grep DB_PASSWORD | tee /var/work/tests/artifacts/6/env-leak-before.txt
```

Guardamos precisamente la línea `DB_PASSWORD=<valor real>` del entorno del proceso, y no
simplemente la palabra `DB_PASSWORD` sin valor: el checker la contrastará por sí mismo con el valor real
del Secret `db-creds`, no hace falta calcular y comparar el valor por tu cuenta.

Recreamos el Pod con el mismo nombre: quitamos `envFrom`, montamos el mismo Secret como volume
`db-creds-vol` en `/etc/secrets`, read-only, con `defaultMode: 0400` (`256` en decimal, como lo
muestra `kubectl get pod -o json`). `0400` es read-only solo para el propietario del archivo
dentro del contenedor; el propio proceso de la aplicación igualmente debe ejecutarse con ese UID; de lo contrario
no podrá leer el archivo.

La mayoría de los campos del Pod (incluido `volumes`) son inmutables, por lo que el Pod hay que eliminarlo y crearlo de nuevo con el mismo nombre. De nuevo es más barato
generar el esqueleto mediante `--dry-run` y añadir el volume en `vim` que escribir todo el YAML:

```bash
k run app-vulnerable -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > app-vulnerable-fixed.yaml
vim app-vulnerable-fixed.yaml
```

```yaml
# Añade al spec del Pod:
spec:
  automountServiceAccountToken: false     # añadir
  containers:
  - name: app-vulnerable
    volumeMounts:                         # añadir
    - name: db-creds-vol                  # añadir
      mountPath: /etc/secrets             # añadir
      readOnly: true                      # añadir
    ...
  volumes:                                # añadir
  - name: db-creds-vol                    # añadir
    secret:                               # añadir
      secretName: db-creds                # añadir
      defaultMode: 0400                   # añadir
```

```bash
k delete pod app-vulnerable -n security-104
k apply -f app-vulnerable-fixed.yaml
k wait -n security-104 --for=condition=Ready po/app-vulnerable --timeout=120s
```

Confirmamos tres propiedades finales, y no solo «el secret no está en el environment»: los permisos
del archivo son exactamente `400` (y no simplemente contienen en algún lugar la subcadena `400`) y, lo que es más importante, la aplicación
todavía puede REALMENTE leer el valor del secret; de lo contrario el hardening podría romper sin que nos demos cuenta
la propia funcionalidad de la aplicación:

```bash
k exec -n security-104 app-vulnerable -- cat /proc/1/environ | tr '\0' '\n' | grep DB_PASSWORD
# no se encuentra nada: es lo esperado

k exec -n security-104 app-vulnerable -- stat -L -c '%a' /etc/secrets/DB_PASSWORD \
  | tee /var/work/tests/artifacts/6/secret-file-mode.txt
# 400 - precisamente este valor, y no un texto arbitrario que contenga en algún lugar "400". El flag -L
# es obligatorio: el secret volume se monta mediante una cadena de symlinks ("..data"), y sin -L
# stat mostrará el modo del propio symlink (siempre 777 en Linux), y no del archivo real.

# Positive control: el proceso de la aplicación debe poder realmente leer el valor del secret.
k exec -n security-104 app-vulnerable -- cat /etc/secrets/DB_PASSWORD
# debe coincidir con el valor que había en env-leak-before.txt antes de la corrección
```

`defaultMode: 0400` protege frente a la lectura por otros UID en este mismo Pod (por ejemplo, un
sidecar-container vecino sin el UID necesario), pero no sustituye al encryption at rest de etcd y no impide
que un proceso ejecutado con el UID esperado lea el propio archivo: el mount permite precisamente eso.
Asegúrate también de que `db-creds` no esté montado a la vez por una SEGUNDA vía
(por ejemplo, además mediante un `projected` volume): debe quedar exactamente un volume
que monte este Secret.

Al final ejecuta `check_result`.

## 7. Auditoría y revocación de los caminos ocultos de RBAC privilege escalation

`build-agent-hidden-privesc` no contiene el wildcard `*`, pero `impersonate`/`bind`/`escalate`/
CSR-approval son una categoría aparte de verbs peligrosos: no amplían la lista de recursos
visibles, sino que dan la posibilidad de **actuar en nombre de otro** o de **concederse
permisos adicionales**. En esta versión del fixture el ClusterRole también contiene los
básicos `create`/`update` sobre `clusterroles`/`clusterrolebindings`: sin ellos `bind`/`escalate`
serían escalation primitives incompletas (RBAC exige O BIEN ya tener los permisos del rol, O BIEN
tener explícitamente `escalate`/`bind` EN EL CONTEXTO de un intento real de crear/actualizar un Role/Binding).
Encontramos todos los ClusterRoleBinding cuyos ClusterRole permitan cualquiera de los verbs peligrosos. No partimos
desde los ClusterRole (hay decenas en el clúster, incluidos los `system:*` estándar), sino desde los
ClusterRoleBinding: `kubectl get clusterrolebinding` ya por defecto muestra la columna
`ROLE` (formato `ClusterRole/<nombre>`), y `-o wide` añade además `USERS`/`GROUPS`/
`SERVICEACCOUNTS`: no hacen falta ni custom-columns ni YAML:

```bash
mkdir -p /var/work/tests/artifacts/7
k get clusterrolebinding -o wide | grep -v system:
# build-agent-hidden-privesc   ClusterRole/build-agent-hidden-privesc   ...   security-104/build-agent
```

Para cada candidato miramos su ClusterRole de forma legible para humanos, sin `jq`/`grep` sobre el YAML:
`kubectl describe` imprime por sí mismo los verbs en una tabla, donde se ven de inmediato `impersonate`/`bind`/
`escalate` y la regla aparte sobre `certificatesigningrequests/approval`:

```bash
k describe clusterrole build-agent-hidden-privesc
# Los Verbs en la tabla PolicyRule mostrarán impersonate / bind / escalate / update
# (sobre certificatesigningrequests/approval): a simple vista se ve que el rol es peligroso
```

Guardamos el nombre del ClusterRoleBinding (no del ClusterRole: pueden no coincidir, en este laboratorio
coincidieron por casualidad) en el artifact:

```bash
echo build-agent-hidden-privesc > /var/work/tests/artifacts/7/dangerous-bindings-before.txt
cat /var/work/tests/artifacts/7/dangerous-bindings-before.txt
```

`build-agent-hidden-privesc` debe estar en el archivo final (como nombre del ClusterRoleBinding,
no del ClusterRole). Eliminamos precisamente este ClusterRoleBinding (y el ClusterRole, para que la plantilla no
quede disponible para reutilizarse), sin tocar los bindings `system:*`, que dan a los
componentes core de Kubernetes el acceso necesario de `impersonate`/CSR:

```bash
k delete clusterrolebinding build-agent-hidden-privesc
k delete clusterrole build-agent-hidden-privesc
```

Confirmamos la revocación de TODOS los permisos peligrosos declarados, y no solo de parte de ellos. Dos matices:
el fixture da `impersonate` a la vez sobre tres tipos de recurso (`users`/`groups`/`serviceaccounts`):
comprobar solo `users` no demuestra la revocación de los otros dos; y `TYPE/NAME` en `kubectl auth
can-i` es un resourceName, y no un subresource (`kubectl auth can-i --help` muestra directamente
el ejemplo "jobs.batch/bar": la comprobación de un objeto literalmente llamado `bar`), por lo que para
`certificatesigningrequests/approval` hace falta un flag aparte `--subresource=approval`, y no
una barra:

```bash
k auth can-i impersonate users --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate groups --as=system:serviceaccount:security-104:build-agent
k auth can-i impersonate serviceaccounts -n security-104 --as=system:serviceaccount:security-104:build-agent
k auth can-i bind clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i escalate clusterroles --as=system:serviceaccount:security-104:build-agent
k auth can-i update certificatesigningrequests --subresource=approval --as=system:serviceaccount:security-104:build-agent
k auth can-i approve signers/kubernetes.io/kube-apiserver-client --as=system:serviceaccount:security-104:build-agent
# no / no / no / no / no / no / no
```

Al final ejecuta `check_result`.

## 8. Baseline a nivel de namespace: SA `default` sin automount

La tarea 3 desactivaba el automount de forma puntual, en un Pod concreto y en su propio SA. Aquí
hace falta un baseline sistémico: editamos el SA `default` del namespace **antes** de crear en él cualquier
Pod, para que ningún workload nuevo reciba el token por defecto, aunque el desarrollador
olvide el campo explícito en el manifest.

El ServiceAccount `default` lo crea un controller aparte de forma asíncrona tras la aparición del
Namespace: `kubectl wait` sabe esperar precisamente a la aparición del objeto (`--for=create`), y no
solo a su condition, por lo que no hacen falta ni un retry manual ni un bucle casero:

```bash
k create namespace security-104-baseline
k wait -n security-104-baseline --for=create sa/default --timeout=30s

k -n security-104-baseline patch sa default \
  -p '{"automountServiceAccountToken":false}'
k -n security-104-baseline get sa default \
  -o jsonpath='{.automountServiceAccountToken}{"\n"}'
# false
```

Creamos un Pod que **no** indica ni `serviceAccountName` ni `automountServiceAccountToken`:
es el caso más frecuente en la realidad, cuando el desarrollador simplemente no piensa en el SA. El campo
`automountServiceAccountToken` debe ESTAR AUSENTE en el spec del Pod: indicar explícitamente `false`
demostraría solo una configuración puntual del propio Pod (como en la tarea 3), y no que
el namespace-level baseline realmente funcione.

Aquí no hace falta ni siquiera `--dry-run`: como en el Pod no se añade ningún campo sobre SA/automount,
`kubectl run` sin flags crea exactamente lo que hace falta, directamente:

```bash
k run implicit-default-sa -n security-104-baseline --image=busybox:1.36 --command -- sh -c "sleep 3600"
k wait -n security-104-baseline --for=condition=Ready po/implicit-default-sa --timeout=60s
k get po implicit-default-sa -n security-104-baseline -o jsonpath='{.spec.serviceAccountName}{"\n"}'
# default

k get po implicit-default-sa -n security-104-baseline \
  -o jsonpath='{.spec.automountServiceAccountToken}{"\n"}'
# salida vacía: el campo está ausente en el spec, y no establecido en false

k exec -n security-104-baseline implicit-default-sa -- \
  test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
echo "exit code: $?"
# exit code: 0 - el archivo no existe, y el propio exec se ejecutó con éxito (a diferencia de un simple
# "cat" sobre un archivo inexistente, cuyo exit code también es distinto de cero, pero por otra
# razón; test ! -e hace precisamente la comprobación necesaria, y su propio éxito
# hay que exigirlo aparte, y no simplemente "cualquier error = el archivo no existe")
```

El valor del SA actúa solo si el Pod no lo redefine por sí mismo. Si en el mismo namespace
hace falta un Pod con acceso a la API, añade `automountServiceAccountToken: true` explícitamente en el
manifest concreto, tras comprobar que el acceso realmente hace falta; no cambies el baseline
del SA `default` de vuelta a `true` para todo el namespace. Tampoco montes a mano un
`Secret` antiguo (legacy) con `type: kubernetes.io/service-account-token` mediante `volumes[].secret`:
eso daría al Pod un token de API válido con independencia de los ajustes de automount.

Al final ejecuta `check_result`.

## 9. Tarea de integración: detección de un cambio peligroso de RBAC → audit log → containment

Las tareas 1-8 cerraban caminos concretos de elevación de privilegios, disponibles para el propio `build-agent`
(wildcard, impersonate/bind/escalate, automount). Aquí hace falta otra capa de protección:
la detección de un **RBAC grant peligroso concedido por un administrador** (por error, por
una automatización comprometida o malintencionadamente), y no solo una instantánea actual de RBAC.
Nos conectamos al control-plane y preparamos un audit backend mínimo:

```bash
ssh control-plane
sudo -i
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["clusterroles", "clusterrolebindings"]
- level: Metadata
EOF
```

La regla de RBAC va la primera: la regla más específica debe preceder al catch-all
general, de lo contrario `Metadata` interceptará el evento antes. `omitStages: [RequestReceived]`
a nivel de toda la policy quita el registro superfluo anterior al procesamiento de la petición: no tiene
`requestObject`/`responseStatus`, y el checker descarta de todos modos esas entradas (`stage ==
"ResponseComplete"`), y con la regla catch-all `Metadata` sobre TODAS las demás peticiones del clúster
esta etapa duplicaría el volumen de audit.log sin beneficio.

Editamos el static manifest: añadimos `--audit-policy-file`/`--audit-log-path` y hostPath
volume/volumeMount para los directorios de la policy y de los logs, con la misma técnica que en la tarea 5 para
`authentication-config.yaml`:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/9-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# En el array command añade líneas con la misma indentación que el resto de los argumentos:
#   - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
# En los volumeMounts del contenedor (la misma indentación que los elementos vecinos):
#   - mountPath: /etc/kubernetes/audit
#     name: audit-policy
#     readOnly: true
#   - mountPath: /var/log/kubernetes/audit
#     name: audit-log
# En los volumes del Pod (la misma indentación que los elementos vecinos):
#   - hostPath:
#       path: /etc/kubernetes/audit
#       type: Directory
#     name: audit-policy
#   - hostPath:
#       path: /var/log/kubernetes/audit
#       type: DirectoryOrCreate
#     name: audit-log
systemctl restart kubelet
exit
exit
```

`systemctl restart kubelet` fuerza la reconstrucción inmediata del static Pod: como en la
tarea 5, es más rápido que esperar a que el kubelet note por sí mismo el cambio del archivo:

```bash
k get po -n kube-system -l component=kube-apiserver
# STATUS debe pasar a Running; si todavía no, espera un par de segundos y repite
```

Volvemos a la máquina de trabajo (en nombre del administrador `cluster1-admin`) y creamos
el binding peligroso: esto **no** es un intento de escalada por parte de `build-agent` (ya no tiene
caminos reales hacia ello tras la tarea 7), sino una acción de administrador simulada,
que el audit log debe capturar como evidence reproducible de quién exactamente la
realizó y a quién exactamente se concedieron los permisos:

```bash
k create clusterrolebinding incident-simulated-escalation \
  --clusterrole=cluster-admin \
  --serviceaccount=security-104:build-agent
```

Primero simplemente nos aseguramos a simple vista de que la regla de audit realmente funciona y de que el evento llegó al
log: en el examen normalmente hace falta precisamente esta comprobación, y no un artifact ya hecho:

```bash
ssh control-plane
sudo cat /var/log/kubernetes/audit/audit.log | jq . | grep -A 30 incident-simulated-escalation
exit
```

`jq .` imprime cada registro del log de forma legible (un campo por línea), `grep -A 30`
muestra la línea encontrada con el nombre y 30 líneas DESPUÉS de ella: es suficiente para ver
`stage`, `user.username` (el iniciador real), `requestObject.roleRef`,
`requestObject.subjects` a simple vista, sin una sintaxis especial de jq.

Esto es suficiente para un examen real, pero este laboratorio además exige un archivo artifact con el
evento: no porque al checker no le baste con saber que la regla funciona (él mismo, de forma independiente,
lee `audit.log` en el control-plane mediante SSH), sino para comprobar una habilidad aparte:
extraer y guardar precisamente un registro REAL como forensic evidence, y no relatarlo
con tus propias palabras (el checker contrasta el `auditID` de tu archivo con el `auditID` del registro real en el log).
`/var/work/tests/artifacts/9/` es una ruta en la máquina de TRABAJO, y no en el control-plane, por lo que
guardamos desde la máquina de trabajo mediante `ssh control-plane "..."`, con la misma combinación de grep por subcadenas normales
(nombre del evento + `ResponseComplete`, para no dar con el registro intermedio
`ResponseStarted` de la misma request):

```bash
mkdir -p /var/work/tests/artifacts/9
ssh control-plane "sudo cat /var/log/kubernetes/audit/audit.log" \
  | grep incident-simulated-escalation | grep ResponseComplete \
  | tail -n1 > /var/work/tests/artifacts/9/audit-escalation-event.json
```

Guardamos el evento **completo**, tal como realmente está en el audit log (incluido el `auditID`): no
lo reescribimos ni construimos el JSON a mano, de lo contrario el artifact no coincidirá con el registro real
en el log durante la verificación.

Containment: eliminamos el binding y confirmamos que el acceso está realmente revocado, y no que simplemente el
objeto haya dejado de ser legible. `can-i` sin `-n`/`-A` comprueba solo el namespace actual del
contexto de kubeconfig, y no todo el clúster: para un RoleBinding namespaced en `security-104`
(a diferencia del ClusterRoleBinding cluster-wide ya eliminado) esto cambia el resultado,
por lo que indicamos el namespace explícitamente:

```bash
k delete clusterrolebinding incident-simulated-escalation
k auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent \
  | tee /var/work/tests/artifacts/9/containment-result.txt
# no
```

La diferencia con la tarea 7: allí encontrábamos y revocábamos un camino oculto **ya existente** mediante
análisis estático de los objetos RBAC, perteneciente al propio workload (`build-agent`). Aquí la
source of truth es un **evento en el tiempo** (el audit log), que demuestra quién exactamente
(el campo `user.username` es el iniciador real de la petición, en este caso el administrador, y no
`build-agent`) concedió los permisos peligrosos y a quién exactamente: es lo que hace falta para un
incidente real, cuando el propio objeto podría haber sido eliminado ya tras su uso, y `build-agent` en el
evento figura solo como receptor de los permisos, y no como autor de la petición.

Al final ejecuta `check_result`.

## 10. Decodificar, crear y montar un Secret

`legacy-config` ya existe. Leemos ambos valores a través de la API, y no adivinamos:

```bash
mkdir -p /var/work/tests/artifacts/10
SERVICE_USER=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_USER}' | base64 -d)
SERVICE_TOKEN=$(k get secret legacy-config -n security-104 -o jsonpath='{.data.SERVICE_TOKEN}' | base64 -d)
printf 'SERVICE_USER=%s\nSERVICE_TOKEN=%s\n' "$SERVICE_USER" "$SERVICE_TOKEN" \
  | tee /var/work/tests/artifacts/10/decoded-values.txt
```

Creamos un nuevo generic Secret con los mismos nombres de clave y los mismos valores:
`--from-literal` codifica por sí mismo el valor en base64, no hace falta hacerlo a mano:

```bash
k create secret generic rehydrated-config -n security-104 \
  --from-literal=SERVICE_USER="$SERVICE_USER" \
  --from-literal=SERVICE_TOKEN="$SERVICE_TOKEN"
```

Lo montamos como read-only volume en un Pod: de nuevo dry-run + edición puntual en `vim`:

```bash
k run secret-workflow -n security-104 --image=busybox:1.36 --command --dry-run=client -o yaml \
  -- sh -c "sleep 3600" > secret-workflow.yaml
vim secret-workflow.yaml
```

```yaml
# Añade al spec del Pod:
spec:
  automountServiceAccountToken: false      # añadir
  containers:
  - name: secret-workflow
    volumeMounts:                          # añadir
    - name: rehydrated-config-vol          # añadir
      mountPath: /etc/rehydrated           # añadir
      readOnly: true                       # añadir
    ...
  volumes:                                 # añadir
  - name: rehydrated-config-vol            # añadir
    secret:                                # añadir
      secretName: rehydrated-config        # añadir
```

```bash
k apply -f secret-workflow.yaml
k wait -n security-104 --for=condition=Ready po/secret-workflow --timeout=60s
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_USER
k exec -n security-104 secret-workflow -- cat /etc/rehydrated/SERVICE_TOKEN
# deben coincidir con $SERVICE_USER / $SERVICE_TOKEN de arriba
```

Al final ejecuta `check_result`.

## 11. Reparar el Role existente y vincularlo a un SA de otro namespace

El Role existente `pod-role` en `rbac-a` permite `get`, `list`, `delete`: quitamos el
`delete` sobrante y añadimos el `watch` necesario:

```bash
k patch role pod-role -n rbac-a --type=json -p \
  '[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
k auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev # no
k auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev  # yes
```

`shared-config` ya existe en `rbac-b`. Creamos un Role+RoleBinding NUEVO precisamente en
`rbac-b`: RoleBinding admite un subject de otro namespace, pero los propios permisos
actúan solo en el namespace del propio RoleBinding:

```bash
k create role configmap-reader -n rbac-b --resource=configmaps --verb=get,list
k create rolebinding configmap-reader-binding -n rbac-b \
  --role=configmap-reader --serviceaccount=rbac-a:dev

k auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev    # yes
k auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev # no
k auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev       # no
```

Creamos un Pod en `rbac-a` que realmente use `dev`:

```bash
k run rbac-a-workload -n rbac-a --image=busybox:1.36 \
  --overrides='{"spec":{"serviceAccountName":"dev"}}' -- sh -c "sleep 3600"
```

Al final ejecuta `check_result`.

## 12. Usuario con certificado de cliente mediante CSR + namespaced RBAC

Generamos una private key y un CSR con `CN=john`: el RBAC para un usuario basado en certificado
se vincula mediante `kind: User`, y no `ServiceAccount`, y `User` no tiene un objeto de API
propio: su identity depende por completo de que el CN del certificado de cliente
coincida con el `name` en el binding.

```bash
mkdir -p /var/work/tests/artifacts/12
openssl genrsa -out /var/work/tests/artifacts/12/john.key 2048
openssl req -new -key /var/work/tests/artifacts/12/john.key \
  -out /tmp/john.csr -subj "/CN=john"
```

Lo enviamos como un `CertificateSigningRequest` de Kubernetes con el mismo signer que ya se
usa en la tarea 7 para la aprobación de un CSR (`kubernetes.io/kube-apiserver-client`:
el signer correcto precisamente para un certificado client-auth que autenticará
las peticiones al API server):

```bash
cat > john-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: $(base64 -w0 /tmp/john.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF
k apply -f john-csr.yaml
k certificate approve john-csr
k get csr john-csr -o jsonpath='{.status.certificate}' \
  | base64 -d > /var/work/tests/artifacts/12/john.crt
```

Comprobamos que el certificado realmente está firmado por este clúster, y no solo que el campo
`status.certificate` no esté vacío:

```bash
openssl verify -CAfile <(ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt) \
  /var/work/tests/artifacts/12/john.crt
# /var/work/tests/artifacts/12/john.crt: OK
openssl x509 -in /var/work/tests/artifacts/12/john.crt -noout -subject
# subject=CN = john
```

RBAC: un Role en `development`, un RoleBinding sobre `kind: User, name: john`: `--user=john` en
`kubectl create rolebinding` establece por sí mismo `kind: User`, no hace falta escribir YAML:

```bash
k create role john-pod-access -n development --resource=pods --verb=create,list,get
k create rolebinding john-pod-access-binding -n development \
  --role=john-pod-access --user=john

k auth can-i create pods -n development --as=john  # yes
k auth can-i list pods -n development --as=john    # yes
k auth can-i get pods -n development --as=john     # yes
k auth can-i delete pods -n development --as=john  # no
k auth can-i create pods -n security-104 --as=john # no
```

`--as=john` demuestra solo la lógica de RBAC (impersonation, disponible para cualquier admin
con independencia de que se haya emitido un certificado real). Demostramos aparte que precisamente el
certificado EMITIDO es realmente aceptado por el API server mediante una petición TLS client-auth
auténtica:

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ssh control-plane sudo cat /etc/kubernetes/pki/ca.crt > /tmp/cluster-ca.crt
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/development/pods"     # 200
curl -s -o /dev/null -w '%{http_code}\n' --cacert /tmp/cluster-ca.crt \
  --cert /var/work/tests/artifacts/12/john.crt --key /var/work/tests/artifacts/12/john.key \
  "$SERVER/api/v1/namespaces/security-104/pods"     # 403
```

La misma demostración, pero mediante el habitual `kubectl`, y no `curl`: construimos para John un
kubeconfig aparte a partir del certificado ya emitido (`set-credentials` con `--client-certificate`/
`--client-key`, y no `--token`, porque la identity aquí es precisamente un client-cert, y no un
ServiceAccount token):

```bash
k config set-cluster cluster1 --server="$SERVER" \
  --certificate-authority=/tmp/cluster-ca.crt --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-credentials john \
  --client-certificate=/var/work/tests/artifacts/12/john.crt \
  --client-key=/var/work/tests/artifacts/12/john.key --embed-certs=true \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config set-context john@cluster1 --cluster=cluster1 --user=john \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig
k config use-context john@cluster1 \
  --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development
# funciona: RBAC lo permite

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n security-104
# Error from server (Forbidden) - el mismo 403 que en la comprobación con curl de arriba

k --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig auth whoami
# Username: john - confirma que el kubeconfig realmente se autentica precisamente como
# john, y no simplemente da por casualidad los códigos de respuesta necesarios
```

Al final ejecuta `check_result`.
