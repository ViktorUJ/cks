[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 113 - эталонное решение: kubeadm minor upgrade

> Работаем как на экзамене: `kubectl` - на рабочей машине, а операции над узлом (apt, kubeadm,
> kubelet) - на самом узле: зайдите на него `ssh <узел>`, перейдите в root (`sudo -i`),
> выполните команды и выйдите (`exit`, `exit`). Стартовая версия кластера `1.35.x`, целевая -
> `1.36.x`. Имена узлов (`<cp-имя>`, `<worker-имя>`) берём из `kubectl get no`; на экзамене они другие, в этой лабе ssh-алиасы: `k8s113_controlPlane_1` и `k8s113_node_worker1`.

## Где взять команды в документации

| Что нужно | Страница и раздел |
| :--- | :--- |
| Переключить apt-репозиторий на следующий minor (правится только версия в URL файла `/etc/apt/sources.list.d/kubernetes.list`, keyring остаётся прежним) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| Выбрать версию (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| Обновить `kubeadm`, `kubeadm upgrade plan`, `kubeadm upgrade apply v1.xx.x` на первом control-plane | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| Обновить `kubelet` и `kubectl`, `systemctl daemon-reload`, `restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Worker-узел: `kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

На узлах Ubuntu `needrestart` настроен в режиме «только список» (без диалога OK/Cancel), поэтому
`apt-get install` не останавливается на вопросах.

Вместо `1.36.x` в командах подставьте реальный patch из `apt-cache madison kubeadm` и из
вывода `kubeadm upgrade plan`.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

В `kubectl get no` запомните имена узлов (`ip-10-...`): они понадобятся для `drain` и `uncordon`. Ниже
`<cp-имя>` - имя control-plane, `<worker-имя>` - имя worker-узла.

## Шаг 0. Параллельно запустите availability-полинг (задание 4)

Перед upgrade откройте отдельную сессию (`tmux`) на рабочей машине и оставьте цикл опроса
Deployment `canary` работать на всё время следующих шагов:

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. Upgrade control-plane

```bash
ssh <cp-имя>
sudo -i
```

```bash
# на control-plane (root): текущие версии
kubeadm version -o short; kubelet --version

# переключить репозиторий на следующий minor: в файле заменить v1.35 на v1.36
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

Обновите kubeadm (реальный patch вместо `x`). **Эту команду выполняйте отдельно:** `apt-get`
сбрасывает буфер ввода терминала, поэтому строки, вставленные сразу за ней, пропадают.

```bash
# на control-plane (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# на control-plane (root)
kubeadm version -o short
kubeadm upgrade plan
```

Возьмите конкретную версию из вывода `plan` и выполните upgrade, сохранив **полный** вывод:

```bash
# на control-plane (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # из root
exit   # с control-plane
```

```bash
# на рабочей машине: забрать вывод для проверки
scp <cp-имя>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

Только теперь, ПОСЛЕ успешного `kubeadm upgrade apply`, drain узла и обновление kubelet/kubectl:

```bash
# на рабочей машине
kubectl drain <cp-имя> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <cp-имя>
sudo -i
```

```bash
# на control-plane (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# на control-plane (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # из root
exit   # с control-plane
```

```bash
# на рабочей машине
kubectl uncordon <cp-имя>
kubectl get nodes
```

## 2. Upgrade worker-узла

Начинайте только после того, как control-plane `Ready` на `1.36.x` (version skew policy:
kubelet worker-узла не может быть новее control-plane). Дождитесь, пока `canary` снова `2/2`:

```bash
# на рабочей машине: повторяйте, пока AVAILABLE не станет 2
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <worker-имя>
sudo -i
```

```bash
# на worker (root): тот же репозиторий, что и на control-plane
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# на worker (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# на worker (root)
# на worker-узле (и дополнительных control-plane) вместо apply выполняется upgrade node
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # из root
exit   # с worker
```

```bash
# на рабочей машине
scp <worker-имя>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <worker-имя> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <worker-имя>
sudo -i
```

```bash
# на worker (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# на worker (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # из root
exit   # с worker
```

```bash
# на рабочей машине
kubectl uncordon <worker-имя>
kubectl get nodes
```

## 3. Проверка порядка upgrade

Задание 3 не требует отдельных команд: порядок доказывает checker-owned монитор
(`/var/lib/cks-lab113-checker/upgrade-monitor.log` на рабочей машине), который писался всё время
с bootstrap. Если вы следовали шагам по порядку (сначала полностью раздел 1, потом раздел 2), в
логе есть строка, где control-plane уже на `v1.36.x`, `Ready` и schedulable, а worker ещё на
`v1.35.x`.

## 4. Проверка отсутствия downtime

> Во время `kubeadm upgrade apply` на единственном control-plane API server на несколько секунд
> перезапускается, и `kubectl` в цикле опроса не отвечает. Такие строки записаны как
> `available=api-unreachable` и в подсчёт минимума не входят: недоступность API - не простой
> `canary`. Наличие или отсутствие downtime фиксирует независимый монитор чекера (Pod Ready и контейнеры через `crictl`).

Остановите цикл опроса из Шага 0 (`Ctrl+C` в его сессии) и проверьте, что минимум `available`
за прогон не опускался до 0:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

Обе реплики `canary` разнесены по разным узлам (required `podAntiAffinity`) и защищены
`PodDisruptionBudget` с `minAvailable: 1`, поэтому корректный последовательный drain (сначала
один узел, затем другой, после uncordon) не опускает `available` ниже `1`.

## Финальная проверка

```bash
kubectl get nodes
check_result
```

Оба узла должны быть `Ready` на `v1.36.x`, ни один не `SchedulingDisabled`.
