<!-- Standalone RU release: ссылки на переводы удалены, потому что соответствующие файлы не входят в архив. -->

# Глава 20. Admission-контроллеры и policy-движки: OPA/Gatekeeper и Kyverno

> **Проблема.** RBAC может законно разрешить CI создать Deployment, но не проверяет, что образ
> взят из доверенного registry, у Pod нет опасных полей, а объект содержит обязательные
> организационные метки. Ручной review YAML легко обходится шаблоном, API-клиентом или ошибкой
> в pipeline; без policy объект попадёт в etcd и будет запущен. Admission-контроль должен
> проверить или безопасно дополнить такой запрос до его сохранения.

> **Что дальше.** Pod Security Admission из [главы 19](../19/ru.md) применяет готовые
> Pod Security Standards, но не отвечает на все правила организации: разрешён ли реестр
> образов, обязательна ли метка владельца, надо ли добавить безопасное поле или создать
> сопутствующий объект. Admission control - последний программируемый барьер перед записью
> объекта в etcd. Это часть домена **Minimize Microservice Vulnerabilities** CKS (20%):
> здесь строим собственные правила на OPA/Gatekeeper, Kyverno и встроенном CEL.

> **Что нужно знать из CKA.** Базовый путь запроса `authentication -> authorization ->
> admission -> etcd`, ServiceAccount и RBAC разобраны в
> [главе 21 CKA](../../../cka/course/21/ru.md); базовые ограничения контейнера - в
> [главе 20 CKA](../../../cka/course/20/ru.md). Здесь не повторяем эти механизмы, а
> превращаем требования безопасности в проверяемые cluster-wide policy.

> 🧠 Admission проверяет поля уже разрешённого API-запроса перед записью в etcd; RBAC не оценивает безопасность YAML.

## 20.1. Модель угроз: небезопасный манифест как вход в кластер

RBAC отвечает на вопрос, может ли identity создать Pod. Если разработчику разрешён
`create pods`, RBAC не проверяет, что именно находится в YAML. Поэтому в кластер могут
попасть `privileged`-контейнер, `hostPath: /`, образ из неизвестного registry, Pod без
`runAsNonRoot` или Deployment без метки владельца. Такой объект может быть полностью
разрешён RBAC, но всё равно нарушать security baseline.

Admission control получает уже аутентифицированный и авторизованный запрос, но до
сохранения. Mutating-контроллер может дополнить объект, validating-контроллер принимает
или отклоняет его. Если любой validating этап ответит отказом, объект в etcd не появится.

```mermaid
flowchart TB
    client["kubectl / CI<br/>/ controller"] --> authn["authentication<br/>кто отправил запрос"]
    authn --> authz["authorization<br/>/ RBAC<br/>можно ли выполнить verb"]
    authz --> mutate["mutating<br/>admission<br/>встроенные плагины /<br/>MAP / webhook"]
    mutate --> validate["validating<br/>admission<br/>PSA / VAP / webhook"]
    validate -->|"allow"| etcd["etcd"]
    validate -->|"deny"| rejected["запрос отклонён<br/>объект не создан"]

    subgraph api["Обработка объекта<br/>API server<br/>концептуально"]
        conversion["conversion, defaulting<br/>и API validation"]
    end
    authz -. "зависит от API<br/>и типа запроса" .-> conversion
    conversion -. "объект участвует<br/>в admission" .-> mutate
    conversion -. "объект участвует<br/>в admission" .-> validate

    style client fill:#326ce5,color:#fff
    style authn fill:#673ab7,color:#fff
    style authz fill:#673ab7,color:#fff
    style mutate fill:#f4b400,color:#000
    style conversion fill:#326ce5,color:#fff
    style validate fill:#f4b400,color:#000
    style etcd fill:#0f9d58,color:#fff
    style rejected fill:#db4437,color:#fff
```

Порядок admission важен: mutating-контроллеры выполняются до validating, поэтому
validating-policy видит получившийся объект. Conversion, defaulting и API validation на
диаграмме показаны как концептуальная обработка объекта, а не как один жёстко расположенный
этап: детали зависят от API и типа запроса. Встроенные admission plugins и webhooks имеют
свой порядок и могут вызываться повторно при изменении объекта другим mutating webhook.
Mutation должна быть идемпотентной: повторное применение не должно добавлять второй
одинаковый volume, label или sidecar.

| Слой | Вопрос | Пример |
|---|---|---|
| RBAC | кому можно `create pods`? | CI может создавать Pod только в `team-a` |
| PSA | соответствует ли Pod стандарту `baseline`/`restricted`? | запрещён privileged Pod в restricted namespace |
| custom policy | соответствует ли объект правилам организации? | образ только из `registry.example.com`; есть label `owner` |
| mutating policy | какой безопасный default добавить? | поставить `allowPrivilegeEscalation: false` |

PSA и policy engine не заменяют друг друга. PSA быстро и одинаково применяет стандартные
ограничения Pod. Gatekeeper, Kyverno или CEL закрывают специфические требования. Не
дублируйте одну и ту же жёсткую проверку в трёх местах без причины: отказ станет сложнее
диагностировать, а разные сообщения и исключения начнут расходиться.

> 🏭 `failurePolicy` определяет реакцию на **техническую или evaluation-ошибку** на admission webhook path, а не на явное policy-решение. Она применяется, например, при timeout, TLS/DNS/Service/Pod-ошибке, некорректном HTTP/AdmissionReview response, а также при ошибке вычисления `matchConditions`.
>
> `matchConditions` API server вычисляет **до** вызова webhook. Если хотя бы одно condition вернуло `false`, webhook штатно пропускается. Если ни одно не `false`, но хотя бы одно завершилось ошибкой, webhook не вызывается: при `Fail` API server отклоняет запрос, при `Ignore` продолжает его без этого webhook. Если webhook был успешно вызван и явно вернул `allowed: false`, запрос отклоняется и при `Fail`, и при `Ignore`.
>
> При `Fail` такая техническая/evaluation-ошибка тоже отклоняет create/update: policy нельзя молча обойти, но сбой webhook **или ошибка его `matchConditions`** может остановить deploy и часть операций control plane. Поэтому security-critical webhook должен быть надёжнее одного Pod: несколько replicas уменьшают риск отказа, PDB не даёт добровольному disruption удалить все replicas одновременно, корректный TLS обеспечивает доверенное HTTPS-соединение, а метрики и alerts по error/latency позволяют заметить деградацию до outage.
>
> При `Ignore` API остаётся доступным, но в момент такой ошибки объект проходит **без проверки этого webhook** — это сознательное окно обхода policy, а не режим «более мягкого deny». Для критичного зрелого запрета обычно выбирают `Fail`; `Ignore` может быть временным компромиссом на rollout или для некритичного контроля, если риск bypass принят явно.

## 20.2. Webhook: доступность тоже является security-решением

Gatekeeper и Kyverno обычно работают как admission webhook: `kube-apiserver` по HTTPS
отправляет им `AdmissionReview`, затем ждёт ответ `allowed: true/false` и возможные JSON
patches. У webhook есть два особенно важных параметра в `MutatingWebhookConfiguration` или
`ValidatingWebhookConfiguration`:

| Параметр | Значение для безопасности | Риск |
|---|---|---|
| `failurePolicy: Fail` | ошибка webhook path или `matchConditions` (если ни одно condition не `false`) отклоняет запрос | outage engine или ошибочное CEL condition блокирует deploy и иногда control plane operations |
| `failurePolicy: Ignore` | при такой ошибке API server продолжает запрос без этой webhook-проверки | окно обхода policy во время сбоя или ошибки condition |
| `timeoutSeconds` | ограничивает время ожидания API server | слишком большой timeout задерживает все create/update |
| `namespaceSelector`/`objectSelector` | сужает scope webhook | ошибочный selector может пропустить критичный namespace |
| `matchPolicy` | определяет сопоставление версий API | неожиданный match способен применить правило шире или уже |

