# Лаба 108 — Admission policies с Kyverno

## Цель

В этой CKS-лабе вы установите Kyverno и защитите namespace `policy-108` policy-as-code
правилами. Практика охватывает validating admission: запрет тега `latest`, обязательный
`runAsNonRoot`, allowlist registry; в последнем, опциональном этапе — mutation Pod при
admission. Работайте только с объектами и именами, указанными в заданиях.

## Проверьте себя перед стартом

<details>
<summary>1. Почему запрет только явного тега `:latest` не закрывает весь риск mutable-tag?</summary>

Если image указан без тега вообще (например, `nginx`), Docker/OCI по умолчанию резолвит его как `nginx:latest` - implicit latest. Policy, проверяющая только буквальное совпадение строки `:latest`, пропустит такой image, хотя семантически это то же самое, что явный `:latest`. Правильная policy должна отклонять и явный, и implicit latest - либо требовать явный versioned tag/digest.
</details>

<details>
<summary>2. Зачем validating policy проверять `ephemeralContainers` отдельно от `containers`/`initContainers`?</summary>

`kubectl debug` добавляет ephemeral container в УЖЕ существующий Pod через отдельный subresource API (`pods/ephemeralcontainers`), а не через обычный CREATE/UPDATE Pod. Если policy матчит только на ресурс `pods` без явного включения этого subresource, попытка добавить непроверенный/untrusted ephemeral container может пройти мимо всех validating policies, написанных для обычных containers.
</details>

<details>
<summary>3. В чём принципиальная разница между `ValidatingPolicy` и `MutatingPolicy` в Kyverno?</summary>

`ValidatingPolicy` только проверяет запрос и либо разрешает, либо отклоняет его (Allow/Deny) - объект не изменяется. `MutatingPolicy` МЕНЯЕТ объект перед сохранением (добавляет/меняет поля, например label) - запрос всё равно проходит, но с изменённым содержимым. Задание 5 использует mutation именно потому, что цель - добавить label автоматически, а не отклонить Pod.
</details>

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

<details>
<summary>💡 Подсказка к заданию 1</summary>

`/usr/local/bin/install-kyverno` уже настроен на закреплённую версию - не пытайтесь ставить Kyverno через `helm install` вручную с другим chart, это может привести к несовместимой версии CRD. После установки подождите: admission controller Pod должен стать `Available`, это происходит не мгновенно.
</details>

---
| **2** | **Запретить image с тегом `latest`** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) с `validationActions: [Deny]`. Она должна применяться к Pod и subresource `pods/ephemeralcontainers` namespace `policy-108` и отклонять любой image в `containers`, `initContainers` или `ephemeralContainers`, который заканчивается на `:latest`. |
| Критерии приёмки | Policy существует и работает в режиме Deny; admission отклоняет `:latest` в каждом из трёх списков, а versioned trusted images принимает. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Готовое CEL-выражение для "запретить и явный, и implicit latest" уже приведено в конце README этой лабы (секция "Совместимость и точная семантика запрета образов") - используйте его как основу, не изобретайте свою логику с нуля. Не забудьте `matchConstraints.resourceRules` покрывает и `pods`, и subresource `pods/ephemeralcontainers` отдельно.
</details>

---
| **3** | **Требовать запуск не от root** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `require-run-as-non-root` в режиме Deny. Для каждого Pod в `policy-108` поле `spec.securityContext.runAsNonRoot` должно быть явно равно `true`. |
| Критерии приёмки | Policy существует и Deny; Pod с `runAsNonRoot: false` не проходит server-side admission. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Проверяйте именно ЯВНОЕ значение `true`, а не "отсутствие `false`" - CEL-выражение вида `object.spec.securityContext.runAsNonRoot == true` не пройдёт, если поле вообще не задано (`null != true`). Если хотите разрешить Pod без явного значения, это отдельное решение дизайна policy - но задание требует явную проверку.
</details>

---
| **4** | **Allowlist container registry** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `allow-approved-registries` в режиме Deny. Для каждого контейнера (`containers`, `initContainers`, `ephemeralContainers`) разрешайте только `registry.k8s.io/*` или `ghcr.io/cks-lab/*`; остальные image registry запретите. |
| Критерии приёмки | Policy существует и Deny; untrusted image отклоняется во всех трёх списках, trusted image допускается во всех трёх списках. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

`startsWith('registry.k8s.io/')` - самая надёжная проверка префикса, но убедитесь, что оба разрешённых registry проверяются через OR (любой из двух подходит), а не AND (оба одновременно, что невозможно для одного image). Как и в задании 2, не забудьте про `ephemeralContainers` - это тот же паттерн проверки трёх списков контейнеров.
</details>

---
| **5** | **Опционально: mutate label через Kyverno** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`), которая добавляет к Pod namespace `policy-108` label `security.cks.io/managed-by: kyverno`, если он отсутствует. Используйте mutation, а не validation. |
| Критерии приёмки | Server-side dry-run Pod с разрешённым registry и `runAsNonRoot: true` возвращает добавленный label. Этот этап отображается в `check_result`, но его пропуск допустим. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Этот этап опциональный - если у вас закончилось время, можно его пропустить без риска для остальной лабы. Тестовый Pod для проверки mutation должен уже проходить policies из заданий 2-4 (trusted registry, non-root) - если он сам будет отклонён одной из предыдущих policy, вы не увидите результат mutation вообще.
</details>

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

## Совместимость и точная семантика запрета образов

Лаба фиксирует Kubernetes 1.36.0 и Kyverno 1.19 для знакомства с новыми
`policies.kyverno.io/v1` API. Это **forward-looking / unsupported combination**: Kyverno
1.19 официально тестируется с Kubernetes 1.33–1.35, а не 1.36. Перед применением вне
лаборатории выбирайте поддерживаемую матрицу версий и сверяйте release notes.

В задании 2 под «запретом `latest`» понимается также запрет неявного `latest`: `nginx`
без tag и digest недопустим так же, как `nginx:latest`. Разрешены только image с явным
тегом, отличным от `latest`, либо с digest (`@sha256:...`). Безопасная CEL-проверка для
каждого image: `image.contains('@') || (image.matches('^(?:.*/)?[^/:]+:[^/]+$') &&
!image.endsWith(':latest'))`.
