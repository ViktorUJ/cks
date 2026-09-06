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

## Проверьте себя перед стартом

<details>
<summary>1. Чем `enforce` отличается от `audit`/`warn` в Pod Security Admission?</summary>

`enforce` реально блокирует создание Pod, нарушающего выбранный уровень PSS - admission request завершается ошибкой. `audit`/`warn` НЕ блокируют запрос: Pod всё равно создаётся, но `audit` добавляет annotation в audit log kube-apiserver, а `warn` показывает пользователю текстовое предупреждение при `kubectl apply`. Это разные уровни ответственности: `audit`/`warn` - для наблюдения перед включением реальной блокировки, `enforce` - собственно защита.
</details>

<details>
<summary>2. Почему для namespace нужно закреплять `*-version` label вместе с уровнем PSS?</summary>

Без фиксированной версии (`enforce-version`) PSA будет использовать текущую версию Kubernetes при каждой проверке - если кластер обновится, набор правил `restricted`/`baseline` может измениться незаметно для вас, и Pod, который проходил вчера, может начать отвергаться сегодня без ваших действий. Фиксация версии делает поведение предсказуемым и воспроизводимым независимо от будущих обновлений кластера.
</details>

<details>
<summary>3. Почему `ValidatingAdmissionPolicy` из задания 6 не дублирует PSA, а дополняет его?</summary>

