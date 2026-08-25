[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 32 - Эталонное решение

Установлен Istio `1.29.1` (профиль по умолчанию). Пространство имён `app` (с
включённым istio-injection) запускает образ `viktoruj/ping_pong`, который
использует gRPC (`PingPong.Echo` возвращает имя хоста обслуживающего pod):

- **grpc-server** - gRPC-сервер Echo/Health, **3 реплики** (gRPC на порту
  `8079`);
- **grpc-client** - тот же образ, используемый для создания gRPC-нагрузки
  (`/app -grpc-client ...`).

**Service** `grpc-server` создан с **неправильно названным** портом (`tcp`).
Из-за этого Istio рассматривает порт `8079` как необработанный L4 TCP: одно
долгоживущее HTTP/2 gRPC-соединение закрепляется за одним pod, поэтому клиент
видит только **один** отдельный сервер, и балансировка по запросам не происходит.

## Цель

1. Заставить Istio распознавать порт gRPC, чтобы он выполнял балансировку
   нагрузки **по запросам** (HTTP/2) между всеми backend pod.
2. Добавить `VirtualService` для `grpc-server` с gRPC **повторными попытками** и
   **тайм-аутом**.

## Шаг 1. Исправьте название порта Service

gRPC использует HTTP/2, а не необработанный TCP. Istio определяет протокол по
**префиксу** имени порта (`grpc`, `http2`, ...) или явному полю `appProtocol`.
Переименуйте порт в `grpc` (и/или установите `appProtocol: grpc`):

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

Эквивалентный полный манифест:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

Как только Istio увидит кластер HTTP/2 (gRPC), Envoy балансирует **каждый
запрос** внутри общего соединения между всеми endpoint без дополнительной
настройки.

## Шаг 2. VirtualService с gRPC-повторными попытками + тайм-аутом

gRPC работает поверх HTTP, поэтому он настраивается через блок `http` (не
`tcp`): применяются повторные попытки, тайм-ауты, маршрутизация по заголовкам и
балансировка по запросам.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` использует условия с поддержкой gRPC: `unavailable`, `cancelled`,
  `deadline-exceeded` соответствуют кодам состояния gRPC; `refused-stream` и
  `connect-failure` покрывают проблемы транспорта.
- `timeout` ограничивает весь запрос; `perTryTimeout` ограничивает каждую
  попытку.

## Шаг 3. (необязательно) Закрепите политику балансировки нагрузки

Балансировка по запросам включена по умолчанию, когда порт является gRPC. Чтобы
явно задать политику:

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## Шаг 4. Проверьте

Создайте gRPC-нагрузку с клиента и убедитесь, что запросы достигают **всех
трёх** backend pod (балансировка по запросам):

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

Ожидаемый итог:

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` доказывает, что запросы балансируются по запросам. До
исправления (порт назывался `tcp`) та же команда сообщает `distinct servers: 1`.

## Почему это работает

- **gRPC использует HTTP/2, а не TCP.** При представлении L4/TCP Envoy
  балансирует *соединения*: один gRPC-клиент поддерживает единственное
  долгоживущее соединение, поэтому каждый вызов закрепляется за одним pod.
  Объявление порта как `grpc` заставляет Envoy разбирать HTTP/2 и балансировать
  **каждый запрос** (поток) между endpoint.
- **Название порта является переключателем.** Порт должен называться `grpc` /
  `grpc-*` (или `http2`) либо иметь `appProtocol: grpc`. Нейтральное имя (`tcp`,
  без имени) отключает каждую функцию L7: нет LB по запросам, повторных попыток,
  тайм-аутов и метрик gRPC.
- **Функции L7 применяются к gRPC.** Поскольку это HTTP, gRPC получает
  `http`-повторные попытки (с `retryOn`, поддерживающим gRPC),
  `timeout`/`perTryTimeout`, маршрутизацию по заголовкам, внедрение ошибок и
  расширенную телеметрию, точно так же, как обычный HTTP.
