[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - solución de referencia: System Hardening del SO y Docker

> Cómo trabajar: entramos una sola vez en el nodo por `ssh` y ejecutamos los comandos directamente en él (bajo
> `sudo -i`, para no escribir `sudo` antes de cada comando): es más rápido que enviar
> cada comando con un `ssh` aparte, y así es como conviene trabajar en el examen. El nombre del
> nodo control-plane lo vemos con `kubectl get no`:
>
> ```bash
> kubectl get no
> ssh <nombre-del-nodo-de-la-salida>
> sudo -i
> ```
>
> Comprobaciones y artefactos: el checker lee los artefactos de la **máquina de trabajo** (`worker`), en
> `/var/work/tests/artifacts/<número>/`, por eso tras los cambios en el nodo salimos (`exit`, `exit`) y
> guardamos el artefacto con un comando corto desde el `worker`. Para ello define una vez el nombre del nodo:
>
> ```bash
> CP=<nombre-del-nodo-de-la-salida>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Los artefactos solo son necesarios para la comprobación del laboratorio: en el examen no existen, allí bastan los comandos en el
> nodo y una comprobación rápida del resultado. Los comandos guardan la salida en un archivo (`>`), el contenido lo vemos
> aparte con `cat <archivo>`: el resultado esperado se indica en los comentarios `# ...` bajo el bloque.
>
> Para el Docker-host entramos igual: `ssh docker-host`, luego `sudo -i`.

## 1. Desactivar un servicio systemd innecesario

El servicio `cks-lab105-unused.service` no es necesario para Kubernetes y aumenta la superficie de
ataque. Lo detendremos y prohibiremos su arranque automático.

En el control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Artefacto (en el `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. Cerrar el TCP/8080 innecesario

El puerto 8080 lo abre deliberadamente el servicio `cks-lab105-port.service`; no lo necesita ni el
control-plane ni el kubelet. Detenemos y desactivamos el servicio: ambas acciones son obligatorias,
de lo contrario el listener volverá tras un reboot, aunque ahora el puerto esté cerrado.

En el control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # salida vacía: el puerto está cerrado
exit
exit
```

Artefactos (en el `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# el puerto ya se comprobó en el nodo (`ss -ltn | grep 8080` - vacío), registramos el resultado:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. Limitar el tráfico entrante con UFW

Primero determinamos la topología y los orígenes necesarios. Es un control-plane de un solo nodo,
que también ejecuta workload. El worker debe tener acceso SSH y API; el Pod CIDR y el propio
nodo, acceso API. Aquí no hay flows kubelet/CNI entre nodos. No abrimos `22`/`6443` a
`Anywhere`.

En el `worker` miramos los valores necesarios a simple vista:

```bash
kubectl get no -o wide                                      # INTERNAL-IP del nodo
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # IP del worker
```

Los anotamos en el preflight (sustituye por tus valores; la línea `role=` es obligatoria):

```bash
WORKER_IP=<ip-worker>; NODE_IP=<internal-ip-del-nodo>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

Baseline ANTES de UFW: comprobamos que TCP/10250 (kubelet HTTPS) es realmente alcanzable ahora; sin
esto, el "bloqueado" tras UFW no demuestra nada: el puerto podía no estar disponible por otra
razón (security group, routing). El checker se contrasta aparte con su propio baseline, pero tu
registro también hace falta:

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - el puerto es alcanzable (sirve cualquier 1xx-5xx, incluidos 401/403)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

Si el baseline no es alcanzable (curl devolvió `000`), primero corrige la conectividad; de lo contrario, el resultado
tras UFW no será convincente.

Las reglas de UFW las configuramos en el nodo. Primero permitimos el recovery y los orígenes necesarios, y solo
después cambiamos el default. Los valores `WORKER_IP`/`NODE_IP`/`POD_CIDR` los tomamos de `preflight.txt`
(sustituye por los tuyos):

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

Artefactos (en el `worker`). `ufw show added` es la representación normalizada de las reglas que
realmente añadiste (NO está garantizada la forma/orden original de los comandos: UFW los normaliza al
mostrarlos). La comprobación compara precisamente esta lista con el allowlist esperado: guárdala
también, es la evidence más fiable del exact allow-set. Gestiona el firewall solo mediante `ufw`:
NO edites `/etc/ufw/before*.rules` ni `/etc/ufw/after*.rules` a mano, son
framework-files con las default-reglas comunes, y no un lugar para source-scoped rules; el checker
contrasta su hash con el bootstrap-baseline propiedad del checker y detectará la edición directa.

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# Ejecutar desde una SSH/console session todavía abierta si se pierde la API:
sudo ufw disable
sudo ufw status verbose
# corregir las allow rules estrechas, comprobar source IP/CIDR
sudo ufw --force enable
# Si las reglas están dañadas por completo, solo mediante la console/recovery channel:
sudo ufw --force reset
EOF
```

Comprobamos que el clúster está sano (desde el `worker`):

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# El workload dentro del clúster debe seguir resolviendo DNS y alcanzando el API server
# (UFW no debe romper el tráfico Pod -> CoreDNS ni Pod -> API):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # debe devolver el Address del servicio kubernetes
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # cualquier código, salvo 000

# El flow no deseado worker -> kubelet no debe dar una HTTP response.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - transport deny
```

Retest E2E completo obligatorio DESPUÉS de `ufw reload`: demuestra que el ruleset sobrevive al
reload, y no solo funciona en memoria justo después de `ufw enable`. Sin este paso se puede
obtener por casualidad un falso PASS justo tras enable:

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# Repetimos las mismas dos comprobaciones del workload tras el reload:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# El mismo contrato que antes del reload: el worker sigue sin alcanzar el kubelet.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

Comprobación declared vs effective: `ufw show added` es la lista declarativa, reconstruida
a partir de los metadatos `### tuple ###`, que el propio ufw escribe en `user.rules` al añadir una regla
mediante la CLI. El estado real del kernel tras `ufw reload` es lo que muestra
`ufw show user-rules`. Compara no solo la CANTIDAD de líneas, sino también su CONTENIDO
(source/port/proto): `ufw-user-input` debe mostrar el loopback (all, lo) y tres reglas tcp
dpt:22/6443 con las source-direcciones exactas, y `ufw6-user-input` - EXACTAMENTE una línea, el mismo
loopback ACCEPT para v6 (`ufw allow in on lo` es una regla por interfaz sin una IP explícita,
por eso ufw siempre crea tanto la versión v4 como la v6). Cualquier OTRA línea/adicional allí es
un bypass ajeno:

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

En la salida deben estar `Status: active`, `Default: deny (incoming)` y las source-scoped rules,
tanto en `ufw status verbose` como en la lista declarativa `ufw show added`. No cierres
la SSH session original hasta que `/readyz`, nodes, calico-node, el workload (incluido el Pod DNS antes y
después del reload) y ambas comprobaciones negativas de `10250` (antes y después de `ufw reload`, con el mismo
contrato CURL_EXIT/HTTPCODE) hayan dado el resultado esperado.

## 4. Proteger el kubeconfig del administrador

`/etc/kubernetes/admin.conf` contiene la credential de cluster-admin. Solo root
puede leerlo.

En el control-plane:

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Artefacto (en el `worker`):

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. Prohibir el root login directo por SSH

Cambiamos la configuración, comprobamos la sintaxis antes del reload y aplicamos sin cortar la sesión
actual.

En el control-plane:

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

La sesión actual no se corta con `reload ssh`. Pero durante el reinicio de sshd una nueva
conexión al control-plane puede recibir `Connection refused` durante 1-2 segundos: es
normal y no significa que la configuración esté rota (ya la comprobó `sshd -t`), simplemente
repite el comando.

`sshd -T` sin connection context no aplica los bloques `Match` en absoluto: el man de `sshd(8)`
dice directamente que `Match` en test mode se aplica solo cuando se pasa `-C`. Por eso
comprobamos mediante `-C`, simulando una conexión root real desde el worker (las direcciones las tomamos de
`preflight.txt` de la tarea 3):

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Artefacto (en el `worker`, tras una pausa de un par de segundos):

```bash
# WORKER_IP y NODE_IP - los mismos valores que en la tarea 3
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Cerrar el acceso inseguro al Docker daemon en `docker-host`

TCP/2375 no tiene TLS ni autenticación: el acceso a él es prácticamente igual a un acceso root al
host. Eliminamos el systemd override de laboratorio con el TCP listener, establecemos el propietario del unix-socket
mediante un socket override y eliminamos a `developer` del grupo `docker`.

Aplicamos los cambios mediante un `daemon-reload` completo + restart de **ambas** unit; es un
paso obligatorio, y no simplemente "releer la configuración": sin un restart real se puede por casualidad
"pasar" la comprobación si Docker simplemente dejó de responder (entonces TCP/2375 está cerrado no porque
se haya quitado `-H tcp://`, sino porque el daemon no funciona en absoluto).

En el `docker-host`:

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control: Docker tras el restart realmente FUNCIONA (no solo no escucha en 2375: debe
funcionar plenamente a través del unix-socket):

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

Persistent config check: la unit effective no contiene `-H tcp://`, y el socket override realmente
establece los valores necesarios (y no solo coincide temporalmente con ellos):

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

El contrato de la tarea es más amplio que el puerto 2375: la Docker API no debe escuchar TCP en ningún puerto, y
`docker.socket` no debe contener TCP `ListenStream`:

```bash
ss -ltnp | grep -E 'dockerd|docker\.socket'    # salida vacía
systemctl cat docker.socket | grep ListenStream # solo /run/docker.sock (y un reset vacío)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Artefactos (en el `worker`):

```bash
# el puerto 2375 ya se comprobó en docker-host (`ss -ltnp | grep dockerd` - vacío), registramos el resultado:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

Tras completar todos los pasos, ejecuta `check_result`.

## 7. Prohibir la carga del módulo `sctp`

`sctp` está cargado, pero no lo necesitan ni kubeadm, ni containerd, ni Calico en este nodo. Intentamos
descargar el módulo ya cargado y, en cualquier caso, bloqueamos la recarga tanto
mediante `blacklist` como mediante un override de `install`. Ambas directivas actúan a nivel de
`modprobe` (alias resolution y un `modprobe sctp` explícito) y eliminan el camino de carga habitual;
no sustituyen un kernel-level enforcement (`insmod` inserta el módulo directamente mediante syscall
y no lee `modprobe.d`, y `modprobe --ignore-install` puede eludir `install` con igual
acceso root): para este laboratorio lo importante es eliminar precisamente el camino esperado de autocarga, y no
modelar una protección frente a un usuario que ya tiene root en el nodo.

**`modprobe -r sctp` puede no funcionar en un clúster ya activo**: es lo esperado y no
es un error del estudiante. Los módulos de protocolo del kernel (incluido `sctp`) obtienen una referencia persistente
por network-namespace (`try_module_get` en la inicialización pernet) para cada netns
que ya existía en el momento de cargar el módulo; en este nodo ya funcionan Pods
(calico, coredns, kube-system), por lo que `sctp` puede quedar en estado `in use` con un
refcount distinto de cero y un `/sys/module/sctp/holders` VACÍO (es decir, no lo mantiene otro módulo:
no hay nada que descargar recursivamente). Esto no se puede corregir sin detener todos esos Pods, lo que no
entra en la tarea. Lo importante, y lo que se comprueba, es lo que está bajo el control del estudiante:
que el módulo no pueda cargarse DE NUEVO.

En el control-plane:

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # puede estar vacío o no: ambas variantes son válidas
modprobe --show-config | grep sctp      # install sctp /bin/true y blacklist sctp
exit
exit
```

Artefacto (en el `worker`): el estado actual (`absent` o `present`) y el override en la configuración
efectiva de modprobe:

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (o lsmod: present - ambas variantes son válidas, ver arriba)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` y sysctl seguros

Primero corregimos sysctl: `protectKernelDefaults: true` hará que el kubelet **falle al
arrancar** si los valores actuales del kernel no coinciden con sus expectativas, por eso los sysctl
deben aplicarse antes de reiniciar el kubelet.

En el control-plane:

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

Ahora habilitamos `protectKernelDefaults` en la configuración del kubelet y reiniciamos el servicio:

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

El nodo debe permanecer `Ready` (desde el `worker`):

```bash
kubectl get no
```

Si el kubelet no arranca tras este paso, comprueba precisamente el orden: los sysctl deben
estar aplicados (`sysctl --system`), y no solo escritos en el archivo, antes de que el kubelet
los compruebe al arrancar.

## 9. Encontrar y neutralizar un binario SUID innecesario

`find` mostrará tanto los binarios SUID del sistema (`sudo`, `passwd`, `mount`: no los tocamos) como
el `/usr/local/bin/cks-lab105-suid-tool` de laboratorio, que no necesita ningún componente de
Kubernetes en este nodo.

`/var/lib/containerd` se excluye de la salida: sus rutas de snapshot de overlayfs son el contenido de
las capas de container image, y no binarios instalados en el host, y cambian con cualquier
pull/extract de una imagen durante el laboratorio, con independencia de las acciones del estudiante.

El artefacto `suid-before.txt` hay que guardarlo **antes** de la corrección (en el `worker`):

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

Quitamos el bit SUID solo al archivo de laboratorio (en el control-plane) y nos aseguramos de que los
binarios SUID del sistema no se han tocado: `sudo`/`passwd` deben conservar el bit SUID, de lo contrario la funcionalidad
básica del SO se rompe:

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Artefacto `suid-after.txt` (en el `worker`):

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

Tras completar todos los pasos, ejecuta `check_result`.

## 10. Desactivar los core dumps y proteger los procesos SUID

Un core dump puede contener secrets y claves de la memoria del proceso en el momento del crash: hay que
prohibirlo tanto para procesos normales como para procesos SUID. `fs.suid_dumpable` lo añadimos al mismo
archivo `/etc/sysctl.d/99-kubernetes.conf` que ya se creó en la tarea 8: no creamos una configuración
aparte que entre en conflicto.

En Ubuntu `ulimit -c 0` y `fs.suid_dumpable=0` **no garantizan** la ausencia de core dump:
`man 5 core` documenta directamente que el kernel ignora `RLIMIT_CORE` si
`kernel.core_pattern` dirige el dump a un handler de userspace mediante pipe (`|program`).
Ubuntu está configurado así por defecto: el crash lo intercepta Apport y lo guarda en
`/var/lib/apport/coredump/` CON INDEPENDENCIA de `ulimit -c` del proceso. La única forma fiable
es redefinir el propio `kernel.core_pattern` hacia un handler deliberadamente inoperante.

Limitamos también el tamaño del core dump a nivel de límites de procesos: es un mecanismo aparte de
`suid_dumpable`/`core_pattern` (soft limit para crashes normales con la escritura clásica
basada en archivo, si alguna vez se restablece).

En el control-plane:

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` se aplica a las nuevas login-sesiones mediante PAM, y no a las shell ya abiertas:
comprobamos precisamente en una sesión nueva:

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Artefacto `coredump.txt` (en el `worker`). Incluye un controlled crash probe: confirmamos que
tras un `SIGSEGV` real no aparece NINGÚN core dump retenido NUEVO, ni en el directorio actual
estándar ni mediante Apport:

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

Tras completar todos los pasos, ejecuta `check_result`.
