# Лаба 105 - эталонное решение: System Hardening ОС и Docker

> Как работать: один раз заходим на ноду по `ssh` и выполняем команды прямо на ней (под
> `sudo -i`, чтобы не писать `sudo` перед каждой командой) - это быстрее, чем отправлять
> каждую команду отдельным `ssh`, и именно так стоит работать на экзамене. Имя
> control-plane ноды смотрим через `kubectl get no`:
>
> ```bash
> kubectl get no
> ssh <имя-ноды-из-вывода>
> sudo -i
> ```
>
> Проверки и артефакты: checker читает артефакты с **рабочей машины** (`worker`), в
> `/var/work/tests/artifacts/<номер>/`, поэтому после правок на ноде выходим (`exit`, `exit`) и
> сохраняем артефакт короткой командой с `worker`. Для неё один раз задайте имя ноды:
>
> ```bash
> CP=<имя-ноды-из-вывода>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Артефакты нужны только для проверки лабы: на экзамене их нет, там достаточно команд на
> ноде и беглой проверки результата. Команды сохраняют вывод в файл (`>`), содержимое смотрим
> отдельно через `cat <файл>` - ожидаемый результат указан в комментариях `# ...` под блоком.
>
> Для Docker-хоста заходим так же: `ssh docker-host`, затем `sudo -i`.

## 1. Отключить ненужный systemd-сервис

Сервис `cks-lab105-unused.service` не нужен для Kubernetes и увеличивает поверхность
атаки. Остановим его и запретим автозапуск.

