# Лаба 112 - Runtime: Falco, audit-логи и неизменяемый root filesystem

## Цель

В этой CKS-лабе вы настроите контроль runtime-событий на ноде и audit-логирование API
control plane, а затем сделаете workload неизменяемым в рантайме. Работа идёт на одном
узле: `control-plane` одновременно является workload-нодой, поэтому Falco видит события
из тестовых Pod, а kube-apiserver находится в static Pod manifest.

## Связь с курсом

- [Глава 29. Поведенческий анализ во время выполнения: Falco](../../course/29/ru.md)
- [Глава 30. Обнаружение угроз и расследование фаз атаки](../../course/30/ru.md)
- [Глава 31. Иммутабельность контейнеров в runtime](../../course/31/ru.md)
- [Глава 32. Audit-логи Kubernetes](../../course/32/ru.md)

## Инфраструктура

| Компонент | Назначение |
|---|---|
| `k8s-1` | одноузловой Kubernetes `1.36.0`, containerd и Calico; имя ноды `control-plane` |
| `worker` | рабочая машина с `kubectl`, `check_result` и SSH-доступом `ssh control-plane` |
| `runtime-112` | подготовленный namespace; в нём уже есть Secret `audit-secret` |

Bootstrap намеренно **не** устанавливает Falco и **не** включает audit backend. Он только
готовит каталог `/etc/kubernetes/audit`, каталог логов
`/var/log/kubernetes/audit` и Secret для контролируемого API-запроса. Не меняйте CNI,
версию кластера, Secret или Kubernetes-манифесты вне задания 4.

## Развёртывание

```bash
TASK=112 make run_cks_task
```

На рабочей машине:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## Задания

---
| **1** | **Установить и запустить Falco на workload-ноде** |
| :---: | :--- |
| Что делаем | На `control-plane` установите пакет Falco из официального репозитория Falco и запустите сервис. Используйте modern eBPF engine; не устанавливайте kernel module вручную. Включите сервис через systemd. |
| Критерии приёмки | `falco --version` выполняется; `systemctl is-active falco` возвращает `active`; конфигурация содержит `engine.kind: modern_ebpf`. |

---
| **2** | **Зафиксировать стандартное событие shell в контейнере** |
| :---: | :--- |
| Что делаем | Создайте в `runtime-112` Pod `falco-shell` из `busybox:1.36`, оставьте его Running (`sleep 3600`) и включите `stdin: true`, `tty: true`. Откройте в нём интерактивный `/bin/sh`, дождитесь правила Falco **Terminal shell in container** и сохраните подходящую строку из journal Falco в `/var/work/tests/artifacts/2/falco-shell.log` на рабочей машине. |
| Критерии приёмки | Pod `falco-shell` Running; артефакт не пуст и содержит `Terminal shell in container`. Событие должно быть получено Falco, а не записано вручную. |

---
| **3** | **Добавить и вызвать custom Falco rule** |
| :---: | :--- |
| Что делаем | На `control-plane` добавьте в `/etc/falco/falco_rules.local.yaml` правило с именем `CKS112 Custom Shell Marker`. Оно должно ловить spawned process в контейнере, у которого `proc.cmdline` содержит `CKS112_CUSTOM_EVENT`, и выводить точную фразу `CKS112 custom shell marker` вместе с `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` и `command=%proc.cmdline`. Перезапустите Falco. Из `falco-shell` вызовите контролируемый процесс с marker, найдите срабатывание и сохраните его в `/var/work/tests/artifacts/3/falco-custom.log`. |
| Критерии приёмки | Локальный rules-файл существует, содержит имя правила, условие marker и идентификаторы расследования; сервис Falco активен; настоящий journal-артефакт содержит marker, container ID и PID. |

