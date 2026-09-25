# Лаба 108 — Admission policies с Kyverno

## Цель

В этой CKS-лабе вы установите Kyverno и защитите namespace `policy-108` policy-as-code
правилами. Практика охватывает validating admission: запрет тега `latest`, обязательный
`runAsNonRoot`, allowlist registry; в последнем, опциональном этапе — mutation Pod при
admission. Задание 6 сравнивает этот подход с другим механизмом — встроенным
`ImagePolicyWebhook`, где решение об image принимает внешний HTTP(S)-backend через API
`ImageReview`, а не CEL-выражение внутри кластера. Финальное задание 7 — третий, отдельный
admission engine: **Gatekeeper (OPA/Rego)**, где вы чините уже развёрнутую, но неполную
policy, а не пишете CEL внутри Kyverno. Работайте только с объектами и именами, указанными
в заданиях.

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

В отличие от Kyverno, **Gatekeeper (OPA) для задания 7 уже установлен** bootstrap-ом
кластера, вместе со стартовым (намеренно неполным) `ConstraintTemplate` и `Constraint`.
Это сделано специально: задание 7 проверяет умение найти и дописать Rego в уже
существующем `ConstraintTemplate`, а не установить admission engine с нуля - эту часть
уже тренирует задание 1 для Kyverno. Задание 7 работает в отдельном namespace
`gatekeeper-108`, изолированном от Kyverno-заданий 1-5 (`policy-108`), чтобы Pod не мог
быть отклонён одновременно двумя разными admission engine.

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

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

Первая команда должна вернуть сам CRD (не ошибку `NotFound`); версия image должна
содержать `v1.19.`; хотя бы один Deployment должен иметь `AVAILABLE` больше `0`.
</details>

---
| **2** | **Запретить image с тегом `latest`** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) с `validationActions: [Deny]`. Она должна применяться к Pod и subresource `pods/ephemeralcontainers` namespace `policy-108` и отклонять любой image в `containers`, `initContainers` или `ephemeralContainers`, который является явным `:latest` ИЛИ implicit latest (образ без тега и без digest вообще). |
| Критерии приёмки | Policy существует и работает в режиме Deny; admission отклоняет и явный `:latest`, и implicit latest (untagged) в каждом из трёх списков контейнеров, а versioned trusted images и digest-pinned images принимает. |

<details>
<summary>💡 Подсказка к заданию 2</summary>

`matchConstraints.resourceRules` должен покрывать и `pods`, и subresource
`pods/ephemeralcontainers` отдельно - иначе `kubectl debug` пройдёт мимо policy. Для
самой CEL-логики: разберите строку image на `registry/path` и `tag` по последнему `:`
ПОСЛЕ последнего `/` (наличие `:` до последнего `/` может быть частью порта registry, а
не тега); если после разбора тега нет вообще - это implicit latest; если тег есть, но
равен `latest` - тоже запрещённый случай; digest (`@sha256:...`) - отдельный, всегда
разрешённый случай, не подпадающий под тег вовсе.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Прежде чем применять policy, убедитесь, что нарушающий Pod вообще проходит admission
(baseline) - иначе непонятно, denial вызван вашей policy или чем-то другим:

```bash
# baseline: до применения policy - должно пройти (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

Примените policy, затем повторите ТОТ ЖЕ manifest - теперь должно завершиться ошибкой
admission (exit не 0), а сообщение должно ссылаться на вашу policy:

```bash
kubectl apply --context "$CTX" -f deny-latest-tag.yaml   # ваш файл policy
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

Повторите тот же baseline→apply→probe→compare цикл для: image без тега вообще
(`registry.k8s.io/pause`), `:latest` в `initContainers`, и `:latest`/untagged через
`kubectl debug --image=...` на уже запущенном разрешённом Pod (`pods/ephemeralcontainers`
subresource). Наконец, проверьте positive control - versioned tag должен проходить и
после применения policy, не только до.
</details>

---
| **3** | **Требовать запуск не от root** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `require-run-as-non-root` в режиме Deny. Для каждого Pod в `policy-108` поле `spec.securityContext.runAsNonRoot` должно быть явно равно `true`. |
| Критерии приёмки | Policy существует и Deny; Pod с `runAsNonRoot: false`, а также Pod без этого поля вообще (неявное значение), не проходит server-side admission. |

<details>
<summary>💡 Подсказка к заданию 3</summary>

Проверяйте именно ЯВНОЕ значение `true`, а не "отсутствие `false`" - CEL-выражение вида `object.spec.securityContext.runAsNonRoot == true` не пройдёт, если поле вообще не задано (`null != true`), и это здесь ТРЕБУЕТСЯ: задание отклоняет и явный `false`, и отсутствующее поле - должны быть denied оба случая, а не только явный `false`.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

