[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 17 - Эталонное решение

Istio `1.29.1` установлен (ingress gateway на NodePort `32080`). Приложение `ping-pong`
развернуто в пространстве имен `app` и доступно через ingress gateway по адресу
`http://myapp.local:32080/`.

## Цель

Применить **локальное ограничение скорости** к ingress gateway с помощью `EnvoyFilter`: разрешить
не более 5 запросов в минуту, остальные отклонять с HTTP `429`.

## Шаг 1. Базовая проверка

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Шаг 2. Примените локальное ограничение скорости (EnvoyFilter)

```bash
cat > ratelimit.yaml <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-local-rate-limit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.local_ratelimit
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
            value:
              stat_prefix: http_local_rate_limiter
              token_bucket:
                max_tokens: 5
                tokens_per_fill: 5
                fill_interval: 60s
              filter_enabled:
                runtime_key: local_rate_limit_enabled
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              filter_enforced:
                runtime_key: local_rate_limit_enforced
                default_value:
                  numerator: 100
                  denominator: HUNDRED
              response_headers_to_add:
                - append_action: OVERWRITE_IF_EXISTS_OR_ADD
                  header:
                    key: x-local-rate-limit
                    value: "true"
EOF

kubectl apply -f ratelimit.yaml
```

## Шаг 3. Проверьте

```bash
for i in $(seq 10); do
  curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
done
# first ~5 -> 200, the rest -> 429
```

## Как это работает

- **`token_bucket`** - `max_tokens: 5`, `tokens_per_fill: 5`, `fill_interval: 60s`:
  корзина содержит 5 токенов и каждые 60 секунд пополняется до 5. Каждый запрос
  потребляет один токен; когда корзина пуста, запросы отклоняются с `429`.
- **`filter_enabled` / `filter_enforced`** - доля запросов, для которых фильтр
  активен и действительно применяется (в обоих случаях `100%`).
- **context: GATEWAY** - фильтр добавляется в listener ingress gateway, поэтому
  ограничение применяется ко всему входящему трафику на границе.

## Локальное и глобальное ограничение скорости

- **Локальное ограничение скорости** (эта лабораторная работа) - каждый экземпляр Envoy хранит
  собственную корзину токенов. Просто, без дополнительных компонентов, но фактический лимит
  умножается на количество реплик gateway.
- **Глобальное ограничение скорости** - Envoy вызывает внешнюю службу ограничения скорости (на базе Redis),
  поэтому лимит общий для всех реплик. Используются фильтр
  `envoy.filters.http.ratelimit`, а также `ConfigMap` с дескрипторами и
  развернутая служба ratelimit. Используйте этот вариант, когда нужна точная квота для всего кластера.