Нельзя бездумно менять `failurePolicy` у webhook, установленного Helm chart: chart может
перезаписать изменение. Сначала проверьте, что engine имеет несколько replicas, PodDisruptionBudget,
TLS и alert на ошибки/latency. Новый запрет безопаснее вводить как audit/warn, исправить
существующие нарушения и только потом включить enforcement. Для критичного зрелого правила
обычно выбирают `Fail`; для первого rollout важнее не остановить кластер и не принять это за
доказательство работающей защиты.

Минимальная конфигурация webhook должна явно задавать endpoint, доверие TLS и контракт
`AdmissionReview`. Например, validating webhook ниже использует Service; для mutating
webhook структура аналогична, но добавьте `reinvocationPolicy: IfNeeded` или `Never` и
сделайте mutation идемпотентной. `caBundle` здесь сокращён: в рабочем manifest это
base64-кодированный CA сертификат webhook.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: require-owner.example.com
webhooks:
- name: require-owner.example.com
  clientConfig:
    service:
      namespace: policy-system
      name: policy-webhook
      path: /validate
      port: 443
    caBundle: <base64-ca>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["pods"]
    scope: "*"
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 5
  matchPolicy: Equivalent
  namespaceSelector:
    matchLabels:
      policy.example.com/enforce-owner: "true"
  matchConditions:
  - name: skip-kube-system
    expression: "request.namespace != 'kube-system'"
```

Custom namespace label в `namespaceSelector` — часть security boundary: identity, для которой правило обязательно, не должна иметь права удалить или изменить этот label. Для фиксированного scope безопаснее сопоставлять неизменяемый `kubernetes.io/metadata.name`; custom enforcement labels меняет только platform/security роль. То же относится к `objectSelector`: label, которым пользователь сам может изменить объект и выйти из scope, не подходит как deny-boundary.

```bash
SUBJECT='system:serviceaccount:team-a:ci'
NS='team-a'
kubectl auth can-i patch namespaces/"$NS" --as="$SUBJECT"
kubectl auth can-i update namespaces/"$NS" --as="$SUBJECT"
# Для application/CI identity оба ответа должны быть `no`.
```

Для mutating webhook к тому же контракту добавляется правило повторного вызова:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: default-security.example.com
webhooks:
- name: default-security.example.com
  clientConfig:
    service:
      namespace: policy-system
      name: policy-webhook
      path: /mutate
    caBundle: <base64-ca>
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
  reinvocationPolicy: IfNeeded
  failurePolicy: Fail
  timeoutSeconds: 5
```

```bash
# Какие webhook реально зарегистрированы и как они ведут себя при ошибке.
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations
kubectl get validatingwebhookconfiguration <name> -o yaml
kubectl -n gatekeeper-system get pods
kubectl -n kyverno get pods
```

Admission проверяет лишь запрос к API. Он не заменяет image scanning, runtime detection,
NetworkPolicy, RBAC и audit logs. Образ, разрешённый в admission, всё ещё должен пройти
supply-chain проверки из глав 25-28; уже запущенный процесс контролируют главы 29-32.

> 🎯 Свяжите `ConstraintTemplate` (code/schema) с `Constraint` (scope/параметры/`enforcementAction`), затем докажите `dryrun` → `deny`.
>
> В этом примере template объявляет тип `K8sRequiredLabels`, его Rego-проверку и допустимый параметр `labels`; constraint `pods-must-have-owner` — конкретный экземпляр этого типа. Проследите связь: `match` ограничивает Pod и исключённые namespaces, `parameters.labels: ["owner"]` передаёт Rego требование, а `enforcementAction` выбирает реакцию на найденное нарушение.
>
> Доказательство делайте новыми одноразовыми Pod: в `dryrun` создайте Pod без `owner`, убедитесь, что он принят API, затем дождитесь его записи в `status.violations`. После patch на `deny` попробуйте создать **другой** Pod без `owner`: API должен его отклонить. В качестве контрольного положительного сценария Pod с `owner` должен приниматься в обоих режимах. Не используйте для этого только существующий Pod или `--dry-run`: они не доказывают, что admission и audit отработали для нового объекта.

## 20.3. OPA/Gatekeeper: `ConstraintTemplate` и `Constraint`

**OPA** (Open Policy Agent) — движок, который умеет принимать policy-решения. **Gatekeeper**
подключает его к Kubernetes admission: когда кто-то пытается создать или изменить объект,
API server передаёт объект Gatekeeper для проверки. Если правило находит нарушение,
Gatekeeper сообщает результат — записать его как наблюдение, предупредить или отклонить
запрос. Для первого чтения не нужно уметь писать Rego или CEL: сначала важно понять,
**какое правило проверяется, где оно действует и что произойдёт при нарушении**.

Для этого Gatekeeper разделяет policy на два ресурса — это не дублирование, а возможность
написать правило один раз и применять его по-разному:

1. `ConstraintTemplate` — **шаблон/чертёж правила**. В нём хранится проверяющий код на
   Rego или CEL, целевой admission handler и OpenAPI schema разрешённых параметров. Schema
   проверяет параметры самого `Constraint`, а не Pod напрямую: например, что `labels` —
   список строк. После применения template Gatekeeper создаёт CRD (Custom Resource
   Definition) — то есть регистрирует в API Kubernetes новый вид ресурса для этого правила.
2. `Constraint` — **включённый экземпляр правила**. Он выбирает `match` scope (какие
   объекты и namespaces проверять), передаёт значения в `parameters` и задаёт
   `enforcementAction` — что делать при нарушении. Один template можно переиспользовать
   для разных команд, namespaces или наборов обязательных labels, создавая отдельный
   constraint для каждого случая.

Запомните flow: **template определяет правило → constraint настраивает и включает его →
создание/изменение объекта попадает в `match` → Gatekeeper запускает проверку с
`parameters` → `enforcementAction` определяет результат**. Это похоже на класс и экземпляр:
template содержит code, который требует review и тестов; constraint обычно меняют чаще,
когда расширяют охват policy. В одном target выбирайте один движок: у legacy `rego` выше
приоритет, а в `code[]` CEL (`K8sNativeValidation`) имеет приоритет над Rego.

### Установка и быстрая проверка Gatekeeper

Установку выполняют централизованно, а не во время экзаменационного задания. Для Helm
release сначала зафиксируйте версию chart в GitOps-манифесте и проверьте values конкретной
версии:

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
GATEKEEPER_CHART_VERSION="${GATEKEEPER_CHART_VERSION:?set exact chart version}"
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --version "$GATEKEEPER_CHART_VERSION"

kubectl -n gatekeeper-system get deploy,pods
kubectl get crd | grep -E 'gatekeeper|constraints.gatekeeper' 
```

Ниже policy требует label `owner` у Pod вне системных namespaces. Она компактнее, чем
проверка `privileged`, но показывает все части модели и даёт понятный отказ.

```yaml
# API Gatekeeper для переиспользуемого шаблона policy.
apiVersion: templates.gatekeeper.sh/v1
# Шаблон определяет новый тип constraint, но сам ещё не включает проверку.
kind: ConstraintTemplate
metadata:
  # Имя шаблона Kubernetes; обычно совпадает с именем Rego package.
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        # Kind ресурса Constraint, который Gatekeeper создаст из этого template.
        kind: K8sRequiredLabels
      validation:
        # Schema проверяет spec.parameters Constraint, а не incoming Pod.
        openAPIV3Schema:
          type: object
          properties:
            labels:
              # Constraint передаёт policy список обязательных label keys.
              type: array
              items:
                type: string
  targets:
  # Встроенный target, вызываемый на admission create/update запросах.
  - target: admission.k8s.gatekeeper.sh
    # Блок Rego, который возвращает violation при нарушении.
    rego: |
      # Namespace имён Rego policy.
      package k8srequiredlabels

      # Создать violation для каждого отсутствующего обязательного label.
      violation[{"msg": msg}] {
        # Берёт по одному значению из spec.parameters.labels Constraint.
        required := input.parameters.labels[_]
        # input.review.object — Pod из текущего admission request.
        not input.review.object.metadata.labels[required]
        # Сообщение появится в audit status или в отказе deny.
        msg := sprintf("missing required label: %v", [required])
      }
