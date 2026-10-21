[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - solución de referencia: AppArmor y seccomp

> Los comandos de Kubernetes (`kubectl`) ejecútalos en la máquina de trabajo (`worker`). Todo lo relativo al
> propio nodo (AppArmor, kubelet, `crictl`) hazlo **directamente en el nodo**: entra por `ssh` una
> sola vez y conviértete en root (`sudo -i`); es más rápido que enviar cada comando con un
> `ssh control-plane '...'` aparte, y así es como hay que trabajar en el examen. El namespace
> `security-106` se crea en la tarea 3.
>
> ```bash
> ssh control-plane
> sudo -i
> # ... comandos en el nodo ...
> exit   # de root
> exit   # del nodo de vuelta al worker
> ```
>
> La comprobación lee los artefactos de la **máquina de trabajo** (`/var/work/tests/artifacts/<número>/`); son
> necesarios solo para el laboratorio: en el examen no existen. Los guardamos con un comando corto desde el `worker`
> (`> archivo`), el contenido lo vemos aparte con `cat <archivo>`.

## 1. Traslado y carga del AppArmor profile

El perfil está solo en la máquina de trabajo. Lo copiamos al nodo (desde el `worker`), luego en el nodo
lo colocamos en su sitio y lo cargamos en el kernel. El archivo ya contiene el flag `complain`, por lo que
basta con un solo `apparmor_parser -r` para la carga inicial (sin `aa-complain`, que, igual que
`aa-enforce`, analiza todos los archivos de `/etc/apparmor.d/` y fallaría con el aún roto
`k8s-106-broken-profile` de la tarea 9):

```bash
# en el worker
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# en el nodo
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# se espera: "k8s-106-deny-write":	"complain",
```

## 2. Paso del AppArmor profile a enforce

El profile ahora está en modo `complain` (cargado con ese flag en la tarea 1). Seguimos en el nodo
(como root) y pasamos precisamente el profile existente a enforcing mode:

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# se espera: "k8s-106-deny-write":	"enforce",
# El 'aa-status | grep ...' normal no mostrará el modo del perfil: en la salida de texto los perfiles
# están agrupados bajo encabezados ('N profiles are in enforce mode.'), los nombres van sin sufijo.
# Para comprobar un perfil concreto usa 'aa-status --pretty-json' (o '--json').
exit
exit
```

No uses `aa-enforce`/`aa-complain` ni otras herramientas de modificación de perfiles del
paquete `apparmor-utils`, escritas en Python, para ESTE perfil mientras no esté hecha la
tarea 9: internamente llaman a `apparmor.read_profiles()`, que al arrancar analiza
(parsea) **todos** los archivos de `/etc/apparmor.d/`, incluido el aún no cargado y deliberadamente
roto `/etc/apparmor.d/k8s-106-broken-profile` de la tarea 9, y fallan con un error del
parser en un archivo AJENO, sin llegar siquiera a intentar alcanzar tu perfil. `apparmor_parser`
(un binario, y no un wrapper de Python), invocado directamente con UN archivo concreto, analiza
solo ese y no está sujeto a este problema; por eso editamos el flag del perfil
(quitamos `complain` de `flags=(...)`) a mano con `sed` y después recargamos precisamente
ese archivo con `apparmor_parser -r`.

`aa-status` es una herramienta aparte para ver el estado, y no para modificar perfiles, y aquí no
viene al caso. El modo de un perfil concreto lo muestra `aa-status --pretty-json` (comprobado en
el nodo del laboratorio, apparmor 3.0.4; `--json` da lo mismo en una sola línea, por ejemplo
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`). La alternativa es el archivo del kernel
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles`: allí el formato es
`name (enforce|complain)`.

## 3. Pod con Localhost AppArmor y denegación de escritura

Creamos el namespace y el Pod. `emptyDir` garantiza la presencia de `/work`; el profile permite
la ejecución del proceso, pero prohíbe la escritura en este directorio. El node selector vincula el Pod al
nodo en el que el profile realmente está cargado.

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# en el worker
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# espera a STATUS Running (repite get), luego ejecuta exec

# Evidence: el perfil realmente está asignado al proceso PID 1, y no solo escrito en el Pod YAML.
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# Control positivo ANTES de la denegación: una operación read permitida precisamente sobre el mismo /work,
# donde se comprobará el denial; sin este paso la denegación de escritura no se podría distinguir
# de un mount/mountPath que no funciona en absoluto (en ese caso ni siquiera la lectura estaría disponible).
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Control negativo: el denial debe ser precisamente una denegación de escritura de AppArmor.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# se espera un código distinto de cero: Permission denied / Operation not permitted
```

