[Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Глава 21. ServiceAccount; аутентификация, авторизация, admission

> **Что дальше.** Завершаем часть 3. Мы много раз говорили, что все запросы идут через
> API-сервер (глава 2). Теперь разберём, что API-сервер делает с каждым запросом:
> проверяет, **кто** вы (аутентификация), **что вам можно** (авторизация) и **допустим ли
> сам запрос** (admission). Отдельно - **ServiceAccount**: идентичность, под которой к API
> обращаются сами поды. Это обзорная глава для части 3 (глубже RBAC пойдёт в главе 38).
> Тема - домен Security обоих экзаменов.

## 21.1. Три барьера на входе в API-сервер

Каждый запрос к API-серверу проходит три этапа по очереди. Не прошёл любой - запрос
отклонён.

```mermaid
flowchart LR
    req["Запрос<br>(kubectl / под /<br>компонент)"] --> authn["1 · Аутентификация<br>КТО ты?"]
    authn --> authz["2 · Авторизация<br>ЧТО тебе можно?"]
    authz --> adm["3 · Admission<br>запрос ДОПУСТИМ<br>и валиден?"]
    adm --> etcd["Сохранение в etcd"]
    style req fill:#673ab7,color:#fff
    style authn fill:#326ce5,color:#fff
    style authz fill:#0f9d58,color:#fff
    style adm fill:#f4b400,color:#000
    style etcd fill:#db4437,color:#fff
```

| Этап | Вопрос | Отвечает |
|------|--------|----------|
| Аутентификация (authn) | Кто ты? | сертификаты, токены, ServiceAccount |
| Авторизация (authz) | Что тебе разрешено? | RBAC (глава 38) |
| Admission control | Запрос вообще допустим? Дополнить/проверить? | admission-контроллеры |

## 21.2. Аутентификация: кто обращается

Kubernetes различает два вида «пользователей»:

```mermaid
flowchart TB
    h0["Обычные пользователи<br>(люди)"] --> h1["нет объекта User<br>в кластере"] --> h2["аутентификация:<br>клиентские сертификаты,<br>OIDC-токены,<br>внешние провайдеры"]
    s0["ServiceAccount<br>(для подов/процессов)"] --> s1["ЕСТЬ объект<br>в кластере"] --> s2["аутентификация:<br>токен ServiceAccount"]
    style h0 fill:#673ab7,color:#fff
    style s0 fill:#0f9d58,color:#fff
    style h1 fill:#9c27b0,color:#fff
    style h2 fill:#9c27b0,color:#fff
    style s1 fill:#3cb371,color:#fff
    style s2 fill:#3cb371,color:#fff
```

- **Обычные пользователи (люди)** - у Kubernetes **нет** объекта «User». Люди
  аутентифицируются внешними средствами: клиентскими TLS-сертификатами (глава 39),
  OIDC-токенами, интеграцией с внешними провайдерами. Kubernetes лишь доверяет имени из
  сертификата/токена.
- **ServiceAccount** - для приложений и процессов внутри кластера. Это **настоящий
  объект** Kubernetes, живущий в namespace.

## 21.3. ServiceAccount: идентичность для подов

Когда под хочет обратиться к API-серверу (например, оператор читает объекты, или
приложение создаёт ресурсы), он делает это от имени **ServiceAccount**. Каждый под всегда
работает под каким-то ServiceAccount - если не указать, используется `default` из его
namespace.

```mermaid
flowchart LR
    pod["Под<br>serviceAccountName: my-sa"] -->|"токен SA"| api["API-сервер"]
    api -->|"проверяет: кто (my-sa)<br>+ что можно (RBAC)"| result["разрешить/запретить"]
    style pod fill:#0f9d58,color:#fff
    style api fill:#326ce5,color:#fff
    style result fill:#f4b400,color:#000
```

```bash
# Создать ServiceAccount
kubectl create serviceaccount my-sa

# Посмотреть
kubectl get sa
```

Привязка к поду:

```yaml
spec:
  serviceAccountName: my-sa
  containers:
  - name: app
    image: myapp
```

## 21.4. Как токен ServiceAccount попадает в под

Kubernetes автоматически монтирует под токен ServiceAccount, чтобы приложение могло
предъявить его API-серверу. В современных версиях (проецируемые токены,
BoundServiceAccountTokenVolume, GA с 1.22) токен краткоживущий, привязан к аудитории
(audience) и автоматически ротируется - в отличие от старых «вечных» токенов.

> **Что изменилось (важно для актуальных кластеров).** Автомонтирование токена в под
> включено **по умолчанию** и никуда не делось. Но с **Kubernetes 1.24** перестал
> автоматически создаваться **долгоживущий Secret** с токеном на каждый ServiceAccount:
> под получает короткоживущий проецируемый токен, а не «вечный» из Secret. Если
> долгоживущий токен всё-таки нужен (например, для внешней системы), его создают явно -
> `kubectl create token <sa>` (короткий, по TokenRequest API) или отдельным Secret с
> аннотацией `kubernetes.io/service-account.name`. Отключить же само монтирование можно
> флагом `automountServiceAccountToken: false` (см. ниже).

```
/var/run/secrets/kubernetes.io/serviceaccount/
├── token       # токен для аутентификации в API
├── ca.crt      # сертификат CA кластера
└── namespace   # namespace пода
```

```mermaid
flowchart TB
    sa["ServiceAccount my-sa"] -->|"kubelet<br>монтирует токен"| pod["Под<br>/var/run/secrets/<br>.../token"]
    pod -->|"предъявляет<br>токен"| api["API-сервер<br>аутентифицирует как<br>system:serviceaccount:<br>ns:my-sa"]
    style sa fill:#0f9d58,color:#fff
    style pod fill:#326ce5,color:#fff
    style api fill:#f4b400,color:#000
```

Если поду **не нужен** доступ к API (обычному приложению чаще всего не нужен),
автомонтирование токена стоит отключить - это хорошая практика безопасности:

```yaml
spec:
  automountServiceAccountToken: false
```

Так под не таскает с собой лишний токен, который в случае компрометации дал бы доступ к
API.

## 21.5. Авторизация: что разрешено (RBAC)

Аутентификация ответила «кто ты». Дальше авторизация решает «что тебе можно». Основной
механизм - **RBAC (Role-Based Access Control)**. Идея: права описываются в Role/ClusterRole
(что можно делать), а привязываются к субъекту (пользователю или ServiceAccount) через
RoleBinding/ClusterRoleBinding.

```mermaid
flowchart LR
    subj["Субъект<br>(User или ServiceAccount)"] -->|"RoleBinding<br>связывает"| role["Role/ClusterRole<br>(набор разрешений:<br>verbs на resources)"]
    role --> perm["например: get,list,watch<br>на pods в namespace dev"]
    style subj fill:#673ab7,color:#fff
    style role fill:#0f9d58,color:#fff
    style perm fill:#f4b400,color:#000
```

Быстрая проверка своих прав - без разбора всей структуры:

```bash
kubectl auth can-i create pods
kubectl auth can-i delete nodes
kubectl auth can-i get pods --as=system:serviceaccount:dev:my-sa -n dev
```

`kubectl auth can-i` - незаменимый инструмент и на экзамене, и в жизни: он прямо отвечает
«можно/нельзя». Полностью RBAC (Role, ClusterRole, binding'и, verbs, resources) разберём
в главе 38.

### Кейс: дать пользователю полный доступ к namespace dev

Частая задача: выдать человеку (не поду, а пользователю) **полный доступ ко всем объектам
внутри одного namespace** `dev`, ничего не разрешая в остальных. Решается в два шага:
создать **идентичность пользователя** и **привязать к ней права** через RBAC. Помним:
объекта `User` в Kubernetes нет - личность подтверждается сертификатом (или OIDC), а RBAC
лишь оперирует его именем.

**Шаг 1. Идентичность через клиентский сертификат.** Пользователь `dev-user` предъявляет
API-серверу клиентский TLS-сертификат, где `CN` = имя пользователя. Генерируем ключ и CSR,
подписываем через встроенный CertificateSigningRequest:

```bash
# ключ и запрос на сертификат (CN станет именем пользователя)
openssl genrsa -out dev-user.key 2048
openssl req -new -key dev-user.key -out dev-user.csr -subj "/CN=dev-user"

# отправляем CSR в кластер (request — base64 от .csr)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user
spec:
  request: $(base64 -w0 dev-user.csr)
  signerName: kubernetes.io/kube-apiserver-client
  usages: ["client auth"]
EOF

kubectl certificate approve dev-user                         # админ одобряет
kubectl get csr dev-user -o jsonpath='{.status.certificate}' | base64 -d > dev-user.crt
```

Дальше формируют kubeconfig-контекст для пользователя (сертификат + CA кластера):

```bash
kubectl config set-credentials dev-user \
  --client-certificate=dev-user.crt --client-key=dev-user.key --embed-certs=true
kubectl config set-context dev-user --cluster=<имя-кластера> --user=dev-user --namespace=dev
```

**Шаг 2. Права: Role + RoleBinding в namespace dev.** «Полный доступ ко всем объектам»
внутри namespace - это Role с `*` по группам, ресурсам и глаголам. Именно **Role**
(namespaced), а не ClusterRole, ограничивает права рамками `dev`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: dev-admin
rules:
- apiGroups: ["*"]        # все API-группы
  resources: ["*"]        # все ресурсы (pods, deployments, services, ...)
  verbs: ["*"]            # все действия (get, list, create, update, delete, ...)
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: dev
  name: dev-user-admin
subjects:
- kind: User
  name: dev-user          # то самое CN из сертификата
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: dev-admin
  apiGroup: rbac.authorization.k8s.io
```

**Проверка:**

```bash
kubectl auth can-i '*' '*' -n dev --as=dev-user      # yes — полный доступ в dev
kubectl auth can-i get pods -n prod --as=dev-user    # no  — в других namespace прав нет
```

Итог: пользователь получил полный доступ строго в `dev`. Ключевые моменты - **Role
(namespaced), а не ClusterRole**, чтобы права не «растеклись» на весь кластер, и
**RoleBinding именно в `dev`**. Если бы нужен был доступ во всех namespace, взяли бы
ClusterRole + ClusterRoleBinding; если один и тот же набор прав в нескольких конкретных
namespace - удобно один раз описать ClusterRole и привязывать её RoleBinding'ом в каждом
нужном namespace.

**Как получить список пользователей.** Команды `kubectl get users` **не существует** -
User не объект Kubernetes, отдельного реестра людей в кластере нет. «Список» получают
косвенно, разобрав, кому что выдано, - по субъектам привязок RBAC и по выданным
сертификатам:

```bash
# все субъекты-пользователи из RoleBinding и ClusterRoleBinding
kubectl get rolebindings,clusterrolebindings -A \
  -o jsonpath='{range .items[*]}{range .subjects[?(@.kind=="User")]}{.name}{"\n"}{end}{end}' | sort -u

# кто и когда получал клиентские сертификаты (идентичности)
kubectl get csr

# пользователи, прописанные в вашем kubeconfig (локально, не в кластере)
kubectl config get-users
```

**Как удалить созданного пользователя.** «Удаление» пользователя - это **отзыв его прав**,
т.к. самого объекта User нет:

```bash
# 1. Снять права — удалить привязку (и выделенную Role, если она только для него)
kubectl delete rolebinding dev-user-admin -n dev
kubectl delete role dev-admin -n dev            # если Role создавалась под него

# 2. Убрать учётку из kubeconfig (локально)
kubectl config delete-user dev-user
kubectl config delete-context dev-user

# 3. Косметически — удалить объект CSR
kubectl delete csr dev-user
```

> **Важно про сертификаты.** В ванильном Kubernetes **нет отзыва (CRL)** для клиентских
> сертификатов: пока срок действия не истёк, сертификат продолжает проходить
> аутентификацию. После удаления привязок такой пользователь всё ещё «войдёт», но прав у
> него не будет (кроме того, что даёт группа `system:authenticated`). Поэтому для реального
> отзыва доступа полагаются на **короткоживущие** сертификаты или на внешний IdP (OIDC),
> где учётку можно отключить централизованно. Если сертификат скомпрометирован до
> истечения - меняют/перевыпускают CA (тяжёлая операция).

> **А как это в управляемых кластерах (на примере AWS EKS)?** Там сертификаты и CSR обычно
> не используют - личности берут из **IAM**, а Kubernetes лишь сопоставляет их своим
> пользователям/группам. Схема:
>
> - **Аутентификация - через IAM.** kubeconfig от `aws eks update-kubeconfig` содержит
>   exec-плагин, который вызывает `aws eks get-token` и предъявляет API-серверу токен,
>   подтверждающий IAM-идентичность (роль или пользователя). Своего пароля/сертификата у
>   человека нет - вход по его AWS-учётке.
> - **Сопоставление IAM → Kubernetes.** Раньше это делали через ConfigMap `aws-auth` в
>   `kube-system` (секции `mapUsers`/`mapRoles`: IAM ARN → k8s-имя и группы). Сейчас
>   рекомендуется нативный механизм **EKS Access Entries**:
>
>   ```bash
>   # связать IAM-роль с идентичностью в кластере и назначить группы для RBAC
>   aws eks create-access-entry --cluster-name demo \
>     --principal-arn arn:aws:iam::111122223333:role/dev-team \
>     --kubernetes-groups dev-admins
>   ```
> - **Права - всё тот же RBAC.** Дальше группе (`dev-admins`) выдают Role/RoleBinding в
>   нужном namespace - ровно как в кейсе выше. Либо навешивают управляемую EKS
>   access-policy (`aws eks associate-access-policy`, например `AmazonEKSAdminPolicy` с
>   ограничением на namespace) - это «обёртка» над теми же RBAC-разрешениями.
>
> Итог: в EKS «создание пользователя» = создание/выбор **IAM-принципала** + его
> сопоставление (access entry или `aws-auth`) с k8s-группой, а внутрикластерные права по‑прежнему
> задаёт RBAC. Аналогично устроены GKE (Google IAM) и AKS (Entra ID). Отзыв доступа там
> делается централизованно - убрать access entry / IAM-права, без возни с CRL.

Подробнее про RBAC - в главе 38.

## 21.6. Admission control: последний барьер

После аутентификации и авторизации запрос проходит через **admission-контроллеры** -
плагины, которые могут его изменить или отклонить. Их два вида:

```mermaid
flowchart LR
    req["Запрос<br>(уже authn + authz OK)"] --> mut["Mutating admission<br>ИЗМЕНЯЕТ запрос<br>(дефолты, вставки)"]
    mut --> val["Validating admission<br>ПРОВЕРЯЕТ запрос<br>(разрешить/отклонить)"]
    val --> save["Сохранить в etcd"]
    style req fill:#673ab7,color:#fff
    style mut fill:#326ce5,color:#fff
    style val fill:#0f9d58,color:#fff
    style save fill:#db4437,color:#fff
```

- **Mutating** - меняют объект перед сохранением: подставляют значения по умолчанию,
  внедряют sidecar (так работает инъекция прокси в service mesh), проставляют labels.
- **Validating** - проверяют и отклоняют, если объект нарушает правила.

Примеры встроенных admission-контроллеров, которые вы уже встречали неявно:

| Контроллер | Что делает |
|-----------|-----------|
| `LimitRanger` | применяет LimitRange (глава 14) |
| `ResourceQuota` | проверяет ResourceQuota (глава 14) |
| `PodSecurity` | применяет Pod Security Admission (глава 20) |
| `ServiceAccount` | подставляет ServiceAccount и монтирует токен |
| `NamespaceLifecycle` | не даёт создавать объекты в удаляемом namespace |

Свои правила добавляют через **webhook'и** (ValidatingWebhookConfiguration,
MutatingWebhookConfiguration) - так работают Kyverno, OPA/Gatekeeper, cert-manager,
инъекция sidecar. Это объясняет, откуда в поде «сами появляются» sidecar-контейнеры или
дефолтные значения.

Важные детали конвейера admission (их спрашивают):

- **Порядок строгий:** сначала **все mutating**, затем повторная проверка схемы, затем
  **все validating**. Поэтому validating видит объект уже после всех изменений mutating.
- **failurePolicy webhook'а** (`Fail`/`Ignore`) решает, что делать, если ваш webhook-сервер
  недоступен. `Fail` (по умолчанию) безопаснее (не пропустит), но **упавший webhook с
  `Fail` может заблокировать создание объектов** в кластере - частая причина инцидента
  «ничего не создаётся». `Ignore` - доступность важнее строгости.
- **PodSecurityPolicy (PSP) удалён** в 1.25; на смену пришёл встроенный **Pod Security
  Admission** (глава 20) либо внешние движки (Kyverno/Gatekeeper через webhook).
- Список включённых admission-плагинов задаётся флагом apiserver
  `--enable-admission-plugins` (в манифесте `/etc/kubernetes/manifests/kube-apiserver.yaml`).

## 21.7. Полная картина: путь запроса

Соберём всё вместе - это карта, которую полезно держать в голове.

```mermaid
sequenceDiagram
    participant C as kubectl / под
    participant A as API-сервер
    participant Adm as Admission
    participant E as etcd
    C->>A: запрос (создать под) + удостоверение
    A->>A: 1. Authn — кто это? (сертификат/токен/SA)
    A->>A: 2. Authz — можно ли ему это? (RBAC)
    A->>Adm: 3. Mutating admission (дефолты, sidecar)
    Adm->>Adm: Validating admission (проверка правил)
    Adm-->>A: допущено
    A->>E: сохранить объект
    E-->>A: ок
    A-->>C: 201 Created
```

Любой из барьеров может отклонить запрос: не тот, кто говорит (authn) → 401; нет прав
(authz) → 403; нарушает политику (admission) → отказ с причиной. Понимание этой цепочки -
ключ к разбору «почему мне/поду отказано».

## 21.8. Как это применяют в продакшене

- **Отдельный ServiceAccount на приложение.** В проде не используют `default` SA для
  рабочих нагрузок - каждому приложению создают свой ServiceAccount с минимальными правами
  (RBAC). Это ограничивает ущерб при компрометации пода.
- **Отключение автомонтирования токена.** Приложениям, которым не нужен доступ к API
  (большинство), ставят `automountServiceAccountToken: false` - чтобы не носить лишний
  ключ доступа.
- **IRSA / Workload Identity.** В облаке ServiceAccount связывают с облачными ролями
  (AWS IRSA, GCP Workload Identity), чтобы под получал доступ к облачным сервисам (S3,
  очереди) без статичных ключей - по идентичности SA.
- **Admission-политики как страж.** Kyverno/OPA Gatekeeper через validating-webhook'и
  enforce'ят правила: запрет privileged, обязательные метки/лимиты, разрешённые реестры
  образов. Это способ не пускать в кластер небезопасные или несоответствующие объекты.
- **Mutating-инъекция.** Service mesh (Istio) и секрет-инъекторы (Vault Agent) работают
  через mutating-webhook - автоматически добавляют sidecar/секреты в поды, не меняя их
  манифесты.

## 21.9. Мини-глоссарий

- **Аутентификация (authn)** - установление, кто отправитель запроса.
- **Авторизация (authz)** - проверка, что отправителю разрешено (RBAC).
- **Admission control** - проверка/изменение запроса после authn+authz.
- **Mutating / Validating admission** - изменяющие / проверяющие контроллеры.
- **ServiceAccount** - идентичность пода/процесса для доступа к API.
- **default SA** - ServiceAccount по умолчанию в каждом namespace.
- **automountServiceAccountToken** - монтировать ли токен SA в под.
- **RBAC** - управление доступом на основе ролей (глава 38).
- **webhook (admission)** - внешняя проверка/изменение объектов (Kyverno, OPA, mesh).

## 21.10. Итоги главы

- Каждый запрос к API проходит три барьера: аутентификация (кто), авторизация (что
  можно, RBAC), admission (допустимость и изменение).
- Люди аутентифицируются внешне (сертификаты, OIDC) - объекта User в Kubernetes нет;
  поды - через ServiceAccount (реальный объект в namespace).
- Каждый под работает под ServiceAccount (по умолчанию `default`); токен монтируется в
  под автоматически, но при отсутствии нужды его лучше отключить.
- Авторизацию делает RBAC; быстрая проверка прав - `kubectl auth can-i`.
- Admission-контроллеры бывают mutating (меняют объект: дефолты, sidecar) и validating
  (отклоняют по правилам); кастомные - через webhook'и (Kyverno, OPA, mesh).
- Понимание цепочки authn → authz → admission - ключ к разбору отказов (401/403/политика).

## 21.11. Как это пригодится: на экзамене и в реальной работе

**На экзамене.** «Создай ServiceAccount и назначь поду», «проверь, может ли SA делать X»
(`kubectl auth can-i --as`), понимание, почему запрос отклонён (authn/authz/admission) -
частые задания домена Security. Это фундамент для главы 38 (RBAC), где задания про Role и
binding'и.

**В реальной работе.** Отдельный ServiceAccount с минимальными правами на каждое
приложение - базовая гигиена безопасности. Отключение лишних токенов, связка SA с
облачными ролями (IRSA), admission-политики (Kyverno) и mutating-инъекция (mesh) - всё
это ежедневные инструменты безопасной и управляемой эксплуатации кластера.

## 21.12. Вопросы для самопроверки

1. Какие три барьера проходит запрос к API-серверу и на какой вопрос отвечает каждый?
2. Чем аутентификация обычных пользователей отличается от ServiceAccount? Почему нет
   объекта User?
3. Под каким ServiceAccount работает под, если явно не указать? Где лежит его токен?
4. Зачем и когда отключают `automountServiceAccountToken`?
5. Как быстро проверить, разрешено ли субъекту действие?
6. Чем mutating admission отличается от validating? Приведите примеры каждого.
7. Как через admission-webhook'и в под «сами» попадают sidecar или дефолтные значения?

## Практика

На этом часть 3 (конфигурация и безопасность) завершена. Дальше - часть 4, специфичная
для CKAD: дизайн и сборка приложений, начиная с multi-container паттернов (глава 22).
ServiceAccount и проверка прав отрабатываются в лабах по безопасности; глубокий RBAC ждёт
в главе 38.

🧪 Лаба 113 (ServiceAccount, RBAC и CSR): [tasks/cka/labs/113](../../labs/113/README_RU.MD)

🧪 Лаба 121 (RBAC-дриллы: SA, Role/ClusterRole, binding'и): [tasks/cka/labs/121](../../labs/121/README_RU.MD)

🎮 Killercoda (в браузере, без установки): [Create ServiceAccount](https://killercoda.com/chadmcrowell/course/ckad/create-serviceaccount) · [Create Service Account For a Pod](https://killercoda.com/chadmcrowell/course/cka/create-sa-for-pod) · [Role and RoleBinding](https://killercoda.com/chadmcrowell/course/ckad/role-rolebinding) · [Restrict Pod Deletes with RBAC](https://killercoda.com/chadmcrowell/course/ckad/restrict-rbac)

---
[Оглавление](../README_RU.md) · [Глава 20](../20/ru.md) · [Глава 22](../22/ru.md)