---
# API и kind экземпляра, созданного этим ConstraintTemplate.
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  # Уникальное имя конкретно включённой policy.
  name: pods-must-have-owner
spec:
  # Audit-only: записывать violation, но пока не блокировать Pod.
  enforcementAction: dryrun
  match:
    # Не применять правило к системным namespaces.
    excludedNamespaces: ["kube-system", "gatekeeper-system", "kyverno"]
    kinds:
    # Пустая API group означает core/v1 API.
    - apiGroups: [""]
      # Проверять только Pod, а не все Kubernetes-объекты.
      kinds: ["Pod"]
  parameters:
    # Значение для input.parameters.labels в Rego: label owner обязателен.
    labels: ["owner"]
```

#### Как читать эту policy

Сначала Gatekeeper смотрит на `match` в `Constraint`. Здесь он проверяет только Pod и
пропускает перечисленные системные namespaces; объект вне scope вообще не попадает в это
правило. Для каждого подходящего create/update Gatekeeper формирует `input.review.object`:
это incoming Pod в форме Kubernetes API. Одновременно он передаёт
`spec.parameters` constraint в `input.parameters`. Поэтому в данном примере
`input.parameters.labels` равно `["owner"]`.

В Rego правило — это набор условий, соединённых логическим **И**. Оно читается снизу
вверх как «создай violation, если все строки в теле выполнились»:

- `required := input.parameters.labels[_]` перебирает каждый обязательный label; `_`
  означает «очередной элемент массива». Здесь единственным значением станет `owner`.
- `not input.review.object.metadata.labels[required]` истинно, когда у incoming Pod нет
  этого ключа label.
- `msg := ...` формирует понятное сообщение, а `violation[{"msg": msg}]` — специальный
  результат, который Gatekeeper считает нарушением. При `dryrun` он попадёт в
  `status.violations`; при `deny` API server вернёт это сообщение и не создаст Pod.

Для первой policy достаточно помнить четыре идеи Rego: `input` — read-only входные данные,
`:=` сохраняет найденное значение в переменную, `[_]` перебирает список, `not` описывает
отсутствие/невыполнение условия. Не нужно писать отдельные `if/else`: если тело правила не
удаётся доказать, `violation` не создаётся. Эта policy проверяет **наличие** ключа `owner`;
если организации нужен непустой или форматированный value, это должно быть отдельным
условием.

#### Быстрый pattern для экзамена: scope namespace и запрет `latest`

Сначала переведите задачу в четыре поля: **что** проверять (Pod и image), **где**
(`match.namespaces`), **условие нарушения** (image использует `latest`) и **реакция**
(`dryrun`, затем `deny`). Для owner в одном namespace не нужен новый template: у
`K8sRequiredLabels` замените `excludedNamespaces` на `namespaces: ["team-a"]` и оставьте
`parameters.labels: ["owner"]`.

Для отдельного запрета `latest` шаблон ниже можно написать и применить как один файл. Он
проверяет обычные, init- и ephemeral containers: проверка только `spec.containers` оставила
бы bypass. Функция считает нарушением и явный `:latest`, и image без tag (например,
`nginx`, для которого Kubernetes подразумевает `latest`); digest `@sha256:...` не считается
latest.

```yaml
# API Gatekeeper для шаблона запрета latest image tag.
apiVersion: templates.gatekeeper.sh/v1
# Template содержит Rego; Constraint ниже выберет его scope и режим реакции.
kind: ConstraintTemplate
metadata:
  # Имя template Kubernetes.
  name: k8sdisallowlatest
spec:
  crd:
    spec:
      names:
        # Kind Constraint, который будет использовать этот template.
        kind: K8sDisallowLatest
      validation:
        # У этой policy нет настраиваемых parameters, но schema всё равно описывает object.
        openAPIV3Schema:
          type: object
          properties: {}
  targets:
  # Подключить проверку к Gatekeeper admission handler.
  - target: admission.k8s.gatekeeper.sh
    rego: |
      # Namespace имён Rego policy.
      package k8sdisallowlatest

      # Собрать контейнеры из всех трёх списков PodSpec, чтобы не оставить bypass.
      pod_containers[container] {
        container := input.review.object.spec.containers[_]
      }
      pod_containers[container] {
        container := input.review.object.spec.initContainers[_]
      }
      pod_containers[container] {
        container := input.review.object.spec.ephemeralContainers[_]
      }

      # Явный tag :latest запрещён.
      image_uses_latest(image) {
        endswith(image, ":latest")
      }
      # Image без tag (например nginx) Kubernetes трактует как latest; digest разрешён.
      image_uses_latest(image) {
        not contains(image, "@")
        path := split(image, "/")
        last := path[count(path) - 1]
        not contains(last, ":")
      }

      # Вернуть Gatekeeper violation для каждого контейнера с latest image.
      violation[{"msg": msg}] {
        container := pod_containers[_]
        image_uses_latest(container.image)
        msg := sprintf("image %q must not use the latest tag", [container.image])
      }
---
# Экземпляр template: включает запрет только для выбранного scope.
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDisallowLatest
metadata:
  # Уникальное имя policy с namespace-specific scope.
  name: pods-without-latest-in-team-a
spec:
  # Начать с audit; после проверки заменить на deny.
  enforcementAction: dryrun
  match:
    # Scope: policy применяется только к Pod в namespace team-a.
    namespaces: ["team-a"]
    kinds:
    # Core/v1 API group.
    - apiGroups: [""]
      # Проверять именно Pod admission requests.
      kinds: ["Pod"]
```

На экзамене не пытайтесь сначала сделать универсальный framework: берите минимальный
`ConstraintTemplate`, задавайте точный `kind`/`match` и одно условие `violation`. Затем
проверьте отрицательный и положительный случаи: в `team-a` Pod с `nginx:latest` должен
сначала появиться в violations, после перехода на `deny` — быть отклонён, а Pod с
`nginx:1.27` — пройти. Проверяйте scope отдельно: та же попытка вне `team-a` не должна
совпасть с этим constraint.

```bash
kubectl apply -f gatekeeper-owner.yaml
kubectl get constrainttemplates
kubectl get k8srequiredlabels
kubectl describe k8srequiredlabels pods-must-have-owner
```

`enforcementAction: dryrun` собирает нарушения в `status.violations`, но не блокирует
запрос. После исправления уже существующих Pod и проверки scope замените его на `deny`.
Некоторые версии Gatekeeper также поддерживают action `warn`; точные доступные действия
проверяйте по установленному CRD, а не по случайному примеру из другой версии.

```bash
kubectl get k8srequiredlabels pods-must-have-owner \
  -o jsonpath='{range .status.violations[*]}{.kind}/{.name}{": "}{.message}{"\n"}{end}'

# Только после audit и исправления workload.
kubectl patch k8srequiredlabels pods-must-have-owner --type merge \
  -p '{"spec":{"enforcementAction":"deny"}}'
```

### Пример Gatekeeper для опасного `privileged`

Для security-critical запрета template должен проверять обычные, `initContainers` и
`ephemeralContainers`; иначе один из списков остаётся bypass-путём.

```rego
package k8sdisallowprivileged

violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("privileged container %q is not allowed", [container.name])
}

violation[{"msg": msg}] {
  container := input.review.object.spec.initContainers[_]
  container.securityContext.privileged == true
  msg := sprintf("privileged initContainer %q is not allowed", [container.name])
}