Un exit code distinto de cero y el texto 'permission denied' por sí solos NO demuestran que precisamente
esta regla de AppArmor haya actuado: un error DAC/filesystem normal se vería idéntico desde
el punto de vista de la shell. Vincula la denegación precisamente a este profile mediante el kernel audit log; lo miramos
en el nodo justo después del intento de arriba:

```bash
# en el nodo
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# se espera una entrada del tipo: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod: creación del archivo; al escribir en un archivo existente será "w")
exit
exit
```

Si `/proc/1/attr/current` no está disponible en el runtime concreto, regístralo y apóyate
en la asignación del Localhost profile junto con el kernel `apparmor="DENIED"` para ese profile;
un solo código distinto de cero sin esta evidence es insuficiente, ya que puede darlo un mount o un
Unix permission normal.

## 4. RuntimeDefault para un Pod normal

`RuntimeDefault` es un baseline portable, que elige el perfil estándar de
containerd/runtime. El campo se indica explícitamente a nivel de Pod.

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# en el worker
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp y demostración del bloqueo de `unshare`

El archivo está solo en la máquina de trabajo, en `/opt/lab106-fixtures/cks-106-deny-unshare.json`.
Lo copiamos al nodo (desde el `worker`) y lo colocamos en el kubelet seccomp root (en el nodo):

```bash
# en el worker
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# en el nodo
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

En la API indicamos la ruta relativa al seccomp root: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` aquí es una excepción peligrosa deliberada solo para el laboratorio (la comprobación del control sin seccomp la hace el checker). Sin el custom
filter, `unshare -n` con esta capability puede funcionar; seccomp debe devolver `EPERM`.
Esto no es una hardened combination. `allowPrivilegeEscalation: false` activa `no_new_privs`, pero
no quita las capabilities ya concedidas al proceso, por eso no usamos este campo como
«compensación» de `SYS_ADMIN`. En producción esa capability se elimina si no hay una
necesidad demostrada. En Kubernetes la capability se escribe como `SYS_ADMIN`, sin el prefijo `CAP_`.

Usamos `unshare -n` (network namespace, `CLONE_NEWNET`), y NO `unshare -m` (mount
namespace). Ambas operaciones requieren la misma `CAP_SYS_ADMIN`, pero BusyBox `unshare -m`
tras un `unshare(2)` exitoso ejecuta además un syscall `mount(2)` independiente
para la forced private propagation, y el perfil de AppArmor por defecto de containerd (`RuntimeDefault`,
que recibe este Pod, ya que aquí no se indica un `appArmorProfile` explícito) contiene
`deny mount,` sin ninguna condición sobre los flags, con independencia de las capabilities/seccomp. Por eso
`unshare -m true` puede fallar con `EPERM` por AppArmor, aunque seccomp no
limite `unshare` en absoluto: un probe así mezclaría dos security controls distintos. `unshare -n`
llama solo al propio syscall `unshare(2)`, sin un `mount()` colateral.

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# en el worker
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# se espera un código distinto de cero: Operation not permitted / Permission denied
```

## 7. User namespaces: `hostUsers: false` y `uid_map`

`hostUsers: false` pide al kubelet que asigne al Pod un user namespace propio: el root (UID 0)
dentro del contenedor se mapea a un rango de UID del host sin privilegios. No indicamos
`runAsUser`, para que el proceso realmente arranque como UID 0 **dentro** del namespace; precisamente este
caso muestra la traducción, y no la ausencia de privilegios desde el principio.

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# en el worker
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

El host PID del contenedor no coincide con el PID dentro del contenedor ni se ve directamente a través de
`kubectl`. Tomamos el ID del contenedor en el worker y obtenemos el PID mediante `crictl inspect` en el nodo
donde realmente se ejecuta el Pod:

```bash
# en el worker
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - copia el <ID> sin el prefijo containerd://

