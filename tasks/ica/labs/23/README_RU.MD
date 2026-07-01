# Lab 23 — WasmPlugin: расширение data plane через WebAssembly

## Обзор

Иногда встроенных CRD Istio (`AuthorizationPolicy`, `EnvoyFilter`) не хватает — нужна
собственная логика прямо в data plane. Для этого есть **WebAssembly (Wasm)**: вы пишете
(или берёте готовый) модуль, и Envoy загружает его динамически в рантайме, без
пересборки прокси.

В этой лабе вы подключите community-модуль **`basic_auth`** на ingress gateway, чтобы
запросы требовали HTTP Basic-аутентификацию.

> Istio `1.29` использует API `WasmPlugin` (`extensions.istio.io/v1alpha1`). В `1.30+`
> ему на смену приходит API `TrafficExtension`.

Istio уже установлен (ingress gateway на NodePort `32080`), приложение `ping-pong`
развёрнуто в namespace `app` и опубликовано на `http://myapp.local:32080/`.

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"нет/неверные creds"| R["401 Unauthorized"]
    GW -->|"верные creds"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## Задание

1. Проверить, что без плагина приложение доступно (`200`).
2. Применить `WasmPlugin`, который на ingress gateway (`selector: istio=ingressgateway`)
   грузит модуль `basic_auth` из OCI-реестра и требует Basic-аутентификацию.
3. Проверить, что без учётных данных запрос отбивается `401`, а с корректными — `200`.

## Шаг 1. Базовое поведение (без auth)

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## Шаг 2. Применить WasmPlugin

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

Istio-agent на ingress gateway скачает OCI-образ Wasm, закеширует его локально и встроит
как HTTP-фильтр. Дайте несколько секунд.

## Шаг 3. Проверка

```bash
# без учётных данных -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# с корректными данными -> 200  (base64 от admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## Как это работает

- **WebAssembly (Wasm)** позволяет добавить в Envoy кастомную логику без пересборки
  прокси и загрузить её динамически в рантайме.
- **`url: oci://...`** — модуль поставляется как OCI-артефакт; istio-agent тянет и
  кеширует его. Также поддерживаются `file://` (вшит в образ) и `http(s)://`.
- **`phase: AUTHN`** ставит фильтр рано в цепочке (до роутинга/авторизации).
- **`selector`** ограничивает плагин ворклоадами по лейблам (здесь — ingress gateway).
- **`pluginConfig`** передаётся в модуль; `basic_auth` читает `basic_auth_rules` (префикс
  пути, методы, допустимые креды).

## Когда использовать Wasm

- Кастомная аутентификация, обогащение/валидация заголовков, протокольная логика,
  которую не выразить встроенными CRD.
- Сначала пробуйте встроенные API; Wasm — когда действительно нужен свой код в data
  plane. Учитывайте эксплуатационную цену: доставка модуля, версионирование и рантайм-
  загрузка (`failStrategy` задаёт поведение при неудачной загрузке).

## Проверка результата

Запустите на worker PC:

```bash
check_result
```

## Итог

Вы расширили data plane собственным Wasm-модулем, подгружаемым из OCI-реестра, и добавили
Basic-аутентификацию на границе mesh без изменения приложения. Работа с `WasmPlugin` —
senior-навык для случаев, когда встроенных возможностей Istio недостаточно.

## Инфраструктура

| Компонент | Тип | Кол-во | Роль |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | ёмкость для приложения |
| worker PC | `t3.small` | 1 | рабочее место: `kubectl`, `curl`, `check_result` |

Регион: `eu-central-1` (AZ `eu-central-1a` / `eu-central-1b`).