violation[{"msg": msg}] {
  container := input.review.object.spec.ephemeralContainers[_]
  container.securityContext.privileged == true
  msg := sprintf("privileged ephemeralContainer %q is not allowed", [container.name])
}
```

Условие `container.securityContext.privileged == true` не срабатывает для отсутствующего
поля, то есть default `false` допускается. PSA `restricted` уже покрывает этот класс
требований - используйте custom Rego только когда нужны свои scope, исключения или
расширенная логика.

> 🔬 Kyverno CEL API для validation, mutation, generation и других admission-сценариев.

## 20.4. Kyverno 1.19: CEL-based policy types

> **Compatibility note.** Kyverno v1.19 официально поддерживает Kubernetes v1.33-v1.35
> (`kyverno.io/docs/installation/releases/`, released Aug 2026). Core-лаба этой главы
> (Lab108) выполняется на Kubernetes v1.36 - это осознанная forward-looking комбинация,
> которая **не входит** в протестированную и гарантированную support matrix Kyverno v1.19.
> Установка и базовые сценарии обычно работают, но именно эта пара версий не покрыта
> officially tested compatibility, поэтому не считайте успешную установку доказательством
> полной поддержки v1.36. Для подготовки к текущему экзамену (ориентированному на v1.35)
> сверьте поведение отдельно на v1.35, где Kyverno v1.19 официально протестирован.
> Compatibility third-party admission-компонентов (Kyverno, Gatekeeper и аналоги)
> необходимо сверять с их собственной release matrix отдельно от версии Kubernetes курса.

### Как читать Kyverno CEL policy

Kyverno — Kubernetes policy engine: его controllers и admission webhook читают policy
ресурсы из API и реагируют на операции с объектами. В новых CEL-based типах policy — это
обычный YAML-ресурс, а CEL — короткий язык выражений внутри поля `expression`. Он не
заменяет YAML и не является shell-скриптом: выражение получает входные данные, например
`object` — объект текущего admission request, — и вычисляет значение.

Для первого чтения проходите каждый пример по одному flow: **какая операция и resource
совпадают с `matchConstraints` → какие дополнительные условия проходят → что делает policy**.
`ValidatingPolicy` вычисляет булево expression: `true` разрешает объект, `false` создаёт
нарушение; действие `Audit` только фиксирует его, а `Deny` отклоняет запрос.
`MutatingPolicy` возвращает изменение объекта до его сохранения. `GeneratingPolicy` просит
background controller создать или синхронизировать другой объект после совпадения source
resource. Поэтому generation не является мгновенным admission deny.

Сначала выбирайте тип по результату, а не по синтаксису CEL: `ValidatingPolicy` — проверить
и при необходимости запретить, `MutatingPolicy` — добавить безопасный default,
`GeneratingPolicy` — создать связанный ресурс, `DeletingPolicy` — удалить по rule,
`ImageValidatingPolicy` — проверить image. Cluster-wide типы действуют по заданному scope;
`Namespaced...` варианты живут и действуют только в своём namespace. Не смешивайте эти
ресурсы с legacy `Policy`/`ClusterPolicy`: у них другой API и другие поля.

Начиная с Kyverno 1.19 основной путь - отдельные CEL-based cluster-wide типы группы
`policies.kyverno.io/v1`: `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`,
`DeletingPolicy` и `ImageValidatingPolicy`. Для каждого есть namespaced-вариант
`NamespacedValidatingPolicy`, `NamespacedMutatingPolicy`, `NamespacedGeneratingPolicy`,
`NamespacedDeletingPolicy` или `NamespacedImageValidatingPolicy`, действующий только в
своём namespace. Legacy `Policy` и `ClusterPolicy` (`kyverno.io/v1`), а также
`CleanupPolicy` (`kyverno.io/v2`) deprecated в 1.19 и будут удалены в 1.20. Не смешивайте
поля двух моделей в одном объекте.

В курсе проверена связка Kyverno `v1.19.x` и Helm chart `3.9.0`. После установки проверьте
именно новые CRD и фактический image контроллера:

```bash
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno --create-namespace --version 3.9.0
kubectl get crd validatingpolicies.policies.kyverno.io \
  mutatingpolicies.policies.kyverno.io \
  generatingpolicies.policies.kyverno.io \
  deletingpolicies.policies.kyverno.io \
  imagevalidatingpolicies.policies.kyverno.io
kubectl -n kyverno get deploy -o jsonpath='{..image}'
```

### `ValidatingPolicy`: требовать `runAsNonRoot`

`ValidatingPolicy` ничего не меняет: она отвечает на вопрос «можно ли принять этот объект?».
Сначала policy совпадает с create/update Pod, затем CEL получает Pod как `object`.
Expression должен вернуть `true`, иначе Kyverno создаёт violation с полем `message`.
`Audit` позволяет запрос и собирает результат для исправления manifests; после проверки
реального scope переключайте на `Deny`, который отклонит такой Pod. Проверка ниже требует
явный pod-level baseline; она не заменяет полный PSS `restricted`.

```yaml
# API новой CEL-based Kyverno policy.
apiVersion: policies.kyverno.io/v1
# Validation не изменяет объект: она разрешает или фиксирует/отклоняет нарушение.
kind: ValidatingPolicy
metadata:
  # Уникальное имя policy в кластере.
  name: require-pod-run-as-non-root
spec:
  # Сначала audit-only: запрос не блокируется, violation можно изучить.
  validationActions: [Audit]
  matchConstraints:
    resourceRules:
    # Core/v1 Pod; проверять и создание, и последующие изменения.
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  # Для каждого совпавшего Pod expression должен вернуть true.
  - message: "Pod spec.securityContext.runAsNonRoot must be true"
    expression: >-
      // has предотвращает обращение к отсутствующему securityContext.
      has(object.spec.securityContext) &&
      // ? безопасно читает optional field; отсутствие или false даёт false.
      object.spec.securityContext.?runAsNonRoot.orValue(false)
```

```bash
kubectl apply -f kyverno-run-as-non-root.yaml
kubectl get validatingpolicy require-pod-run-as-non-root
kubectl patch validatingpolicy require-pod-run-as-non-root --type merge \
  -p '{"spec":{"validationActions":["Deny"]}}'
```

### `MutatingPolicy`: прозрачная маркировка

`MutatingPolicy` отвечает не «разрешить или запретить», а «какой безопасный default
добавить к уже принятому объекту». Она срабатывает после match, строит изменённый fragment
объекта и API server сохраняет результат. Mutation не должна маскировать небезопасный image:
для security-critical полей чаще лучше явная validation. Безопасный учебный пример добавляет
только audit-label. `ApplyConfiguration` означает, что CEL строит желаемый fragment в виде
`Object{...}`, а Kyverno применяет его вместо legacy `patchStrategicMerge`:

```yaml
# API CEL-based Kyverno policy, которая изменяет объект до сохранения.
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  # Имя policy, добавляющей traceable audit label.
  name: mark-kyverno-managed-pods
spec:
  matchConstraints:
    resourceRules:
    # Менять только новые core/v1 Pod, а не все ресурсы.
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["pods"]
  mutations:
  # ApplyConfiguration применяет CEL-constructed fragment к incoming object.
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        // Object{...} — CEL representation желаемого fragment Kubernetes object.
        Object{
          metadata: Object.metadata{
            // Добавляем label, не заменяя остальные metadata.labels.
            labels: {"security.example.com/policy": "kyverno"}
          }
        }
```

### `GeneratingPolicy`: default-deny для нового Namespace

`GeneratingPolicy` реагирует на source object и просит отдельный background controller
создать downstream resource. В этом примере source — новый Namespace, а результат —
`NetworkPolicy` внутри него. YAML template остаётся читаемым, а CEL вычисляет и подставляет
имя Namespace. При `synchronize.enabled: true` Kyverno продолжает сверять и синхронизировать
сгенерированный объект с policy. Это не утверждение о Kubernetes `ownerReferences` и не
заменяет явного распределения ответственности: не поручайте GitOps-controller и Kyverno
одновременно синхронизировать один и тот же объект.

```yaml
# API CEL-based policy, которая создаёт/синхронизирует downstream resource.
apiVersion: policies.kyverno.io/v1
kind: GeneratingPolicy
metadata:
  # Имя policy для NetworkPolicy нового Namespace.
  name: generate-default-deny-ingress
