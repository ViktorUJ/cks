> **Язык:** русский. Переводы будут добавлены после публикации соответствующих файлов.

# Глава 11. Pod Security Standards и Pod Security Admission

> **Что дальше.** В [главе 10](../10/ru.md) были разделены аутентификация и авторизация: они определяют, кто обращается к API и какие действия ему разрешены. Но право создать `Pod` ещё не делает его манифест безопасным. Здесь разберём, как встроенный Pod Security Admission проверяет параметры `Pod` по Pod Security Standards (PSS). Это часть домена KCSA **Kubernetes Security Fundamentals** с весом 22%. Примеры ориентированы на Kubernetes `v1.36`.

## 11.1 Назначение Pod Security Standards

**Pod Security Standards**, или PSS, задают три готовых профиля безопасности для `Pod`. Они ограничивают настройки, которые могут связать контейнер с рабочим узлом, повысить его привилегии или ослабить изоляцию. Примеры таких настроек: `privileged: true`, host namespaces, опасные Linux capabilities и небезопасные типы томов.

PSS отвечают на вопрос: «Какой уровень привилегий допустим для этой рабочей нагрузки?» Они не заменяют проверку кода, RBAC или сетевую изоляцию. Например, RBAC решает, вправе ли субъект создать `Pod`, а PSS проверяет, соответствует ли сам `Pod` выбранному профилю.

В Kubernetes PSS применяет встроенный admission-контроллер **Pod Security Admission** (PSA). Он проверяет запрос до сохранения объекта: манифест, нарушающий включённый режим `enforce`, не будет принят API Server.

```mermaid
flowchart LR
    client["Клиент создаёт Pod"] --> api["API Server"]
    api --> psa["PSA проверяет PSS
для Namespace"]
    psa -->|"соответствует"| stored["Pod сохранен"]
    psa -->|"нарушает enforce"| denied["Запрос отклонен"]
    style psa fill:#673ab7,color:#fff
    style stored fill:#0f9d58,color:#fff
    style denied fill:#db4437,color:#fff
```

## 11.2 Профили `privileged`, `baseline` и `restricted`

Профили PSS расположены от наименее к наиболее строгому. Каждый следующий профиль включает ограничения предыдущего.

| Профиль | Для чего нужен | Основная идея |
|---|---|---|
| `privileged` | Доверенные системные компоненты, которым действительно нужен доступ к узлу | PSA не накладывает ограничений PSS. |
| `baseline` | Общий минимальный уровень для обычных namespace и перехода от старых рабочих нагрузок | Блокирует известные пути эскалации, например привилегированные контейнеры и host namespaces. |
| `restricted` | Обычные прикладные рабочие нагрузки | Требует least privilege: non-root, ограниченные capabilities, безопасный seccomp и отсутствие эскалации привилегий. |

`privileged` не означает «безопасный для приложения». Это сознательное отсутствие ограничений PSA, которое может быть оправдано для CNI, CSI или узлового агента, но редко оправдано для обычного сервиса.

`baseline` отсекает наиболее опасные запросы. В частности, он запрещает `privileged`-контейнеры, `hostNetwork`, `hostPID`, `hostIPC`, небезопасные capabilities и `hostPath`. Он полезен как минимальная защита, но не требует, чтобы процесс работал не от root.

`restricted` подходит для большинства прикладных `Pod`. Среди его типичных требований: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault` или `Localhost`, удаление capabilities через `drop: ["ALL"]` и ограниченный список типов томов. Точные проверки привязаны к версии PSS, поэтому версию фиксируют в labels namespace.

## 11.3 Режимы PSA и labels namespace

PSA выбирает профиль и режим через labels у `Namespace`. Один и тот же стандарт можно включить тремя способами:

| Режим | Результат при нарушении | Когда полезен |
|---|---|---|
| `enforce` | API Server отклоняет создание или изменение неподходящего `Pod` | Защита уже готового namespace. |
| `audit` | Запрос проходит, но нарушение попадает в audit events | Оценка нарушений без остановки поставки. |
| `warn` | Запрос проходит, а клиент получает предупреждение | Быстрая обратная связь разработчику или CI. |

Каждому режиму можно задать собственный профиль и версию: например, строго применять `baseline`, но предупреждать о несоответствии `restricted`. Label с версией фиксирует ожидаемое поведение при обновлении Kubernetes, а значение `latest` использует текущую версию стандартов.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.36
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.36
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.36
```

