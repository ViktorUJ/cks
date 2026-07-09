[Eng version](en.md)

# Глава 14. AuthorizationPolicy: авторизация service-to-service

> **Что дальше.** В главе 13 мы включили mTLS: теперь трафик зашифрован, и мы знаем,
> кто на том конце соединения. Но mTLS не ограничивает, что этому собеседнику
> позволено делать. Этим занимается `AuthorizationPolicy` - она отвечает на вопрос
> «кому, куда и каким способом можно обращаться». Это второй столп безопасности Istio.

## 14.1. Зачем нужна авторизация

Вспомним конец прошлой главы. Включили `STRICT` mTLS - до сервиса `payments` больше не
дотянется никто без валидной mesh-личности. Но любой сервис внутри mesh со своим
сертификатом всё ещё может обратиться к `payments`. А хочется сказать точнее: «к
payments можно только из frontend и только методом GET».

Это и есть авторизация. mTLS дал нам проверенную личность (кто это), а
`AuthorizationPolicy` использует эту личность, чтобы решать, что этому клиенту
разрешено.

## 14.2. Структура AuthorizationPolicy

У ресурса три главные части:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: payments-policy
  namespace: app
spec:
  selector:               # к каким подам применяется
    matchLabels:
      app: payments
  action: ALLOW           # что делать: ALLOW / DENY / CUSTOM / AUDIT
  rules:                  # при каких условиях
  - from:
    - source:
        principals: ["cluster.local/ns/app/sa/frontend"]
    to:
    - operation:
        methods: ["GET"]
```

- **`selector`** - на какие поды действует политика (здесь `payments`). Без selector -
  на весь namespace.
- **`action`** - что делать с подходящими запросами.
- **`rules`** - условия: кто (`from`), куда и как (`to`), при каких обстоятельствах
  (`when`).

## 14.3. Default-deny: закрываем всё

Принцип Zero Trust: сначала запретить всё, потом точечно разрешить нужное. В Istio
канонический способ «запретить всё» выглядит неожиданно - это `ALLOW`-политика **без
единого правила**:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: payments-deny-all
  namespace: app
spec:
  selector:
    matchLabels:
      app: payments
  action: ALLOW
  # rules отсутствуют => ни один запрос не подходит => всё запрещено (403)
```

Логика такая: как только на под навешена хотя бы одна `ALLOW`-политика, действует
правило «разрешено только то, что явно перечислено в `rules`». Правил нет - значит, не
подходит ничего, и все запросы получают `403`.

Часто default-deny делают на весь namespace (или даже весь mesh через политику в
`istio-system`), а потом добавляют точечные разрешения.

## 14.4. Разрешаем точечно: from, to, when

Теперь откроем ровно то, что нужно. Добавляем вторую политику, которая разрешает доступ
к `payments` только из `frontend` и только методом `GET`:

```yaml
spec:
  selector:
    matchLabels:
      app: payments
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/app/sa/frontend"]  # КТО
    to:
    - operation:
        methods: ["GET"]                                   # ЧТО можно делать
        paths: ["/api/*"]                                  # по каким путям
    when:
    - key: request.headers[x-env]                          # доп. условие
      values: ["prod"]
```

Три блока правила:

- **`from`** - источник запроса. Чаще всего это `principals` (SPIFFE-личность из главы
  13), но бывает и `namespaces`, и `ipBlocks`.
- **`to`** - что можно делать: HTTP-методы (`methods`), пути (`paths`), порты.
- **`when`** - дополнительные условия: заголовки, JWT-claims и другие атрибуты запроса.