spec:
  evaluation:
    synchronize:
      # Background controller продолжает сверять generated NetworkPolicy с template.
      enabled: true
  matchConstraints:
    resourceRules:
    # Trigger — создание core/v1 Namespace.
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["namespaces"]
  matchConditions:
  # Не генерировать policy в системных namespaces.
  - name: skip-system-namespaces
    expression: >-
      !(object.metadata.name in
      ["kube-system", "kube-public", "kube-node-lease", "kyverno"])
  variables:
  # Сохранить имя source Namespace для использования внутри YAML template.
  - name: namespaceName
    expression: object.metadata.name
  generate:
  - template:
      # Подставить CEL variable в YAML между (( ... )).
      interpolate: cel
      value: |
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          # Фиксированное имя downstream NetworkPolicy.
          name: default-deny-ingress
          # Создать её в том Namespace, который вызвал policy.
          namespace: (( variables.namespaceName ))
          labels:
            # Позволяет определить владельца generated object.
            app.kubernetes.io/managed-by: kyverno
        spec:
          # Пустой selector охватывает все Pod Namespace.
          podSelector: {}
          # Default deny только ingress; egress задаётся отдельно.
          policyTypes: [Ingress]
```

Это только ingress default deny. Egress, DNS и разрешённые связи задавайте отдельными
`NetworkPolicy` - см. [главу 04](../04/ru.md).

`GeneratingPolicy` — provisioning/reconciliation mechanism, а не атомарный admission barrier: Namespace создаётся раньше, чем background controller гарантированно создаст downstream `NetworkPolicy`. До передачи namespace workload identity подтвердите фактический baseline, например `kubectl -n <new-namespace> get networkpolicy default-deny-ingress`; наличие самой `GeneratingPolicy` этого не доказывает.

Перед использованием generation проверьте права фактического ServiceAccount background controller на целевой ресурс. Для `synchronize.enabled: true` нужны и read/watch, и управление downstream resource; все шесть проверок ниже должны вернуть `yes`:

```bash
KYVERNO_BG='system:serviceaccount:kyverno:kyverno-background-controller'
for verb in get list watch create update delete; do
  kubectl auth can-i "$verb" networkpolicies.networking.k8s.io \
    --all-namespaces --as="$KYVERNO_BG"
done
```

### Миграция legacy policy

Инвентаризируйте legacy ресурсы командой
`kubectl get policies.kyverno.io,clusterpolicies.kyverno.io` (или `kubectl get pol,cpol`),
а также `CleanupPolicy`, зафиксируйте поведение положительными и отрицательными тестами.
Перенесите validate/mutate/generate/delete/image rules в соответствующий новый тип и удалите
legacy объект только после проверки admission и background reports. Для production сверяйте
[руководство миграции Kyverno](https://kyverno.io/docs/guides/migration-to-cel/)
с установленной minor-версией.

> 🏭 Выбор engine зависит от владения policy, языка, CI и webhook; не дублируйте deny-контроль без причины.

## 20.5. Gatekeeper и Kyverno: что выбрать

Оба движка могут deny небезопасный Pod, собирать audit-нарушения и работать через
admission webhook. Различается язык, модель и удобство конкретного правила.

| Критерий | Gatekeeper / OPA | Kyverno |
|---|---|---|
| Язык проверки | Rego или CEL в `ConstraintTemplate` | CEL и YAML templates |
| Модель ресурса | `ConstraintTemplate` с Rego/CEL + `Constraint` | отдельные CEL-based policy types, включая namespaced variants |
| Validate | да | да |
| Mutate | отдельные mutator resources, возможности зависят от версии | `MutatingPolicy` |
| Generate | не основной сценарий | `GeneratingPolicy` |
| Delete / cleanup | не основной сценарий | `DeletingPolicy` |
| Сложная логика и внешнее использование OPA | сильная сторона Rego | возможна, но YAML читается проще для K8s policy |
| Порог для команды, привыкшей к Kubernetes YAML | выше | ниже |

Выбор не означает, что другой инструмент хуже. Если организация уже использует OPA для
Terraform, API gateway и CI, Gatekeeper уменьшает число языков policy. Если нужны mutation,
generation и review в привычном Kubernetes YAML, Kyverno часто проще. Не устанавливайте
оба только ради одинаковых правил: два webhook увеличивают latency, эксплуатационную
поверхность и риск противоречивых отказов. Допустимо разделение ответственности, если оно
документировано: например, Gatekeeper для сложных Rego constraints, Kyverno для mutation и
image verification.

В обоих случаях policy - код: храните `ConstraintTemplate`/`Constraint` или CEL-based
Kyverno policy в Git, назначайте владельца и тесты, применяйте в staging, начинайте с
audit/warn и сохраняйте evidence нарушений. До кластера добавьте CI mini-lab с разрешённым
и запрещённым fixture. Для Gatekeeper используйте декларативные Suite/Test/Case
(`apiVersion: test.gatekeeper.sh/v1alpha1`, `kind: Suite`), а не прямой `gator test` denied
fixture: у deny Constraint найденное нарушение даёт `gator test` exit code 1, хотя policy
работает правильно. Kyverno проверяйте через `kyverno test --require-tests`, чтобы отсутствие
test manifest не давало зелёный pipeline. CI должен завершаться ошибкой, если allowed manifest
отклонён или denied manifest принят. Исключение должно быть узким, ограниченным по времени и
видимым в review - не глобальным `excludedNamespaces: ["*"]`.

> 🏭 CI fixtures должны принять разрешённый и отклонить запрещённый объект до admission в кластере.

### CI mini-lab: проверка policy до rollout

Положительный и отрицательный manifests должны жить рядом с policy в Git. Сохраните template
и constraint в `templates-and-constraints/template.yaml` и
`templates-and-constraints/constraint.yaml`, fixtures — в `allowed.yaml` и `denied.yaml`, а
рядом создайте `suite.yaml`:

```yaml
apiVersion: test.gatekeeper.sh/v1alpha1
kind: Suite
tests:
- name: require-owner
  template: templates-and-constraints/template.yaml
  constraint: templates-and-constraints/constraint.yaml
  cases:
  - name: allowed-has-owner
    object: allowed.yaml
    assertions:
    - violations: no
  - name: denied-missing-owner
    object: denied.yaml
    assertions:
    - violations: yes
```

```bash
# Оба ожидаемых результата дают успешный exit code: deny fixture обязан иметь violation.
gator verify suite.yaml                    # либо: gator verify ./...

# Kyverno: pipeline падает, если kyverno-test.yaml не найден.
kyverno test --require-tests ./policy/kyverno
```

`gator verify` рассматривает `violations: no` для allowed и `violations: yes` для denied как
ожидаемые assertions, поэтому job станет красным лишь при регрессии policy или fixtures.
Используйте команды и структуру файлов, соответствующие закреплённой версии CLI; cluster
admission test остаётся отдельным этапом интеграционного CI.

> 🔬 Native CEL выполняется в API server без webhook, но не покрывает generation, reports, signature verification и сложную Rego-логику.

## 20.6. Native CEL: validation и mutation без внешнего webhook

`ValidatingAdmissionPolicy` (VAP) и `ValidatingAdmissionPolicyBinding` задают встроенную
validation на CEL. В Kubernetes 1.36 `MutatingAdmissionPolicy` (MAP) и
`MutatingAdmissionPolicyBinding` стали stable и включены по умолчанию. MAP - это
in-process mutation внутри API server: CEL возвращает либо `ApplyConfiguration`, который
сливается по правилам server-side apply, либо `JSONPatch`. Для обоих native API binding
обязателен: именно он привязывает policy к scope, а без binding policy не действует.

VAP остаётся только validating-механизмом: он не меняет и не генерирует объекты. В связке
VAP + MAP native stack уже умеет mutation и validation без webhook, но не заменяет engine
для generate, policy reports, image signature verification, сложных внешних данных или
Rego.

### `MutatingAdmissionPolicy`: добавить безопасную метку в ограниченном scope

Пример ниже применяется только к Pod в namespace с label
`policy.example.com/native-mutation=true`. `ApplyConfiguration` удобен для добавления
поля; для точных операций над массивами или путями используйте `JSONPatch` с CEL-списком
`JSONPatch{...}`. `spec.reinvocationPolicy` обязателен: `Never` не вызывает MAP повторно,
а `IfNeeded` допускает повторную оценку после mutation других admission-этапов. Порядок с
другими mutating plugins/webhooks не гарантирован, поэтому mutation должна быть
идемпотентной. Не применяйте mutation как замену обязательной security validation.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionPolicy
metadata:
  name: add-native-admission-label
spec:
  failurePolicy: Fail
  reinvocationPolicy: IfNeeded
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE"]
      resources: ["pods"]
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        Object{
          metadata: Object.metadata{
            labels: {"admission.example.com/mutated": "true"}
          }
        }
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingAdmissionPolicyBinding
metadata:
  name: add-native-admission-label
spec:
  policyName: add-native-admission-label
  matchResources:
    namespaceSelector:
      matchLabels:
        policy.example.com/native-mutation: "true"
```

