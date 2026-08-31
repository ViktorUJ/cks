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
control-plane, ни kubelet.

```bash
ssh "$CP" 'sudo systemctl disable --now cks-lab105-port.service'
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

# Allow recovery and required API sources before changing the default.
ssh "$CP" "sudo ufw allow from '$WORKER_IP' to any port 22 proto tcp comment 'CKS105 worker SSH recovery'"
ssh "$CP" "sudo ufw allow from '$WORKER_IP' to any port 6443 proto tcp comment 'CKS105 worker API'"
ssh "$CP" "sudo ufw allow from '$NODE_IP' to any port 6443 proto tcp comment 'CKS105 node API'"
ssh "$CP" "sudo ufw allow from '$POD_CIDR' to any port 6443 proto tcp comment 'CKS105 Pod API'"
ssh "$CP" 'sudo ufw allow in on lo comment "CKS105 loopback"; sudo ufw default allow outgoing; sudo ufw default deny incoming; sudo ufw --force enable'
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  | tee /var/work/tests/artifacts/3/ufw.txt

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
kubectl exec -n cks-105-health deploy/health-probe -- \
  sh -c 'code=$(curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz); test "$code" != 000'

# Нежелательный worker -> kubelet flow не должен дать HTTP response.
set +e
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
set -e
```

В выводе должны быть `Status: active`, `Default: deny (incoming)` и source-scoped rules.
Не закрывайте исходную SSH session, пока `/readyz`, nodes, workload и отрицательная
проверка `10250` не дали ожидаемый результат.

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
ssh "$CP" "sudo sshd -T | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
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
ssh docker-host 'sudo systemctl daemon-reload && sudo systemctl stop docker.service && sudo systemctl restart docker.socket && sudo systemctl start docker.service'
ssh docker-host 'sudo chown root:root /var/run/docker.sock && sudo chmod 660 /var/run/docker.sock'
ssh docker-host 'sudo gpasswd -d developer docker || true'
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
