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

## 11.3. Gateway и HTTPRoute на примере

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

## 11.4. Сравнение с Istio API

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| Ресурсы входа | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| Привязка маршрута | поле `gateways` в VirtualService | `parentRefs` в Route |
| Выбор реализации | `selector` на ingress gateway | `gatewayClassName` |
| Версии/subsets | `DestinationRule` (subsets) | иначе, часть через расширения |
| Стандарт | специфичный для Istio | общий, вендор-нейтральный |
| Зрелость в Istio | стабильный, все возможности | поддерживается, активно растёт |
| Продвинутые фичи | mirror, fault, сложные match - всё есть | базовое есть, часть через расширения |
| Портируемость | только Istio | любой совместимый ingress/mesh |

Главный вывод из таблицы: Gateway API выигрывает в стандартности и портируемости, а
Istio API - в полноте возможностей (особенно продвинутых: зеркалирование, fault
injection, тонкая маршрутизация).

## 11.5. Что и когда использовать (best practices)

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

- нужны продвинутые фичи: traffic mirroring, fault injection, сложные правила match,
  делегирование маршрутов;
- у вас уже много рабочих манифестов на Istio API и нет причин их переписывать;
- нужны политики DestinationRule (тонкая балансировка, circuit breaking, subsets),
  которых в базовом Gateway API нет.

**Общие правила:**

- Не описывайте один и тот же маршрут одновременно и через VirtualService, и через
  HTTPRoute - это путаница и конфликты. Для одного сервиса выберите что-то одно.
- Istio API никуда не уходит и полностью поддерживается, так что миграция может быть
  постепенной: новые сервисы на Gateway API, старые остаются как есть.
- Direction движения индустрии - в сторону Gateway API, поэтому его стоит знать и
  осваивать, даже если сегодня основной трафик у вас на Istio API.

## 11.6. Итоги главы

- Kubernetes Gateway API (`gateway.networking.k8s.io`) - вендор-нейтральный стандарт
  управления входящим трафиком; Istio его реализует.
- Не путайте Istio `Gateway` и `Gateway` из Gateway API - это разные ресурсы.
- Роли в Gateway API: `GatewayClass` (реализация), `Gateway` (что слушать), `HTTPRoute`
  и другие Route (куда направить).
- Привязка маршрута к шлюзу - через `parentRefs`, выбор реализации - через
  `gatewayClassName: istio`.
- Istio API полнее по возможностям (mirror, fault, DestinationRule), Gateway API лучше
  по стандартности и портируемости.
- Best practice: Gateway API для нового ingress, стандартных сценариев и ambient; Istio
  API - когда нужны продвинутые фичи; не смешивать оба для одного маршрута.

## 11.7. Вопросы для самопроверки

1. Какую проблему решает Kubernetes Gateway API по сравнению с Istio API?
2. Чем отличаются два ресурса с именем `Gateway`?
3. Какие ресурсы Gateway API соответствуют Istio Gateway и VirtualService?
4. За что отвечают `gatewayClassName` и `parentRefs`?
5. В каких случаях лучше остаться на Istio VirtualService/DestinationRule?
6. Почему не стоит описывать один маршрут одновременно в обоих API?

## Практика

Настройте ingress через Kubernetes Gateway API (Gateway + HTTPRoute):

🧪 Лаба 16: [tasks/ica/labs/16](../../labs/16/README_RU.MD)

---
[Оглавление](../README.md) · [Глава 10](../10/ru.md) · [Глава 12](../12/ru.md)