На control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Артефакт (на `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. Закрыть ненужный TCP/8080

Порт 8080 открыт намеренно сервисом `cks-lab105-port.service`; он не нужен ни
control-plane, ни kubelet. Останавливаем и отключаем сервис - оба действия обязательны,
иначе listener вернётся после reboot, даже если сейчас порт закрыт.

На control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # пустой вывод - порт закрыт
exit
exit
```

Артефакты (на `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# порт уже проверен на ноде (`ss -ltn | grep 8080` - пусто), фиксируем результат:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. Ограничить входящий трафик UFW

Сначала определяем топологию и необходимые источники. Это одноузловой control-plane,
который также запускает workload. Worker должен иметь SSH и API access; Pod CIDR и сам
узел - API access. Межнодовых kubelet/CNI flows здесь нет. Не открываем `22`/`6443` для
`Anywhere`.

На `worker` смотрим нужные значения глазами:

```bash
kubectl get no -o wide                                      # INTERNAL-IP ноды
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # IP worker
```

Записываем их в preflight (подставьте свои значения; строка `role=` обязательна):

```bash
WORKER_IP=<ip-worker>; NODE_IP=<internal-ip-ноды>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

Baseline ДО UFW: проверяем, что TCP/10250 (kubelet HTTPS) реально достижим сейчас - без
этого "заблокировано" после UFW ничего не доказывает, порт мог быть недоступен по другой
причине (security group, routing). Checker отдельно сверяется со своим baseline, но и ваша
запись нужна:

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - порт достижим (любой 1xx-5xx, включая 401/403, подходит)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

Если baseline недостижим (curl вернул `000`) - сначала исправьте связность, иначе результат
после UFW будет неубедительным.

Правила UFW настраиваем на ноде. Сначала разрешаем recovery и нужные источники, и только
потом меняем default. Значения `WORKER_IP`/`NODE_IP`/`POD_CIDR` берём из `preflight.txt`
(подставьте свои):

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

Артефакты (на `worker`). `ufw show added` - нормализованное представление правил, которые
вы реально добавили (НЕ гарантированно исходный вид/порядок команд - UFW нормализует их при
отображении). Проверка сравнивает именно этот список с ожидаемым allowlist - сохраните его
тоже, это самая надёжная evidence exact allow-set. Управляйте firewall только через `ufw` -
НЕ редактируйте `/etc/ufw/before*.rules` или `/etc/ufw/after*.rules` вручную, это
framework-файлы с общими default-правилами, а не место для source-scoped rules; checker
сверяет их хэш с checker-owned bootstrap-baseline и заметит прямое редактирование.

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# Выполнять из ещё открытой SSH/console session при потере API:
sudo ufw disable
sudo ufw status verbose
# исправить узкие allow rules, проверить source IP/CIDR
sudo ufw --force enable
# Если правила повреждены полностью, только через console/recovery channel:
sudo ufw --force reset
EOF
```

Проверяем, что кластер здоровый (с `worker`):

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# Workload внутри кластера должен по-прежнему резолвить DNS и достигать API server
# (UFW не должен ломать трафик Pod -> CoreDNS и Pod -> API):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # должен вернуть Address сервиса kubernetes
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # любой код, кроме 000

# Нежелательный worker -> kubelet flow не должен дать HTTP response.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - транспортный deny
```

Обязательный полный E2E retest ПОСЛЕ `ufw reload` - доказывает, что ruleset переживает
reload, а не только работает в памяти сразу после `ufw enable`. Без этого шага можно
случайно получить ложное PASS сразу после enable:

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# Те же две проверки workload повторяем после reload:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# Тот же контракт, что и до reload: worker по-прежнему не достигает kubelet.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

Проверка declared vs effective: `ufw show added` - декларативный список, реконструированный
из `### tuple ###` метаданных, которые ufw сам пишет в `user.rules` при добавлении правила
через CLI. Реальное же состояние ядра после `ufw reload` - то, что показывает
`ufw show user-rules`. Сравнивайте не только КОЛИЧЕСТВО строк, но и их СОДЕРЖИМОЕ
(source/port/proto): `ufw-user-input` должен показывать loopback (all, lo) и три tcp
dpt:22/6443 правила с точными source-адресами, а `ufw6-user-input` - РОВНО одну строку, тот
же loopback ACCEPT для v6 (`ufw allow in on lo` - правило по интерфейсу без явного IP,
поэтому ufw всегда создаёт и v4-, и v6-версию). Любая ДРУГАЯ/дополнительная строка там -
посторонний bypass:

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

В выводе должны быть `Status: active`, `Default: deny (incoming)` и source-scoped rules -
как в `ufw status verbose`, так и в декларативном списке `ufw show added`. Не закрывайте
исходную SSH session, пока `/readyz`, nodes, calico-node, workload (включая Pod DNS до и
после reload) и обе отрицательные проверки `10250` (до и после `ufw reload`, с тем же
CURL_EXIT/HTTPCODE контрактом) не дали ожидаемый результат.

## 4. Защитить kubeconfig администратора

`/etc/kubernetes/admin.conf` содержит cluster-admin credential. Его может читать
только root.

На control-plane:

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Артефакт (на `worker`):

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. Запретить прямой root login по SSH

Изменяем конфигурацию, проверяем синтаксис до reload и применяем без разрыва текущей
сессии.

На control-plane:

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

Текущая сессия при `reload ssh` не рвётся. Но на время перезапуска sshd новое
подключение на control-plane может на 1-2 секунды получить `Connection refused` - это
нормально и не означает, что конфигурация сломана (её уже проверил `sshd -t`), просто
повторите команду.

`sshd -T` без connection context не применяет `Match`-блоки вообще - man `sshd(8)`
прямо говорит, что `Match` в test mode применяется только когда передан `-C`. Поэтому
проверяем через `-C`, симулируя реальное root-соединение с worker (адреса берём из
`preflight.txt` задания 3):

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Артефакт (на `worker`, после паузы в пару секунд):

```bash
# WORKER_IP и NODE_IP - те же значения, что в задании 3
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Закрыть небезопасный доступ к Docker daemon на `docker-host`

TCP/2375 не имеет TLS и аутентификации: доступ к нему практически равен root-доступу к
хосту. Удаляем учебный systemd override с TCP listener, задаём владельца unix-сокета
через socket override и удаляем `developer` из группы `docker`.

Применяем изменения через полный `daemon-reload` + restart **обоих** unit-ов - это
обязательный шаг, а не просто "перечитать конфиг": без реального restart можно случайно
"пройти" проверку, если Docker просто перестал отвечать (тогда TCP/2375 закрыт не потому,
что убран `-H tcp://`, а потому что демон вообще не работает).

На `docker-host`:

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

Positive control: Docker после restart реально РАБОТАЕТ (не просто не слушает 2375 - он
должен полноценно функционировать через unix-сокет):

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

Persistent config check - effective unit не содержит `-H tcp://`, а socket override реально
задаёт нужные значения (а не просто временно совпадает с ними):

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

Контракт задания шире, чем порт 2375: Docker API не должен слушать TCP ни на одном порту, а
`docker.socket` не должен содержать TCP `ListenStream`:

```bash
ss -ltnp | grep -E 'dockerd|docker\.socket'    # пустой вывод
systemctl cat docker.socket | grep ListenStream # только /run/docker.sock (и пустой сброс)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Артефакты (на `worker`):

```bash
# порт 2375 уже проверен на docker-host (`ss -ltnp | grep dockerd` - пусто), фиксируем результат:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

После выполнения всех шагов запустите `check_result`.

## 7. Запретить загрузку модуля `sctp`

`sctp` загружен, но не нужен ни kubeadm, ни containerd, ни Calico на этой ноде. Пробуем
выгрузить уже загруженный модуль, затем в любом случае блокируем повторную загрузку и
через `blacklist`, и через `install` override. Обе директивы действуют на уровне
`modprobe` (alias resolution и явный `modprobe sctp`) и устраняют обычный путь загрузки;
они не заменяют kernel-level enforcement (`insmod` вставляет модуль напрямую через syscall
и не читает `modprobe.d`, а `modprobe --ignore-install` может обойти `install` при равном
root-доступе) - для этой лабы важно устранить именно ожидаемый путь автозагрузки, а не
смоделировать защиту от пользователя, уже имеющего root на ноде.

**`modprobe -r sctp` может не отработать на уже живом кластере** - это ожидаемо и не
является ошибкой студента. Протокольные модули ядра (в т.ч. `sctp`) получают persistent
per-network-namespace ссылку (`try_module_get` в pernet-инициализации) для каждого netns,
который уже существовал в момент загрузки модуля - на этой ноде уже работают Pod'ы
(calico, coredns, kube-system), поэтому `sctp` может остаться в состоянии `in use` с
ненулевым refcount и ПУСТЫМ `/sys/module/sctp/holders` (то есть держит не другой модуль -
рекурсивно выгрузить нечего). Это нельзя исправить без остановки всех этих Pod'ов, что не
входит в задание. Важно и проверяется именно то, что находится под контролем студента:
модуль не может быть загружен ЗАНОВО.

На control-plane:

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # может быть как пусто, так и непусто - оба варианта допустимы
modprobe --show-config | grep sctp      # install sctp /bin/true и blacklist sctp
exit
exit
```

Артефакт (на `worker`): текущее состояние (`absent` или `present`) и override в effective
modprobe config:

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (или lsmod: present - оба варианта допустимы, см. выше)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` и безопасные sysctl

Сначала исправляем sysctl - `protectKernelDefaults: true` заставит kubelet **упасть при
старте**, если текущие значения ядра не совпадают с его ожиданиями, поэтому sysctl
обязаны быть применены раньше, чем перезапуск kubelet.

На control-plane:

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

Теперь включаем `protectKernelDefaults` в конфигурации kubelet и перезапускаем сервис:

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

Нода должна остаться `Ready` (с `worker`):

```bash
kubectl get no
```

Если kubelet не поднимается после этого шага - проверьте именно порядок: sysctl должны
быть применены (`sysctl --system`), а не только записаны в файл, прежде чем kubelet
проверит их при старте.

## 9. Найти и обезвредить лишний SUID-бинарник

`find` покажет и системные SUID-бинарники (`sudo`, `passwd`, `mount` - их не трогаем), и
учебный `/usr/local/bin/cks-lab105-suid-tool`, который не требуется ни одному компоненту
Kubernetes на этой ноде.

`/var/lib/containerd` исключён из вывода: его overlayfs snapshot-пути - это содержимое
слоёв container image, а не установленные на хосте бинарники, и они меняются при любом
pull/extract образа во время лабы, независимо от действий студента.

Артефакт `suid-before.txt` нужно сохранить **до** исправления (на `worker`):

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

Снимаем SUID-бит только с учебного файла (на control-plane) и убеждаемся, что системные
SUID-бинарники не задеты - `sudo`/`passwd` обязаны остаться с SUID-битом, иначе базовая
функциональность ОС ломается:

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Артефакт `suid-after.txt` (на `worker`):

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

После выполнения всех шагов запустите `check_result`.

## 10. Отключить core dumps и защитить SUID-процессы

Core dump может содержать секреты и ключи из памяти процесса на момент crash - его нужно
запретить как для обычных, так и для SUID-процессов. `fs.suid_dumpable` добавляем в тот же
файл `/etc/sysctl.d/99-kubernetes.conf`, что уже создан в задании 8 - не создаём отдельный
конфликтующий конфиг.

На Ubuntu `ulimit -c 0` и `fs.suid_dumpable=0` **не гарантируют** отсутствие core dump:
`man 5 core` прямо документирует, что `RLIMIT_CORE` игнорируется ядром, если
`kernel.core_pattern` направляет dump в userspace-обработчик через pipe (`|program`).
Ubuntu по умолчанию именно так настроен - crash перехватывает Apport и сохраняет его в
`/var/lib/apport/coredump/` НЕЗАВИСИМО от `ulimit -c` процесса. Единственный надёжный
способ - переопределить сам `kernel.core_pattern` на заведомо неработающий handler.

Ограничиваем также размер core dump на уровне лимитов процессов - это отдельный механизм от
`suid_dumpable`/`core_pattern` (soft limit для обычных crash при классической
file-based записи, если она когда-либо будет восстановлена).

На control-plane:

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` применяется к новым login-сессиям через PAM, а не к уже открытым shell -
проверяем именно в новой сессии:

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Артефакт `coredump.txt` (на `worker`). Включает controlled crash probe: подтверждаем, что
после реального `SIGSEGV` не появляется НОВЫЙ retained core dump - ни в стандартном
текущем каталоге, ни через Apport:

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

После выполнения всех шагов запустите `check_result`.