---
| **4** | **Включить audit-логирование: RequestResponse для ConfigMap, Metadata для Secret** |
| :---: | :--- |
| Что делаем | На `control-plane` создайте `/etc/kubernetes/audit/policy.yaml`. Policy должна: записывать `RequestResponse` для core resource `configmaps` (контролируемый forensic-пример на нечувствительном ресурсе); для core resource `secrets` использовать только `Metadata`, **чтобы тело Secret не попадало в журнал**; завершаться безопасным шумоподавляющим catch-all `Metadata`. В static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` добавьте `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log`, ротацию (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`) и необходимые hostPath volume/volumeMount для policy-каталога и каталога логов. Дождитесь восстановления API. Создайте ConfigMap `audit-config` в `runtime-112`, прочитайте его (`kubectl get configmap audit-config -n runtime-112 -o json`) и сохраните RequestResponse event в `/var/work/tests/artifacts/4/configmap-request-response.json`. Затем прочитайте `kubectl get secret audit-secret -n runtime-112 -o json` и сохраните его Metadata event в `/var/work/tests/artifacts/4/secret-metadata.json`. |
| Критерии приёмки | kube-apiserver healthy; static manifest содержит оба audit-флага и монтирования; policy задаёт `RequestResponse` для `configmaps` и `Metadata` для `secrets`; в `/var/work/tests/artifacts/4/configmap-request-response.json` — RequestResponse event для ConfigMap; в `/var/work/tests/artifacts/4/secret-metadata.json` — событие Secret уровня `Metadata` **без полей `requestObject`/`responseObject`** (тело Secret не залогировано). |

---
| **5** | **Сделать Pod с root filesystem только для чтения** |
| :---: | :--- |
| Что делаем | Создайте в `runtime-112` Pod `immutable-app`: контейнер `app`, образ `busybox:1.36`, `sleep 3600`. На контейнере включите `securityContext.readOnlyRootFilesystem: true`; создайте `emptyDir` `writable-tmp` и смонтируйте его в `/tmp` без `readOnly: true`. Не используйте `hostPath`. Докажите, что `touch /cks-112-write-denied` неуспешен, а `touch /tmp/allowed` успешен; сохраните результат отказа в `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Критерии приёмки | Pod Running; root filesystem read-only; `/tmp` - writable `emptyDir`; в Pod нет `hostPath`; запись в rootfs блокируется, в `/tmp` разрешена; артефакт не пуст. |

---
| **6** | **Полная цепочка расследования и containment** |
| :---: | :--- |
| Что делаем | После включения audit backend запустите в `falco-shell` контролируемый долгоживущий процесс с аргументом `CKS112_CUSTOM_EVENT`. **Начните расследование с нового Falco alert**, а не с Pod manifest. Из alert извлеките short container ID и host PID. На `control-plane` через `crictl ps/inspect/inspectp` сопоставьте container → Pod sandbox → namespace/Pod; через Kubernetes API определите ноду. Сохраните `crictl inspect` и `inspectp`. Пока процесс жив, сохраните `/proc/<PID>/status`, `cmdline`, `cgroup` и дерево PID/PPID/user. В audit log найдите `pods/exec` event для `runtime-112/falco-shell` и сохраните его без request/response body. Классифицируйте фазу как `Execution`, технику как `Container Administration Command`, составьте `evidence-summary.txt`. Затем примените default-deny ingress+egress `NetworkPolicy` `incident-quarantine`, удалите скомпрометированный Pod и сохраните отрицательную проверку: повторный `kubectl exec` не проходит. |
| Критерии приёмки | В `/var/work/tests/artifacts/6/` есть настоящий Falco alert, CRI inspect/inspectp, три `/proc`-артефакта, process lineage, Metadata audit event для `pods/exec`, итоговая сводка и результат containment; Pod `falco-shell` отсутствует; `incident-quarantine` выбирает все Pod и закрывает ingress+egress; повторный exec имеет non-zero exit code. |

## Проверка

```bash
check_result
```

Проверка содержит Init и шесть независимых тестов. Она проверяет состояние Falco и
kube-apiserver по SSH, API-объекты, CRI/`/proc` evidence, audit correlation, containment
и фактический отказ записи в rootfs. После
изменения static Pod manifest не перезапускайте kubelet без необходимости: kubelet сам
заметит изменение. Если API временно недоступен, дождитесь `kubectl get --raw=/readyz`.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD).

## Удаление

```bash
TASK=112 make delete_cks_task
```
