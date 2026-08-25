[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 27 - Эталонное решение

Установлен Istio `1.29.1` (ingress gateway на NodePort `32080`). Приложение `ping-pong`
развернуто в пространстве имен `app` и доступно по адресу `http://myapp.local:32080/`.

## Цель

Подключить `EnvoyFilter` со встроенным HTTP-фильтром **inline Lua** к ingress gateway, который:
- добавляет заголовок ответа `x-lua-lab: hello-from-lua`;
- отклоняет любой запрос с `x-block: yes`, возвращая `403`.

## Шаг 1. Базовая проверка

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## Шаг 2. Примените Lua EnvoyFilter

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: lua-edge
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
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_request(request_handle)
                if request_handle:headers():get("x-block") == "yes" then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "blocked by lua\n")
                end
              end
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-lua-lab", "hello-from-lua")
              end
EOF
```

## Шаг 3. Проверьте

```bash
# response header added by Lua
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab
# x-lua-lab: hello-from-lua

# request blocked by Lua
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/
# 403

# normal request still works
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# 200
```

## Как это работает

- **`EnvoyFilter`** исправляет необработанную конфигурацию Envoy, которую генерирует Istio. Здесь он вставляет
  встроенный HTTP-фильтр **Lua** (`envoy.filters.http.lua`) в ingress gateway
  в цепочку фильтров непосредственно перед router.
- Lua-скрипт реализует два callback жизненного цикла:
  - `envoy_on_request(request_handle)` выполняется для каждого запроса; может читать/изменять заголовки, читать
    тело или завершать обработку с помощью `request_handle:respond(...)`.
  - `envoy_on_response(response_handle)` выполняется для каждого ответа; здесь он добавляет заголовок.
- `context: GATEWAY` ограничивает действие патча ingress gateway. Используйте `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND` для обращения к sidecar рабочих нагрузок.

## Lua, Wasm и встроенные CRD

- **Inline Lua** - самый быстрый способ добавить небольшую пользовательскую логику: без образа, без сборки, правка
  скрипта в YAML. Отлично подходит для настройки заголовков, простой фильтрации запросов и быстрых экспериментов.
- **Wasm** (Лабораторная работа 23) - для более сложной или повторно используемой логики на полноценном языке (Rust/Go), с версиями
  и распространением в виде OCI-образа, выполняемого в песочнице.
- **Встроенные CRD** (`AuthorizationPolicy`, `Telemetry`, ...) - всегда сначала отдавайте предпочтение им;
  используйте Lua/Wasm только когда они не позволяют выразить необходимое.

> `EnvoyFilter` - низкоуровневый API, чувствительный к версиям. Istio предупреждает, что его конфигурация может
> изменяться между релизами. Делайте такие патчи минимальными и тестируйте их при обновлениях.