Такой namespace отклоняет несовместимые `Pod`, одновременно оставляя след в аудите и предупреждение для клиента. Перед включением `enforce: restricted` в существующем namespace обычно сначала используют `audit` и `warn`: это показывает несовместимые манифесты без неожиданного отказа production-поставки.

### Namespace labels и cluster-wide defaults - два разных способа настройки PSA

Labels на `Namespace` - не единственный способ включить PSA. Сам admission-контроллер PSA можно настроить через `AdmissionConfiguration` (`PodSecurityConfiguration`) на уровне `kube-apiserver`, задав **cluster-wide defaults**: профиль и режим `enforce`/`audit`/`warn`, которые применяются по умолчанию к namespace, если у него нет собственных labels. Кластер может также определить исключения (`exemptions`) для отдельных namespace, `RuntimeClass` или `User`, независимо от их labels.

Из этого следует важное уточнение модели: если в namespace **нет** labels PSA, это **не означает автоматически**, что для него нет никакой политики PSS вообще. Правильная модель такая:

1. если у namespace есть свои labels PSA - действуют они;
2. если labels нет, но кластер явно сконфигурирован с cluster-wide defaults через `PodSecurityConfiguration` - действуют они;
3. если нет ни labels namespace, ни явно заданных cluster-wide defaults - действует встроенное значение по умолчанию самого admission-контроллера, которое соответствует профилю `privileged` в режиме `enforce` (`latest` версии). Такой permissive-по-умолчанию профиль практически не блокирует Pod, но формально это тоже применяемая политика PSS, а не «отсутствие всякой проверки».

Labels namespace обычно имеют приоритет над cluster-wide defaults там, где они заданы явно: они переопределяют (override) применимый по умолчанию профиль или режим для конкретного namespace. Поэтому вопрос «что произойдёт с Pod в namespace без labels» не имеет единственного универсального ответа без указания, сконфигурированы ли в этом кластере явные cluster-wide defaults: KCSA-уровня рассуждение должно явно называть это допущение и не путать «эффективно permissive default `privileged`» с «отсутствием любой проверки PSS».

Ниже минимальный пример `Pod`, рассчитанный на профиль `restricted`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: payments
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

PSA проверяет конфигурацию, но не подтверждает, что конкретный образ способен работать с такими ограничениями. Это обязанность команды, которая должна проверить рабочую нагрузку до включения строгого `enforce`.

## 11.4 PSP, границы PSA и policy engines

**PodSecurityPolicy** (PSP) был прежним механизмом ограничения `Pod`. Он удалён из Kubernetes начиная с `v1.25`, поэтому для Kubernetes `v1.36` его не используют. PSA является встроенной заменой для стандартных профилей PSS.

PSA намеренно ограничен. Он работает только с тремя фиксированными профилями и не выражает правила конкретной организации. Например, PSA не может потребовать образ только из `registry.example.internal`, обязательную label `owner`, лимит CPU или особый набор исключений для одного `Deployment`.

Когда нужны такие условия, используют policy engine или встроенные admission-политики: например, Kyverno, OPA/Gatekeeper либо ValidatingAdmissionPolicy с CEL. Эти механизмы дополняют PSA, а не отменяют его: PSA удобно применяет базовый безопасный профиль, а отдельная политика проверяет специфические требования организации.

## 11.5 Карта admission control: built-in, webhook и policy

Admission выполняется **после** authentication и authorization, до сохранения изменения в etcd. Он оценивает объект и не выдаёт identity или API-permission. Упрощённая карта для KCSA:

```text
Admission control
├── built-in plugins: NodeRestriction, LimitRanger, ResourceQuota,
│   ServiceAccount, AlwaysPullImages, PodSecurity
├── MutatingAdmissionWebhook
├── ValidatingAdmissionWebhook
└── ValidatingAdmissionPolicy + CEL
```

`LimitRanger` применяет ограничения и defaults `LimitRange`; `ResourceQuota` не допускает превышение namespace quota; `ServiceAccount` выполняет связанную с service account автоматизацию; `AlwaysPullImages` требует pull image перед запуском; `NodeRestriction` сужает изменения от kubelet. Это примеры admission plugins, а не список, который нужно заучивать целиком.

OPA/Gatekeeper и Kyverno - policy engines, которые могут участвовать в admission path. Они **не** являются встроенным Kubernetes authorizer и **не** аутентифицируют клиента. `Gatekeeper`/Kyverno проверяют или изменяют API-объект в соответствии с policy после того, как identity уже установлена и запрос авторизован. Для простых встроенных проверок используют `ValidatingAdmissionPolicy` с CEL без внешнего HTTP webhook.

| Сценарий | Лучший механизм | Почему не близкий distractor |
|---|---|---|
| Kubelet пытается изменить чужой `Node` | `NodeRestriction` | Node authorizer - стадия authorization; здесь проверяется допустимость mutation. |
| Namespace исчерпал разрешённый суммарный CPU | `ResourceQuota` admission plugin | HPA не запрещает request и не ограничивает tenant quota. |
| Запретить image вне corporate registry | validating policy / Gatekeeper / Kyverno / CEL policy | RBAC проверяет caller, но не анализирует поле image. |

## 11.6 Как это применяют на практике

Команда платформы обычно разделяет namespace по назначению. Для прикладных namespace выбирают `restricted`, для устаревших рабочих нагрузок начинают с `baseline`, а системные компоненты размещают отдельно и обоснованно используют `privileged` только там, где это необходимо.

Внедрение строят наблюдаемо: сначала смотрят предупреждения и audit events, исправляют `securityContext` и совместимость образов, затем включают `enforce`. Версию PSS фиксируют в labels, чтобы обновление кластера не изменило правила проверки без решения команды.

Исключение не должно превращаться в обход политики. Если конкретной рабочей нагрузке нужен доступ к узлу, её изолируют в отдельном namespace, документируют причину и сужают полномочия всеми доступными средствами: RBAC, сетевыми правилами, отдельными узлами и аудитом.

## 11.7 Exam vocabulary / Мини-глоссарий

| Термин | Значение |
|---|---|
| PSS | Pod Security Standards, три стандартных профиля безопасности `Pod`. |
| PSA | Pod Security Admission, встроенный admission-контроллер, применяющий PSS. |
| `privileged` | Профиль без ограничений PSA; подходит только для осознанно доверенных случаев. |
| `baseline` | Профиль, блокирующий распространённые пути эскалации привилегий. |
| `restricted` | Строгий профиль least privilege для прикладных рабочих нагрузок. |
| `enforce` | Режим PSA, который отклоняет нарушающий правила `Pod`. |
| `audit` | Режим PSA, записывающий нарушения в аудит без отказа запроса. |
| `warn` | Режим PSA, показывающий предупреждение клиенту без отказа запроса. |
| PSP | Удалённый механизм PodSecurityPolicy, не используемый в Kubernetes `v1.36`. |

## 11.8 Exam Essentials / Итоги главы

- PSS определяют три готовых профиля: `privileged`, `baseline` и `restricted`.
- PSA проверяет `Pod` до сохранения через labels `Namespace`; он дополняет RBAC, а не заменяет его.
- `baseline` блокирует очевидно опасные параметры, а `restricted` дополнительно требует least privilege.
- `enforce` отклоняет нарушение, `audit` записывает его в аудит, `warn` сообщает о нём клиенту.
- Версии профилей фиксируют labels вида `pod-security.kubernetes.io/*-version: v1.36`.
- PSP удалён, а PSA не покрывает произвольные правила организации. Для них применяют policy engine или admission policy.

