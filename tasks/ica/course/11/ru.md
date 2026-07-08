[Eng version](en.md)

# Глава 11. Kubernetes Gateway API

> **Что дальше.** В главах 5-10 мы управляли трафиком через ресурсы Istio: Gateway и
> VirtualService. Но в Kubernetes появился общий стандарт для того же самого -
> Kubernetes Gateway API. Istio его полноценно поддерживает и считает будущим для
> ingress. В этой главе разберём, что это такое, сравним с ресурсами Istio и, главное,
> поймём, что и когда лучше использовать.

## 11.1. Зачем понадобился отдельный стандарт

Ресурсы `Gateway` и `VirtualService` из `networking.istio.io` работают отлично, но у
них есть один минус: это **Istio-специфичный** API. Если вы завтра решите сменить mesh
или ingress-контроллер, все манифесты придётся переписывать под другой продукт. У
каждого решения (Istio, nginx, Traefik, облачные шлюзы) был свой набор ресурсов.

Сообщество Kubernetes решило эту проблему единым стандартом - **Kubernetes Gateway API**
(`gateway.networking.k8s.io`). Это вендор-нейтральный API для управления входящим
трафиком, который реализуют многие продукты, в том числе Istio. Пишете один раз по
стандарту - и это работает на любой совместимой реализации.

Сразу предупредим о путанице в названиях. Есть два разных ресурса со словом `Gateway`:

- `Gateway` из `networking.istio.io` - ресурс Istio (мы использовали его с главы 5).
- `Gateway` из `gateway.networking.k8s.io` - ресурс стандарта Kubernetes Gateway API.

Это разные API с разной структурой. Дальше под «Gateway API» имеем в виду именно
второй, стандартный.

## 11.2. Роли и ресурсы Gateway API

В Gateway API ответственность разделена на несколько ресурсов, каждый под свою роль:

| Ресурс | Отвечает за | Аналог в Istio |
|--------|-------------|----------------|
| `GatewayClass` | тип реализации (кто обрабатывает трафик) | задаётся при установке |
| `Gateway` | что слушать: порты, протоколы, TLS | Istio `Gateway` |
| `HTTPRoute` | правила маршрутизации HTTP | Istio `VirtualService` |

Кроме `HTTPRoute` есть и другие маршруты для разных протоколов: `TCPRoute`, `TLSRoute`,
`GRPCRoute`. Идея та же, что и в Istio: отдельно «что слушаем» (Gateway), отдельно «куда
направляем» (Route).

## 11.3. Установка CRD Gateway API

Важный практический момент, о который часто спотыкаются: ресурсы Gateway API - это **CRD,
которых по умолчанию в кластере может не быть**. Istio реализует стандарт, но сами
определения (`GatewayClass`, `Gateway`, `HTTPRoute`…) должно поставить или сообщество, или
Istio. Если CRD не установлены, ваши манифесты просто не применятся.

Проверить наличие:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

Если CRD нет, поставьте их из официального релиза стандарта (канал `standard` содержит
стабильные ресурсы, `experimental` - ещё и `TCPRoute`/`TLSRoute` и прочее):

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio ставит `GatewayClass` с именем `istio` автоматически при установке (istiod следит за
CRD и создаёт класс). Проверить, что класс на месте:

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway и HTTPRoute на примере

Поднимем шлюз на порту 80 и направим весь трафик на сервис `reviews`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # эту реализацию обеспечивает Istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # к какому Gateway привязан маршрут
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # сразу имя Kubernetes Service
      port: 8080
