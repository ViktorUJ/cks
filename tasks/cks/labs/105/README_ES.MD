[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening del SO y seguridad del Docker daemon

## Objetivo

En este laboratorio de CKS reducirás la superficie de ataque de dos hosts Linux. En el
control-plane de Kubernetes hay que desactivar los servicios innecesarios, cerrar un puerto abierto, configurar el firewall,
proteger el kubeconfig y prohibir el root login directo por SSH. En un `docker-host` aparte
hay que eliminar tres configuraciones peligrosas del Docker daemon: la TCP API sin TLS, el acceso a
`docker.sock` a través del grupo `docker` y el acceso del usuario `developer` a ese socket.

Este entorno de laboratorio se ha creado deliberadamente inseguro. No traslades la configuración original
a producción: la Docker API en TCP/2375 sin TLS da acceso root remoto a cualquiera que pueda
conectarse al puerto.

## Compruébate antes de empezar

<details>
<summary>1. ¿En qué se diferencia `systemctl disable` de `systemctl stop` y por qué para la tarea 1 hacen falta ambos?</summary>

`stop` detiene el proceso ya en ejecución ahora mismo, pero no afecta al arranque automático en el siguiente arranque del sistema. `disable` quita el servicio del arranque automático (el unit-file deja de estar vinculado al target), pero no detiene el proceso que ya está funcionando. Para cerrar por completo la superficie de ataque hacen falta ambas cosas; de lo contrario, el servicio seguirá funcionando ahora o volverá a arrancar tras un reboot.
</details>

<details>
<summary>2. ¿Por qué una TCP Docker API sin TLS (`-H tcp://0.0.0.0:2375`) equivale a un acceso root remoto?</summary>

El Docker daemon funciona con privilegios de root, y su API no tiene built-in authentication sin TLS client certificates. Cualquiera que pueda conectarse a este puerto por la red puede lanzar un container arbitrario con `--privileged` y la host filesystem montada, y obtener el control total del host, saltándose SSH y cualquier otro mecanismo de control de acceso.
</details>

<details>
<summary>3. ¿Por qué `chmod 600` para el kubeconfig es importante, aunque el archivo ya sea accesible solo para root a través del sistema de archivos?</summary>

`/etc/kubernetes/admin.conf` contiene un client certificate con permisos de `cluster-admin`: si el modo del archivo es demasiado amplio (por ejemplo, `644`, legible por todos), CUALQUIER usuario de este nodo, incluso sin sudo, puede leer la credential y obtener acceso administrativo completo al clúster de forma remota, sin necesidad de escalar privilegios en el propio nodo.
</details>

<details>
<summary>4. ¿Por qué un core dump de un proceso puede filtrar un secret, aunque el propio secret nunca se haya escrito en disco?</summary>

Un core dump es una imagen de la memoria del proceso en el momento del crash, que **puede** incluir valores descifrados de variables, claves privadas y tokens mantenidos en claro. No está garantizado que sea toda la memoria del proceso: el conjunto de mapeos depende de `/proc/<pid>/coredump_filter`, y algunas áreas pueden quedar excluidas, por ejemplo mediante `MADV_DONTDUMP`. Por eso, aunque la aplicación nunca escriba explícitamente el secret en un archivo, un crash dump puede guardar en disco, en un archivo legible, los secrets presentes en los mapeos incluidos.
</details>

## Relación con el curso

- [Capítulo 14. Minimización del footprint del SO del host y seguridad del runtime-daemon](../../course/14/es.md)
- [Capítulo 15. Least-privilege en el host y minimización del acceso externo](../../course/15/es.md)
- [CKA: systemd, servicios y Linux](../../../cka/course/00-5-linux/es.md)
- [CKA: contenedores y runtime](../../../cka/course/00-4-containers/es.md)

## Infraestructura

El entorno se despliega mediante Terragrunt en AWS `eu-central-1`:

| Componente | Finalidad |
|---|---|
| `vpc` | VPC `10.10.0.0/16` con dos subredes públicas |
| `ssh-keys` | clave SSH para las conexiones internas |
| `k8s-1` | clúster kubeadm de un solo nodo con Kubernetes `1.36.0`, containerd, Calico; este es el control-plane objetivo |
| `docker-host` | un Ubuntu 22.04 aparte con Docker y una configuración deliberadamente insegura |
| `worker` | máquina de trabajo con `kubectl`, configuración SSH y `check_result` |

`worker` tiene acceso SSH al control-plane por su Kubernetes node name y a un host
aparte por el nombre `docker-host`. Docker no es el runtime del clúster de Kubernetes: su
configuración de la tarea 6 está aislada en `docker-host`.

## Despliegue

```bash
TASK=105 make run_cks_task
```

Conéctate al `worker` (el contexto de kubectl ya está configurado), mira el nombre del nodo
control-plane y entra en los hosts:

```bash
kubectl get no
ssh <nombre-del-nodo-de-la-salida>
ssh docker-host
```

Comandos útiles:

```bash
time_left
check_result
```

Guarda los artefactos de comprobación en `/var/work/tests/artifacts/<número>/`. No hace falta crear
manifests de Kubernetes para este laboratorio.

## Tareas

---
| **1** | **Desactivar un servicio innecesario** |
| :---: | :--- |
| Qué hacemos | En el control-plane desactiva y detén `cks-lab105-unused.service`. El servicio no es necesario para el funcionamiento de Kubernetes y no debe arrancar tras un reboot. |
| Criterios de aceptación | `systemctl is-enabled cks-lab105-unused.service` devuelve `disabled`, `systemctl is-active` - `inactive`; en `/var/work/tests/artifacts/1/service.txt` hay una línea `disabled inactive`. |

<details>
<summary>💡 Pista para la tarea 1</summary>

Orden de los comandos: `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service`: hacen falta ambos pasos, ninguno sustituye al otro (consulta la pregunta 1 en la sección de autoevaluación de arriba). El artefacto debe contener precisamente la línea "disabled inactive" (en ese orden, separadas por un espacio): comprueba el formato antes de guardar.
</details>

---
| **2** | **Cerrar un puerto abierto innecesario** |
| :---: | :--- |
| Qué hacemos | En el control-plane elimina el listener TCP/8080 creado por `cks-lab105-port.service`. Desactiva y detén el servicio (ambas acciones son obligatorias; consulta la pregunta 1 en la sección de autoevaluación); no lo necesita ni el control-plane ni el kubelet. |
| Criterios de aceptación | `ss -ltn` no muestra TCP/8080; `systemctl is-enabled cks-lab105-port.service` devuelve `disabled`, `systemctl is-active` - `inactive`; `/var/work/tests/artifacts/2/service.txt` contiene la línea `disabled inactive`; `/var/work/tests/artifacts/2/port-8080.txt` contiene `tcp/8080: closed`. |

<details>
<summary>💡 Pista para la tarea 2</summary>

Primero averigua qué proceso mantiene el puerto (`sudo ss -ltnp | grep 8080`), para asegurarte de que realmente es `cks-lab105-port.service` y no otra cosa. Cerrar el puerto mediante el firewall (tarea 3) no basta para esta tarea: el test comprueba que el PROPIO listener no exista, y no simplemente que esté bloqueado desde fuera.
</details>

---
| **3** | **Limitar el tráfico entrante con el firewall** |
| :---: | :--- |
| Qué hacemos | • Antes de habilitar UFW, registra el rol del nodo, la worker source IP, la node InternalIP y el `spec.podCIDR`.<br/>• **Baseline obligatorio antes del firewall:** registra un baseline-probe de TCP/10250 (kubelet HTTPS endpoint) desde el worker: un `curl` con `CURL_EXIT`/`HTTPCODE` reales, que demuestre la alcanzabilidad de red del puerto (cualquier 1xx-5xx, incluidos 401/403, cuenta como alcanzabilidad: la kubelet API realmente respondió). Sin este paso, el "bloqueado" posterior al hardening no se puede distinguir de un fallo ajeno (security group, routing) que bloqueaba el puerto ya antes de UFW. Además de tu registro, el checker lo contrasta de forma independiente con su propio bootstrap-baseline, registrado ANTES de entregar el laboratorio en el directorio protegido `/var/lib/cks-lab105-checker` (`0711 root:root`, aparte de `/var/work/tests`, que por defecto es escribible por todos).<br/>• Topología: un control-plane de un solo nodo + workload node. Hacen falta exactamente cinco reglas: loopback, SSH recovery desde el worker, API `6443/tcp` desde el worker, desde el propio nodo y desde el Pod CIDR. etcd/scheduler/controller-manager usan flows locales, en esta topología no hay flows CNI/kubelet entre nodos.<br/>• Gestiona el firewall solo con el comando `ufw` (allow/deny/reject/limit/route, luego enable/reload). No edites a mano `/etc/ufw/before*.rules`, `after*.rules`, `user.rules`, `user6.rules`: los framework-files (before/after) se contrastan por hash con el bootstrap-baseline, y `user.rules`/`user6.rules` (donde ufw escribe tus reglas) se comprueban por el estado real del kernel (`ufw show user-rules`), y no solo por el archivo.<br/>• Añade las source-scoped allow rules antes de `ufw default deny incoming`. No uses `ALLOW Anywhere` amplios y no añadas ninguna otra regla además de estas cinco (loopback + 4 source-scoped), incluidos deny/reject/route.<br/>• Habilita UFW y guarda en `/var/work/tests/artifacts/3/`: `ufw status`, `ufw show added` (representación normalizada de las reglas añadidas, no necesariamente en la forma/orden original de los comandos), el preflight (incluido el baseline TCP/10250) y los comandos de recovery.<br/>• **Retest obligatorio tras `ufw reload`:** ejecuta `sudo ufw reload` y repite TODAS las mismas comprobaciones (readyz, node Ready, calico-node Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count). Una regla que funciona solo en memoria justo después de enable, pero que no sobrevive al reload, no se considera una solución correcta. |
| Criterios de aceptación | • **Baseline TCP/10250:** el bootstrap-baseline propiedad del checker (registrado antes de entregar el laboratorio en `/var/lib/cks-lab105-checker`, directorio `0711 root:root` fuera de `/var/work/tests`, archivo `0444 root:root`) confirma la alcanzabilidad inicial de TCP/10250; tu propio baseline-probe previo a UFW está guardado y muestra una alcanzabilidad de red real (`CURL_EXIT=0`, HTTP `1xx-5xx`). Si el puerto ya no es accesible en el baseline, el resultado de la tarea es `inconclusive`, y no PASS.<br/>• **UFW y el conjunto exacto de reglas:** UFW active, default-deny; `ufw show added` contiene EXACTAMENTE cinco líneas: loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`, sin una sola regla de más de CUALQUIER acción (`allow`/`deny`/`reject`/`limit`/`route`) y sin que falte ninguna de las cinco.<br/>• **Framework-files:** el hash de `/etc/ufw/before*.rules`/`after*.rules` no difiere del bootstrap-baseline propiedad del checker (las reglas se añaden solo mediante `ufw`, los framework-files no se editan a mano).<br/>• **Estado real del kernel:** `sudo ufw show user-rules` (las chains reales `ufw-user-*` mediante `iptables -L`) coincide semánticamente con las cinco reglas esperadas: se comprueba no solo la cantidad, sino el source/interface/protocol/port de CADA regla, tanto tras `enable` como tras `reload`. `ufw6-user-input` permanece con EXACTAMENTE una línea: la versión v6 del loopback ACCEPT (`ufw allow in on lo` crea a la vez una regla v4 y una v6, pues es una regla por interfaz sin una IP explícita; no "completamente vacía"). Esto detecta la edición directa de `user.rules`/`user6.rules` sin tuple metadata (no se refleja ni en `ufw show added` ni en el hash de `before/after`) y la ampliación de una regla ya declarada (por ejemplo, `node_ip`→`6443/tcp`, sustituida a escondidas por `node_ip`→`any`) sin cambiar el número de líneas.<br/>• **Salud del clúster:** `/readyz=ok`; el nodo esperado y todos los Pod `calico-node` permanecen `Ready`; `health-probe` permanece Ready, resuelve DNS y alcanza el Kubernetes Service.<br/>• **Bloqueo del kubelet:** tras UFW, el worker no alcanza el kubelet `10250` (`HTTPCODE=000`, transport deny), precisamente como una regresión respecto del baseline demostrado.<br/>• **Retest tras reload:** **todas las mismas comprobaciones vuelven a pasar tras un `sudo ufw reload` explícito**: readyz/node/calico-node/DNS/Pod→API permanecen sanos, worker→kubelet:10250 permanece bloqueado con el mismo contrato de deny que antes del reload, y el número real de reglas en el kernel vuelve a coincidir con el declarativo.<br/>• **Artefactos:** el artefacto contiene los comandos de recovery (`ufw disable`, comprobación, corrección y nueva habilitación). |

<details>
<summary>💡 Pista para la tarea 3</summary>

El error más peligroso aquí es ejecutar `ufw enable` (default-deny) ANTES de haber añadido la regla allow para SSH desde la worker IP. El orden debe ser: primero todos los `ufw allow from <IP> to any port <port>` necesarios, solo después `ufw --force enable`. Mantén abierta la sesión SSH actual durante todo el trabajo con el firewall: si pierdes el acceso, una segunda sesión de recovery no se conectará (consulta la advertencia de abajo). No olvides el baseline-probe de TCP/10250 ANTES de habilitar UFW: sin él, el "bloqueado" posterior al hardening no demuestra nada: el puerto podía ser inalcanzable ya antes por una razón completamente distinta (por ejemplo, un AWS security group), y entonces UFW no tiene aquí nada que ver; además, el checker tiene su propio baseline, registrado antes de entregar el laboratorio en un directorio protegido aparte, por lo que no se podrá falsificar ese registro a posteriori. Comprueba el allow-set estrictamente mediante `sudo ufw show added` (y no solo `ufw status`): ahí deben estar EXACTAMENTE cinco líneas, ninguna de más (ningún `ALLOW Anywhere` amplio, ningún puerto adicional, y esto vale para CUALQUIER acción: `allow`, `deny`, `reject`, `limit`, `route`, no solo para nuevas reglas allow) y ninguna que falte. Gestiona el firewall solo mediante el comando `ufw`: no edites a mano `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules`: los framework-files se contrastan por hash, y el estado real de `user.rules`/`user6.rules` el checker lo comprueba directamente mediante las reglas iptables reales en las chains `ufw-user-*` (`sudo ufw show user-rules`), por lo que incluso una edición de `user.rules` sin los comentarios `### tuple ###` correctos se detectará tras `ufw reload`. Y no olvides ejecutar `sudo ufw reload` al final y repetir todas las comprobaciones: una regla que funciona solo justo después de `enable`, pero no sobrevive a `reload`, no cuenta.
</details>

> **Recovery primero.** Mantén abierta la sesión SSH actual hasta la comprobación completa. Si la API
> desaparece, desde ella ejecuta `sudo ufw disable`, corrige las allow rules y solo entonces vuelve a
> habilitar el firewall. Si el SSH ya se ha perdido, usa la consola/el recovery channel del proveedor;
> no intentes «curar» la situación con un `allow from any` amplio.
>
> **Límite de aplicabilidad.** Este UFW allowlist está pensado solo para un fixture de un solo nodo.
> No se puede trasladar literalmente a un clúster multi-node: antes del default-deny hay que inventariar
> los flujos del kubelet y entre nodos, el CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort y
> el provider firewall/security groups para la topología concreta.
>
> **Lab-specific exception: UFW en un nodo Calico.** La documentación oficial de Calico sobre
> requisitos recomienda expresamente desactivar firewalld y otros iptables managers en
> los nodos Calico, porque pueden entrar en conflicto con las reglas que establece el propio
> Calico. UFW es también un iptables/nftables manager de este tipo. Este laboratorio mantiene deliberadamente UFW en el
> control-plane para practicar el host firewall hardening (una habilidad aparte en el temario del examen
> CKS), y no como una forma recomendada de combinar Calico con un host firewall en producción: para
> eso Calico ofrece su propio `HostEndpoint`/`GlobalNetworkPolicy`. Precisamente por eso la tarea
> exige explícitamente una secuencia controlada baseline → `ufw enable` → retest con
> la comprobación de que `calico-node` y toda la conectividad de Kubernetes siguen en buen estado (consulta
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **Corregir los permisos del kubeconfig** |
| :---: | :--- |
| Qué hacemos | En el control-plane protege `/etc/kubernetes/admin.conf`, que contiene la credential de cluster-admin: el propietario y el grupo deben ser `root:root`, el modo, `600`. |
| Criterios de aceptación | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` devuelve `root root 600`; el mismo valor está guardado en `/var/work/tests/artifacts/4/admin-conf.txt`. |

<details>
<summary>💡 Pista para la tarea 4</summary>

Un solo comando lo resuelve todo: `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. Compruébalo justo después: si tú mismo usas este archivo como el usuario `ubuntu` mediante `KUBECONFIG=/etc/kubernetes/admin.conf`, el acceso de lectura desaparecerá, y eso es LO ESPERADO: usa un kubeconfig aparte para el trabajo diario.
</details>

---
| **5** | **Prohibir el root login por SSH** |
| :---: | :--- |
| Qué hacemos | En el control-plane establece `PermitRootLogin no` en `/etc/ssh/sshd_config`, comprueba la sintaxis con `sshd -t` y recarga SSH de forma segura. Comprueba el valor efectivo precisamente para una conexión de root con el comando `sshd -T -C "user=root,addr=<tu IP>,laddr=<IP del nodo>,lport=22"`, y no simplemente `sshd -T` sin connection context. |
| Criterios de aceptación | El valor efectivo de `permitrootlogin` para el connection context de root es `no`; `/var/work/tests/artifacts/5/sshd.txt` contiene `PermitRootLogin no`. |

<details>
<summary>💡 Pista para la tarea 5</summary>

`sshd -T` muestra la configuración EFECTIVA, pero SIN connection context (`-C`) los bloques `Match` (`Match User`/`Match Address`/`Match Group` y similares) no se aplican en absoluto: la man-page de `sshd(8)` dice expresamente que las reglas `Match` se aplican en test mode "only when the connection parameters are supplied via one or more `-C` options". Por eso `sshd -T` sin `-C` puede mostrar `permitrootlogin no` del bloque principal de la configuración, aunque un bloque `Match` más específico (por ejemplo, `Match Address <IP del administrador>` o `Match User root`) permita el root login precisamente para la conexión real. Comprueba mediante `sshd -T -C "user=root,addr=<IP>,laddr=<IP del nodo>,lport=22"`: esto simula una conexión root entrante REAL y obliga a `sshd` a aplicar todos los bloques `Match` pertinentes antes de mostrar el valor final. SIEMPRE mantén abierta la sesión SSH actual antes de `systemctl reload sshd` y comprueba desde una sesión nueva, no desde la que ya estaba autenticada antes del cambio.
</details>

---
| **6** | **Cerrar el acceso inseguro al Docker daemon en `docker-host`** |
| :---: | :--- |
| Qué hacemos | • En el `docker-host` aparte, deja de publicar la Docker API por TCP/2375: quita `-H tcp://...` del systemd override de laboratorio, pero conserva el acceso solo mediante el unix-socket.<br/>• Configura `/var/run/docker.sock` como `root:root` con modo `660`; para que persista tras un restart, establécelo mediante un override de `docker.socket`.<br/>• Elimina a `developer` del grupo `docker`.<br/>• Tras los cambios, ejecuta obligatoriamente `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service`: esto demuestra que los ajustes sobreviven al reinicio del daemon, y no que simplemente coincidan temporalmente con el estado esperado.<br/>• Tras el restart, confirma que Docker realmente funciona (`sudo docker version`), y no que simplemente esté detenido. |
| Criterios de aceptación | • **Docker funciona tras el restart:** tras `daemon-reload` + restart, `docker.service` y `docker.socket` están en estado `active`, y `sudo docker version`/`sudo docker info` terminan con éxito (positive control: Docker realmente funciona, no está simplemente "apagado y por eso 2375 está cerrado").<br/>• **No hay TCP API:** en TCP/2375 no hay listener. Tras el restart, la Docker API no tiene ni un solo TCP listener en ningún puerto: el `docker.service` effective no contiene TCP `-H/--host`, y `docker.socket` no contiene TCP `ListenStream`; el único API endpoint es el Unix socket `/var/run/docker.sock`.<br/>• **Socket:** `stat -c '%U %G %a' /var/run/docker.sock` devuelve `root root 660`; el override persistente de `docker.service`/`docker.socket` (mediante `systemctl cat`) no contiene `-H tcp://` y establece `SocketGroup=root`/`SocketMode=0660`.<br/>• **Usuario `developer`:** no pertenece al grupo `docker`, y `sudo -u developer docker ps` termina con un error de acceso.<br/>• **Artefactos:** crea `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` con las líneas `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 Pista para la tarea 6</summary>

La pertenencia al grupo `docker` es de hecho equivalente a root: cualquier proceso con acceso a `docker.sock` puede montar el sistema de archivos del host mediante un container `--privileged`. Para asegurarte de que `developer` ha sido eliminado del grupo, no basta con comprobar `groups developer`: los cambios de pertenencia a un grupo se aplican a las sesiones de login NUEVAS; comprueba precisamente mediante `sudo -u developer docker ps` en un comando nuevo, no en una sesión de `developer` ya abierta. No te detengas en la primera ejecución correcta de la comprobación: ejecuta `daemon-reload` y `restart` de ambas units (`docker.socket`, `docker.service`) y repite las comprobaciones DE NUEVO: sin este paso se puede pasar la tarea por casualidad simplemente deteniendo temporalmente Docker (entonces 2375 está cerrado no porque se haya quitado `-H tcp://`, sino porque el daemon no funciona en absoluto); asegúrate también de que `sudo docker version` funciona tras el restart: esto demuestra que Docker realmente funciona, y no está simplemente "apagado".
</details>

---
| **7** | **Prohibir la carga de un módulo del kernel no utilizado (`modprobe` blacklist)** |
| :---: | :--- |
| Qué hacemos | • En el control-plane el módulo `sctp` está cargado, pero no lo necesitan ni kubeadm, ni containerd, ni Calico en este laboratorio. Intenta descargarlo (`sudo modprobe -r sctp`).<br/>• **La descarga puede no funcionar en un clúster ya activo, y eso no es un error:** los módulos de protocolo del kernel obtienen una referencia persistente por network-namespace para cada netns que existía en el momento de su carga, y en este nodo ya funcionan Pods (calico, coredns, etc.); detenerlos no forma parte de la tarea.<br/>• Prohíbe la recarga mediante `/etc/modprobe.d/60-cks-sctp.conf` con las directivas `blacklist sctp` e `install sctp /bin/true`.<br/>• Limitaciones del threat model: ambas directivas actúan a nivel de `modprobe` (alias resolution y dependency loading); no son una protección absoluta del kernel. `insmod` inserta el módulo directamente mediante una kernel syscall y no lee `modprobe.d`, y `modprobe --ignore-install` puede eludir el override de `install` con el acceso a nivel de host adecuado. Para el propietario root del nodo esto es lo esperado: el objetivo es eliminar el camino de carga habitual (`modprobe sctp`, autocarga por alias al acceder a un protocol), y no protegerse de un usuario que ya tiene root en el nodo.<br/>• Confirma que `modprobe --show-config` muestra el override efectivo y que un `modprobe sctp` directo no cambia el estado del módulo. |
| Criterios de aceptación | • **Archivo:** `/etc/modprobe.d/60-cks-sctp.conf` contiene ambas líneas `blacklist sctp` e `install sctp /bin/true`.<br/>• **Config efectiva:** `modprobe --show-config \| grep sctp` muestra `install sctp /bin/true`.<br/>• **Estado del módulo:** un nuevo `modprobe sctp` directo no cambia el estado del módulo (estaba cargado: sigue cargado; no estaba cargado: sigue sin cargar).<br/>• **Artefacto:** `/var/work/tests/artifacts/7/sctp.txt` contiene la línea `lsmod: absent` O `lsmod: present` (cualquiera de las dos: el estado actual real) y la línea `install sctp /bin/true`. |

<details>
<summary>💡 Pista para la tarea 7</summary>

`blacklist sctp` por sí sola no lo bloquea todo: impide la AUTOCARGA por alias resolution, pero un `modprobe sctp` directo funcionará igualmente sin el override de `install`. Hacen falta ambas líneas: `blacklist` para la autocarga, `install sctp /bin/true` para la llamada explícita a `modprobe sctp` (sustituye el comando de carga por un no-op). Prueba `sudo modprobe -r sctp` para descargar un módulo ya cargado, pero si obtienes `FATAL: Module sctp is in use` con un `/sys/module/sctp/holders` vacío, es lo esperado en un clúster activo (per-netns pinning de los Pods ya en ejecución) y no impide pasar la tarea; la configuración igualmente evita las cargas FUTURAS, que es lo que se comprueba.
</details>

---
| **8** | **`protectKernelDefaults` y sysctl seguros para el kubelet** |
| :---: | :--- |
| Qué hacemos | • En el control-plane ahora `kernel.unprivileged_bpf_disabled = 0`: los procesos sin privilegios pueden cargar programas eBPF, lo que amplía la kernel attack surface. Corrígelo.<br/>• Añade `vm.overcommit_memory = 1` (recomendación típica para la estabilidad de kubelet/containerd bajo memory pressure).<br/>• Establece ambos parámetros mediante `/etc/sysctl.d/99-kubernetes.conf`, luego aplica `sudo sysctl --system`.<br/>• Habilita `protectKernelDefaults: true` en `/var/lib/kubelet/config.yaml` y reinicia el kubelet.<br/>• **El orden importa:** con `true`, el kubelet comprueba al arrancar que los kernel/cgroup parameters actuales coinciden con los defaults esperados y **no arranca** si no coinciden; por eso los sysctl deben aplicarse **antes** de reiniciar el kubelet, y no después. |
| Criterios de aceptación | • **Valores live:** `sysctl kernel.unprivileged_bpf_disabled` devuelve `1`; `sysctl vm.overcommit_memory` devuelve `1`.<br/>• **Configuración persistente:** `/etc/sysctl.d/99-kubernetes.conf` contiene ambos parámetros como líneas activas (`kernel.unprivileged_bpf_disabled = 1`, `vm.overcommit_memory = 1`); un comentario, `= 1 # comment` o un `sysctl -w` temporal no cuentan.<br/>• **kubelet:** la configuración efectiva del kubelet (`/api/v1/nodes/<node>/proxy/configz`) contiene `protectKernelDefaults: true`.<br/>• **Estado tras el reinicio:** `systemctl is-active kubelet` devuelve `active`, y el nodo permanece `Ready`. |

<details>
<summary>💡 Pista para la tarea 8</summary>

El orden aquí es crítico y está subrayado deliberadamente en la descripción de la tarea: primero `sysctl --system` (aplicar los valores), SOLO DESPUÉS habilitar `protectKernelDefaults: true` y reiniciar el kubelet. Si se hace en el orden inverso, el kubelet al arrancar detectará una discrepancia entre los kernel parameters y sus expectativas y se negará a arrancar: el nodo permanecerá NotReady, y no podrás entender la causa sin leer los logs del kubelet (`journalctl -u kubelet`). La comprobación se guía por la configuración REALMENTE EN VIGOR del kubelet mediante `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"`, y no por el texto de `config.yaml`: si la línea del archivo está comentada o contiene una errata, `grep` aun así podría encontrarla, aunque el kubelet siga funcionando con el valor antiguo por defecto. Tras editar el archivo, reinicia obligatoriamente el kubelet y comprueba precisamente mediante `configz`.
</details>

---
| **9** | **Encontrar y neutralizar un binario SUID innecesario** |
| :---: | :--- |
| Qué hacemos | • En el control-plane ejecuta `find / -xdev -perm -4000 -type f 2>/dev/null` y encuentra entre los resultados `/usr/local/bin/cks-lab105-suid-tool`: un binario de laboratorio, creado específicamente con el bit SUID y que no es necesario para ningún componente de Kubernetes en este nodo.<br/>• Guarda la lista completa de archivos SUID encontrados **antes** de la corrección en `/var/work/tests/artifacts/9/suid-before.txt`.<br/>• Quita al binario el bit SUID (`chmod u-s`).<br/>• Guarda el modo de `cks-lab105-suid-tool` **después** de la corrección en `/var/work/tests/artifacts/9/suid-after.txt`.<br/>• No toques los binarios SUID del sistema (`passwd`, `sudo`, `mount` y similares): eliminarlos rompe el funcionamiento normal del SO y no entra en el alcance de la tarea. |
| Criterios de aceptación | • **Antes de la corrección:** `suid-before.txt` contiene la ruta `/usr/local/bin/cks-lab105-suid-tool` entre los archivos SUID encontrados.<br/>• **Tras la corrección:** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` devuelve `755` (sin el bit SUID `4`); `suid-after.txt` contiene `755`.<br/>• **Binarios del sistema:** los binarios SUID estándar (por ejemplo, `/usr/bin/sudo` o `/usr/bin/passwd`) permanecen con el bit SUID, intactos. |

<details>
<summary>💡 Pista para la tarea 9</summary>

`chmod u-s` quita precisamente el bit SUID, sin tocar el resto de los permisos (a diferencia de `chmod 755`, que además sobrescribirá todos los demás bits de permisos; en este caso el resultado coincide, pero `u-s` es más seguro como hábito general). No ejecutes `find / -perm -4000` sin `-xdev` salvo necesidad extrema: sin él el comando escaneará los sistemas de archivos de red/virtuales montados y puede tardar muchísimo o colgarse. La comprobación compara el conjunto actual de binarios SUID del sistema con el baseline registrado ANTES del inicio del laboratorio: está prohibido tocar cualquier otro binario SUID del sistema (no solo `sudo`/`passwd`), y simplemente devolver el SUID a `sudo` no ayudará si accidentalmente (o a propósito) se lo quitaste a otra cosa. Las rutas dentro de `/var/lib/containerd` (capas de container image mediante overlayfs) no se tienen en cuenta ni en el baseline ni en la comprobación: no son archivos del host, y su conjunto cambia de forma natural con el pull/extract de imágenes, con independencia de ti.
</details>

---
| **10** | **Desactivar los core dumps y proteger los procesos SUID frente a la captura de un volcado de memoria** |
| :---: | :--- |
| Qué hacemos | • Un core dump de un proceso puede contener secrets descifrados, claves privadas y tokens que estaban en memoria en el momento del crash.<br/>• En el control-plane añade a `/etc/security/limits.conf` las líneas `* hard core 0` y `* soft core 0` (limitación del tamaño del core dump).<br/>• Prohíbe el dump para procesos SUID/privileged: `fs.suid_dumpable = 0` en `/etc/sysctl.d/99-kubernetes.conf` (el mismo archivo que en la tarea 8; no crees un archivo aparte que entre en conflicto).<br/>• **En Ubuntu esto no basta:** el crash dump por defecto no se pasa directamente a un archivo, sino a través de `kernel.core_pattern`, que apunta a un userspace pipe handler (Apport). Apport intercepta el crash en `/var/lib/apport/coredump/` con independencia de `ulimit -c`, porque el kernel ignora `RLIMIT_CORE` precisamente para los pipe-handlers (consulta `man 5 core`: "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program").<br/>• Por eso, establece además `kernel.core_pattern = \|/bin/false` en el mismo `/etc/sysctl.d/99-kubernetes.conf`: esto sustituye el pipe-handler por uno deliberadamente inoperante, y el kernel no crea dump ni en un archivo ni mediante Apport. Aplica `sudo sysctl --system`.<br/>• Confirma: `sysctl fs.suid_dumpable` devuelve `0`, y `cat /proc/sys/kernel/core_pattern` devuelve `\|/bin/false`.<br/>• Confirma: un login-shell nuevo (`bash -l` o `sudo su - ubuntu -c 'ulimit -c'`, precisamente con `sudo`; un `su` normal sobre uno mismo igualmente pide contraseña) muestra `ulimit -c` igual a `0`.<br/>• Confirma: tras un crash real de un proceso de prueba (`SIGSEGV`) no aparece ningún core dump nuevo ni en `/var/lib/apport/coredump/` ni en ningún otro sitio. |
| Criterios de aceptación | • **Valores live:** `sysctl -n fs.suid_dumpable` devuelve `0`; `cat /proc/sys/kernel/core_pattern` devuelve `\|/bin/false`.<br/>• **sysctl persistente:** `/etc/sysctl.d/99-kubernetes.conf` contiene las líneas activas (no comentadas) `fs.suid_dumpable = 0` y `kernel.core_pattern = \|/bin/false`.<br/>• **Límites:** `/etc/security/limits.conf` contiene ambas líneas `* hard core 0` y `* soft core 0`; un login-shell nuevo muestra `ulimit -c` igual a `0`.<br/>• **Crash probe:** un controlled crash de un proceso de prueba no crea un nuevo core dump retenido.<br/>• **Artefacto:** `/var/work/tests/artifacts/10/coredump.txt` contiene todas las confirmaciones, incluido el resultado del controlled crash probe. |

<details>
<summary>💡 Pista para la tarea 10</summary>

`ulimit -c` en TU sesión SSH actual no cambiará tras editar `limits.conf`: los límites de PAM se aplican solo al crear una sesión/login-shell NUEVA. Comprueba mediante `sudo su - ubuntu -c 'ulimit -c'` (login nuevo; `sudo` es obligatorio: `su` incluso sobre uno mismo siempre pide contraseña, si no se invoca desde root) o abre una nueva sesión SSH, y no compruebes `ulimit -c` en la misma shell donde editaste el archivo. Ambos valores son necesarios: `hard` es el techo absoluto, `soft` es el valor efectivo por defecto; si se establece solo `soft`, el proceso puede subir por sí mismo el límite hasta `hard`. La trampa clave de la tarea: `ulimit -c 0` y `fs.suid_dumpable=0` **no desactivan** el core dump en Ubuntu por sí solos: `man 5 core` dice directamente que el kernel ignora `RLIMIT_CORE` si `kernel.core_pattern` apunta a un pipe-handler (`|program`), y Ubuntu por defecto dirige el crash precisamente a un handler así (Apport), que intercepta el dump con independencia de `ulimit`. La única forma fiable es redefinir el propio `kernel.core_pattern` (por ejemplo, a `|/bin/false`), y no solo los límites del proceso.
</details>

## Adicionalmente: kernel y containerd/CRI hardening

Es una breve práctica node-local más allá de las tareas 7–9, que no entra en los criterios automáticos del
fixture. Muestra un contexto CRI más amplio, no limitado a un módulo concreto del kernel.

En este laboratorio Kubernetes usa **containerd**, y no Docker. Por eso los mismos principios
hay que aplicarlos al CRI: comprueba los permisos de `/run/containerd/containerd.sock` y
`/etc/containerd/config.toml`, no añadas usuarios normales al grupo que da acceso
al socket y permite `ctr`/`crictl` con este endpoint solo a administradores
privilegiados. No cambies a ciegas el propietario ni el modo del CRI-socket en funcionamiento: una
configuración errónea detendrá el kubelet y los workloads.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# se espera una denegación de acceso para un usuario sin privilegios
```

## Comprobación

En el `worker` ejecuta:

```bash
check_result
```

La comprobación contiene `0 Init` y diez tests independientes. Comprueba el estado de ambos
hosts por SSH y los artefactos obligatorios. Tras editar `sshd_config` o una systemd unit,
espera a que termine `systemctl reload/restart` antes de volver a lanzar la comprobación.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=105 make delete_cks_task
```