# en el nodo
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# por ejemplo: 15205 - este es el <host PID>
```

`/proc/<host PID>/uid_map` en el nodo describe la traducción: tres números - `<container-uid-start>
<host-uid-start> <length>`. Para `hostUsers: false` la primera línea debe empezar por `0`
(container UID 0), pero el host-uid-start debe ser **distinto de cero**: ese es
el rango del host sin privilegios, y `length` es el bloque estándar per-Pod de `65536` UID.

```bash
# en el nodo (como root)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (el host-uid-start es distinto en cada Pod, lo principal es que no sea 0)
exit
exit
```

Guardamos la línea `uid_map` en el artefacto (en el `worker`):

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

Si `host-uid-start` es `0`, el user namespace no se aplicó (por ejemplo, por un
containerd/runc incompatible o por la ausencia de `hostUsers: false` en el Pod realmente aplicado):
eso no es hardening, sino un root normal en el host. Para comparar: un Pod normal sin
`hostUsers: false` también tiene el archivo `/proc/<host-PID>/uid_map`, pero el proceso permanece en el
host (initial) user namespace. Por eso el mapping empieza por UID 0 -> host UID 0 (normalmente
una línea del tipo `0 0 4294967295`, por ejemplo `cat /proc/1/uid_map` en el nodo), y no por
un host UID per-Pod sin privilegios. En `userns-probe` con `hostUsers: false` esperamos lo
contrario: `0 <host-uid-distinto-de-cero> <rango-per-pod>`.

## 8. `seccompDefault: true` en el kubelet

Todos los Pod anteriores indicaban explícitamente `seccompProfile`. Aquí comprobamos el node-level baseline:
si el desarrollador olvida este campo, el kubelet debe aplicar `RuntimeDefault` por sí mismo, y no
dejar el proceso `Unconfined`. Editamos la configuración del kubelet en el nodo:

```bash
# en el nodo
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# en el worker: el nombre del Node en la API no es el alias 'control-plane' de /etc/hosts, sino el nombre real del nodo (ip-10-...)
kubectl get nodes     # Ready
```

Creamos un Pod sin una sola mención de `seccompProfile`, ni a nivel de Pod ni de container:

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# en el worker
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- el kubelet aplicó RuntimeDefault por sí mismo, sin el campo en el manifest

# Compruébalo mediante la configuración REALMENTE APLICADA del kubelet, no mediante el texto del archivo en
# el disco: un drop-in o un flag de línea de comandos podrían redefinir el valor sin
# cambiar el propio config.yaml:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

Sin `seccompDefault: true` el mismo manifest daría `Seccomp: 0` (`Unconfined`): es fácil
comprobarlo revirtiendo el flag y recreando el Pod, si hace falta asegurarse de la diferencia.

## 9. Depuración de un perfil AppArmor roto

`/etc/apparmor.d/k8s-106-broken-profile` ya está en el disco, pero nunca se cargó: le
falta una coma tras la regla `deny /work/** w`. Primero encontramos el error sin cargar en el
kernel. `-p`/`--preprocess` aquí NO sirve: es un preprocessing (expande
`#include` a stdout), y no un safe dry-run/syntax-check. Usamos `-Q`/`--skip-kernel-load`
(compilación/comprobación completa sin cargar en el kernel) o `-d`/`--debug`
(una sola vez: solo syntax check).

El artefacto `apparmor-debug.txt` debe contener el error **original** del parser, por eso
lo guardamos antes de la corrección (en el `worker`):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Usamos `sudo` también para la comprobación compile-only `-Q`: en el nodo del laboratorio (apparmor 3.0.4, Ubuntu)
sin privilegios el parser en cada ejecución intenta configurar la policy cache en
`/var/cache/apparmor` y falla con "Failed setting up policy cache (/var/cache/apparmor):
Permission denied" ANTES de comprobar la sintaxis: obtendrás un error engañoso de permisos en lugar del
error de sintaxis real, y `apparmor-debug.txt` no contendrá el texto necesario
"syntax error". Comprobado en el propio nodo, incluso con un perfil deliberadamente roto.
La alternativa sin `sudo` es añadir `-K`/`--skip-cache` (`apparmor_parser -Q -K ...`): sin
caching el parser llega al análisis del perfil. `sudo` se ha elegido en este laboratorio por un workflow
unificado con el posterior `-r`, que en cualquier caso requiere privilegios.

Corregimos en el nodo: una regla de AppArmor debe terminar con una coma. Después cargamos el
perfil corregido en el kernel: precisamente con `-r -v` (reload + verbose), y no con `-Q`/`-p`, que
no cargan nada:

```bash
# en el nodo
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# se espera: "k8s-106-broken-profile":	"enforce",
```

Comprobación final de que el archivo ahora es válido sin errores:

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

Ahora, en el `worker`, añade la confirmación de la carga DESPUÉS de la corrección al mismo artefacto:

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

Al final ejecuta (en el `worker`):

```bash
check_result
```
