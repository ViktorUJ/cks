[Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Лаба 107 - Pod Security Admission: restricted, audit/warn и read-only root filesystem

## Цель

В этой CKS-лабе вы настроите встроенный **Pod Security Admission (PSA)** через
labels namespace. Для production namespace будет включён `restricted` в режиме
`enforce`, проверен отказ небезопасного Pod и развёрнут проходящий hardened Pod.
Для отдельного namespace вы включите наблюдающие режимы `audit` и `warn` уровня
`baseline`. В завершение root filesystem контейнера станет read-only, а единственная
необходимая запись будет разрешена в `emptyDir`.

Работайте только с объектами из заданий. В кластере заранее созданы пустые namespace
`psa-restricted-107`, `psa-observe-107` и `psa-controller-107`; PSA-labels и workload в них отсутствуют.

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
| Критерии приёмки | Оба enforce-label имеют точные значения; небезопасный Pod не проходит admission в `psa-restricted-107`; системные namespace `kube-system`, `kube-public` и `kube-node-lease` не получают `pod-security.kubernetes.io/*` labels в рамках этой лаборатории. |

<details>
<summary>💡 Подсказка к заданию 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - оба label применяются мгновенно, PSA не требует перезапуска чего-либо. Проверьте себя через `kubectl apply --dry-run=server` с `hostNetwork: true` - именно `--dry-run=server` (не `client`), потому что admission controllers, включая PSA, работают только на server-side.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Сначала baseline - ДО установки labels убедитесь, что тот же небезопасный manifest
проходит (иначе непонятно, denial вызван вашим enforce label или чем-то ещё):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

Установите оба label, затем повторите ТОТ ЖЕ manifest - теперь должна быть ошибка
admission с текстом `violates PodSecurity`:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **Hardened Pod, проходящий restricted** |
| :---: | :--- |
| Что делаем | Создайте Pod `restricted-app` в `psa-restricted-107` из `busybox:1.36`, работающий не от root и не завершающийся сразу. Установите pod-level `runAsNonRoot: true`, `runAsUser: 1000` и `seccompProfile: RuntimeDefault`. В container securityContext запретите privilege escalation, сбросьте capability `ALL`, явно оставьте `privileged: false` и задайте `seccompProfile: RuntimeDefault`. |
| Критерии приёмки | Pod принят PSA и запущен; работает как UID 1000/non-root, и ни один container/init/ephemeral container не переопределяет pod-level `runAsUser: 1000`; seccomp - `RuntimeDefault`; escalation и privileged запрещены; capabilities `ALL` сброшены. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

Если Pod получает admission rejection - читайте сообщение об ошибке внимательно, оно обычно называет ТОЧНОЕ недостающее поле (например, "container has no capabilities.drop"). Важная деталь про семантику PSS `restricted` в Kubernetes 1.36: она требует эффективный (не обязательно буквально продублированный) допустимый `seccompProfile` - pod-level профиль (`spec.securityContext.seccompProfile.type`) может наследоваться контейнерами, у которых своё поле не задано, и наоборот, container-level поля достаточно, если оно явно задано у ВСЕХ контейнеров, даже без pod-level профиля. То есть сам PSS не требует буквально ОБА уровня одновременно. **В этой лабе мы намеренно просим задать `RuntimeDefault` явно и на Pod, и на контейнере** - не потому что этого требует PSS, а чтобы вы попрактиковались с обоими уровнями конфигурации. Аналогично `runAsUser: 1000` - это explicit hardening-решение именно этой лабы: PSS `restricted` запрещает UID `0`, но не требует конкретно `1000` (любое non-zero значение или полное отсутствие поля допустимо для самого PSS).
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

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Baseline - ДО установки labels нарушающий manifest должен пройти без предупреждения PSA
(namespace ещё не наблюдается):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

Установите все четыре label, затем повторите ТОТ ЖЕ manifest - теперь `kubectl apply`
должен вывести `Warning: ... would violate PodSecurity "baseline:v1.36"`, а команда
всё равно должна завершиться успехом (exit 0), а не ошибкой:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
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

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Это задание фактически повторяет self-check задания 3, но с постоянным Pod. После
создания `baseline-audit-sample` убедитесь, что он действительно существует и
`Running`/`Pending` (не был отклонён):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

Сравните с namespace `psa-restricted-107` (задание 1): тот же самый небезопасный manifest там
ДОЛЖЕН быть отклонён, а здесь - принят. Разница именно в `enforce` label, который есть
у одного namespace и отсутствует у другого:

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **Read-only root filesystem с writable emptyDir** |
| :---: | :--- |
| Что делаем | Доработайте `restricted-app`: на контейнере включите `readOnlyRootFilesystem: true`. Создайте volume `writable-tmp` типа `emptyDir` (рекомендуется `medium: Memory`, чтобы временные файлы не попадали на диск ноды) и смонтируйте его в `/tmp` без `readOnly: true`. Контейнеру разрешено писать только в этот временный том; не используйте `hostPath`. Докажите оба исхода живым вызовом внутри Pod: попытка записи в корень контейнера (например, `touch /root-write-test.txt`) должна завершиться ошибкой `Read-only file system`, а запись в `/tmp/test.txt` - успешно пройти. При изменении неизменяемых полей Pod удалите и создайте `restricted-app` заново с тем же именем. |
| Критерии приёмки | У контейнера read-only root filesystem; `emptyDir` с именем `writable-tmp` смонтирован в `/tmp` как writable; для regular containers это единственный writable declarative `volumeMount`, а все дополнительные `volumeMounts` read-only; hardened-настройки из задания 2 сохранены; живая попытка записи в корень контейнера возвращает `Read-only file system`, а запись в `/tmp/test.txt` завершается успешно, а содержимое читаемо. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

`readOnlyRootFilesystem` относится к полям, которые нельзя изменить у уже существующего Pod (immutable field) - `kubectl apply` с изменённым securityContext вернёт ошибку. Удалите Pod (`kubectl delete pod restricted-app`) и создайте заново с тем же именем, а не пытайтесь обновить существующий на месте.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: требовать `automountServiceAccountToken: false`** |
| :---: | :--- |
| Что делаем | • PSA `restricted` уже требует `allowPrivilegeEscalation: false`, `capabilities.drop`, содержащий `ALL`, non-root и seccomp - задание 2 показывает именно это.<br/>• Но PSS `restricted` **не проверяет** `automountServiceAccountToken`: Pod, не нуждающийся в Kubernetes API, может тихо получить смонтированный ServiceAccount token и полностью пройти PSA. Это отдельный, не покрытый PSS control, поэтому здесь уместен именно custom `ValidatingAdmissionPolicy`, а не дублирование встроенного PSA.<br/>• Создайте `ValidatingAdmissionPolicy` `require-no-automount-token` с CEL-выражением, требующим `automountServiceAccountToken == false` на уровне Pod.<br/>• Примените `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, ограниченную `matchResources.namespaceSelector` на `psa-restricted-107`, с `validationActions: [Deny]`.<br/>• Докажите все три состояния server-side dry-run: полностью PSA-совместимый Pod (со всеми полями из задания 2 - non-root, seccomp, drop ALL, escalation false) без поля должен получить DENY от точной пары policy+binding; `automountServiceAccountToken: false` должен получить ALLOW; `automountServiceAccountToken: true` должен снова получить DENY от той же пары.<br/>• После создания policy новые Pod в `psa-restricted-107` (в том числе пересоздаваемый `restricted-app`) должны сами содержать `automountServiceAccountToken: false`, иначе политика их отклонит. |
| Критерии приёмки | • **Объекты:** `ValidatingAdmissionPolicy require-no-automount-token` и её `ValidatingAdmissionPolicyBinding` существуют, `validationActions` содержит `Deny`, Binding матчит только `psa-restricted-107`. В лаборатории существует ровно одна Binding для этой policy - `require-no-automount-token-binding`; дополнительные Binding этой policy для других namespace не создаются.<br/>• **Три состояния:** server-side dry-run PSA-совместимого Pod без `automountServiceAccountToken: false` отклонён именно парой `ValidatingAdmissionPolicy 'require-no-automount-token'` и `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` (не PSA-сообщением `violates PodSecurity` и не другой policy); Pod с `automountServiceAccountToken: false` принят, а Pod с `automountServiceAccountToken: true` отклонён той же точной парой.<br/>• **Покрытие всех Pod:** policy покрывает все Pod, выбранные её `resourceRules`, внутри `psa-restricted-107`. Не добавляйте `spec.matchConditions`, `matchConstraints.objectSelector` или `matchConstraints.namespaceSelector` в `ValidatingAdmissionPolicy`, а также `objectSelector` в Binding `matchResources` - они сужают coverage до части Pod, и workload сможет выпасть из проверки по label или условию запроса.<br/>• **Namespace scope:** задаётся только Binding `matchResources.namespaceSelector`, точно привязанным к `psa-restricted-107`; selector не содержит условий по другим namespace-label keys и сам по себе однозначно ограничивает scope этим namespace.<br/>• **CEL:** validation не содержит исключений по имени/labels/annotations Pod, user/request, `namespaceObject`, `params`, `variables` или другим полям: решение зависит только от `object.spec.automountServiceAccountToken` (допустима любая корректная CEL-форма, в том числе optional-синтаксис `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` отсутствует или пуст: её отдельные CEL expressions могут влиять на admission через `failurePolicy`, поэтому admission control задаётся только `spec.validations`. `variables` и `paramKind` не используются.<br/>• **Resource scope:** `matchConstraints.resourceRules` ограничивают policy ровно `core/v1 pods` для операций `CREATE` и `UPDATE`, без `resourceNames`; `scope` отсутствует, равен `*` или `Namespaced`, но не `Cluster`; `excludeResourceRules` не используются. Binding не сужает resource/operation scope через собственные `resourceRules`/`excludeResourceRules`.<br/>• Это позволяет доказать полный boolean contract тремя состояниями `missing / false / true`, а не несколькими выбранными workload-примерами. |

<details>
<summary>💡 Подсказка к заданию 6</summary>

Тестовый Pod для этого задания должен быть ПОЛНОСТЬЮ PSA-совместим (все поля из задания 2), кроме отсутствующего `automountServiceAccountToken: false` - если тестовый Pod нарушает и PSS, и вашу новую policy одновременно, вы не сможете доказать, что именно ВАША policy сработала, а не встроенный PSA. `ValidatingAdmissionPolicyBinding` без `matchResources.namespaceSelector` применится ко ВСЕМУ кластеру - обязательно ограничьте scope ТОЧНО одним namespace `psa-restricted-107` (например через `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`), а не через `matchExpressions` с несколькими значениями, где `psa-restricted-107` - лишь одно из нескольких совпадающих namespace: если ваш selector случайно матчит и `psa-observe-107`, то же самое правило начнёт неожиданно действовать и там.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Baseline - ДО создания VAP/Binding тот же PSA-совместимый, но без automount opt-out,
Pod должен пройти (PSA сам его не отклоняет, `automountServiceAccountToken` не входит
в PSS):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

Создайте VAP + Binding и повторите manifest без поля - теперь запрос должен получить
DENY именно от `ValidatingAdmissionPolicy 'require-no-automount-token'` через binding
`require-no-automount-token-binding`, НЕ от PSA. Затем проверьте оба явных значения:
`false` должен пройти, а `true` должен получить DENY от той же точной пары.

```bash
kubectl apply -f require-no-automount-token.yaml   # ваши VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# ожидается: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

С тем же PSA-совместимым manifest задайте `automountServiceAccountToken: false` - запрос
должен пройти:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# ожидается: pod/self-check-automount-false created (или server-side dry-run success)
```

Теперь задайте `automountServiceAccountToken: true` - запрос снова должен быть отклонён
точно той же policy и binding:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# ожидается: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Наконец, самое важное - проверьте ГРАНИЦУ scope, а не только факт denial: тот же самый
manifest (без automount opt-out), но в namespace `psa-observe-107`, должен ПРОЙТИ - если
он тоже отклоняется, значит ваш `namespaceSelector` матчит больше, чем один namespace:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# ожидается: 0 (не denied) - иначе scope binding'а слишком широкий
```
</details>

---

| **7** | **Controller-driven admission denial: диагностика через ReplicaSet events** |
| :---: | :--- |
| Что делаем | В пустом namespace `psa-controller-107` создайте Deployment `controller-app` (label `app=controller-app`, replicas=1) с простым Pod template без hardening (например `busybox:1.36`, `sleep 3600`, без `securityContext`) - он должен успешно запуститься, PSA пока не мешает. Затем включите `pod-security.kubernetes.io/enforce=restricted` и `enforce-version=v1.36` на этом namespace (уже существующий Pod продолжит работать - PSA не трогает уже созданные объекты). Удалите текущий Pod: ReplicaSet попытается создать замену, и теперь admission её отклонит. Проверьте причину через `kubectl -n psa-controller-107 describe rs` и `kubectl -n psa-controller-107 get events` - там будет `FailedCreate` с текстом `violates PodSecurity "restricted:v1.36"`. Исправьте Pod template Deployment (добавьте те же hardening поля, что в задании 2: non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) и дождитесь, пока ReplicaSet успешно создаст новый, проходящий Pod. |
| Критерии приёмки | В namespace действует enforce `restricted:v1.36`; Pod template в Deployment полностью соответствует PSS `restricted`; после удаления текущего Pod ReplicaSet реально создаёт новый Ready Pod под текущим enforce-режимом (не просто "объект существует" - проверяется живым удалением и повторным созданием). |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Порядок важен: сначала Deployment без hardening (проходит, PSA пока не enforce), потом
label enforce=restricted на namespace (существующий Pod не пострадает), потом `kubectl
delete pod -l app=controller-app` - вот тут ReplicaSet и наткнётся на admission deny.
Если не удалить Pod вручную, вы не увидите отказ вообще, пока естественным образом не
произойдёт какой-то reschedule. Чинить нужно именно `spec.template` в Deployment (`kubectl
edit deployment controller-app` или `kubectl apply` с исправленным манифестом), а не
namespace label - откат enforce не является решением этого задания.
</details>

---

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и семь независимых заданий. Она дополнительно выполняет
server-side dry-run небезопасного Pod, поэтому отсутствие постоянного «плохого» Pod в
restricted namespace - ожидаемый и правильный результат. Задание 7 checker сам удаляет
текущий Pod `controller-app` и проверяет, что ReplicaSet реально пересоздаёт Ready Pod -
не принимает как доказательство текст events.

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
прочитать через `kubectl`. Наблюдаемое доказательство в задании 4 - предупреждение PSA
(`Warning: ... would violate PodSecurity "baseline"`) при server-side admission и успешное
создание Pod без `enforce`; audit mode объяснён, но его log annotation этой лабой не
проверяется.