PSS `restricted` определяет фиксированный, стандартизированный набор security-полей (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` НЕ входит в этот набор - PSA его не проверяет вообще. Значит, Pod может быть полностью совместим с `restricted` и всё равно тихо получить смонтированный API-токен, который ему не нужен. Custom `ValidatingAdmissionPolicy` закрывает именно этот пробел, не пытаясь заменить или продублировать то, что уже делает PSA.
</details>

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

<details>
<summary>💡 Подсказка к заданию 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - оба label применяются мгновенно, PSA не требует перезапуска чего-либо. Проверьте себя через `kubectl apply --dry-run=server` с `hostNetwork: true` - именно `--dry-run=server` (не `client`), потому что admission controllers, включая PSA, работают только на server-side.
</details>

---
| **2** | **Hardened Pod, проходящий restricted** |
| :---: | :--- |
| Что делаем | Создайте Pod `restricted-app` в `psa-restricted-107` из `busybox:1.36`, работающий не от root и не завершающийся сразу. Установите pod-level `runAsNonRoot: true`, `runAsUser: 1000` и `seccompProfile: RuntimeDefault`. В container securityContext запретите privilege escalation, сбросьте capability `ALL`, явно оставьте `privileged: false` и задайте `seccompProfile: RuntimeDefault`. |
| Критерии приёмки | Pod принят PSA и запущен; работает как UID 1000/non-root; seccomp — `RuntimeDefault`; escalation и privileged запрещены; capabilities `ALL` сброшены. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Если Pod получает admission rejection - читайте сообщение об ошибке внимательно, оно обычно называет ТОЧНОЕ недостающее поле (например, "container has no capabilities.drop"). `restricted` требует поля И на уровне Pod, И на уровне контейнера - забыть seccompProfile на одном из двух уровней - частая ошибка.
</details>

---
| **3** | **Наблюдающие режимы baseline** |
| :---: | :--- |
| Что делаем | На namespace `psa-observe-107` включите оба режима PSA: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. Не добавляйте `enforce`: это namespace для поэтапного наблюдения перед блокировкой. |
| Критерии приёмки | Присутствуют четыре labels audit/warn с уровнем `baseline` и версией `v1.36`; enforce-label отсутствует. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Четыре отдельных label - легко забыть один из них (особенно `-version` для одного из режимов). Проверьте все четыре сразу: `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

---
| **4** | **Warn/audit не блокируют legacy workload** |
| :---: | :--- |
| Что делаем | Создайте в `psa-observe-107` Pod `baseline-audit-sample` из `busybox:1.36`, который работает с `hostNetwork: true` и выполняет `sleep 3600`. При `kubectl apply` зафиксируйте предупреждение PSA о нарушении baseline: Pod должен быть создан, потому что `warn` и `audit` сами по себе не запрещают запрос. |
| Критерии приёмки | `baseline-audit-sample` существует, имеет `hostNetwork: true` и был допущен API; в namespace по-прежнему нет enforce-режима. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

Если Pod НЕ создался - проверьте, не установили ли вы случайно `enforce` label в задании 3 вместо только `audit`/`warn`. Warning от PSA появляется прямо в выводе `kubectl apply` (`Warning: would violate PodSecurity "baseline:v1.36"`), не нужно искать его в отдельном логе.
</details>

---
| **5** | **Read-only root filesystem с writable emptyDir** |
| :---: | :--- |
| Что делаем | Доработайте `restricted-app`: на контейнере включите `readOnlyRootFilesystem: true`. Создайте volume `writable-tmp` типа `emptyDir` (рекомендуется `medium: Memory`, чтобы временные файлы не попадали на диск ноды) и смонтируйте его в `/tmp` без `readOnly: true`. Контейнеру разрешено писать только в этот временный том; не используйте `hostPath`. Докажите оба исхода живым вызовом внутри Pod: попытка записи в корень контейнера (например, `touch /root-write-test.txt`) должна завершиться ошибкой `Read-only file system`, а запись в `/tmp/test.txt` — успешно пройти. При изменении неизменяемых полей Pod удалите и создайте `restricted-app` заново с тем же именем. |
| Критерии приёмки | У контейнера read-only root filesystem; `emptyDir` с именем `writable-tmp` смонтирован в `/tmp` как writable; hardened-настройки из задания 2 сохранены; живая попытка записи в корень контейнера возвращает `Read-only file system`, а запись в `/tmp/test.txt` завершается успешно и читаемым содержимым. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

`readOnlyRootFilesystem` относится к полям, которые нельзя изменить у уже существующего Pod (immutable field) - `kubectl apply` с изменённым securityContext вернёт ошибку. Удалите Pod (`kubectl delete pod restricted-app`) и создайте заново с тем же именем, а не пытайтесь обновить существующий на месте.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: требовать `automountServiceAccountToken: false`** |
| :---: | :--- |
| Что делаем | PSA `restricted` уже требует `allowPrivilegeEscalation: false`, `capabilities.drop` содержит `ALL`, non-root и seccomp — задание 2 показывает именно это. Но PSS `restricted` **не проверяет** `automountServiceAccountToken`: Pod, не нуждающийся в Kubernetes API, может тихо получить смонтированный ServiceAccount token и полностью пройти PSA. Это отдельный, не покрытый PSS control, поэтому здесь уместен именно custom `ValidatingAdmissionPolicy`, а не дублирование встроенного PSA. В namespace `psa-restricted-107` создайте `ValidatingAdmissionPolicy` `require-no-automount-token` с CEL-выражением, требующим `automountServiceAccountToken == false` на уровне Pod. Примените `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, ограниченную `matchResources.namespaceSelector` на `psa-restricted-107`, с `validationActions: [Deny]`. Докажите оба исхода server-side dry-run: полностью PSA-совместимый Pod (со всеми полями из задания 2 — non-root, seccomp, drop ALL, escalation false) **без** `automountServiceAccountToken: false` должен быть отклонён именно этой policy, а не PSA; тот же Pod с `automountServiceAccountToken: false` должен пройти. |
| Критерии приёмки | `ValidatingAdmissionPolicy require-no-automount-token` и её `ValidatingAdmissionPolicyBinding` существуют, `validationActions` содержит `Deny`, Binding матчит только `psa-restricted-107`. Server-side dry-run PSA-совместимого Pod без `automountServiceAccountToken: false` отклонён с сообщением именно этой policy (не PSA-сообщением `violates PodSecurity`); тот же Pod с `automountServiceAccountToken: false` принят. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Тестовый Pod для этого задания должен быть ПОЛНОСТЬЮ PSA-совместим (все поля из задания 2), кроме отсутствующего `automountServiceAccountToken: false` - если тестовый Pod нарушает и PSS, и вашу новую policy одновременно, вы не сможете доказать, что именно ВАША policy сработала, а не встроенный PSA. `ValidatingAdmissionPolicyBinding` без `matchResources.namespaceSelector` применится ко ВСЕМУ кластеру - обязательно ограничьте scope только нужным namespace.
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и шесть независимых заданий. Она дополнительно выполняет
server-side dry-run небезопасного Pod, поэтому отсутствие постоянного «плохого» Pod в
restricted namespace — ожидаемый и правильный результат.

## Решение

Эталонное решение: [worker/files/solutions/1_RU.MD](worker/files/solutions/1_RU.MD)

## Удаление

```bash
TASK=107 make delete_cks_task
```

## Примечание о версии PSA и наблюдаемости audit

Лаба намеренно закрепляет PSA labels на `v1.36`, поскольку сам учебный кластер работает
на Kubernetes 1.36.0. На 2026-09-06 официальный blueprint CKS ориентирован на Kubernetes
`v1.35`; поэтому это **forward-looking** учебная конфигурация, а не утверждение о версии
экзамена. Для подготовки к текущему экзамену замените суффиксы `*-version` на `v1.35` и
сверьте поведение с документацией этой версии.

Режим `audit` добавляет в **audit event kube-apiserver** annotation
`pod-security.kubernetes.io/audit-violations` для нарушившего Pod. Учебная инфраструктура
не настраивает и не предоставляет audit-log sink, поэтому эту annotation здесь нельзя
прочитать через `kubectl`. Наблюдаемое доказательство в задании 4 — предупреждение PSA
(`Warning: ... would violate PodSecurity "baseline"`) при server-side admission и успешное
создание Pod без `enforce`; audit mode объяснён, но его log annotation этой лабой не
проверяется.
