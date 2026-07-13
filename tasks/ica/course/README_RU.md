[Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md)

# Istio: практический самоучитель

Практический курс по Istio service mesh с привязкой к лабораторным работам
(`tasks/ica/labs`). Для инженеров, прошедших CKA. Часть 1 покрывает экзамен ICA,
Часть 2 - best practices для реальной эксплуатации.

Структура: каждая тема - папка с номером. Внутри лежат локализованные файлы.
Основной язык - русский (`ru.md`), с него делаются переводы.

Доступные локализации (главы курса и лабораторные работы переведены полностью):

- 🇷🇺 Русский - `ru.md` (основной, источник истины)
- 🇬🇧 English - `en.md`
- 🇪🇸 Español - `es.md`
- 🇫🇷 Français - `fr.md`
- 🇩🇪 Deutsch - `de.md`

Переключение между языками - по ссылкам в первой строке каждой главы и в шапке
этого оглавления. Мок-экзамены (`tasks/ica/mock`) доступны только на английском.

## Содержание

### Часть 1. Основы и подготовка к ICA

1. [Введение в service mesh и архитектуру Istio](01/ru.md)
2. [Установка и конфигурация Istio](02/ru.md)
3. [Обновление Istio: Helm, ревизии, canary и in-place](03/ru.md)
4. [Data plane: Envoy и sidecar injection](04/ru.md)
5. [Управление трафиком: Gateway, VirtualService, DestinationRule](05/ru.md)
6. [Релизные стратегии: canary, header-routing, traffic mirroring](06/ru.md)
7. [Балансировка нагрузки и locality-aware failover](07/ru.md)
8. [Устойчивость: fault injection, timeouts, retries, circuit breaking](08/ru.md)
9. [Edge TLS: ingress в режимах SIMPLE, MUTUAL, PASSTHROUGH](09/ru.md)
10. [Маршрутизация TCP, gRPC и WebSocket](10/ru.md)
11. [Kubernetes Gateway API](11/ru.md)
12. [Egress: ServiceEntry, egress gateway, TLS origination](12/ru.md)
13. [mTLS и PeerAuthentication: модель Zero Trust](13/ru.md)
14. [AuthorizationPolicy: авторизация service-to-service](14/ru.md)
15. [Аутентификация пользователей: RequestAuthentication и JWT](15/ru.md)
16. [Управление сертификатами: кастомный CA, cert-manager и istio-csr](16/ru.md)
17. [Observability: Prometheus, Grafana, Jaeger, Kiali](17/ru.md)
18. [Telemetry API: access logs и распределённый трейсинг](18/ru.md)
19. [Sidecar scoping и оптимизация конфигурации прокси](19/ru.md)
20. [Rate limiting: локальное ограничение запросов](20/ru.md)
21. [Расширение data plane: EnvoyFilter, Lua и WasmPlugin](21/ru.md)
22. [Ambient mode: ztunnel и waypoint proxy](22/ru.md)
23. [StatefulSet и headless-сервисы в mesh](23/ru.md)
24. [Troubleshooting Istio](24/ru.md)

### Часть 2. Best practices для реального использования

25. [Прогрессивная доставка с Flagger](25/ru.md)
26. [Миграция продакшена без даунтайма: ingress-nginx → Istio](26/ru.md)
27. [Istio на EKS: продакшн-установка](27/ru.md)
28. [Мультикластерный mesh](28/ru.md)
29. [Не-Kubernetes нагрузки: VM в mesh](29/ru.md)
30. [Производительность control plane и эксплуатация](30/ru.md)
31. [Харденинг и модель угроз mesh](31/ru.md)

### Подготовка к экзамену

32. [Экзамен ICA: формат и подготовка](32/ru.md)
