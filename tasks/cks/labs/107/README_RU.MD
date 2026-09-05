# Лаба 107 — Pod Security Admission: restricted, audit/warn и read-only root filesystem

## Цель

В этой CKS-лабе вы настроите встроенный **Pod Security Admission (PSA)** через
labels namespace. Для production namespace будет включён `restricted` в режиме
`enforce`, проверен отказ небезопасного Pod и развёрнут проходящий hardened Pod.
Для отдельного namespace вы включите наблюдающие режимы `audit` и `warn` уровня
`baseline`. В завершение root filesystem контейнера станет read-only, а единственная
необходимая запись будет разрешена в `emptyDir`.

Работайте только с объектами из заданий. В кластере заранее созданы пустые namespace
`psa-restricted-107` и `psa-observe-107`; PSA-labels и workload в них отсутствуют.

## Инфраструктура

Окружение разворачивается через Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | ключи SSH для доступа к машинам |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая машина с `kubectl`, контекстом `cluster1-admin@cluster1` и `check_result` |

Control-plane принимает обычные Pod, поэтому отдельный worker-узел Kubernetes не
нужен. Все задания выполняются на рабочей машине.

## Развёртывание

```bash
TASK=107 make run_cks_task
```

Подключитесь по SSH к рабочей машине и проверьте доступ к кластеру:

```bash
time_left
kubectl get nodes
check_result
```

## Задания

---
| **1** | **Enforce restricted с закреплённой версией** |
| :---: | :--- |
| Что делаем | На namespace `psa-restricted-107` установите `pod-security.kubernetes.io/enforce=restricted` и `pod-security.kubernetes.io/enforce-version=v1.36`. Убедитесь, что PSA действительно отвергает небезопасный Pod: server-side dry-run Pod с `hostNetwork: true` в этом namespace должен завершиться ошибкой с `violates PodSecurity`. Не меняйте labels системных namespace. |
| Критерии приёмки | Оба enforce-label имеют точные значения; небезопасный Pod не проходит admission в `psa-restricted-107`. |

---
| **2** | **Hardened Pod, проходящий restricted** |
| :---: | :--- |
| Что делаем | Создайте Pod `restricted-app` в `psa-restricted-107` из `busybox:1.36`, работающий не от root и не завершающийся сразу. Установите pod-level `runAsNonRoot: true`, `runAsUser: 1000` и `seccompProfile: RuntimeDefault`. В container securityContext запретите privilege escalation, сбросьте capability `ALL`, явно оставьте `privileged: false` и задайте `seccompProfile: RuntimeDefault`. |
| Критерии приёмки | Pod принят PSA и запущен; работает как UID 1000/non-root; seccomp — `RuntimeDefault`; escalation и privileged запрещены; capabilities `ALL` сброшены. |

---
| **3** | **Наблюдающие режимы baseline** |
| :---: | :--- |
| Что делаем | На namespace `psa-observe-107` включите оба режима PSA: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. Не добавляйте `enforce`: это namespace для поэтапного наблюдения перед блокировкой. |
| Критерии приёмки | Присутствуют четыре labels audit/warn с уровнем `baseline` и версией `v1.36`; enforce-label отсутствует. |

---
| **4** | **Warn/audit не блокируют legacy workload** |
| :---: | :--- |
| Что делаем | Создайте в `psa-observe-107` Pod `baseline-audit-sample` из `busybox:1.36`, который работает с `hostNetwork: true` и выполняет `sleep 3600`. При `kubectl apply` зафиксируйте предупреждение PSA о нарушении baseline: Pod должен быть создан, потому что `warn` и `audit` сами по себе не запрещают запрос. |
| Критерии приёмки | `baseline-audit-sample` существует, имеет `hostNetwork: true` и был допущен API; в namespace по-прежнему нет enforce-режима. |

---
| **5** | **Read-only root filesystem с writable emptyDir** |
| :---: | :--- |
| Что делаем | Доработайте `restricted-app`: на контейнере включите `readOnlyRootFilesystem: true`. Создайте volume `writable-tmp` типа `emptyDir` и смонтируйте его в `/tmp` без `readOnly: true`. Контейнеру разрешено писать только в этот временный том; не используйте `hostPath`. При изменении неизменяемых полей Pod удалите и создайте `restricted-app` заново с тем же именем. |
| Критерии приёмки | У контейнера read-only root filesystem; `emptyDir` с именем `writable-tmp` смонтирован в `/tmp` как writable; hardened-настройки из задания 2 сохранены. |

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и пять независимых заданий. Она дополнительно выполняет
server-side dry-run небезопасного Pod, поэтому отсутствие постоянного «плохого» Pod в
restricted namespace — ожидаемый и правильный результат.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=107 make delete_cks_task
```