```

```mermaid
flowchart LR
    C["Клиент"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>правила маршрутов"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

Ключевые поля:

- **`gatewayClassName: istio`** - говорит, что этот Gateway реализует Istio. Это аналог
  того, как в Istio Gateway мы через `selector` привязывались к ingress gateway.
- **`parentRefs`** в HTTPRoute связывает маршрут с конкретным Gateway. В Istio эту роль
  играло поле `gateways` в VirtualService.
- **`backendRefs`** прямо указывает на Kubernetes Service и порт. Никаких subsets и
  DestinationRule в базовом Gateway API нет - версии и политики описываются иначе.

Ещё одно удобство: когда вы создаёте `Gateway` с `gatewayClassName: istio`, Istio может
автоматически развернуть под этот шлюз отдельный Envoy-деплоймент. Не нужно заранее
ставить ingress gateway - он появляется под конкретный Gateway.

## 11.5. TLS: HTTPS на Gateway API

Edge TLS из главы 9 в Gateway API описывается своими полями. HTTPS-listener объявляют с
`protocol: HTTPS` и блоком `tls`, где режим и ссылка на Secret с сертификатом:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # шлюз терминирует TLS (аналог SIMPLE в Istio)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # тот же tls-Secret, что и в главе 9
    allowedRoutes:
      namespaces:
        from: All                    # какие namespace могут привязывать маршруты (см. 11.7)
```

Соответствие режимов главе 9:

- **`mode: Terminate`** - шлюз расшифровывает TLS (как `SIMPLE`/`MUTUAL` в Istio). Клиентский
  сертификат (аналог `MUTUAL`) настраивается через `frontendValidation`/`BackendTLSPolicy` и
  зависит от версии стандарта.
- **`mode: Passthrough`** - шлюз не расшифровывает, трафик идёт насквозь по SNI (как
  `PASSTHROUGH`); для него используют `TLSRoute`, а не `HTTPRoute`.

Сертификат хранится в обычном Kubernetes `Secret` типа `tls` - его так же можно выпускать
cert-manager'ом (глава 9), просто маршрут теперь ссылается на него через `certificateRefs`,
а не через `credentialName`.

## 11.6. Canary и фильтры в HTTPRoute

Взвешенное разделение трафика (canary из главы 6) в Gateway API - это **стандартная**
возможность, а не расширение: у `backendRefs` есть поле `weight`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # 90% трафика на v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% на v2
      port: 8080
      weight: 10
```

Обратите внимание: в Gateway API нет subsets/DestinationRule, поэтому разные версии - это
**разные Kubernetes Service** (`reviews-v1`, `reviews-v2`), а не subset одного сервиса.

HTTPRoute умеет менять запросы через **фильтры** (`filters`) - это аналог части
возможностей VirtualService:

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # добавить/убрать заголовки
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # зеркалирование трафика (глава 6)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

Полезные типы фильтров: `RequestHeaderModifier`/`ResponseHeaderModifier` (заголовки),
`RequestRedirect` (редиректы, в т.ч. HTTP→HTTPS), `URLRewrite` (переписывание пути/хоста),
`RequestMirror` (зеркалирование). А вот **fault injection** в стандарте нет - это остаётся
эксклюзивом Istio API (глава 8).

## 11.7. Маршруты между namespace: allowedRoutes и ReferenceGrant

Сильная сторона Gateway API - явное и безопасное разделение прав между namespace. Здесь два
механизма.

**`allowedRoutes` на listener** - Gateway сам решает, из каких namespace ему разрешено
привязывать маршруты (`from: Same` - только свой, `All` - любой, `Selector` - по меткам
namespace):

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # только маршруты из namespace с этой меткой
```

**`ReferenceGrant`** - когда ресурс из одного namespace ссылается на ресурс в **другом**
(например, HTTPRoute в `apps` хочет слать трафик на Service в `data`), это по умолчанию
запрещено. Разрешение выдаёт `ReferenceGrant` в **целевом** namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # namespace, где лежит целевой Service
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # кто ссылается
  to:
  - group: ""
    kind: Service              # на что разрешаем ссылаться
```

Это защищает от того, чтобы чужой маршрут «увёл» трафик на сервис в вашем namespace без
вашего согласия - в Istio API такого встроенного механизма нет.

## 11.8. Сравнение с Istio API

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| Ресурсы входа | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Привязка маршрута | поле `gateways` в VirtualService | `parentRefs` в Route |
| Выбор реализации | `selector` на ingress gateway | `gatewayClassName` |
| Версии/subsets | `DestinationRule` (subsets) | разные Service + `weight` в `backendRefs` |
| Canary по весам | `VirtualService` weight | `backendRefs.weight` (штатно) |
| Зеркалирование | `VirtualService` mirror | фильтр `RequestMirror` (штатно) |
| Fault injection | есть | нет (только Istio) |
| Политики к бэкенду | `DestinationRule` (LB, circuit breaking) | нет (только Istio) |
| Разделение прав по namespace | нет встроенного | `allowedRoutes` + `ReferenceGrant` |
| Стандарт | специфичный для Istio | общий, вендор-нейтральный |
| Портируемость | только Istio | любой совместимый ingress/mesh |

Главный вывод из таблицы: Gateway API выигрывает в стандартности, портируемости и
разграничении прав между командами, а Istio API - в полноте возможностей у получателя
(`DestinationRule`: балансировка, circuit breaking, subsets) и в fault injection.
Зеркалирование и canary по весам есть в обоих API.

## 11.9. Что и когда использовать (best practices)

Практические рекомендации, что выбирать в реальных проектах.

**Берите Kubernetes Gateway API, когда:**

- начинаете новый проект и хотите быть на актуальном стандарте;
- важна портируемость: не хотите привязываться к Istio на уровне манифестов;
- нужен понятный раздел ответственности между командами (платформенная команда владеет
  `Gateway`, продуктовые - своими `HTTPRoute`);
- хватает стандартных возможностей маршрутизации (по пути, заголовкам, весам);
- вы работаете с **ambient mode**: waypoint-прокси (глава 22) конфигурируются именно
  через Gateway API.

**Оставайтесь на Istio API (VirtualService/DestinationRule), когда:**

- нужны фичи, которых в стандарте нет: **fault injection** (глава 8), политики
  `DestinationRule` (тонкая балансировка, circuit breaking, outlier detection, subsets),
  делегирование маршрутов;
- у вас уже много рабочих манифестов на Istio API и нет причин их переписывать.

(Зеркалирование и canary по весам есть в обоих API, так что ради них переходить или
оставаться не нужно.)

**Общие правила:**

- Не описывайте один и тот же маршрут одновременно и через VirtualService, и через
  HTTPRoute - это путаница и конфликты. Для одного сервиса выберите что-то одно.
- Istio API никуда не уходит и полностью поддерживается, так что миграция может быть
  постепенной: новые сервисы на Gateway API, старые остаются как есть.
- Direction движения индустрии - в сторону Gateway API, поэтому его стоит знать и
  осваивать, даже если сегодня основной трафик у вас на Istio API.

## 11.10. Итоги главы

- Kubernetes Gateway API (`gateway.networking.k8s.io`) - вендор-нейтральный стандарт
  управления входящим трафиком; Istio его реализует.
- Не путайте Istio `Gateway` и `Gateway` из Gateway API - это разные ресурсы.
- Роли в Gateway API: `GatewayClass` (реализация), `Gateway` (что слушать), `HTTPRoute`
  и другие Route (куда направить).
- Привязка маршрута к шлюзу - через `parentRefs`, выбор реализации - через
  `gatewayClassName: istio`.
- CRD Gateway API по умолчанию может не быть - их ставят отдельно (канал `standard`), а
  `GatewayClass istio` Istio создаёт сам.
- TLS: HTTPS-listener с `tls.mode: Terminate`/`Passthrough` и ссылкой на Secret через
  `certificateRefs` (аналог `credentialName`); сертификаты так же выпускает cert-manager.
- Canary по весам (`backendRefs.weight`, но версии - это разные Service) и зеркалирование
  (фильтр `RequestMirror`) есть штатно; fault injection и политики `DestinationRule` -
  только в Istio API.
- Разграничение прав между namespace: `allowedRoutes` на listener и `ReferenceGrant` для
  cross-namespace ссылок - встроенного аналога в Istio API нет.
- Best practice: Gateway API для нового ingress, стандартных сценариев и ambient; Istio
  API - когда нужны fault injection или политики DestinationRule; не смешивать оба для
  одного маршрута.

## 11.11. Вопросы для самопроверки

1. Какую проблему решает Kubernetes Gateway API по сравнению с Istio API?
2. Чем отличаются два ресурса с именем `Gateway`?
3. Какие ресурсы Gateway API соответствуют Istio Gateway и VirtualService?
4. За что отвечают `gatewayClassName` и `parentRefs`?
5. В каких случаях лучше остаться на Istio VirtualService/DestinationRule? Каких фич нет в
   Gateway API?
6. Почему не стоит описывать один маршрут одновременно в обоих API?
7. Как в Gateway API настроить HTTPS и canary по весам? Чем canary отличается от Istio
   (что с subsets)?
8. Зачем нужны `allowedRoutes` и `ReferenceGrant`? Какую проблему безопасности они решают?
9. Что проверить, если манифесты Gateway API не применяются в кластере?

## Практика

Настройте ingress через Kubernetes Gateway API (Gateway + HTTPRoute):

🧪 Лаба 16: [tasks/ica/labs/16](../../labs/16/README_RU.MD)

---
[Оглавление](../README.md) · [Глава 10](../10/ru.md) · [Глава 12](../12/ru.md)
