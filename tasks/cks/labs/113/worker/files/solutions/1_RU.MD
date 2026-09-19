# Лаба 113 - эталонное решение: kubeadm minor upgrade

> Все Kubernetes-команды с `kubectl` выполняются на рабочей машине. Команды с
> `ssh k8s113_controlPlane_1`/`ssh k8s113_node_worker1` выполняются на соответствующем
> узле кластера. Стартовая версия кластера `1.35.x`, целевая - `1.36.x`.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Шаг 0. Параллельно запустите availability-полинг (задание 4)

Перед тем как начать upgrade, откройте отдельную сессию (например `tmux`/`screen`) на
рабочей машине и оставьте работать цикл опроса Deployment `canary` - он должен идти
непрерывно на протяжении всех следующих шагов:

```bash
while true; do
  available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  echo "$(date +%s) available=${available:-0}" >> /var/work/tests/artifacts/4/canary-availability.log
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
kubectl drain k8s113_controlPlane_1 --context "$CTX" --ignore-daemonsets --delete-emptydir-data
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
kubectl uncordon k8s113_controlPlane_1 --context "$CTX"
kubectl get node k8s113_controlPlane_1 --context "$CTX" -o wide
```

Проверяем итоговые версии на control-plane:

```bash
kubectl version --context "$CTX" -o json | jq -r '.serverVersion.gitVersion'
ssh k8s113_controlPlane_1 'kubeadm version -o short; kubelet --version'
```

## 2. Upgrade worker-узла

Начинайте это задание только после того, как control-plane полностью `Ready` на
`1.36.x` (иначе будет нарушена version skew policy: kubelet worker-узла не должен
быть новее control-plane).

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
kubectl drain k8s113_node_worker1 --context "$CTX" --ignore-daemonsets --delete-emptydir-data
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
kubectl uncordon k8s113_node_worker1 --context "$CTX"
kubectl get node k8s113_node_worker1 --context "$CTX" -o wide
```

## 3. Проверка порядка upgrade

Задание 3 не требует отдельных команд - оно проверяется по времени модификации
evidence-файлов, созданных в заданиях 1 и 2. Если вы следовали шагам по порядку (сперва
полностью Section 1, потом Section 2), файл `kubeadm-upgrade-apply.txt` уже будет
старше (или равного возраста) `kubeadm-upgrade-node.txt` автоматически:

```bash
stat -c '%Y %n' /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
```

## 4. Проверка отсутствия downtime

Остановите цикл опроса из Шага 0 (`Ctrl+C` в его сессии) и проверьте, что минимальное
значение `available` за весь прогон не опускалось до 0:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | cut -d= -f2 | sort -n | head -1
kubectl get deployment canary -n upgrade-113 --context "$CTX"
```

Если минимум оказался `0` - скорее всего обе реплики `canary` были на одном и том же
узле без anti-affinity, и `drain` этого узла на короткое время убрал обе. В этом случае
имеет смысл перераспределить Pod'ы (например через `podAntiAffinity` по `topologyKey:
kubernetes.io/hostname`) и повторить upgrade с самого начала на пересозданном кластере,
либо (если инфраструктура уже обновлена) as-is задокументировать наблюдаемый провал как
часть анализа - тест 4 будет "красным" до тех пор, пока минимум не станет `>= 1`.

## Финальная проверка

```bash
kubectl get nodes --context "$CTX" -o wide
check_result
```

Оба узла должны быть `Ready`, оба - на `v1.36.x`, ни один не `SchedulingDisabled`
(cordoned). `check_result` подтверждает весь набор автоматических проверок.