Практика должна проверить и scope, и его отрицательную границу. Сохраните YAML выше как
`map-add-label.yaml`, затем выполните:

```bash
kubectl apply -f map-add-label.yaml
kubectl create namespace native-map-on
kubectl label namespace native-map-on policy.example.com/native-mutation=true
kubectl create namespace native-map-off

cat <<'EOF' >/tmp/native-map-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: native-map-test
spec:
  containers:
  - name: pause
    image: registry.k8s.io/pause:3.10
EOF

# Scope binding совпал: server-side dry-run возвращает добавленную метку.
kubectl -n native-map-on create --dry-run=server -o yaml -f /tmp/native-map-pod.yaml

# Отрицательный тест binding: в namespace без selector-метки mutation отсутствует.
if kubectl -n native-map-off create --dry-run=server -o yaml \
  -f /tmp/native-map-pod.yaml | grep -q 'admission.example.com/mutated: "true"'; then
  echo "MAP применился вне scope"
  exit 1
fi
```

### `ValidatingAdmissionPolicy`: требовать effective non-root

VAP должен проверять effective-настройку каждого процесса, а не только Pod-level default:
container-level `securityContext.runAsNonRoot` имеет приоритет. Выражение ниже допускает
container-level `true` либо отсутствие этого поля при Pod-level `true`, но отклоняет явный
`false` и `runAsUser: 0` как на Pod-level, так и у обычных, init- и ephemeral containers.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-pod-run-as-non-root
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  variables:
  - name: podRunAsNonRoot
    expression: >-
      has(object.spec.securityContext) &&
      has(object.spec.securityContext.runAsNonRoot) &&
      object.spec.securityContext.runAsNonRoot == true
  - name: allContainers
    expression: >-
      object.spec.containers +
      (has(object.spec.initContainers) ? object.spec.initContainers : []) +
      (has(object.spec.ephemeralContainers) ? object.spec.ephemeralContainers : [])
  validations:
  - expression: >-
      !has(object.spec.securityContext) ||
      !has(object.spec.securityContext.runAsUser) ||
      object.spec.securityContext.runAsUser != 0
    message: "Pod-level runAsUser: 0 is forbidden"
  - expression: >-
      variables.allContainers.all(c,
        (!has(c.securityContext) || !has(c.securityContext.runAsUser) ||
          c.securityContext.runAsUser != 0) &&
        ((has(c.securityContext) && has(c.securityContext.runAsNonRoot)) ?
          c.securityContext.runAsNonRoot == true : variables.podRunAsNonRoot)
      )
    message: "Every app, init and ephemeral container must effectively run non-root; runAsUser: 0 is forbidden"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-pod-run-as-non-root
spec:
  policyName: require-pod-run-as-non-root
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        policy.example.com/enforce-non-root: "true"
```

`object` в CEL - проверяемый объект; также доступны контекст запроса, `oldObject` и
параметры binding. `failurePolicy` VAP/MAP относится к ошибке оценки policy, а не к
доступности сети: внешнего webhook здесь нет. Не публикуйте непроверенное CEL выражение
сразу с `Deny` на весь кластер: сузьте selector, начните с `Audit`/`Warn` и проверьте
положительный и отрицательный случаи.

```bash
kubectl apply -f vap-run-as-non-root.yaml
kubectl label namespace team-example policy.example.com/enforce-non-root=true
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
kubectl get mutatingadmissionpolicy,mutatingadmissionpolicybinding
```

### Параметризованный VAP: policy logic отдельно от лимита команды

`paramKind` определяет тип parameter resource, binding выбирает конкретный объект через
`paramRef`, а CEL получает его как `params`. Здесь один `ConfigMap` ограничивает replicas;
`matchConditions` не оценивает policy для запросов kubelet.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deployment-replica-limit
spec:
  failurePolicy: Fail
  paramKind:
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  matchConditions:
  - name: exclude-kubelet
    expression: '!("system:nodes" in request.userInfo.groups)'
  variables:
  - name: limit
    expression: 'int(params.data["maxReplicas"])'
  validations:
  - expression: "params != null && object.spec.replicas <= variables.limit"
    message: "replicas exceed the team limit"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: team-a-replica-limit
  namespace: policy-system
data:
  maxReplicas: "5"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deployment-replica-limit-team-a
spec:
  policyName: deployment-replica-limit
  validationActions: [Deny]
  paramRef:
    name: team-a-replica-limit
    namespace: policy-system
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        team: a
```

Один policy может иметь несколько bindings и parameter resources для разных команд; все
совпавшие combinations должны пройти. `parameterNotFoundAction: Deny` вместе с
`failurePolicy: Fail` не превращает отсутствующую конфигурацию в bypass.

VAP выполняет authorization check parameter resource: matched requester должен иметь `read`
доступ к `paramKind`/`paramRef`, иначе корректный запрос может быть отклонён. Перед `Deny`
проверьте реальную identity; давайте ей только `get`, а не право менять parameter, и не
храните security-sensitive данные в ConfigMap, который должны читать workload identities.

```bash
SUBJECT='system:serviceaccount:team-a:ci'
kubectl auth can-i get configmap/team-a-replica-limit   -n policy-system --as="$SUBJECT"
```

> 🔬 **Deep Dive — Manifest-Based Admission Control.** В training baseline Kubernetes v1.36 функция Alpha и выключена по умолчанию. В upstream Kubernetes v1.37 она перешла в Beta и enabled by default. Основной workflow этой главы остаётся привязан к v1.36; production-current delta см. в [Kubernetes v1.37 Security Delta](../APPENDIX_K8S_137_SECURITY_DELTA_RU.md).
>
> В v1.36 включите feature gate `ManifestBasedAdmissionControlConfig`; функция загружает webhook и CEL policy manifests с диска API server. Передайте через
> `--admission-control-config-file` `AdmissionConfiguration` с отдельным абсолютным
> `staticManifestsDir` для нужного admission plugin. Такие policies активны при старте,
> независимы от etcd и могут защищать API-based admission configuration от удаления или
> изменения. Это экспериментальная control-plane функция: `metadata.name` **каждого** static
> admission object в v1.36 обязан оканчиваться на `.static.k8s.io`; невалидный static manifest
> при первоначальной загрузке способен не дать API server стать ready. Static manifests
> ограничены поддерживаемыми admission resources; policy не могут использовать `paramKind`, а
> у `ValidatingAdmissionPolicyBinding` и `MutatingAdmissionPolicyBinding` запрещён
> `spec.paramRef`. Static webhook допускает `clientConfig.url`, но не
> `clientConfig.service`. Каждый HA API server должен получать одинаковые файлы; не вводите
> эту функцию без теста startup/reload и управляемой доставки конфигурации.

