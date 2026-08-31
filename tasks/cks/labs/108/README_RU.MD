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
Лаба закрепляет Kyverno `1.19` (Helm chart `3.9.0`) и использует стабильные CEL-based API
`policies.kyverno.io/v1`. Legacy `Policy`/`ClusterPolicy` в `kyverno.io/v1` с этой версии
deprecated и рассматривается только как migration material.

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
| Критерии приёмки | В кластере есть CRD `validatingpolicies.policies.kyverno.io`; версия Kyverno — `1.19.x`; минимум один Deployment namespace `kyverno` имеет доступную реплику. |

---
| **2** | **Запретить image с тегом `latest`** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) с `validationActions: [Deny]`. Она должна применяться к Pod и subresource `pods/ephemeralcontainers` namespace `policy-108` и отклонять любой image в `containers`, `initContainers` или `ephemeralContainers`, который заканчивается на `:latest`. |
| Критерии приёмки | Policy существует и работает в режиме Deny; admission отклоняет `:latest` в каждом из трёх списков, а versioned trusted images принимает. |

---
| **3** | **Требовать запуск не от root** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `require-run-as-non-root` в режиме Deny. Для каждого Pod в `policy-108` поле `spec.securityContext.runAsNonRoot` должно быть явно равно `true`. |
| Критерии приёмки | Policy существует и Deny; Pod с `runAsNonRoot: false` не проходит server-side admission. |

---
| **4** | **Allowlist container registry** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `allow-approved-registries` в режиме Deny. Для каждого контейнера (`containers`, `initContainers`, `ephemeralContainers`) разрешайте только `registry.k8s.io/*` или `ghcr.io/cks-lab/*`; остальные image registry запретите. |
| Критерии приёмки | Policy существует и Deny; untrusted image отклоняется во всех трёх списках, trusted image допускается во всех трёх списках. |

---
| **5** | **Опционально: mutate label через Kyverno** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`), которая добавляет к Pod namespace `policy-108` label `security.cks.io/managed-by: kyverno`, если он отсутствует. Используйте mutation, а не validation. |
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