## 11.9 Не путать и как это встречается на экзамене

В вопросах KCSA важно отличать роль каждого уровня. RBAC отвечает за субъект и действие API, PSA за профиль безопасности `Pod`, а `NetworkPolicy` за разрешённые сетевые потоки. Частая ловушка: считать `warn` защитой, которая блокирует запуск. Он лишь сообщает о нарушении; отказ даёт только `enforce`.

Также проверяют различие между `baseline` и `restricted`. Первый профиль не обещает запуск без root, второй требует более строгий `securityContext`. Если вопрос предлагает `privileged` как default для прикладного namespace, это почти наверняка неверный выбор.

## 11.10 Вопросы для самопроверки

### 1. Какой режим PSA не даёт создать `Pod`, нарушающий выбранный профиль?

a. `warn`

b. `privileged`

c. `audit`

d. `enforce`

<details>
<summary>Ответ и разбор</summary>

**Верный ответ: d.** `enforce` отклоняет запрос. `warn` только добавляет предупреждение, `audit` фиксирует событие, а `privileged` является профилем, а не режимом.

</details>

### 2. Какой профиль PSS обычно выбирают для обычного прикладного `Pod`, которому нужен least privilege?

a. `privileged`

b. `restricted`

c. `baseline`

d. `audit`

<details>
<summary>Ответ и разбор</summary>

**Верный ответ: b.** `restricted` включает требования non-root, безопасного seccomp, запрета эскалации привилегий и ограниченных capabilities. `baseline` является менее строгим промежуточным уровнем.

</details>

### 3. Что из перечисленного PSA не заменяет?

a. Проверку RBAC, имеет ли субъект право `create pods`

b. Проверку параметров `Pod` по PSS

c. Отказ неподходящего `Pod` в режиме `enforce`

d. Применение labels `pod-security.kubernetes.io/enforce`

<details>
<summary>Ответ и разбор</summary>

**Верный ответ: a.** RBAC и PSA решают разные задачи: RBAC проверяет право субъекта на API-действие, а PSA проверяет безопасность объекта. Остальные варианты относятся к PSA.

</details>

### 4. Зачем указывать `pod-security.kubernetes.io/enforce-version: v1.36`?

a. Чтобы закрепить версию PSS, по которой PSA оценивает `Pod`.

b. Чтобы включить шифрование трафика `Pod`.

c. Чтобы выдать контейнеру Linux capability `NET_ADMIN`.

d. Чтобы заменить Kubernetes на версию `v1.36`.

<details>
<summary>Ответ и разбор</summary>

**Верный ответ: a.** Version label фиксирует набор требований PSS и делает изменение правил при обновлении кластера управляемым. Она не меняет версию кластера, сеть или capabilities.

</details>

### 5. Какой механизм уместен для требования «разрешать только образы из внутреннего registry»?

a. `warn` PSA без дополнительных правил.

b. Только профиль `restricted` PSA.

c. Policy engine или admission policy, например Kyverno, Gatekeeper или ValidatingAdmissionPolicy.

d. `PodSecurityPolicy`.

<details>
<summary>Ответ и разбор</summary>

**Верный ответ: c.** PSA применяет лишь фиксированные PSS и не задаёт allowlist registry. PSP удалён, а `warn` не блокирует объект. Специфическое правило реализует отдельная admission-политика.

</details>

> **Куда дальше.** Для практического применения стандартов изучите [главу 19 CKS: Pod Security Admission и Pod Security Standards](../../../cks/course/19/ru.md), а для правил организации поверх PSS - [главу 20 CKS: admission-контроллеры и policy-движки](../../../cks/course/20/ru.md). Полезная база по полям контейнера есть в [главе 20 CKA: SecurityContext и capabilities](../../../cka/course/20/ru.md). Затем перейдите к [главе 12](../12/ru.md) о `Secret`.

[Оглавление](../README_RU.md) · [Глава 10](../10/ru.md) · [Глава 12](../12/ru.md)