[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 23 - Эталонное решение

Установлен Istio `1.29.1` (ingress-шлюз использует NodePort `32080`). Приложение `ping-pong`
развёрнуто в пространстве имён `app` и доступно по адресу `http://myapp.local:32080/`.

## Цель

Расширить плоскость данных Envoy модулем **WebAssembly**: загрузить Wasm-расширение
сообщества `basic_auth` на ingress-шлюзе, чтобы запросы требовали HTTP Basic-аутентификацию.

> Istio `1.29` использует API `WasmPlugin` (`extensions.istio.io/v1alpha1`). В версии `1.30+`
> его заменяет API `TrafficExtension`.

## Шаг 1. Исходное состояние (аутентификация не требуется)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Шаг 2. Примените WasmPlugin

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

Агент Istio на ingress-шлюзе скачивает OCI-образ Wasm, локально кэширует его
и внедряет как HTTP-фильтр. Подождите несколько секунд.

## Шаг 3. Проверка

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Принцип работы

- **WebAssembly (Wasm)** позволяет добавлять пользовательскую логику в Envoy без пересборки прокси
  и динамически загружать её во время выполнения.
- **`url: oci://...`**: модуль поставляется как OCI-артефакт; агент Istio скачивает и
  кэширует его. Также можно использовать `file://` (встроенный в образ) или `http(s)://`.
- **`phase: AUTHN`** размещает фильтр в начале цепочки (до маршрутизации/authz).
- **`selector`** ограничивает плагин рабочими нагрузками по меткам (здесь ingress-шлюз). Объект
  WasmPlugin в `istio-system` с селектором шлюза влияет только на шлюз.
- **`pluginConfig`** передаётся модулю. Модуль `basic_auth` считывает
  `basic_auth_rules` (префикс пути, методы и допустимые учётные данные).

## Когда стоит использовать Wasm

- Пользовательская аутентификация, добавление/обогащение заголовков, проверка запросов или логика протокола, которую
  встроенные CRD Istio (`AuthorizationPolicy`, `EnvoyFilter`) не могут выразить.
- Сначала отдавайте предпочтение встроенным API; используйте Wasm, когда в плоскости данных действительно нужен пользовательский код.
  Учитывайте эксплуатационные затраты: распространение модулей, управление версиями и получение во время выполнения
  (`failStrategy` управляет поведением при неудачной загрузке).
