# Лаба 105 - эталонное решение: System Hardening ОС и Docker

> Команды выполняются на рабочей машине. Получите имя control-plane один раз:
>
> ```bash
> export KUBECONFIG=/home/ubuntu/.kube/config
> CTX=cluster1-admin@cluster1
> CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
>   --context "$CTX" -o jsonpath='{.items[0].metadata.name}')
> ```
>
> Для control-plane используйте `ssh "$CP"`, для отдельного Docker-хоста - `ssh docker-host`.
> Артефакты кладите в `/var/work/tests/artifacts/<номер>/`.

## 1. Отключить ненужный systemd-сервис

Сервис `cks-lab105-unused.service` не нужен для Kubernetes и увеличивает поверхность
атаки. Остановим его и запретим автозапуск.

```bash
ssh "$CP" 'sudo systemctl disable --now cks-lab105-unused.service'
ssh "$CP" 'enabled=$(sudo systemctl is-enabled cks-lab105-unused.service 2>/dev/null || true); active=$(sudo systemctl is-active cks-lab105-unused.service 2>/dev/null || true); echo "$enabled $active"' \
  | tee /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. Закрыть ненужный TCP/8080

Порт 8080 открыт намеренно сервисом `cks-lab105-port.service`; он не нужен ни
control-plane, ни kubelet. Останавливаем и отключаем сервис - оба действия обязательны,
иначе listener вернётся после reboot, даже если сейчас порт закрыт.

```bash
ssh "$CP" 'sudo systemctl disable --now cks-lab105-port.service'
ssh "$CP" 'enabled=$(sudo systemctl is-enabled cks-lab105-port.service 2>/dev/null || true); active=$(sudo systemctl is-active cks-lab105-port.service 2>/dev/null || true); echo "$enabled $active"' \
  | tee /var/work/tests/artifacts/2/service.txt
# disabled inactive
ssh "$CP" 'sudo ss -ltn | grep -qE "[:.]8080([[:space:]]|$)"' \
  && echo 'tcp/8080: still open' \
  || echo 'tcp/8080: closed' \
  | tee /var/work/tests/artifacts/2/port-8080.txt
