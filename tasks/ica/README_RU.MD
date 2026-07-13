[Eng version](README.MD)

# Istio Certified Associate (ICA) - учебные материалы

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

Полная подготовка к сертификации **Istio Certified Associate (ICA)**: самоучитель,
практические лабы и полноценные пробные экзамены - всё в одном месте.

## Что внутри

| Часть | Путь | Что это |
|-------|------|---------|
| **Курс** | [`course/`](course/README_RU.md) | Самоучитель из 32 глав: от идеи service mesh до продакшн-эксплуатации |
| **Лабы** | [`labs/`](labs/) | 31 практическая лаба на реальных кластерах AWS, каждая привязана к главе курса |
| **Пробные экзамены** | [`mock/`](mock/) | 2 полноценных mock-экзамена, имитирующих настоящий ICA |

Рекомендуемый маршрут: изучаете главу курса, закрепляете её лабой, затем прогоняете
mock-экзамены на время.

## Курс

Курс ([`course/README_RU.md`](course/README_RU.md)) состоит из 32 глав и рассчитан на
инженеров, уже знающих Kubernetes (уровень CKA):

- **Часть 1 (главы 1-24)** - основы и полное покрытие доменов экзамена ICA (управление
  трафиком, безопасность, observability, продвинутые сценарии, troubleshooting,
  установка).
- **Часть 2 (главы 25-31)** - best practices для реальной работы: прогрессивная доставка,
  миграция без даунтайма, Istio на EKS, мультикластер, VM-нагрузки, производительность
  control plane, харденинг.
- **Подготовка к экзамену (глава 32)** - формат ICA, советы и ссылки на mock-экзамены.

Каждая глава завершается блоком **«Практика»** со ссылкой на соответствующую лабу.

## Лабы

31 практическая лаба (`labs/01` .. `labs/31`), у каждой есть английская (`README.MD`) и
русская (`README_RU.MD`) версии. Они разворачивают реальные кластеры в AWS через
Terragrunt:

```bash
TASK=01 make run_ica_task      # развернуть лабу 01
TASK=01 make delete_ica_task   # удалить
```

Темы лаб (и глава курса с теорией):

| Лаба | Тема | Глава |
|------|------|-------|
| 01 | Установка Istio, Bookinfo, sidecar injection | 2 |
| 02 | Dark launch, маршрутизация по заголовкам, canary | 5, 6 |
| 03 | Fault injection и ретраи | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress: ServiceEntry, egress gateway, REGISTRY_ONLY | 12 |
| 06 | Балансировка + зеркалирование трафика | 6, 7 |
| 07 | Установка через Helm + canary-обновление (ревизии) | 3 |
| 08 | Observability: Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode (без сайдкаров) | 22 |
| 10 | Устойчивость: timeout + circuit breaker | 8 |
| 11 | Аутентификация пользователей: RequestAuthentication + JWT | 15 |
| 12 | Troubleshooting через istioctl | 24 |
| 13 | Edge TLS (SIMPLE) | 9 |
| 14 | Locality-aware failover | 7 |
| 15 | Установка и конфигурация (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | Локальный rate limiting (EnvoyFilter) | 20 |
| 18 | Telemetry API: access logs + трейсинг | 18 |
| 19 | Кастомный CA в istiod | 16 |
| 20 | Миграция mTLS PERMISSIVE → STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient: waypoint proxy + L7-авторизация | 22 |
| 25 | Прогрессивная доставка с Flagger | 25 |
| 26 | Динамический CA: cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | TCP-маршрутизация | 10 |
| 29 | Ingress TLS: MUTUAL и PASSTHROUGH | 9 |
| 30 | StatefulSet и headless-сервисы | 23 |
| 31 | Миграция без даунтайма: ingress-nginx → Istio | 26 |

## Пробные экзамены (mock)

Два полноценных mock-экзамена в формате ICA:

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 17 задач по базовым концепциям Istio.
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 16 задач по продвинутым паттернам mesh.

Прогоняйте на время, без подсказок, и добивайтесь **70%+**.

## Кастомное терминальное окружение

![Terminal Interface](../../docs/images/cockpit.png)

Инфраструктура даёт заранее настроенный терминал с инструментами и помощниками под
подготовку к ICA.

### Доступные команды
- **`time_left`** - сколько времени осталось
- **`check_result`** - проверить выполнение задачи (`check_result <task>` для конкретной)
- **`hosts`** - информация об ingress gateway (NodePort и IP)

### Преднастроенные инструменты (с bash completion)
- **`kubectl | k`**, **`istioctl`**, **`helm`**, **`yq`**, **`curl`/`wget`**,
  **`podman`**, **`aws`**

### SSH-доступ
```bash
ssh <kubernetes_nodename>
```

## Быстрый старт

```bash
# проверить результат (все задачи или конкретную)
check_result
check_result <номер_задачи>

# информация о кластере/ingress для тестов внешнего доступа
hosts

# сколько времени осталось при прогоне на время
time_left
```

## Что разрешено на экзамене

Можно пользоваться официальной документацией Istio:
**https://istio.io/latest/docs/** и всеми поддоменами. В моках это воспроизведено.

## Советы

1. **Читайте задачу дословно** - точные имена, namespace и спецификации важны.
2. **Проверяйте контекст** через `kubectl config current-context`.
3. **Проверяйте результат** - `curl` из sleep-пода для проверки маршрутизации и политик.
4. **Используйте `istioctl analyze`, `proxy-status`, `proxy-config`** для поиска ошибок.
5. **Разбирайте эталонные решения** после попыток.

## Частые ошибки

- **hosts в VirtualService**: для трафика между namespace указывайте короткое имя и FQDN.
- **Селекторы Gateway**: должны совпадать с метками ingress gateway.
- **Sidecar injection**: поды должны показывать `2/2` контейнера.
- **Переключение контекста**: проверяйте кластер перед применением ресурсов.

---

**Удачи с сертификацией ICA!** Практика решает - пройдите курс, лабы и оба мока, пока не
будете уверенно укладываться в тайминг.
