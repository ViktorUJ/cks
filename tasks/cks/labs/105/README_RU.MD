# Лаба 105 - System Hardening ОС и безопасность Docker daemon

## Цель

В этой CKS-лабе вы уменьшите поверхность атаки двух Linux-хостов. На Kubernetes
control-plane нужно отключить лишние сервисы, закрыть открытый порт, настроить firewall,
защитить kubeconfig и запретить прямой root login по SSH. На отдельном `docker-host`
нужно устранить три опасные настройки Docker daemon: TCP API без TLS, доступ к
`docker.sock` через группу `docker` и доступ пользователя `developer` к этому сокету.

Это учебное окружение намеренно создано небезопасным. Не переносите исходные настройки
в production: Docker API на TCP/2375 без TLS даёт удалённый root-доступ любому, кто может
подключиться к порту.

## Связь с курсом

- [Глава 14. Минимизация footprint хостовой ОС и безопасность runtime-демона](../../course/14/ru.md)
- [Глава 15. Least-privilege на хосте и минимизация внешнего доступа](../../course/15/ru.md)
- [CKA: systemd, сервисы и Linux](../../../cka/course/00-5-linux/ru.md)
- [CKA: контейнеры и runtime](../../../cka/course/00-4-containers/ru.md)

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с двумя публичными подсетями |
| `ssh-keys` | SSH-ключ для внутренних соединений |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd, Calico; это целевой control-plane |
| `docker-host` | отдельный Ubuntu 22.04 с Docker и намеренно небезопасной конфигурацией |
| `worker` | рабочая машина с `kubectl`, SSH-конфигурацией и `check_result` |

`worker` имеет SSH-доступ к control-plane по его Kubernetes node name и к отдельному
хосту по имени `docker-host`. Docker не является runtime Kubernetes-кластера: его
конфигурация из задания 6 изолирована на `docker-host`.

## Развёртывание

```bash
TASK=105 make run_cks_task
```

Подключитесь к `worker`, затем получите имя control-plane:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CTX=cluster1-admin@cluster1
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
  --context "$CTX" -o jsonpath='{.items[0].metadata.name}')
ssh "$CP"
ssh docker-host
```

Полезные команды:

```bash
time_left
check_result
```

Артефакты проверки сохраняйте в `/var/work/tests/artifacts/<номер>/`. Создавать
манифесты Kubernetes для этой лабы не требуется.

## Задания

---
| **1** | **Отключить лишний сервис** |
| :---: | :--- |
| Что делаем | На control-plane отключите и остановите `cks-lab105-unused.service`. Сервис не нужен для работы Kubernetes и не должен стартовать после reboot. |
| Критерии приёмки | `systemctl is-enabled cks-lab105-unused.service` возвращает `disabled`, `systemctl is-active` - `inactive`; в `/var/work/tests/artifacts/1/service.txt` находится строка `disabled inactive`. |

---
| **2** | **Закрыть ненужный открытый порт** |
| :---: | :--- |
| Что делаем | На control-plane устраните listener TCP/8080, созданный `cks-lab105-port.service`. Отключите и остановите сервис; он не нужен ни control-plane, ни kubelet. |
| Критерии приёмки | `ss -ltn` не показывает TCP/8080; `/var/work/tests/artifacts/2/port-8080.txt` содержит `tcp/8080: closed`. |

---
| **3** | **Ограничить входящий трафик firewall** |
| :---: | :--- |
| Что делаем | До включения UFW зафиксируйте роль узла, worker source IP, node InternalIP и `spec.podCIDR`. Это одноузловой control-plane + workload node: нужны loopback, SSH recovery от worker, API `6443/tcp` от worker, самого узла и Pod CIDR; etcd/scheduler/controller-manager используют локальные flows, а межнодовых CNI/kubelet flows в этой топологии нет. Добавьте source-scoped allow rules **до** `ufw default deny incoming`; не используйте широкие `ALLOW Anywhere`. Затем включите UFW и сохраните правила, preflight и recovery-команды в `/var/work/tests/artifacts/3/`. |
| Критерии приёмки | UFW active/default-deny; `22` и `6443` разрешены только нужным источникам; `/readyz=ok`; ожидаемая нода `Ready`; `health-probe` остаётся Ready и достигает Kubernetes Service; worker не достигает kubelet `10250`; артефакт содержит команды recovery (`ufw disable`, проверка, исправление и повторное включение). |

> **Recovery сначала.** Держите текущую SSH-сессию открытой до полной проверки. Если API
> пропал, из неё выполните `sudo ufw disable`, исправьте allow rules и только затем снова
> включите firewall. Если SSH уже потерян, используйте console/recovery channel провайдера;
> не пытайтесь «лечить» ситуацию широким `allow from any`.
>
> **Граница применимости.** Этот UFW allowlist рассчитан только на одноузловую fixture.
> Его нельзя буквально переносить в multi-node cluster: до default-deny нужно инвентаризовать
> kubelet и межнодовые потоки, CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort и
> provider firewall/security groups для конкретной топологии.

---
| **4** | **Исправить права kubeconfig** |
| :---: | :--- |
| Что делаем | На control-plane защитите `/etc/kubernetes/admin.conf`, содержащий cluster-admin credential: владелец и группа должны быть `root:root`, режим - `600`. |
| Критерии приёмки | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` возвращает `root root 600`; то же значение сохранено в `/var/work/tests/artifacts/4/admin-conf.txt`. |