### Сравнение native CEL и webhook engine

| Возможность | VAP | MAP + VAP native stack | Gatekeeper / Kyverno webhook |
|---|---|---|---|
| Где исполняется | внутри API server | внутри API server | отдельные controller/webhook Pod |
| Сетевой отказ webhook | отсутствует | отсутствует | зависит от доступности и `failurePolicy` |
| Validate | да | да | да |
| Mutate | нет | да, `ApplyConfiguration` или `JSONPatch` | Kyverno - да; Gatekeeper - отдельные mutator resources |
| Generate / reports / signature verification | нет | нет | доступны в зависимости от engine |
| Сложная логика | ограничена CEL и API context | ограничена CEL и API context | Rego или policy engine features |
| Жизненный цикл | upstream Kubernetes API | upstream Kubernetes API | отдельная установка, обновление и CRD |

Native CEL - хорошая первая опция для небольшой чистой validation или mutation. Engine
оправдан, когда требуются generation, signature verification, policy reports или общая
policy-платформа. В обоих вариантах обязательны scope, положительный и отрицательный тест,
а также план rollout.

> 🎯 Допустимый manifest принят, нарушающий отклонён; для mutation сравните объект с результатом server-side dry-run.

## 20.7. Проверка: доказать allow, deny и mutation

Проверка policy состоит не из `kubectl apply` без ошибки, а из двух контролируемых
сценариев: корректный объект принят, нарушающий - отклонён с понятной причиной. Применяйте
такие проверки только в test namespace, поскольку `Deny` намеренно меняет admission.

```bash
kubectl create namespace admission-test
kubectl label namespace admission-test policy.example.com/enforce-non-root=true

cat <<'EOF' | kubectl -n admission-test apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: allowed-non-root
  labels:
    owner: platform
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: nginx
    image: nginxinc/nginx-unprivileged:1.30.4-alpine-slim
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    ports:
    - containerPort: 8080
EOF

cat <<'EOF' | kubectl -n admission-test apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rejected-root-default
  labels:
    owner: platform
spec:
  containers:
  - name: nginx
    image: nginx:1.30.4
EOF
# Ожидается: admission webhook или ValidatingAdmissionPolicy ... denied the request
```

После `Enforce` в Kyverno нарушение ищут в ответе API и policy report, если reports
включены. У Gatekeeper проверяют `status.violations` Constraint и сообщение отказа. У VAP
достаточно статуса policy/binding и отказа API server; у MAP дополнительно сравнивают объект
из server-side dry-run с исходным и проверяют отрицательный scope binding.

```bash
kubectl get events -n admission-test --sort-by=.lastTimestamp
kubectl get policyreport -A 2>/dev/null || true
kubectl get k8srequiredlabels pods-must-have-owner -o yaml
kubectl get validatingadmissionpolicy require-pod-run-as-non-root -o yaml
```

Если разрешённый Pod не создаётся, сначала определите источник отказа, а не отключайте все
policy: прочитайте сообщение `kubectl`, event, `kubectl describe` и логи конкретного
controller. Затем сверяйте selector, `match`/`exclude`, namespace labels и actual object
после mutation. Если policy не сработала, проверьте, что webhook/engine healthy, правило
покрывает API version и kind, а тестовый объект не исключён по namespace или label.

> 🏭 Rollout: узкий scope → `Audit`/`dryrun`/`Warn` → remediation → `Deny`/`Enforce`.

## 20.8. Типичные ошибки и безопасный rollout

| Ошибка | Последствие | Безопасный подход |
|---|---|---|
| Сразу включить `Deny`/`Enforce` на все namespaces | блокируются legacy workload и system components | audit/warn -> список нарушений -> remediation -> enforcement |
| Исключить `kube-system`, но не собственный namespace engine | engine может заблокировать самого себя | явно исключить только требуемые system namespaces |
| Проверять только `containers` | обход через `initContainers` или `ephemeralContainers` | покрыть все container lists либо использовать PSA |
| Использовать mutation вместо security requirement | YAML выглядит безопасным, но образ/архитектура остаются неподходящими | mutate только безопасные defaults; обязательные инварианты validate |
| `failurePolicy: Ignore` навсегда | при outage policy обходится | alert, HA, контроль rollout, затем осознанный `Fail` для критичных правил |
| Полагаться на `Audit` как на запрет | нарушающий объект всё равно запускается | применять `Audit` лишь как этап миграции |
| Одновременно завести одинаковый deny в PSA, Gatekeeper и Kyverno | дублирующие ошибки и сложная поддержка | назначить одному слою владельца каждого требования |
| Включить `synchronize.enabled: true` без распределения ответственности | Kyverno продолжает синхронизацию объекта, а GitOps может с ним конфликтовать | документировать, какой controller синхронизирует ресурс; это не вопрос `ownerReferences` |

Перед обновлением Gatekeeper/Kyverno проверяйте CRD migration, compatibility с Kubernetes
v1.36, certificate rotation, resource requests/limits и PDB. Admission outage - incident:
заранее определите, кто может временно сузить scope или откатить release, и логируйте это
изменение через GitOps/audit.

> 🏭 Policy as code: владелец, Git review, fixtures, CI, узкие исключения, admission-метрики и проверяемый rollout.

## 20.9. Как это применяют в продакшене

- **Слои вместо единственного запрета.** PSA `restricted` задаёт массовый baseline;
  custom policy добавляет бизнес-правила: approved registry, owner/cost labels,
  `resources.requests`, signature verification. RBAC по-прежнему ограничивает, кто может
  создавать объекты.
- **Policy as code.** Храните templates, constraints, policies, test fixtures и
  исключения в репозитории. Code review должен видеть и положительный, и отрицательный
  пример, а CI - проверять policy до cluster rollout.
- **Постепенное включение.** Начните с одного namespace, `Audit`/`dryrun`/`Warn`, соберите
  real violations, помогите командам исправить manifests и лишь затем включайте
  `Enforce`/`Deny`.
- **Наблюдаемость admission.** Собирайте latency/error metrics webhook, число violations,
  API server audit events и alerts на отсутствие ready replicas. Проверяйте policy после
  обновления Kubernetes и engine.
- **Минимальные исключения.** Исключение задают на конкретный namespace, service account,
  RuntimeClass или approved image, с владельцем и сроком. Не используйте broad bypass для
  «починки» одного deployment.

## 20.10. Мини-глоссарий

- **Admission control** - этап API server после authentication и authorization, до записи
  объекта в etcd.
- **Mutating admission webhook** - webhook, который добавляет/изменяет объект до validation.
- **Validating admission webhook** - webhook, который разрешает либо отклоняет объект.
- **OPA** - Open Policy Agent, движок policy на Rego.
- **Gatekeeper** - Kubernetes policy engine на OPA с моделью `ConstraintTemplate` +
  `Constraint`.
- **ConstraintTemplate** - Rego или CEL policy code и schema параметров для нового
  constraint type.
- **Constraint** - экземпляр Gatekeeper template с параметрами, match scope и реакцией.
- **Kyverno** - Kubernetes-native policy engine; в 1.19 основной API использует
  `ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`, `DeletingPolicy` и
  `ImageValidatingPolicy`, а также их namespaced-варианты.
- **ValidatingAdmissionPolicy** - встроенная API server validation на CEL без внешнего
  webhook; применяется binding-ом.
- **MutatingAdmissionPolicy** - встроенная API server mutation на CEL через
  `ApplyConfiguration` или `JSONPatch`; применяется binding-ом.
- **CEL** - Common Expression Language, язык выражений для ValidatingAdmissionPolicy.
- **`failurePolicy`** - действие API server, когда webhook/оценка policy недоступны или
  завершаются ошибкой: обычно `Fail` либо `Ignore`.

## 20.11. Итоги главы

- Admission - последний барьер перед etcd: mutation изменяет объект, validation разрешает
  или отклоняет его. RBAC отвечает не на тот же вопрос и не заменяет policy.
