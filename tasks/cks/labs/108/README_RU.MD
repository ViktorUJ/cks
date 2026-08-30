# Лаба 108 — Admission policies с Kyverno

## Цель

В этой CKS-лабе вы установите Kyverno и защитите namespace `policy-108` policy-as-code
правилами. Практика охватывает validating admission: запрет тега `latest`, обязательный
`runAsNonRoot`, allowlist registry; в последнем, опциональном этапе — mutation Pod при
admission. Работайте только с объектами и именами, указанными в заданиях.

## Инфраструктура

Окружение разворачивается Terragrunt в AWS `eu-central-1`:

| Компонент | Назначение |
|---|---|
| `vpc` | VPC `10.10.0.0/16` с публичными подсетями |
| `ssh-keys` | ключи доступа к узлам |
| `k8s-1` | одноузловой kubeadm-кластер Kubernetes `1.36.0`, containerd и **Calico** |
| `worker` | рабочая машина с `kubectl`, Helm и `/usr/local/bin/install-kyverno` |

Control-plane разрешает обычные Pod, поэтому отдельный Kubernetes worker не создаётся.
Kyverno намеренно **не установлен** в начальном состоянии: это часть задания 1. На
рабочей машине подготовлен закреплённый installer, не требующий подбирать chart вручную.

## Развёртывание

```bash
TASK=108 make run_cks_task
```

Подключитесь по SSH к рабочей машине. Контекст `cluster1-admin@cluster1` уже настроен.

```bash
time_left
check_result
```

## Задания

---
| **1** | **Установить Kyverno** |
| :---: | :--- |
| Что делаем | Установите Kyverno в namespace `kyverno`. Используйте подготовленную на worker команду `/usr/local/bin/install-kyverno`; она применяет закреплённый Helm chart. Дождитесь доступности admission controller. |
| Критерии приёмки | В кластере есть CRD `clusterpolicies.kyverno.io`; минимум один Deployment namespace `kyverno` имеет доступную реплику. |

---
| **2** | **Запретить image с тегом `latest`** |
| :---: | :--- |
| Что делаем | Создайте `ClusterPolicy` `deny-latest-tag` с `validationFailureAction: Enforce`. Она должна применяться к Pod namespace `policy-108` и отклонять каждый container, чей image заканчивается на `:latest`. |
| Критерии приёмки | Policy существует и включена в режиме Enforce; server-side admission отклоняет Pod с `registry.k8s.io/pause:latest`. |

---
| **3** | **Требовать запуск не от root** |
| :---: | :--- |
| Что делаем | Создайте `ClusterPolicy` `require-run-as-non-root` в режиме Enforce. Для каждого Pod в `policy-108` поле `spec.securityContext.runAsNonRoot` должно быть явно равно `true`. |
| Критерии приёмки | Policy существует и Enforce; Pod с `runAsNonRoot: false` не проходит server-side admission. |

---
| **4** | **Allowlist container registry** |
| :---: | :--- |
| Что делаем | Создайте `ClusterPolicy` `allow-approved-registries` в режиме Enforce. Для каждого container разрешайте только `registry.k8s.io/*` или `ghcr.io/cks-lab/*`; остальные image registry запретите. |
| Критерии приёмки | Policy существует и Enforce; Pod с `docker.io/library/busybox:1.36` отклоняется admission webhook. |

---
| **5** | **Опционально: mutate label через Kyverno** |
| :---: | :--- |
| Что делаем | Создайте `ClusterPolicy` `add-kyverno-managed-label`, которая добавляет к Pod namespace `policy-108` label `security.cks.io/managed-by: kyverno`, если он отсутствует. Используйте mutation, а не validation. |
| Критерии приёмки | Server-side dry-run Pod с разрешённым registry и `runAsNonRoot: true` возвращает добавленный label. Этот этап отображается в `check_result`, но его пропуск допустим. |

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и пять тестов. Первые четыре обязательны. Пятый тест выполняет
проверку mutation, но не делает лабораторию неуспешной, если optional policy не создана.
Все admission-проверки используют `--dry-run=server`, поэтому образы не скачиваются и
Pod не остаются в namespace.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=108 make delete_cks_task
```