---
| **5** | **Запретить root login по SSH** |
| :---: | :--- |
| Что делаем | На control-plane задайте `PermitRootLogin no` в `/etc/ssh/sshd_config`, проверьте синтаксис через `sshd -t` и безопасно перезагрузите SSH. Проверяйте эффективное значение командой `sshd -T`, а не только текст файла. |
| Критерии приёмки | Эффективное значение `permitrootlogin` равно `no`; `/var/work/tests/artifacts/5/sshd.txt` содержит `PermitRootLogin no`. |

---
| **6** | **Укрепить Docker daemon на `docker-host`** |
| :---: | :--- |
| Что делаем | На отдельном `docker-host` прекратите публикацию Docker API по TCP/2375: уберите `-H tcp://...` из учебного systemd override, но сохраните доступ только через unix-сокет. Настройте `/var/run/docker.sock` как `root:root` с режимом `660`; для устойчивости после restart задайте это через override `docker.socket`. Удалите `developer` из группы `docker`. |
| Критерии приёмки | На TCP/2375 нет listener; `stat -c '%U %G %a' /var/run/docker.sock` возвращает `root root 660`; `developer` не состоит в группе `docker`, а `sudo -u developer docker ps` завершается ошибкой доступа. Создайте `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` со строками `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

## Дополнительно: kernel и containerd/CRI hardening

Это короткая node-local практика, не входящая в автоматические критерии fixture. Перед
отключением модуля подтвердите, что он не нужен ОС и workload. Например, для неиспользуемой
legacy filesystem можно выгрузить модуль и запретить его повторную загрузку:

```bash
ssh "$CP" 'sudo modprobe -r cramfs || true'
ssh "$CP" "printf 'blacklist cramfs\ninstall cramfs /bin/false\n' | sudo tee /etc/modprobe.d/60-cks-hardening.conf"
```

Безопасные sysctl также задавайте явно и сохраняйте вне `/etc/sysctl.conf`, затем
перечитывайте конфигурацию. Конкретные значения должны пройти проверку совместимости с CNI
и workload:

```bash
ssh "$CP" "printf 'kernel.kptr_restrict = 2\nkernel.dmesg_restrict = 1\n' | sudo tee /etc/sysctl.d/60-cks-hardening.conf"
ssh "$CP" 'sudo sysctl --system'
```

В этой лабе Kubernetes использует **containerd**, а не Docker. Поэтому те же принципы
надо применять к CRI: проверьте права `/run/containerd/containerd.sock` и
`/etc/containerd/config.toml`, не добавляйте обычных пользователей в группу, дающую доступ
к сокету, и разрешайте `ctr`/`crictl` с этим endpoint только привилегированным
администраторам. Не меняйте владельца или режим работающего CRI-сокета вслепую: ошибочная
настройка остановит kubelet и workload.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# ожидается отказ доступа для непривилегированного пользователя
```

## Проверка

На `worker` выполните:

```bash
check_result
```

Проверка содержит `0 Init` и шесть независимых тестов. Она проверяет состояние обоих
хостов по SSH и обязательные артефакты. После правки `sshd_config` или systemd unit
дождитесь завершения `systemctl reload/restart`, прежде чем запускать проверку повторно.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=105 make delete_cks_task
```