- Gatekeeper строит policy из `ConstraintTemplate` с Rego или CEL и `Constraint` с
  scope/params; сначала полезно использовать `dryrun`, затем `deny`.
- Kyverno 1.19 описывает validation, mutation, generation, delete/cleanup и image
  verification отдельными CEL-based policy types. Mutation удобна для безопасных defaults,
  но не заменяет validation.
- Gatekeeper и Kyverno - webhook engines, поэтому их availability, TLS, replicas,
  `timeoutSeconds` и `failurePolicy` являются частью security design.
- VAP с CEL работает в API server без внешнего webhook и подходит только для validation.
  В Kubernetes 1.36 stable MAP дополняет native stack mutation через `ApplyConfiguration`
  или `JSONPatch`, но не умеет generation.
- Надёжный rollout: малый scope -> audit/warn -> исправление violations ->
  `Enforce`/`Deny`, с проверкой принятого и отклонённого manifest.

## 20.12. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** Связанный публичный файл curriculum сейчас называется `CKS_Curriculum
v1.34`, тогда как экзаменационная среда CKS сейчас использует Kubernetes v1.35. Это разные
версии: curriculum описывает темы, а runtime определяет доступные API и поведение кластера.
Быстро определяйте, где находится контроль, читайте `ConstraintTemplate` и `Constraint`,
создавайте/проверяйте policy, отличайте `Audit` от `Deny` и находите причину `denied the
request`. Не приписывайте экзамену расширения курса: Kubernetes 1.36 native MAP и Kyverno
1.19 — production-ориентированные дополнения этой главы, а не гарантированные задания
linked curriculum. Перед экзаменом сверяйте актуальную публикацию Linux Foundation/CNCF.

**В реальной работе.** Admission policy предотвращает небезопасную конфигурацию до запуска
workload, а не ищет её после инцидента. Kubernetes 1.36 native MAP/VAP и Kyverno 1.19
полезны как production extension после проверки compatibility конкретного кластера и engine.
Наиболее ценный результат - не число политик, а понятный, тестируемый baseline с узкими
исключениями, наблюдаемостью и распределением ответственности. Это также входная точка
supply-chain контроля: следующая часть курса применит policy к registry, подписям и
артефактам.

## 20.13. Вопросы для самопроверки

<details>
<summary>1. Почему RBAC не может сам запретить `privileged: true` пользователю, которому разрешено создать Pod?</summary>

RBAC решает, имеет ли identity verb `create` для Pod, а не инспектирует поля YAML. Пользователь с разрешением может прислать Pod с `privileged: true`, если validating admission не наложит отдельное правило. PSA, VAP, Gatekeeper или Kyverno проверяют именно содержание объекта до etcd.
</details>

<details>
<summary>2. В каком порядке проходят mutating и validating admission, и почему mutation должна быть идемпотентной?</summary>

Mutating admission выполняется до validating, поэтому validation видит уже изменённый объект. Webhook могут вызываться повторно после изменения другим mutating webhook, а MAP с `IfNeeded` также допускает повторную оценку. Поэтому повторное применение mutation не должно добавлять второй такой же volume, label или sidecar.
</details>

<details>
<summary>3. Чем `ConstraintTemplate` отличается от `Constraint` в Gatekeeper?</summary>

`ConstraintTemplate` определяет новый тип policy: Rego или CEL-код, admission target и OpenAPI schema параметров; после применения Gatekeeper создаёт CRD constraint kind. `Constraint` — экземпляр этого типа с параметрами, `match` scope и `enforcementAction`. Template требует review и тестов как policy code, а constraint обычно меняют при расширении охвата.
</details>

<details>
<summary>4. Когда Kyverno `mutate` оправдан, а когда требование нужно выразить через `validate`?</summary>

Mutation оправдана для прозрачного безопасного default, например добавления audit-label через `ApplyConfiguration`. Для критичного security-инварианта, который нельзя молча исправить, нужна явная validation: она должна отклонить небезопасный объект. Глава отдельно предупреждает не маскировать mutation небезопасный образ или архитектуру.
</details>

<details>
<summary>5. Чем опасны постоянный `failurePolicy: Ignore` и поспешный `failurePolicy: Fail`?</summary>

С `Ignore` при timeout, TLS-ошибке или недоступности webhook объект проходит без данной проверки, создавая окно обхода policy. `Fail` сохраняет границу при такой ошибке, но outage engine может остановить deploy и control-plane operations. До строгого режима нужны replicas, PDB, TLS, latency/error alerting и безопасный rollout.
</details>

<details>
<summary>6. Почему policy сначала запускают в `Audit`/`dryrun`, а не сразу в `Enforce`/`Deny`?</summary>

Audit/dryrun собирает реальные нарушения, не блокируя legacy workloads и системные компоненты. Затем владельцы исправляют manifests, проверяют scope и положительный/отрицательный сценарии. Только после этого `Deny`/`Enforce` вводят как контролируемый запрет, а не как внезапный outage.
</details>

<details>
<summary>7. В чём ограничения `ValidatingAdmissionPolicy` на CEL по сравнению с Kyverno?</summary>

VAP выполняет CEL validation внутри API server и применяется только binding-ом; он не меняет и не генерирует объекты. Native MAP дополняет stack mutation, но не даёт generation, policy reports, image signature verification или Rego. Kyverno предоставляет отдельные CEL-based типы для validate, mutate, generate, delete и image validation, а также namespaced variants.
</details>

<details>
<summary>8. Какие container lists нельзя забыть при самописной проверке `privileged`?</summary>

Нужно проверять `containers`, `initContainers` и `ephemeralContainers`. Проверка только обычных containers оставляет обход через init или debug ephemeral container. Для стандартного класса требований глава советует PSA `restricted`, а самописный Rego должен явно покрывать все эти списки.
</details>

<details>
<summary>9. **Flashback (глава 04).** `NetworkPolicy` default-deny (глава 04) и `failurePolicy: Fail` с `enforce`/`Deny` в admission policy (эта глава) - оба реализуют один и тот же allow-list принцип на разных уровнях стека. Сформулируйте эту аналогию явно: что в admission-policy соответствует "default-deny всем ingress/egress", а что соответствует "узкому разрешённому правилу"?</summary>

В admission-policy эквивалентом default-deny является enforcing rule, при котором объект, не удовлетворяющий требованиям, отклоняется, а `failurePolicy: Fail` не допускает bypass при ошибке webhook. Эквивалент узкого разрешения — точные `match`/selectors, conditions и проверяемые поля, по которым конкретный допустимый объект проходит policy. Как и у NetworkPolicy, широкое исключение разрушает модель allow-list и усложняет audit.
</details>

## Практика

Основная практика этой темы - [лаба 108 CKS: admission-политики Kyverno](../../labs/108/README_RU.MD).
В ней примените policy для trusted registry и restricted workload, проверьте audit и deny,
а также найдите причину отклонения в ответе admission. Опциональный этап лабы проверяет
Kyverno mutation; native in-process mutation отдельно отработайте по
[MAP policy и binding из раздела 20.6](#206-native-cel-validation-и-mutation-без-внешнего-webhook).
Автоматическая проверка лабы запускается командой `check_result`.

Для самостоятельного sandbox подготовьте отдельный кластер или namespace: admission policy
может блокировать системные controller. Начните с `dryrun`/`Audit`, заранее запишите команду
отката и не тестируйте `failurePolicy` отключением production webhook.

## Справочные материалы

- [Kubernetes: Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Kubernetes: Validating Admission Policy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [OPA Gatekeeper documentation](https://open-policy-agent.github.io/gatekeeper/website/)
- [Kyverno documentation](https://kyverno.io/docs/)
- [Kyverno policy reports](https://kyverno.io/docs/policy-reports/)

---
[Оглавление](../README_RU.md) · [Глава 19](../19/ru.md) · [Глава 21](../21/ru.md)