# tcp/8080: closed
```

## 3. Ограничить входящий трафик UFW

Сначала определяем топологию и необходимые источники. Это одноузловой control-plane,
который также запускает workload. Worker должен иметь SSH и API access; Pod CIDR и сам
узел — API access. Межнодовых kubelet/CNI flows здесь нет. Не открываем `22`/`6443` для
`Anywhere`.

```bash
WORKER_IP=$(ssh "$CP" 'printf "%s\n" "${SSH_CONNECTION%% *}"')
NODE_IP=$(kubectl get node "$CP" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
POD_CIDR=$(kubectl get node "$CP" --context "$CTX" -o jsonpath='{.spec.podCIDR}')
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" \
  | tee /var/work/tests/artifacts/3/preflight.txt

# Baseline ДО UFW: доказываем, что TCP/10250 (kubelet HTTPS) реально достижим сейчас -
# без этого шага post-hardening "заблокировано" ничего не доказывает, порт мог быть
# недоступен по совершенно другой причине ещё раньше (security group, routing). Отдельно
# от этой student-owned пробы checker уже зафиксировал свой собственный, checker-owned
# bootstrap baseline в /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt ДО того, как
# лаба была выдана студенту - этот шаг всё равно нужен, потому что тест сравнивает
# post-hardening состояние именно с этим вашим файлом (в дополнение к checker-owned проверке).
set +e
baseline_kubelet_code=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz")
baseline_kubelet_rc=$?
set -e
printf 'baseline kubelet 10250: CURL_EXIT=%s HTTPCODE=%s\n' "$baseline_kubelet_rc" "$baseline_kubelet_code" \
  | tee -a /var/work/tests/artifacts/3/preflight.txt
if [[ "$baseline_kubelet_rc" -eq 0 && "$baseline_kubelet_code" =~ ^[1-5][0-9][0-9]$ ]]; then
  echo "OK: baseline TCP/10250 reachable (exit=$baseline_kubelet_rc http=$baseline_kubelet_code) - a post-UFW block can now be attributed to UFW."
else
  echo "FAIL: TCP/10250 already unreachable before UFW (exit=$baseline_kubelet_rc http=$baseline_kubelet_code) - fix connectivity first, otherwise the post-UFW result is inconclusive." >&2
fi

# Allow recovery and required API sources before changing the default.
ssh "$CP" "sudo ufw allow from '$WORKER_IP' to any port 22 proto tcp comment 'CKS105 worker SSH recovery'"
ssh "$CP" "sudo ufw allow from '$WORKER_IP' to any port 6443 proto tcp comment 'CKS105 worker API'"
ssh "$CP" "sudo ufw allow from '$NODE_IP' to any port 6443 proto tcp comment 'CKS105 node API'"
ssh "$CP" "sudo ufw allow from '$POD_CIDR' to any port 6443 proto tcp comment 'CKS105 Pod API'"
ssh "$CP" 'sudo ufw allow in on lo comment "CKS105 loopback"; sudo ufw default allow outgoing; sudo ufw default deny incoming; sudo ufw --force enable'
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  | tee /var/work/tests/artifacts/3/ufw.txt
# 'ufw show added' - нормализованное представление правил, которые вы реально добавили
# (НЕ гарантированно исходный вид/порядок команд - UFW нормализует их при отображении).
# Проверка сравнивает именно этот список с ожидаемым allowlist - сохраните его тоже, это
# самая надёжная evidence exact allow-set (независимая от того, как 'ufw status'
# группирует/переупорядочивает iptables-производные строки). Управляйте firewall только
# через 'ufw' - НЕ редактируйте /etc/ufw/before*.rules или /etc/ufw/after*.rules вручную,
# это framework-файлы с общими default-правилами, а не место для source-scoped rules;
# checker сверяет их хэш с checker-owned bootstrap-baseline и заметит прямое редактирование.
ssh "$CP" 'sudo ufw show added' \
  | tee -a /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# Выполнять из ещё открытой SSH/console session при потере API:
sudo ufw disable
sudo ufw status verbose
# исправить узкие allow rules, проверить source IP/CIDR
sudo ufw --force enable
# Если правила повреждены полностью, только через console/recovery channel:
sudo ufw --force reset
EOF

kubectl get --raw=/readyz --context "$CTX"
kubectl get nodes --context "$CTX"
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# Pod DNS должен продолжать работать - это отдельная проверка от Pod -> API server.
kubectl exec -n cks-105-health deploy/health-probe -- \
  sh -c 'getent hosts kubernetes.default.svc.cluster.local >/dev/null && echo DNS_OK || echo DNS_FAIL'
kubectl exec -n cks-105-health deploy/health-probe -- \
  sh -c 'code=$(curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz); test "$code" != 000'

# Нежелательный worker -> kubelet flow не должен дать HTTP response.
set +e
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
set -e

# Обязательный полный E2E retest ПОСЛЕ 'ufw reload' - доказывает, что ruleset переживает
# reload, а не только работает в памяти сразу после 'ufw enable'. Без этого шага можно
# случайно настроить правило, которое реально не персистентно (например, забыть 'ufw
# allow' до перезапуска сервиса) и получить ложное PASS сразу после enable.
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz --context "$CTX"
kubectl get nodes --context "$CTX"
kubectl get pods -n kube-system -l k8s-app=calico-node --context "$CTX"
# Pod DNS повторяем ТЕМ ЖЕ probe, что и до reload - reload может перезапустить
# kube-proxy/CNI rule programming и вызвать DNS-специфичную регрессию, которую отдельная
# HTTP-проверка сама по себе не поймает.
kubectl exec -n cks-105-health deploy/health-probe -- \
  sh -c 'getent hosts kubernetes.default.svc.cluster.local >/dev/null && echo DNS_OK || echo DNS_FAIL'
kubectl exec -n cks-105-health deploy/health-probe -- \
  sh -c 'code=$(curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz); test "$code" != 000'
# Тот же контракт, что и до reload: сохраняем И exit code, И HTTPCODE - транспортная
# ошибка с пустым/'000' HTTP-кодом, а не просто ненулевой exit статус сам по себе.
set +e
post_reload_kubelet_code=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz")
post_reload_kubelet_rc=$?
set -e
printf 'post_reload_kubelet 10250: CURL_EXIT=%s HTTPCODE=%s\n' "$post_reload_kubelet_rc" "$post_reload_kubelet_code"

# Проверка decl vs effective: 'ufw show added' - декларативный список, реконструированный
# из '### tuple ###' метаданных, которые ufw сам пишет в user.rules при добавлении
# правила через CLI. Реальное же состояние ядра после 'ufw reload' - именно то, что
# показывает 'ufw show user-rules' (iptables -L на ufw-user-input/-forward/-output).
# Сравнивайте не только КОЛИЧЕСТВО строк, но и их СОДЕРЖИМОЕ (source/port/proto) с этими
# же 5 правилами: одинаковое число правил само по себе НЕ доказательство, что это те же
# самые 5 правил - ufw-user-input построчно должен показывать именно loopback (all, lo)
# и три tcp dpt:22/6443 правила с точными source-адресами, а ufw6-user-input должен быть
# полностью пуст (ни одно из 5 правил не IPv6).
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

```bash
ssh "$CP" 'sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf'
ssh "$CP" "sudo stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  | tee /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. Запретить прямой root login по SSH

Изменяем конфигурацию, проверяем синтаксис до reload и применяем без разрыва текущей
сессии.

```bash
ssh "$CP" "sudo sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config"
ssh "$CP" "sudo grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' | sudo tee -a /etc/ssh/sshd_config"
ssh "$CP" 'sudo sshd -t && sudo systemctl reload ssh'
```

`sshd -T` без connection context не применяет `Match`-блоки вообще - man `sshd(8)`
прямо говорит, что `Match` в test mode применяется только когда передан `-C`. Поэтому
проверяем через `-C`, симулируя реальное root-соединение с worker:

```bash
WORKER_IP=$(ssh "$CP" 'printf "%s\n" "${SSH_CONNECTION%% *}"')
NODE_IP=$(kubectl get node "$CP" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  | tee /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Защитить Docker daemon на `docker-host`

TCP/2375 не имеет TLS и аутентификации: доступ к нему практически равен root-доступу к
хосту. Удаляем учебный systemd override с TCP listener, задаём владельца unix-сокета
через socket override и удаляем `developer` из группы `docker`.

```bash
ssh docker-host 'sudo rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf'
ssh docker-host 'sudo install -d -m 0755 /etc/systemd/system/docker.socket.d'
ssh docker-host 'printf "[Socket]\nSocketGroup=root\nSocketMode=0660\n" | sudo tee /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf >/dev/null'
ssh docker-host 'sudo gpasswd -d developer docker || true'
```

Применяем изменения через полный `daemon-reload` + restart **обоих** unit-ов - это
обязательный шаг, а не просто "перечитать конфиг": без реального restart можно случайно
"пройти" проверку, если Docker просто перестал отвечать (тогда TCP/2375 закрыт не потому,
что убран `-H tcp://`, а потому что демон вообще не работает):

```bash
ssh docker-host 'sudo systemctl daemon-reload'
ssh docker-host 'sudo systemctl restart docker.socket'
ssh docker-host 'sudo systemctl restart docker.service'
ssh docker-host 'sudo chown root:root /var/run/docker.sock && sudo chmod 660 /var/run/docker.sock'
```

Positive control: подтверждаем, что Docker после restart реально РАБОТАЕТ (не просто не
слушает 2375 - он должен полноценно функционировать через unix-сокет):

```bash
ssh docker-host 'sudo systemctl is-active docker.service docker.socket'
ssh docker-host 'sudo docker version && sudo docker info >/dev/null'
# active / active
# (docker version/info должны завершиться без ошибки)
```

Persistent config check - убеждаемся, что effective unit не содержит `-H tcp://` и что
socket override реально задаёт нужные значения (а не просто временно совпадает с ними):

```bash
ssh docker-host 'systemctl cat docker.service | grep -c "H tcp://" || true'
ssh docker-host 'systemctl cat docker.socket'
# 0 (нет совпадений -H tcp://)
# [Socket] ... SocketGroup=root ... SocketMode=0660 ...
```

Проверим TCP listener, сокет и доступ пользователя отдельными артефактами:

```bash
ssh docker-host 'sudo ss -ltn | grep -qE "[:.]2375([[:space:]]|$)"' \
  && echo 'tcp/2375: still open' \
  || echo 'tcp/2375: closed' \
  | tee /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  | tee /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  | tee /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

После выполнения всех шагов запустите `check_result`.

## 7. Запретить загрузку модуля `sctp`

`sctp` загружен, но не нужен ни kubeadm, ни containerd, ни Calico на этой ноде. Сначала
выгружаем уже загруженный модуль, затем блокируем повторную загрузку и через `blacklist`,
и через `install` override. Обе директивы действуют на уровне `modprobe` (alias resolution
и явный `modprobe sctp`) и устраняют обычный путь загрузки; они не заменяют kernel-level
enforcement (`insmod` вставляет модуль напрямую через syscall и не читает `modprobe.d`,
а `modprobe --ignore-install` может обойти `install` при равном root-доступе) - для этой
лабы важно устранить именно ожидаемый путь автозагрузки, а не смоделировать защиту от
пользователя, уже имеющего root на ноде.

```bash
ssh "$CP" 'sudo modprobe -r sctp || true'
ssh "$CP" "printf 'blacklist sctp\ninstall sctp /bin/true\n' | sudo tee /etc/modprobe.d/60-cks-sctp.conf"
```

Подтверждаем оба свойства: модуль реально отсутствует в ядре, а не только удалён из
файла конфигурации, и override виден в effective modprobe config:

```bash
mkdir -p /var/work/tests/artifacts/7
ssh "$CP" '
{
  if sudo lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  sudo modprobe --show-config | grep sctp
}' | tee /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent
# install sctp /bin/true
```

## 8. `protectKernelDefaults` и безопасные sysctl

Сначала исправляем sysctl - `protectKernelDefaults: true` заставит kubelet **упасть при
старте**, если текущие значения ядра не совпадают с его ожиданиями, поэтому sysctl
обязаны быть применены раньше, чем перезапуск kubelet.

```bash
ssh "$CP" "printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' | sudo tee /etc/sysctl.d/99-kubernetes.conf"
ssh "$CP" 'sudo sysctl --system'
ssh "$CP" 'sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory'
```

Теперь включаем `protectKernelDefaults` в конфигурации kubelet и перезапускаем сервис:

```bash
ssh "$CP" 'sudo grep -q "^protectKernelDefaults:" /var/lib/kubelet/config.yaml \
  && sudo sed -i "s/^protectKernelDefaults:.*/protectKernelDefaults: true/" /var/lib/kubelet/config.yaml \
  || echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$CP" 'sudo systemctl restart kubelet'
ssh "$CP" 'sudo systemctl is-active kubelet'
kubectl get node "$CP" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

Если kubelet не поднимается после этого шага - проверьте именно порядок: sysctl должны
быть применены (`sysctl --system`), а не только записаны в файл, прежде чем kubelet
проверит их при старте.

## 9. Найти и обезвредить лишний SUID-бинарник

`find` покажет и системные SUID-бинарники (`sudo`, `passwd`, `mount` - их не трогаем), и
учебный `/usr/local/bin/cks-lab105-suid-tool`, который не требуется ни одному компоненту
Kubernetes на этой ноде.

```bash
mkdir -p /var/work/tests/artifacts/9
ssh "$CP" 'sudo find / -xdev -perm -4000 -type f 2>/dev/null' \
  | tee /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

Снимаем SUID-бит только с учебного файла:

```bash
ssh "$CP" 'sudo chmod u-s /usr/local/bin/cks-lab105-suid-tool'
ssh "$CP" "sudo stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  | tee /var/work/tests/artifacts/9/suid-after.txt
# 755
```

Подтвердите, что системные SUID-бинарники не задеты - `sudo`/`passwd` обязаны остаться с
SUID-битом, иначе базовая функциональность ОС ломается:

```bash
ssh "$CP" "sudo stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd"
```

После выполнения всех шагов запустите `check_result`.

## 10. Отключить core dumps и защитить SUID-процессы

Core dump может содержать секреты и ключи из памяти процесса на момент crash - его нужно
запретить как для обычных, так и для SUID-процессов. `fs.suid_dumpable` добавляем в тот же
файл `/etc/sysctl.d/99-kubernetes.conf`, что уже создан в задании 8 - не создаём отдельный
конфликтующий конфиг:

```bash
ssh "$CP" "printf 'fs.suid_dumpable = 0\n' | sudo tee -a /etc/sysctl.d/99-kubernetes.conf"
```

На Ubuntu `ulimit -c 0` и `fs.suid_dumpable=0` **не гарантируют** отсутствие core dump:
`man 5 core` прямо документирует, что `RLIMIT_CORE` игнорируется ядром, если
`kernel.core_pattern` направляет dump в userspace-обработчик через pipe (`|program`).
Ubuntu по умолчанию именно так настроен - crash перехватывает Apport и сохраняет его в
`/var/lib/apport/coredump/` НЕЗАВИСИМО от `ulimit -c` процесса. Единственный надёжный
способ - переопределить сам `kernel.core_pattern` на заведомо неработающий handler:

```bash
ssh "$CP" "printf 'kernel.core_pattern = |/bin/false\n' | sudo tee -a /etc/sysctl.d/99-kubernetes.conf"
ssh "$CP" 'sudo sysctl --system'
ssh "$CP" 'sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern'
```

Ограничиваем размер core dump на уровне лимитов процессов - это отдельный механизм от
`suid_dumpable`/`core_pattern` (soft limit для обычных crash при классической
file-based записи, если она когда-либо будет восстановлена):

```bash
ssh "$CP" "printf '* hard core 0\n* soft core 0\n' | sudo tee -a /etc/security/limits.conf"
```

`limits.conf` применяется к новым login-сессиям через PAM, а не к уже открытым shell -
проверяем именно в новой сессии:

```bash
mkdir -p /var/work/tests/artifacts/10
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; su - ubuntu -c 'ulimit -c'" \
  | tee /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  | tee -a /var/work/tests/artifacts/10/coredump.txt
```

Controlled crash probe: подтверждаем, что после реального `SIGSEGV` не появляется НОВЫЙ
retained core dump - ни в стандартном текущем каталоге, ни через Apport:

```bash
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
' | tee -a /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

После выполнения всех шагов запустите `check_result`.