Политики с `action: ALLOW` объединяются по принципу ИЛИ: запрос проходит, если его
разрешает **хотя бы одна** ALLOW-политика. То есть default-deny + это разрешение вместе
дают: «к payments можно только из frontend, только GET, только по /api/*, только в prod».

## 14.5. Отрицания, условия when и область действия

Ещё несколько важных возможностей, которые часто нужны на практике.

**Отрицания.** У большинства полей есть форма с `not-`: `notPrincipals`, `notNamespaces`,
`notMethods`, `notPaths`, `notPorts`. Правило срабатывает, если атрибут запроса **не** входит
в перечисленное. Например, «разрешить всё, кроме метода DELETE»:

```yaml
  rules:
  - to:
    - operation:
        notMethods: ["DELETE"]
```

**Ключи `when`.** Блок `when` матчит по произвольным атрибутам запроса. Самые полезные ключи:

- `request.auth.claims[<claim>]` - claim из проверенного JWT (глава 15);
- `request.headers[<name>]` - HTTP-заголовок;
- `source.namespace` / `source.principal` - откуда пришёл запрос;
- `destination.port` - на какой порт;
- `remote.ip` - реальный клиентский IP (см. 14.10 про edge).

**Область действия.** Как и у `PeerAuthentication` (глава 13), уровень определяется namespace и
наличием `selector`:

- **весь mesh** - политика в корневом namespace (`istio-system`);
- **namespace** - политика без `selector` в нужном namespace;
- **конкретные поды** - политика с `selector.matchLabels`.

Это позволяет, например, сделать один default-deny на весь mesh в `istio-system`, а точечные
разрешения держать рядом с сервисами в их namespace.

## 14.6. Действия: ALLOW, DENY, CUSTOM, AUDIT

У поля `action` четыре значения:

| Действие | Что делает |
|----------|-----------|
| `ALLOW` | разрешить подходящие запросы (самое частое) |
| `DENY` | явно запретить подходящие запросы |
| `CUSTOM` | делегировать решение внешнему сервису авторизации |
| `AUDIT` | только логировать совпадение, не влияя на решение |

`ALLOW` используют для модели «разрешаем нужное». `DENY` удобен, чтобы явно закрыть
что-то конкретное (например, запретить метод DELETE отовсюду). `CUSTOM` - для внешней
авторизации (например, через OPA или свой сервис). `AUDIT` - чтобы посмотреть, что бы
сработало, ничего пока не блокируя.

Пример явного `DENY` - запрет метода `DELETE` к `payments` для всех, независимо от других
ALLOW-политик (напомним из 14.7: `DENY` проверяется раньше `ALLOW`):

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: payments-deny-delete
  namespace: app
spec:
  selector:
    matchLabels:
      app: payments
  action: DENY
  rules:
  - to:
    - operation:
        methods: ["DELETE"]     # любой DELETE к payments -> 403, что бы ни разрешал ALLOW
```

## 14.7. Порядок вычисления политик

Когда на под навешано несколько политик, Istio вычисляет их в строгом порядке. Это
частый источник путаницы, поэтому запомните последовательность:

```mermaid
flowchart TB
    R["запрос"] --> C{"CUSTOM запрещает?"}
    C -->|"да"| D1["403"]
    C -->|"нет"| DN{"есть подходящий DENY?"}
    DN -->|"да"| D2["403"]
    DN -->|"нет"| AL{"есть ALLOW-политики?"}
    AL -->|"нет"| OK1["разрешено"]
    AL -->|"да"| M{"хоть одна ALLOW подходит?"}
    M -->|"да"| OK2["разрешено"]
    M -->|"нет"| D3["403"]
    style D1 fill:#db4437,color:#fff
    style D2 fill:#db4437,color:#fff
    style D3 fill:#db4437,color:#fff
    style OK1 fill:#0f9d58,color:#fff
    style OK2 fill:#0f9d58,color:#fff
```

Словами:

1. Сначала проверяются `CUSTOM`-политики. Если внешний authz сказал «нет» - запрет.
2. Потом `DENY`-политики. Если запрос подходит под любую - запрет.
3. Потом `ALLOW`. Если ALLOW-политик **нет вообще** - запрос разрешён (это дефолт без
   политик). Если ALLOW-политики **есть**, запрос должен подойти хотя бы под одну,
   иначе запрет.

Отсюда и «магия» default-deny из раздела 14.3: наличие пустой ALLOW-политики переводит
под в режим «разрешено только явно перечисленное», а перечислять нечего - значит,
запрещено всё.

## 14.8. Связь с mTLS

Важная деталь, которую легко упустить. Правило `from.source.principals` проверяет
SPIFFE-личность клиента. Но откуда Istio знает эту личность? Из mTLS-сертификата,
который клиент предъявил при соединении (глава 13).

Значит, без mTLS правило по `principals` работать надёжно не может: если трафик идёт
plaintext, у Istio нет проверенной личности отправителя. Поэтому авторизация по
личности и mTLS всегда идут в связке: сначала `PeerAuthentication` (STRICT mTLS)
гарантирует, что личность настоящая, а потом `AuthorizationPolicy` по этой личности
решает, что можно.

Если же вы пишете правила только по `namespaces` или `ipBlocks`, а не по `principals`,
то формально mTLS не обязателен - но такие правила слабее, потому что IP и namespace
подделать проще, чем криптографическую личность.

## 14.9. AuthorizationPolicy и NetworkPolicy: слои защиты

Инженеру после CKA стоит сразу задать вопрос: а чем это отличается от `NetworkPolicy`,
которую я уже знаю? Оба ресурса ограничивают доступ, но работают на разных уровнях и
дополняют друг друга.

**NetworkPolicy** (Kubernetes) работает на L3/L4: разрешает или запрещает **сетевые
соединения** между подами по IP, портам и меткам. Её применяет CNI-плагин на уровне
сети (по сути в ядре), ещё до того, как трафик дойдёт до приложения или Envoy.

**AuthorizationPolicy** (Istio) работает на L7: смотрит на криптографическую личность
(SPIFFE), HTTP-метод, путь, заголовки. Её применяет Envoy-sidecar.

| | NetworkPolicy | AuthorizationPolicy |
|---|---------------|---------------------|
| Уровень | L3/L4 (IP, порт) | L7 (identity, метод, путь) |
| Кто применяет | CNI (уровень сети/ядра) | Envoy sidecar |
| Что контролирует | может ли под вообще соединиться | что именно клиенту разрешено сделать |
| Видит identity | нет, только IP и метки подов | да, SPIFFE-личность |
| Видит HTTP | нет | да (метод, путь, заголовки) |
| Нужен ли mesh | нет | да (sidecar или ztunnel) |

Ключевая мысль: это не «или - или», а **два слоя защиты (defense in depth)**.

- NetworkPolicy отсекает нежелательные соединения на уровне сети. Она работает, даже
  если у пода нет sidecar, и её не обойти из скомпрометированного приложения, потому
  что правила живут в ядре, а не в контейнере.
- AuthorizationPolicy добавляет то, чего NetworkPolicy в принципе не может: правила по
  проверенной личности сервиса и по деталям HTTP-запроса.

**Best practices совместного применения:**

- Делайте **default-deny на обоих уровнях**: базовая NetworkPolicy, запрещающая лишние
  соединения в namespace, плюс default-deny AuthorizationPolicy.
- NetworkPolicy используйте для грубой сегментации: какие namespace и поды вообще могут
  общаться по сети (в том числе не-mesh трафик и доступ к control plane).
- AuthorizationPolicy используйте для тонких правил: кто (по identity), какими методами
  и по каким путям может обращаться к сервису.
- Не полагайтесь только на AuthorizationPolicy: она применяется в Envoy внутри пода.
  NetworkPolicy это независимый рубеж на уровне сети, который остаётся, даже если что-то
  пошло не так с sidecar.

Итог: NetworkPolicy отвечает на вопрос «кто с кем может соединиться по сети»,
AuthorizationPolicy - «что именно этому сервису разрешено на уровне приложения».
Вместе они дают полноценную многоуровневую защиту.

### А есть ещё L7 NetworkPolicy (Cilium)

Картина чуть сложнее, чем «NetworkPolicy = L4, Istio = L7». Стандартная Kubernetes
NetworkPolicy действительно только L3/L4. Но некоторые CNI умеют больше. Самый заметный
пример - **Cilium**: на базе eBPF он предлагает **L7-aware сетевые политики**, которые
могут фильтровать HTTP-методы и пути, gRPC, Kafka, DNS-запросы. То есть часть L7-правил
можно делать и на уровне CNI, без Istio.

Возникает очевидный вопрос: если и Cilium, и Istio умеют L7, зачем оба и как их
совмещать? Разберём.

- **Разные модели identity.** Istio авторизует по SPIFFE-личности из mTLS-сертификата.
  Cilium использует свою модель identity на основе меток подов (через eBPF), а mTLS у
  него отдельная опция. Это фундаментально разные подходы к «кто это».
- **Разные точки применения.** Cilium применяет правила в ядре (eBPF) и во встроенном
  per-node Envoy. Istio - в sidecar или waypoint. Если включить L7 в обоих, трафик
  пройдёт через два L7-разбора, что добавляет задержку и сложность отладки.

**Стоит ли применять вместе.** Общая рекомендация - **не дублировать L7-правила в двух
системах**. Практичные варианты:

- **Cilium для L3/L4 + Istio для L7.** Самый распространённый и здоровый вариант: Cilium
  как CNI отвечает за быструю сетевую сегментацию (L3/L4) и, возможно, DNS-политики, а
  Istio берёт на себя весь L7: mTLS, авторизацию по identity, управление трафиком. Это
  как раз частая связка с ambient-режимом Istio.
- **Только Cilium (с его L7)** без Istio - разумно, если вам хватает L7-фильтрации CNI и
  не нужен полноценный mesh (управление трафиком, зеркалирование, богатая
  observability).
- **Только Istio** - если mesh уже есть, L7-политики логично держать в нём, а от CNI
  брать лишь L3/L4.

Чего избегать: одновременно писать пересекающиеся L7-правила и в Cilium, и в Istio.
Это удвоенный оверхед, две точки правды и очень тяжёлая отладка, когда запрос
«необъяснимо» получает 403. Выберите один слой для L7 и держите правила там.

## 14.10. Авторизация на ingress gateway (edge) и ловушка с IP

`AuthorizationPolicy` вешают не только на сервисы внутри mesh, но и на **сам ingress
gateway** - чтобы фильтровать трафик уже на входе (например, пустить в админку только из
офисной сети). Такая политика ставится в namespace шлюза (`istio-system`) с `selector` на
поды шлюза:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ingress-allow-office
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  action: ALLOW
  rules:
  - from:
    - source:
        remoteIpBlocks: ["203.0.113.0/24"]   # реальный клиентский IP
    to:
    - operation:
        hosts: ["admin.example.com"]
```

**Ловушка с IP - `ipBlocks` vs `remoteIpBlocks`.** Это регулярно ломает allowlist по IP,
особенно за балансировщиком:

- **`ipBlocks`** - IP **источника соединения**, как его видит Envoy. За балансировщиком это
  будет IP самого LB/прокси, а не клиента. Фильтровать по нему клиента бесполезно.
- **`remoteIpBlocks`** - **реальный клиентский IP**, который Istio определяет из заголовка
  `X-Forwarded-For` с учётом числа доверенных прокси. Именно это нужно для allowlist по
  адресу клиента.

Но **откуда возьмётся правильный клиентский IP - зависит от типа балансировщика**, и здесь
AWS делится на два случая.

**ALB (L7).** ALB сам добавляет `X-Forwarded-For` с реальным клиентским IP. Достаточно
объяснить Istio, сколько доверенных прокси стоит перед шлюзом, через `numTrustedProxies` в
MeshConfig:

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      gatewayTopology:
        numTrustedProxies: 1     # 1 доверенный прокси (ALB) перед ingress gateway
```

**NLB (L4).** Ключевой момент: **NLB работает на L4 и `X-Forwarded-For` не добавляет** - ему
нечем «подписать» HTTP-заголовок, он про TCP. Поэтому `numTrustedProxies` сам по себе тут не
поможет: XFF просто неоткуда взяться. Клиентский IP за NLB сохраняют через **Proxy Protocol
v2**. Нужно три вещи:

1. **Включить Proxy Protocol на NLB** - аннотацией на Service ingress gateway:

   ```yaml
   serviceAnnotations:
     service.beta.kubernetes.io/aws-load-balancer-type: external
     service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"   # PROXY v2
   ```

2. **Научить ingress gateway разбирать Proxy Protocol** - listener-фильтром через EnvoyFilter:

   ```yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: EnvoyFilter
   metadata:
     name: ingress-proxy-protocol
     namespace: istio-system
   spec:
     selector:
       matchLabels:
         istio: ingressgateway
     configPatches:
     - applyTo: LISTENER
       patch:
         operation: MERGE
         value:
           listener_filters:
           - name: envoy.filters.listener.proxy_protocol
   ```

3. **Сказать Istio доверять источнику из Proxy Protocol** как реальному клиенту - через
   `gatewayTopology`:

   ```yaml
   apiVersion: install.istio.io/v1alpha1
   kind: IstioOperator
   spec:
     meshConfig:
       defaultConfig:
         gatewayTopology:
           proxyProtocol: {}      # брать клиентский IP из PROXY-заголовка
   ```

После этого реальный клиентский IP доступен, и `remoteIpBlocks` / `remote.ip` в
`AuthorizationPolicy` работают корректно. Альтернатива без Proxy Protocol - `instance`-таргеты
NLB с `externalTrafficPolicy: Local`, но она меняет балансировку и health-check'и, поэтому в
mesh обычно берут именно Proxy Protocol.

Коротко: для allowlist по IP клиента используйте **`remoteIpBlocks`**, а клиентский IP до
шлюза донесите - за **ALB** через `numTrustedProxies` (есть XFF), за **NLB** через **Proxy
Protocol v2** (XFF нет). Никогда не полагайтесь на `ipBlocks` за балансировщиком.

## 14.11. Проверка и отладка

Отказ авторизации выглядит однозначно: HTTP **`403`** с телом **`RBAC: access denied`**. Если
видите такой ответ - его вернул не сервис, а Envoy по вашей политике.

Полезное при отладке:

- **Логи sidecar** цели показывают причину отказа:

  ```bash
  kubectl logs <pod> -c istio-proxy -n app | grep -i rbac
  # ищем rbac_access_denied_matched_policy - какая политика сработала
  ```

- **Временный `AUDIT` вместо DENY/ALLOW** - проверить, что политика матчит нужные запросы, не
  блокируя их (совпадения пишутся в лог).
- **`istioctl` описание пода** покажет, какие политики на него навешаны:

  ```bash
  istioctl x describe pod <pod> -n app
  ```

Частые причины «необъяснимого 403»: забыли, что где-то есть default-deny; правило по
`principals` не срабатывает, потому что нет STRICT mTLS (14.8); фильтруете по `ipBlocks` вместо
`remoteIpBlocks` на edge (14.10).

## 14.12. Best practices

- **Default-deny как основа.** Начинайте с запрета всего (пустой `ALLOW` на namespace/mesh) и
  добавляйте точечные разрешения - это и есть Zero Trust.
- **Правила по `principals`, а не по IP.** Криптоличность из mTLS надёжнее IP/namespace;
  фильтрацию по личности используйте как основную (и держите mTLS в `STRICT`, см. 14.8).
- **`DENY` для явных запретов.** Опасные операции (например, `DELETE`, админ-пути) закрывайте
  отдельной `DENY`-политикой - она сработает раньше любых `ALLOW`.
- **На edge - `remoteIpBlocks` + доверие к XFF.** Для allowlist по клиентскому IP не путайте с
  `ipBlocks` (14.10).
- **Least privilege.** Разрешайте минимум: конкретные методы, пути и источники, а не «всё от
  этого namespace».
- **Проверяйте политики** (14.11): `AUDIT` перед включением, логи `rbac`, `istioctl x describe`
  - не полагайтесь на то, что «правило написано, значит работает».
- **Два слоя защиты.** Дополняйте AuthorizationPolicy сетевым default-deny через NetworkPolicy
  (14.9) - на случай проблем с sidecar.

## 14.13. Итоги главы

- `AuthorizationPolicy` отвечает на вопрос «что этому клиенту разрешено», используя
  личность из mTLS.
- Структура: `selector` (на какие поды), `action` (что делать), `rules` (условия:
  `from`, `to`, `when`).
- **Default-deny** это `ALLOW`-политика без правил: она переводит под в режим «только
  явно разрешённое», а раз правил нет - запрещено всё.
- Точечные разрешения задают `from` (кто, обычно `principals`), `to` (методы, пути),
  `when` (доп. условия); ALLOW-политики объединяются по ИЛИ.
- Действия: `ALLOW`, `DENY`, `CUSTOM` (внешний authz), `AUDIT` (только лог).
- Порядок вычисления: CUSTOM, затем DENY, затем ALLOW.
- Авторизация по `principals` работает поверх mTLS-личности, поэтому идёт в связке с
  PeerAuthentication.
- AuthorizationPolicy (L7, Envoy) и NetworkPolicy (L3/L4, CNI) дополняют друг друга;
  best practice - defense in depth: default-deny на обоих уровнях.
- Некоторые CNI (Cilium) умеют L7-политики; чтобы не плодить сложность, L7 держат в
  одной системе - частый выбор: Cilium для L3/L4, Istio для L7.
- Есть отрицания (`notMethods`, `notPaths`…), гибкий `when` (JWT-claims, заголовки, порт,
  `remote.ip`) и уровни действия (mesh/namespace/поды) - как у PeerAuthentication.
- На **ingress gateway** для allowlist по IP клиента берут **`remoteIpBlocks`**, а не
  `ipBlocks` (IP соединения = IP LB). Клиентский IP до шлюза доносят: за **ALB** через
  `numTrustedProxies` (есть XFF), за **NLB** (L4, XFF нет) через **Proxy Protocol v2**.
- Отказ = `403 RBAC: access denied`; отлаживают логами Envoy (`rbac_access_denied`),
  временным `AUDIT` и `istioctl x describe`.

## 14.14. Вопросы для самопроверки

1. Чем задача AuthorizationPolicy отличается от задачи mTLS/PeerAuthentication?
2. Почему `ALLOW`-политика без правил запрещает всё?
3. За что отвечают блоки `from`, `to` и `when`?
4. В каком порядке Istio вычисляет CUSTOM, DENY и ALLOW?
5. Почему правило по `principals` требует mTLS, а по `namespaces` формально нет?
6. Чем NetworkPolicy отличается от AuthorizationPolicy и почему их стоит применять
   вместе?
7. В чём разница между `ipBlocks` и `remoteIpBlocks` на ingress gateway? Как донести реальный
   клиентский IP до шлюза за **ALB** и за **NLB** (и почему для NLB не годится XFF)?
8. Как выглядит отказ авторизации и как найти, какая политика его вызвала?
9. Как сделать явный запрет опасной операции (например, DELETE) независимо от ALLOW-правил?

## Практика

Отработайте default-deny и точечное разрешение (только frontend + GET) поверх STRICT
mTLS - это продолжение лабы из главы 13:

🧪 Лаба 04: [tasks/ica/labs/04](../../labs/04/README_RU.MD)

---
[Оглавление](../README.md) · [Глава 13](../13/ru.md) · [Глава 15](../15/ru.md)