```bash
# baseline: до применения policy, оба варианта должны пройти
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Примените policy и повторите оба manifest - ОБА теперь должны завершиться ошибкой
admission. Затем проверьте positive control: тот же Pod, но с
`runAsNonRoot: true` явно, должен проходить и после применения policy.
</details>

---
| **4** | **Allowlist container registry** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `ValidatingPolicy` `allow-approved-registries` в режиме Deny. Для каждого контейнера (`containers`, `initContainers`, `ephemeralContainers`) разрешайте только `registry.k8s.io/*` или `ghcr.io/cks-lab/*`; остальные image registry запретите. |
| Критерии приёмки | Policy существует и Deny; untrusted image отклоняется во всех трёх списках, trusted image допускается во всех трёх списках. |

<details>
<summary>💡 Подсказка к заданию 4</summary>

`startsWith('registry.k8s.io/')` - самая надёжная проверка префикса, но убедитесь, что оба разрешённых registry проверяются через OR (любой из двух подходит), а не AND (оба одновременно, что невозможно для одного image). Проверяйте именно ALLOWLIST (образ допускается ТОЛЬКО если совпал с одним из двух префиксов), а не денылист конкретно `docker.io` - policy, написанная как "если `docker.io` - deny, иначе allow", пропустит `quay.io`, unqualified images и любой другой сторонний registry. Убедитесь также, что префикс сравнивается с ЗАВЕРШАЮЩИМ `/` (`registry.k8s.io/`, не просто `registry.k8s.io`), иначе похожий по написанию host (`registry.k8s.io.evil.example`) может пройти case-insensitive или неполное совпадение. Как и в задании 2, не забудьте про `ephemeralContainers` - это тот же паттерн проверки трёх списков контейнеров.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

```bash
# baseline: до применения policy - untrusted registry должен пройти
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

Примените policy, повторите тот же manifest - теперь должен быть denied. Это ОДНО
конкретное untrusted-значение (`docker.io`), а не доказательство полноценного
allowlist - policy, которая просто запрещает буквально `docker.io`, но пропускает,
например, unqualified image (implicit Docker Hub без явного host), `quay.io` или
похожий по написанию host (`registry.k8s.io.evil.example`), тоже пройдёт эту ОДНУ
проверку. Повторите тот же baseline→apply→probe→compare минимум для: unqualified
image (`busybox:1.36` без host вообще), другого явного stороннего registry
(`quay.io/...`), похожего по написанию host/path (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), untrusted image в `initContainers`, и untrusted/trusted
image через `kubectl debug` на уже запущенном разрешённом Pod. Наконец, positive control: Pod с ОБОИМИ контейнерами (main + init) из
`registry.k8s.io`/`ghcr.io/cks-lab` должен проходить и после применения policy.
</details>

---
| **5** | **Опционально: mutate label через Kyverno** |
| :---: | :--- |
| Что делаем | Создайте CEL-based `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`), которая добавляет к Pod namespace `policy-108` label `security.cks.io/managed-by: kyverno`, если он отсутствует. Используйте mutation, а не validation. |
| Критерии приёмки | Server-side dry-run Pod с разрешённым registry и `runAsNonRoot: true`, у которого ещё НЕТ этого label, получает его после mutation со значением `kyverno`. Pod, у которого label УЖЕ задан с другим значением, сохраняет исходное значение (mutation не перезаписывает). Этот этап отображается в `check_result`, но его пропуск допустим. |

<details>
<summary>💡 Подсказка к заданию 5</summary>

Этот этап опциональный - если у вас закончилось время, можно его пропустить без риска для остальной лабы. Тестовый Pod для проверки mutation должен уже проходить policies из заданий 2-4 (trusted registry, non-root) - если он сам будет отклонён одной из предыдущих policy, вы не увидите результат mutation вообще. «Если он отсутствует» в задании - не просто пожелание: mutation должна явно проверять наличие label и не трогать объект, если он уже есть, иначе задание не выполнено, даже если Pod без label получает правильное значение.
</details>

---
| **6** | **ImagePolicyWebhook: внешний backend вместо CEL policy** |
| :---: | :--- |
| Что делаем | На рабочей машине уже подготовлен `/opt/image-policy-backend/server.py` — минимальный HTTPS-сервер, реализующий `ImageReview` API (отклоняет image с тегом `:latest` или без тега вовсе). Скопируйте его на `control-plane` и разверните как Deployment в namespace `image-policy`, за Service `image-policy-backend` на порту `8443`. Backend должен принимать соединения по TLS (upstream `ImagePolicyWebhook` контракт требует HTTPS, plain HTTP не поддерживается). На `control-plane` настройте `AdmissionConfiguration` для plugin `ImagePolicyWebhook` (`defaultAllow: false`) и kubeconfig, указывающий на ваш backend. В static manifest `kube-apiserver.yaml` **добавьте** `ImagePolicyWebhook` к уже существующему списку `--enable-admission-plugins` (не заменяйте список целиком - иначе рискуете выключить уже включённые plugins) и включите `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`. После восстановления API создайте Pod с `:latest` — должен быть отклонён; затем Pod с закреплённым тегом — должен быть создан. |
| Критерии приёмки | `image-policy-backend` Available; kube-apiserver healthy с добавленным (не заменённым) plugin и `--runtime-config`; kubeconfig backend'а использует `https://` (не `http://`); Pod с `:latest` отклонён именно ImagePolicyWebhook (сообщение admission содержит `image policy webhook backend denied`); Pod с закреплённым тегом создан и Running; backend, временно остановленный (недоступный), приводит к отказу в приёме НОВОГО image (`defaultAllow: false` работает как fail-closed, а не fail-open). |

<details>
<summary>💡 Подсказка к заданию 6</summary>

`ImagePolicyWebhook` — принципиально другой механизм, чем Kyverno из заданий 1-5: решение принимает внешний HTTPS-backend через API `ImageReview`, а не CEL-выражение внутри кластера. Скопируйте готовый `/opt/image-policy-backend/server.py` на `control-plane` (например `scp`/`cat` через SSH) — задание проверяет понимание wiring admission plugin, TLS-контракта и ImageReview API, а не умение писать HTTP-сервер с нуля. Для TLS: сначала создайте Service (чтобы узнать `ClusterIP`), затем самоподписанный сертификат с этим IP в SAN (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), затем Deployment, монтирующий и код, и сертификат. Не заменяйте существующий `--enable-admission-plugins` новым значением целиком — допишите `ImagePolicyWebhook` через запятую к уже включённым plugins (обычно там уже есть `NodeRestriction`). Также не забудьте `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` — без явного включения этого API backend не будет вызван вообще. Namespace `image-policy` не создан заранее — создайте его сами перед Deployment/Service. Если застряли на детальной последовательности ресурсов/путей/флагов — эталонный порядок действий приведён в решении.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: дописать Rego blocklist** |
| :---: | :--- |
| Что делаем | В кластере уже установлен **Gatekeeper** (OPA), а также `ConstraintTemplate` `k8sblockedregistries` и `Constraint` `K8sBlockedRegistries/deny-bad-registries`, ограниченный отдельным namespace `gatekeeper-108` (не `policy-108` — это отдельный от Kyverno-заданий 1-5 полигон, чтобы Kyverno и Gatekeeper не отклоняли один и тот же Pod одновременно). Rego внутри `ConstraintTemplate` уже содержит несколько заблокированных registry (`untrusted-registry.example`, `docker-fake.test`), но **намеренно не содержит** `very-bad-registry.test`. Найдите `ConstraintTemplate.spec.targets[].rego` и допишите в него правило для `very-bad-registry.test` — именно в Rego, а не в параметрах `Constraint` (`deny-bad-registries` уже полностью корректен и не использует `spec.parameters` вообще — трогать его не нужно). |
| Критерии приёмки | `ConstraintTemplate k8sblockedregistries` существует; его Rego содержит и исходные правила (`untrusted-registry.example`), и новое правило для `very-bad-registry.test`; Pod с образом из `very-bad-registry.test` в `gatekeeper-108` отклоняется именно этим Gatekeeper Constraint (сообщение admission ссылается на `k8sblockedregistries`); Pod с образом из уже заблокированного `untrusted-registry.example` всё ещё отклоняется (регрессии нет); Pod с образом из доверенного `registry.k8s.io` проходит. |

<details>
<summary>💡 Подсказка к заданию 7</summary>

Найдите ConstraintTemplate через `kubectl get constrainttemplate k8sblockedregistries -o yaml`. Rego лежит в `spec.targets[].rego` как многострочная строка — именно её нужно редактировать (`kubectl edit constrainttemplate k8sblockedregistries`, либо `get -o yaml` → правка → `apply`). Существующий Rego объявляет заблокированные registry через отдельные факты вида `blocked_registry("untrusted-registry.example")` — допишите ещё одну такую строку для `very-bad-registry.test`, не удаляя и не заменяя уже существующие. Не путайте это с `Constraint.spec.parameters` — в этой версии policy Constraint не использует parameters вообще, редактировать там нечего.
</details>

<details>
<summary>🔍 Проверьте себя перед `check_result`</summary>

Baseline - ДО исправления: Pod из `very-bad-registry.test` должен пройти (Rego пока
его не покрывает), а уже заблокированный `untrusted-registry.example` — быть отклонён:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

Допишите Rego, повторите ТОТ ЖЕ manifest (под новым именем, старый Pod уже
"создан" через dry-run и не сохраняется) - теперь ожидается ошибка admission от
Gatekeeper, ссылающаяся именно на `k8sblockedregistries`, для ОБОИХ registry:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

Проверьте positive control - доверенный registry должен пройти и после исправления:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## Проверка

На рабочей машине выполните:

```bash
check_result
```

Проверка содержит Init и семь тестов. Первые четыре, шестой и седьмой обязательны. Пятый
тест выполняет проверку mutation, но не делает лабораторию неуспешной, если optional
policy не создана. Задания 2-4 и 7 используют `--dry-run=server`, поэтому образы не
скачиваются и Pod не остаются в namespace; задание 6 проверяет реальный (не dry-run)
admission через ImagePolicyWebhook, поэтому Pod `webhook-pinned-ok` действительно
создаётся.

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
тегом, отличным от `latest`, либо с digest (`@sha256:...`). Точную CEL-логику для этого
критерия задание не даёт готовой - см. подсказку к заданию 2, если нужна дополнительная
опора.
