# Лаба 113 - эталонное решение: kubeadm minor upgrade

> Все Kubernetes-команды с `kubectl` выполняются на рабочей машине. Команды с
> `ssh k8s113_controlPlane_1`/`ssh k8s113_node_worker1` выполняются на соответствующем
> узле кластера. Стартовая версия кластера `1.35.x`, целевая - `1.36.x`.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,4}
# Имена узлов в Kubernetes - hostname инстансов (ip-10-...), а не ssh-алиасы; определяем их по роли.
export CP_NODE=$(kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
export WORKER_NODE=$(kubectl get nodes --context "$CTX" -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
echo "control-plane=$CP_NODE worker=$WORKER_NODE"
```

## Шаг 0. Параллельно запустите availability-полинг (задание 4)

Перед тем как начать upgrade, откройте отдельную сессию (например `tmux`/`screen`) на
рабочей машине и оставьте работать цикл опроса Deployment `canary` - он должен идти
непрерывно на протяжении всех следующих шагов:

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"                     # API ответил: пустое поле = 0 доступных реплик
  else
    echo "$(date +%s) available=api-unreachable"                     # API недоступен - это не простой нагрузки
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. Upgrade control-plane

Проверяем текущие версии перед началом:

```bash
ssh k8s113_controlPlane_1 'kubeadm version -o short; kubelet --version'
kubectl version --context "$CTX" -o json | jq -r '.serverVersion.gitVersion'
```

### Переключаем пакетный репозиторий на целевой minor

`pkgs.k8s.io` хранит отдельный репозиторий на каждую minor-версию - подключённый ранее
репозиторий `core:/stable:/v1.35` не содержит пакеты `1.36.x`, поэтому сначала меняем
keyring и `sources.list.d/kubernetes.list`:

```bash
ssh k8s113_controlPlane_1 '
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq
'
```

### Обновляем kubeadm и выполняем сам upgrade control-plane

```bash
ssh k8s113_controlPlane_1 '
sudo apt-mark unhold kubeadm
sudo apt-get install -y --allow-change-held-packages kubeadm
sudo apt-mark hold kubeadm
kubeadm version -o short
'
```

`kubeadm upgrade plan` показывает доступные целевые версии и не меняет состояние
кластера - выполните его первым, чтобы явно увидеть целевую patch-версию:

```bash
ssh k8s113_controlPlane_1 'sudo kubeadm upgrade plan'
```

Возьмите конкретную версию из вывода `plan` (например `v1.36.1`) и выполните реальный
upgrade, сохраняя ПОЛНЫЙ вывод команды как evidence:

```bash
ssh k8s113_controlPlane_1 'sudo kubeadm upgrade apply v1.36.1 -y' \
  | tee /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
grep -q 'SUCCESS' /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

> Замените `v1.36.1` на реальную последнюю доступную `1.36.x` patch-версию из вывода
> `kubeadm upgrade plan` в вашем окружении - конкретный patch со временем меняется,
> тест проверяет только minor `v1.36`, а не точный patch.

### Drain, обновление kubelet/kubectl, uncordon

Только теперь, ПОСЛЕ успешного `kubeadm upgrade apply`, готовим узел к обновлению
kubelet:

```bash
kubectl drain "$CP_NODE" --context "$CTX" --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh k8s113_controlPlane_1 '
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y --allow-change-held-packages kubelet kubectl
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubelet --version
'
```

```bash
kubectl uncordon "$CP_NODE" --context "$CTX"
kubectl get node "$CP_NODE" --context "$CTX" -o wide
```

Проверяем итоговые версии на control-plane:

```bash
kubectl version --context "$CTX" -o json | jq -r '.serverVersion.gitVersion'
ssh k8s113_controlPlane_1 'kubeadm version -o short; kubelet --version'
```

## 2. Upgrade worker-узла

Начинайте это задание только после того, как control-plane полностью `Ready` на
`1.36.x` (иначе будет нарушена version skew policy: kubelet worker-узла не должен
быть новее control-plane). Дождитесь восстановления `canary` до `2/2` перед стартом:

```bash
kubectl wait \
  -n upgrade-113 \
  --for=condition=Available \
  deployment/canary \
  --timeout=180s

kubectl get pods -n upgrade-113 -l app=canary -o wide
```

```bash
ssh k8s113_node_worker1 '
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq
sudo apt-mark unhold kubeadm
sudo apt-get install -y --allow-change-held-packages kubeadm
sudo apt-mark hold kubeadm
'
```

На worker-узлах (и на дополнительных control-plane узлах, которых здесь нет) вызывается
`kubeadm upgrade node`, а не `apply` - `apply` предназначена только для первого
control-plane узла:

```bash
ssh k8s113_node_worker1 'sudo kubeadm upgrade node' \
  | tee /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
```

### Drain, обновление kubelet/kubectl, uncordon для worker-узла

```bash
kubectl drain "$WORKER_NODE" --context "$CTX" --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh k8s113_node_worker1 '
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y --allow-change-held-packages kubelet kubectl
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubelet --version
'
```

```bash
kubectl uncordon "$WORKER_NODE" --context "$CTX"
kubectl get node "$WORKER_NODE" --context "$CTX" -o wide
```

## 3. Проверка порядка upgrade

Задание 3 не требует отдельных команд - порядок доказывает checker-owned монитор
состояния кластера и версий (`/var/lib/cks-lab113-checker/upgrade-monitor.log` на
рабочей машине), который писался всё время начиная с bootstrap. Если вы следовали
шагам по порядку (сперва полностью Section 1, потом Section 2), в логе будет строка,
где control-plane уже на `v1.36.x`, `Ready` и schedulable, а worker ещё на `v1.35.x`,
и только после неё появляются строки с worker на `v1.36.x`:

```bash
kubectl get nodes --context "$CTX" -o wide
```

## 4. Проверка отсутствия downtime

> Во время `kubeadm upgrade apply` на единственном control-plane API server на несколько
> секунд перезапускается, и `kubectl` в цикле опроса не отвечает. Такие строки записаны как
> `available=api-unreachable` и в подсчёт минимума не входят (шаблон `[0-9]+`): недоступность
> API - не простой `canary`, контейнеры работают. Поэтому downtime доказывает независимый
> монитор чекера, который считает работающие контейнеры через `crictl` на обоих узлах.

Остановите цикл опроса из Шага 0 (`Ctrl+C` в его сессии) и проверьте, что минимальное
значение `available` за весь прогон не опускалось до 0:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | cut -d= -f2 | sort -n | head -1
kubectl get deployment canary -n upgrade-113 --context "$CTX"
```

Bootstrap заранее распределяет обе реплики `canary` по разным nodes (required
`podAntiAffinity`) и создаёт `PodDisruptionBudget` с `minAvailable: 1`, поэтому
корректный последовательный drain (сначала один узел, затем другой, после uncordon) не
должен опускать `available` ниже `1`. Если минимум всё же оказался `0` - проверьте
`kubectl get pods -n upgrade-113 -o wide` и убедитесь, что не оба узла оказались
`cordon`/`drain` одновременно; тест 4 будет "красным" до тех пор, пока минимум не
станет `>= 1`.

## Финальная проверка

```bash
kubectl get nodes --context "$CTX" -o wide
check_result
```

Оба узла должны быть `Ready`, оба - на `v1.36.x`, ни один не `SchedulingDisabled`
(cordoned). `check_result` подтверждает весь набор автоматических проверок.
