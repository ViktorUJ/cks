[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor y seccomp: node-local policy y denegaciones verificables

## Objetivo

En este laboratorio de CKS aplicarás dos mecanismos independientes de protección del proceso del contenedor a
nivel del kernel de Linux. Primero pasarás un perfil de **AppArmor** entregado de antemano de
`complain` a `enforce`, lo asignarás a un Pod mediante el campo moderno
`securityContext.appArmorProfile` y demostrarás la denegación de escritura. Después asignarás el baseline
seguro `RuntimeDefault` y un perfil **seccomp Localhost** custom que bloquea la
llamada al sistema `unshare(2)`.

Es la continuación del `SecurityContext` básico del laboratorio CKA 106: aquí no basta con escribir un
YAML. Los perfiles Localhost viven en el nodo de Kubernetes, por lo que hay que comprobar el nodo, el
placement del Pod y el comportamiento real del proceso.

## Threat model

Supongamos un RCE en el contenedor. La pregunta tras el compromise no es «¿pudo el atacante obtener una shell?», sino «¿qué puede hacer esa shell a continuación?» y qué tan grande es su blast radius.

AppArmor en las tareas 1–3 limita los objetos y las operaciones: el perfil se pasa a enforce y después se demuestra la denegación de escritura. Así, un proceso ya comprometido no obtiene libertad de acción ilimitada solo porque se ejecuta en un contenedor.

seccomp en las tareas 4–6 limita la llamada al sistema disponible: primero se aplica el baseline, después el perfil custom y luego se comprueba la denegación real de `unshare(2)`. La tarea 6 ya contiene un negative control mediante el Pod `sysadmin-control`: con la misma capability sin seccomp filter la llamada pasa, por lo que la comparación muestra precisamente el límite tras el compromise.

## Compruébate antes de empezar

<details>
<summary>1. ¿En qué se diferencia `complain` de `enforce` en AppArmor y por qué `complain` no se puede presentar como prueba de protección?</summary>

En modo `complain` AppArmor solo registra en el log las violaciones del perfil, pero NO las bloquea: una operación que debería estar prohibida se ejecutará igualmente, simplemente aparecerá una entrada en el journal. En `enforce` la operación se bloquea de verdad. La tarea 2 exige explícitamente pasar el perfil a `enforce`, porque la demostración "aquí hay una violación en el log" en `complain` no prueba la protección: el proceso aun así pudo ejecutar la acción.
</details>

<details>
<summary>2. ¿Por qué `allowPrivilegeEscalation: false` no quita la capability `SYS_ADMIN` ya concedida?</summary>

`allowPrivilegeEscalation: false` activa el flag del kernel `no_new_privs`, que prohíbe al proceso obtener privilegios NUEVOS mediante `execve` (por ejemplo, mediante un binario setuid o file capabilities). Esto no afecta a los privilegios que el proceso YA tiene en su effective/bounding set: si el contenedor se ejecuta con la capability `SYS_ADMIN` explícita en el manifest, esa capability sigue disponible con independencia del valor de `allowPrivilegeEscalation`.
</details>

<details>
<summary>3. ¿Por qué `localhostProfile` en el manifest del Pod se indica como una ruta relativa y no absoluta?</summary>

El kubelet resuelve por sí mismo la ruta relativa respecto de su seccomp root (por defecto `/var/lib/kubelet/seccomp/`). Si se indica una ruta absoluta, el kubelet buscará el archivo POR ESA RUTA ABSOLUTA dentro del seccomp root, lo que casi nunca coincidirá con la ubicación real del archivo: el Pod obtendrá `CreateContainerError`.
</details>

## Relación con el curso

- [Capítulo 16. AppArmor](../../course/16/es.md)
- [Capítulo 17. seccomp](../../course/17/es.md)
- [Capítulo 03. Container Runtime Security](../../course/03/es.md)

## Infraestructura

El entorno se despliega mediante Terragrunt en AWS `eu-central-1`.

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con subredes públicas |
| `ssh-keys` | claves para acceder al nodo |
| `k8s-1` | clúster kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd y **Calico** |
| `worker` | máquina de trabajo con `kubectl`, `check_result` y acceso SSH al nodo como `control-plane` |

Para ahorrar recursos, el control-plane es el único workload-node: se le ha quitado el
`NoSchedule` taint. Está marcado con el label
`security.cks.io/localhost-profiles-106=true`. Todos los Pod de este laboratorio deben elegir precisamente
este nodo: el perfil Localhost existe solo en él, y el planificador (scheduler) no lo traslada a otro nodo.

El bootstrap preparó **únicamente**:

- el label del nodo `security.cks.io/localhost-profiles-106=true` para un placement seguro;
- en la máquina de trabajo (worker), en `/opt/lab106-fixtures/`: los archivos fuente de `k8s-106-deny-write`
  (AppArmor profile) y `cks-106-deny-unshare.json` (seccomp profile custom).

Ni el AppArmor profile ni el seccomp profile están preinstalados en el workload-node ni
cargados en su kernel: el traslado y la carga inicial de cada uno de ellos forman parte de las tareas 1 y 5.
No cambies la ruta del seccomp profile y no crees el profile dentro de un Pod normal: el traslado de
los archivos al nodo lo realizas tú como administrador del nodo mediante SSH, y no desde dentro del workload.

## Despliegue

```bash
TASK=106 make run_cks_task
```

Conéctate por SSH a la máquina de trabajo. El contexto ya está configurado:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Comprueba el acceso al nodo y los worker-side fixtures antes de empezar a trabajar:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## Tareas

---
| **1** | **Trasladar y cargar el AppArmor profile** |
| :---: | :--- |
| Qué hacemos | El archivo fuente del profile `k8s-106-deny-write` está solo en la máquina de trabajo, en `/opt/lab106-fixtures/k8s-106-deny-write`. Cópialo al nodo `control-plane` en `/etc/apparmor.d/k8s-106-deny-write` (por ejemplo, mediante `scp`) y cárgalo en el kernel mediante `sudo apparmor_parser -r`. El profile ya contiene el flag `complain`: no hace falta habilitarlo por segunda vez, eso es cosa de la tarea 2. |
| Criterios de aceptación | `/etc/apparmor.d/k8s-106-deny-write` está presente en el nodo; `/sys/kernel/security/apparmor/profiles` contiene una línea con el nombre `k8s-106-deny-write` (en cualquier modo: `complain` o `enforce`), es decir, el profile realmente está cargado en el kernel, y no simplemente copiado al disco. |

<details>
<summary>💡 Pista para la tarea 1</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` copia el archivo al nodo
en un directorio temporal; muévelo desde allí con `sudo` a `/etc/apparmor.d/` (un usuario normal
no tiene permisos de escritura directamente allí). Después `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` compila y carga el profile en el kernel: sin este
paso el archivo en el disco no da ninguna protección y no aparecerá en
`/sys/kernel/security/apparmor/profiles`.
</details>

---
| **2** | **Pasar el AppArmor profile a enforce** |
| :---: | :--- |
| Qué hacemos | En el nodo `control-plane` pasa el profile `k8s-106-deny-write`, cargado en la tarea 1, al modo `enforce`. El modo original `complain` registra las violaciones, pero no es una protección. No elimines el profile ni cambies su nombre. |
| Criterios de aceptación | Existe un nodo con el label `security.cks.io/localhost-profiles-106=true`; `/etc/apparmor.d/k8s-106-deny-write` está disponible; `/sys/kernel/security/apparmor/profiles` contiene la línea `k8s-106-deny-write (enforce)`. El bootstrap-baseline propiedad del checker (registrado ANTES de entregar el laboratorio, sobre una copia transitoria de este mismo profile mientras aún estaba en `complain`) confirma que una escritura que corresponde al patrón `/work/**` de este profile entonces realmente pasaba: sin esto no se puede demostrar que precisamente el paso a `enforce` provocó la denegación posterior. |

<details>
<summary>💡 Pista para la tarea 2</summary>

El comando `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` recarga un perfil ya existente: si estaba en `complain` y el archivo en disco ya describe `enforce`, este comando basta. Compruébalo mediante `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write`: la salida debe mostrar explícitamente `(enforce)`. No lo compruebes mediante `aa-status`: ese comando agrupa los perfiles bajo encabezados de sección (`N profiles are in enforce mode.`) e imprime debajo solo los nombres desnudos de los perfiles, SIN el sufijo `(enforce)`/`(complain)` en cada línea: ese sufijo solo existe en `/proc/<pid>/attr/current` y en el archivo del kernel `/sys/kernel/security/apparmor/profiles`, y no en la lista de perfiles de `aa-status`.

No uses `aa-enforce`/`aa-complain` para este perfil mientras no esté hecha la tarea 9:
estas herramientas de Python de `apparmor-utils`, antes de su trabajo principal, analizan
(parsean) **todos** los archivos de `/etc/apparmor.d/`, incluido el aún roto `k8s-106-broken-profile`
de la tarea 9, y fallan con un error del parser en un archivo ajeno. Edita el flag `complain` en el archivo
del perfil directamente (`sed`) y recarga precisamente ESE archivo mediante `apparmor_parser -r`:
este binario, a diferencia de `aa-enforce`, analiza solo el archivo que se le pasa.
</details>

---
| **3** | **Localhost AppArmor Pod y bloqueo de escritura** |
| :---: | :--- |
| Qué hacemos | Crea el namespace `security-106` y el Pod `apparmor-writer`. El Pod debe elegir el label del nodo de la infraestructura, desactivar el automount del ServiceAccount token y, a nivel de Pod, establecer `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write`. Usa `busybox:1.36`, el contenedor `app`, el comando de espera `sleep 3600` y un `emptyDir` montado en `/work`. Tras el arranque, confirma el profile efectivo con el comando `cat /proc/1/attr/current` (si la interfaz está disponible), ejecuta una operación de lectura permitida, por ejemplo `cat /etc/hostname >/dev/null`, y después intenta escribir un archivo en `/work`; la operación debe terminar con una denegación. En el nodo registra el AppArmor denial para el profile/process mediante `journalctl -k \| grep -i apparmor` o `dmesg \| grep -i apparmor`. |
| Criterios de aceptación | El Pod está en ejecución, usa precisamente el profile Localhost y el nodeSelector correcto; el profile efectivo del proceso muestra `k8s-106-deny-write` en enforce mode (cuando `/proc/.../attr/current` está disponible); la operación de lectura permitida (por ejemplo, `cat /etc/hostname` o `ls /work`) pasa, y el checker escribe de forma independiente su propio archivo único (per-run) en `/work` y recibe una denegación de AppArmor. En el kernel journal/audit log hay un evento `apparmor="DENIED"` con este profile que se refiere precisamente a ESTE intento (por el nombre único del archivo): esto excluye un false pass por un evento denial obsoleto en el journal. |

<details>
<summary>💡 Pista para la tarea 3</summary>

`appArmorProfile` para un perfil de tipo `Localhost` se indica mediante dos campos separados: `type: Localhost` y `localhostProfile: k8s-106-deny-write` (el nombre del perfil SIN la ruta `/etc/apparmor.d/`): es el mismo nombre con el que el perfil se cargó en la tarea 1. Si el Pod no arranca (CreateContainerError), comprueba que el profile realmente ya está cargado en el nodo NECESARIO mediante el nodeSelector: los perfiles de AppArmor son node-local, no se trasladan automáticamente.
</details>

---
| **4** | **Baseline seguro de seccomp RuntimeDefault** |
| :---: | :--- |
| Qué hacemos | Crea en `security-106` el Pod `runtime-default` con `busybox:1.36` y `sleep 3600`. A nivel de Pod indica explícitamente `securityContext.seccompProfile.type: RuntimeDefault`; el Pod también debe elegir el nodo preparado. Comprueba en el contenedor `/proc/1/status`: se espera `Seccomp: 2`. |
| Criterios de aceptación | El Pod está en `Running`, en su securityContext a nivel de Pod se ha seleccionado `RuntimeDefault` y el proceso está en seccomp filter mode. |

<details>
<summary>💡 Pista para la tarea 4</summary>

`Seccomp: 2` en `/proc/1/status` significa "filter mode activo" (SECCOMP_MODE_FILTER): es lo que debes ver. `Seccomp: 0` significaría la ausencia total de seccomp filter (`Unconfined`). Es la más sencilla de las tres tareas de seccomp (4-6): si no pasa, lo más probable es que el problema esté en el nodeSelector, y no en el propio seccompProfile.
</details>

---
| **5** | **Trasladar y usar un Localhost seccomp profile custom** |
| :---: | :--- |
| Qué hacemos | El archivo fuente `cks-106-deny-unshare.json` está solo en la máquina de trabajo, en `/opt/lab106-fixtures/cks-106-deny-unshare.json`. Determina el nodo con el label `security.cks.io/localhost-profiles-106=true`, crea en él el directorio `/var/lib/kubelet/seccomp/profiles/` (si aún no existe) y copia allí el JSON con el mismo nombre. Después crea el Pod `localhost-seccomp` en `security-106` en ese nodo. A nivel de Pod indica `seccompProfile.type: Localhost` y la ruta relativa `profiles/cks-106-deny-unshare.json`, sin `/var/lib/kubelet/seccomp/`. El contenedor `app` debe usar `busybox:1.36`, recibir la capability `SYS_ADMIN` y seguir en ejecución tras la comprobación. **No presentes esta combinación como un hardened baseline:** `SYS_ADMIN` sigue siendo una de las capabilities más peligrosas, y `allowPrivilegeEscalation: false` no quita los privilegios ya concedidos. Es un capability-focused experiment, en el que la seguridad la muestra un seccomp deny concreto. |
| Criterios de aceptación | El JSON profile está trasladado y existe en el nodo en la ruta correcta; el Pod con el nodeSelector correcto usa el profile `Localhost:profiles/cks-106-deny-unshare.json`; el JSON profile contiene `SCMP_ACT_ERRNO`/`errnoRet: 1` para `unshare`; en el contenedor se ha añadido solo el `SYS_ADMIN` necesario para el experimento. |

<details>
<summary>💡 Pista para la tarea 5</summary>

La ruta `profiles/cks-106-deny-unshare.json` es relativa al kubelet seccomp root `/var/lib/kubelet/seccomp/`, es decir, el archivo real en el nodo debe estar en la ruta `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json`: allí es donde hay que copiarlo desde la máquina de trabajo (por ejemplo, `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, luego `sudo mkdir -p` y `sudo mv` en el nodo). No escribas en el manifest la ruta absoluta completa: el kubelet añadirá la raíz por sí mismo. `SYS_ADMIN` se concede aquí PRECISAMENTE para el experimento (hace falta una capability que permita llamar a `unshare` en principio), y no como práctica recomendada: no confundas el escenario didáctico con un baseline de producción.
</details>

---
| **6** | **Demostrar la denegación del syscall `unshare(2)`** |
| :---: | :--- |
| Qué hacemos | En el comando del contenedor `localhost-seccomp` ejecuta `unshare -n true`, guarda la confirmación exitosa de la denegación esperada en `/tmp/unshare-result` como la línea `unshare denied by seccomp`, y después mantén el contenedor con `sleep 3600`. Un nuevo comando `kubectl exec ... -- unshare -n true` debe devolver un código distinto de cero. Para un attack-minded negative control crea un Pod `sysadmin-control` en el mismo nodo con `seccompProfile.type: Unconfined` y la misma única capability `SYS_ADMIN`; su `unshare -n true` debe terminar con éxito. Elimina el control Pod tras la comprobación. |
| Criterios de aceptación | El Localhost Pod está en ejecución; `Seccomp: 2`; `unshare` es bloqueado por el custom profile. En el control Pod el mismo syscall con la misma capability y sin seccomp filter pasa. Esto demuestra el kernel behavior, y no solo la presencia de un YAML. |

<details>
<summary>💡 Pista para la tarea 6</summary>

Usa precisamente `unshare -n true` (unshare network namespace, `CLONE_NEWNET`), y NO
`unshare -m true`. `-m` (mount namespace) requiere `CAP_SYS_ADMIN` igual que `-n`, pero
BusyBox `unshare -m`, tras un `unshare(2)` exitoso, ejecuta además un SEGUNDO syscall
`mount(2)` independiente (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
para forzar la private propagation: es un comportamiento de unshare, activo por defecto
si no se pasa explícitamente `--propagation unchanged`, e incluso entonces `mount()` igualmente se
llama, solo que con flags nulos). El perfil AppArmor por defecto de containerd (`RuntimeDefault`,
que recibe un Pod sin un `securityContext.appArmorProfile` explícito) contiene `deny mount,`
SIN ninguna condición sobre los flags: esa prohibición actúa con independencia de las capabilities y del
seccomp. Por eso `unshare -m true` puede fallar con `EPERM` por AppArmor INCLUSO cuando
seccomp no limita `unshare` en absoluto, lo que hace que ese probe sea una prueba poco fiable
precisamente de una denegación de seccomp. `unshare -n` (`CLONE_NEWNET`) llama SOLO al propio syscall
`unshare(2)` sin ningún `mount()` posterior, y tanto `localhost-seccomp` como
`sysadmin-control` usan el mismo `SYS_ADMIN`, por lo que la diferencia en el resultado
se explica sin ambigüedad precisamente por el seccomp filter, y no por un efecto secundario de AppArmor.

El orden de los comandos es importante para la fuerza probatoria: primero ejecuta `unshare -n true` y asegúrate de que falla con un error (exit code distinto de cero), SOLO DESPUÉS escribe la línea `unshare denied by seccomp` en `/tmp/unshare-result`: no escribas la línea de antemano, "suponiendo" el resultado. El negative control (`sysadmin-control`) debe usar LA MISMA capability `SYS_ADMIN`, pero `seccompProfile.type: Unconfined`: si olvidas indicar `Unconfined` explícitamente, el Pod puede recibir `RuntimeDefault` por defecto (si está habilitado `seccompDefault` de la tarea 8) y el test no mostrará la diferencia.
</details>

Las Linux capabilities y el privilege escalation son ejes distintos. `allowPrivilegeEscalation: false`
activa `no_new_privs` y prohíbe obtener privilegios **nuevos** mediante `execve` (setuid/setgid y
file capabilities), pero no elimina `SYS_ADMIN`, ya añadida al bounding/effective set.
Para un workload normal usa `capabilities.drop: ["ALL"]` y, por separado,
`allowPrivilegeEscalation: false`; el experimento de arriba deliberadamente no es un baseline así.

---
| **7** | **User namespaces: `hostUsers: false` y traducción de UID mediante `uid_map`** |
| :---: | :--- |
| Qué hacemos | Los User namespaces son GA en Kubernetes v1.36 (consulta el [capítulo 03](../../course/03/es.md), el [capítulo 18](../../course/18/es.md) y el Security Delta v1.36). La teoría explica que `hostUsers: false` traduce el root del contenedor a un host UID sin privilegios; aquí hay que demostrarlo sobre un proceso vivo. Crea en `security-106` un Pod `userns-probe` en el nodo preparado con `spec.hostUsers: false`, la imagen `busybox:1.36`, el comando `sleep 3600`; no establezcas `runAsUser` a nivel de Pod, para que el proceso arranque como UID 0 **dentro** del contenedor. Confirma `id` dentro del contenedor (`uid=0`). Determina el host PID del proceso del contenedor mediante `crictl inspect` (por analogía con el laboratorio 112) o mediante `kubectl get pod -o jsonpath` + `crictl ps`, después en el nodo lee `/proc/<host PID>/uid_map`. Guarda ambas salidas (`id` dentro del contenedor y el contenido de `uid_map`) en `/var/work/tests/artifacts/6/userns.txt`. |
| Criterios de aceptación | El Pod está en `Running`, `spec.hostUsers == false`, elige el nodo preparado; `id` dentro del contenedor muestra `uid=0(root)`; `/proc/<host PID>/uid_map` en el nodo contiene una línea del tipo `0 <host-uid> <length>`, donde `<host-uid>` **no es igual a 0** (el root del contenedor está traducido a un host UID sin privilegios) y `<length>` es como mínimo `65536` (el rango estándar de UID por Pod); el artefacto contiene ambas partes de la evidence. |

<details>
<summary>💡 Pista para la tarea 7</summary>

`id` DENTRO del contenedor mostrará `uid=0(root)` con independencia de `hostUsers`: es lo esperado, el contenedor ve SU propio namespace, donde su root es realmente el UID 0 en ese namespace. La protección real solo se ve DESDE FUERA: en el propio nodo, en `/proc/<host PID>/uid_map`, donde el UID 0 dentro del contenedor se traduce a algún UID grande sin privilegios en el host. Para encontrar el host PID, usa `crictl inspect <container-id>`: precisamente de allí, y no de `kubectl get pod`, que conoce solo el objeto de Kubernetes, y no el PID a nivel de host del proceso.
</details>

---
| **8** | **`seccompDefault: true` a nivel de kubelet: baseline sin un perfil explícito** |
| :---: | :--- |
| Qué hacemos | Todos los Pod de las tareas 4–6 indican explícitamente `seccompProfile` en el manifest. En la realidad un desarrollador puede olvidar este campo; entonces, sin un node-level baseline, el Pod recibe `Unconfined`. En el nodo habilita `seccompDefault: true` en `/var/lib/kubelet/config.yaml` y reinicia el kubelet (`systemctl restart kubelet`). Crea un Pod `no-seccomp-field` en `security-106` en el nodo preparado con `busybox:1.36` (`sleep 3600`), **sin indicar en absoluto securityContext.seccompProfile**, ni a nivel de Pod ni a nivel de contenedor. A través de `/proc/1/status` dentro del contenedor confirma que el kubelet aplicó `RuntimeDefault` automáticamente (`Seccomp: 2`), y no dejó `Unconfined` (`Seccomp: 0`). |
| Criterios de aceptación | La configuración efectiva (aplicada) del kubelet, mediante `/api/v1/nodes/<node>/proxy/configz`, campo `.kubeletconfig.seccompDefault`, es igual a `true`; `systemctl is-active kubelet` devuelve `active`, el nodo permanece `Ready`; el Pod `no-seccomp-field` no tiene `seccompProfile` en ningún nivel de su especificación; `/proc/1/status` dentro del contenedor muestra `Seccomp: 2`. |

<details>
<summary>💡 Pista para la tarea 8</summary>

El requisito clave es que el Pod REALMENTE no mencione `seccompProfile` en absoluto, ni a nivel de Pod ni a nivel de contenedor. Si copias el manifest de las tareas 4–6 y simplemente olvidas eliminar este campo, el test no demostrará lo que debe: que precisamente el `seccompDefault` a nivel de nodo (y no la indicación explícita en el manifest) proporcionó `Seccomp: 2`.

La comprobación se guía por la configuración REALMENTE APLICADA del kubelet, y no por el texto del archivo en
el disco: `curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
Un simple grep sobre `/var/lib/kubelet/config.yaml` no demuestra que ese mismo archivo lo
use el kubelet en ejecución: un flag de línea de comandos o un drop-in podrían redefinir el
valor sin cambiar el propio archivo. Reinicia obligatoriamente el kubelet tras editar el
archivo: la configuración no se recoge al vuelo.
</details>

---
| **9** | **Depuración y reconstrucción de un perfil AppArmor roto (`apparmor_parser -r -v`)** |
| :---: | :--- |
| Qué hacemos | En el disco ya está `/etc/apparmor.d/k8s-106-broken-profile`: un perfil con un error de sintaxis que **nunca se ha cargado** en el kernel. Encuentra el error por tu cuenta mediante `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load`: ejecuta por completo la comprobación/compilación del perfil, pero no lo carga en el kernel) o `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`, una sola vez: solo la comprobación de la corrección sintáctica), corrige el archivo y carga el perfil en el kernel mediante `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile`. Confirma la carga mediante `aa-status \| grep k8s-106-broken-profile`. Guarda la salida del error **antes** de la corrección y la confirmación de la carga **después** en `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Criterios de aceptación | `apparmor-debug.txt` contiene el texto del error del parser (por ejemplo, `syntax error`) del intento **antes** de la corrección; el bootstrap-baseline propiedad del checker (registrado ANTES de entregar el laboratorio, independientemente de tu artifact) confirma de forma independiente que el perfil original realmente contenía un syntax error; `/etc/apparmor.d/k8s-106-broken-profile` en el disco ya no contiene el error de sintaxis original; `aa-status` muestra `k8s-106-broken-profile` entre los perfiles cargados (en cualquier modo: `enforce` o `complain`); un nuevo `apparmor_parser -Q` sobre el archivo corregido termina sin error. |

<details>
<summary>💡 Pista para la tarea 9</summary>

`apparmor_parser -p` (`--preprocess`) NO es un modo safe dry-run/syntax-check: es
simplemente un preprocessing, que expande las directivas `#include` e imprime el
perfil resultante en stdout, sin garantizar por sí mismo la ausencia de efectos secundarios y sin estar
pensado precisamente para comprobar la sintaxis. Usa `-Q`/`--skip-kernel-load`
(ejecuta la compilación/comprobación completa, pero no carga en el kernel) o `-d`/`--debug`
(una sola vez: solo la comprobación de la corrección sintáctica) para encontrar de forma SEGURA
el error de sintaxis sin efectos secundarios. Solo después de corregir el archivo usa
`-r` (reload/load) para la carga real en el kernel. La sintaxis de AppArmor requiere una coma como
separador de reglas dentro del bloque: estudia la salida del parser para encontrar qué carácter
falta y dónde exactamente.

Ejecuta `apparmor_parser` mediante `sudo`, incluso con `-Q`/`-d`: en el nodo del laboratorio (apparmor 3.0.4,
Ubuntu), sin privilegios el parser en cada ejecución intenta configurar la policy cache en
`/var/cache/apparmor` y falla con "Failed setting up policy cache: Permission denied" ANTES de
comprobar la sintaxis: obtendrás un error engañoso de permisos en lugar del error de sintaxis
real del perfil. Esto está comprobado en el propio nodo (incluso con un perfil deliberadamente roto).
Si necesitas ejecutarlo sin `sudo`, añade `-K` (`--skip-cache`: sin ningún caching):
`apparmor_parser -Q -K` sin privilegios llega al análisis del perfil y muestra el error
real. La carga y el reload (`-r`) en cualquier caso requieren privilegios.
</details>

## Comprobación

En la máquina de trabajo ejecuta:

```bash
check_result
```

La comprobación contiene Init y nueve tests independientes. Lee el state del Pod mediante la API, comprueba el
profile en el nodo por SSH y ejecuta escenarios negativos controlados. Si el Localhost
Pod no se crea, primero mira `kubectl describe pod`: la causa habitual es una ruta absoluta
en lugar de una relativa o la asignación del Pod a un nodo sin el profile.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=106 make delete_cks_task
```
