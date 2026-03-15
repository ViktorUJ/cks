# ping_pong_front

<p align="center">
    <a href="https://github.com/ViktorUJ/cks"><img src="https://raw.githubusercontent.com/ViktorUJ/terraform-aws-vpc/master/img/logo_192x192.png" width="192" height="192" alt="SRE Learning Platform"/></a>
</p>

Лёгкий **HTTP reverse proxy** на Go, созданный для **эмуляции поведения фронтенд-сервисов** в окружениях Kubernetes/Istio. Основное назначение — тестирование **политик повторных попыток Istio (retry)** и сценариев управления трафиком, в частности ситуаций, когда бэкенд-сервис становится недоступным и Istio должен выполнить повторные запросы от имени фронтенда.

Сервис проксирует входящие запросы на настраиваемый бэкенд-сервер, сохраняя все **заголовки, query-параметры и тело запроса**, и возвращает ответ бэкенда, дополненный **метаданными прокси**: кодом ответа и временем ответа бэкенда. Поскольку сервис прозрачно передаёт коды ошибок бэкенда (5xx, таймауты), Istio видит реальные условия сбоя и запускает логику повторных попыток точно так же, как с настоящим фронтенд-сервисом.

## Содержание
- [Как это работает](#как-это-работает)
- [Сценарии использования с Istio](#сценарии-использования-с-istio)
- [Примеры запуска](#примеры-запуска)
- [Запуск](#запуск)
  - [Docker](#запуск-в-docker)
  - [Kubernetes](#запуск-в-kubernetes)
  - [Сборка из исходного кода](#сборка-из-исходного-кода)
- [Конфигурация](#конфигурация)
- [Формат ответа](#формат-ответа)
- [API](#api)

---

## Как это работает

```
Клиент  →  ping_pong_front  →  Бэкенд (BACKEND_URL)
                ↑
        копирует все заголовки,
        query-параметры, тело запроса
        измеряет время ответа
        возвращает тело ответа бэкенда +
        блок с метаданными прокси
```

Каждый входящий запрос пересылается на `BACKEND_URL` со следующими параметрами:
- все оригинальные заголовки (включая пользовательские)
- оригинальный HTTP-метод
- оригинальный путь и query-строка
- оригинальное тело запроса
- добавленный заголовок `X-Forwarded-For` с IP-адресом клиента

Ответ клиенту включает:
- все заголовки от бэкенда
- заголовок `X-Backend-Status-Code`
- заголовок `X-Backend-Response-Time`
- блок с метаданными прокси перед телом ответа бэкенда

---

## Сценарии использования с Istio

`ping_pong_front` выступает в роли реального фронтенда, который обращается к бэкенду через service mesh Istio. Это делает его идеальным инструментом для тестирования функций управления трафиком Istio без написания собственного кода приложения.

### Тестирование повторных попыток Istio при сбое бэкенда

Разверните `ping_pong_front` как фронтенд и `ping_pong` как бэкенд. Настройте `VirtualService` Istio с политикой повторных попыток, затем симулируйте сбои бэкенда (остановка подов, инъекция ошибок) и наблюдайте, как Istio прозрачно выполняет повторные запросы:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: backend
spec:
  hosts:
    - backend-svc
  http:
    - retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure
      route:
        - destination:
            host: backend-svc
```

Поскольку `ping_pong_front` передаёт реальный код ответа бэкенда (`X-Backend-Status-Code`) и время ответа (`X-Backend-Response-Time`), в ответе чётко видно, выполнял ли Istio повторные попытки и какая из них завершилась успешно.

### Типовые сценарии тестирования

| Сценарий | Как симулировать |
|---|---|
| Падение пода бэкенда | `kubectl delete pod <backend-pod>` |
| Перегрузка бэкенда (503) | Установить `MAX_RESPONSE_WORKER=1` на `ping_pong` бэкенде |
| Медленный ответ / таймаут бэкенда | Установить `RESPONSE_DELAY=6000` на бэкенде, `BACKEND_TIMEOUT=5s` на фронте |
| Инъекция ошибок Istio | Добавить `HTTPFaultInjection` в `VirtualService` бэкенда |

---

## Примеры запуска

### Базовый прокси к бэкенд-сервису

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080
```

### Кастомный порт и таймаут бэкенда

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080 \
  --env SRV_PORT=9000 \
  --env BACKEND_TIMEOUT=10s
```

### Совместное использование с ping_pong в качестве бэкенда

```bash
# запуск бэкенда
kubectl run backend --image viktoruj/ping_pong --env SRV_PORT=8081

# запуск прокси перед ним
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://backend:8081 \
  --env SRV_PORT=8080
```

### Отключить логирование в stdout

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080 \
  --env ENABLE_OUTPUT=false
```

---

## Запуск

### Запуск в Docker

```bash
docker run -d -p 8080:8080 \
  -e BACKEND_URL=http://my-backend:8081 \
  viktoruj/ping_pong_front
```

### Запуск в Kubernetes

```bash
kubectl run front --image viktoruj/ping_pong_front \
  --env BACKEND_URL=http://my-backend-svc:8080
```

### Сборка из исходного кода

```bash
cd docker/ping_pong_front/app
go mod tidy
go run app.go
# или собрать бинарник
go build -o ping_pong_front app.go
```

Запуск с переменными окружения:

```bash
BACKEND_URL=http://localhost:8081 SRV_PORT=8080 go run app.go
```

---

## Конфигурация

| Переменная окружения | По умолчанию            | Описание                                                                              |
|----------------------|-------------------------|---------------------------------------------------------------------------------------|
| `BACKEND_URL`        | `http://localhost:8081` | URL бэкенд-сервера. Все запросы пересылаются сюда.                                    |
| `SRV_PORT`           | `8080`                  | Порт, на котором слушает прокси.                                                      |
| `BACKEND_TIMEOUT`    | `5s`                    | Таймаут запроса к бэкенду. Принимает формат Go duration: `5s`, `500ms`, `1m30s`.     |
| `ENABLE_OUTPUT`      | `true`                  | Логировать запросы в stdout.                                                          |

---

## Формат ответа

Каждый ответ содержит блок с метаданными прокси, за которым следует полное тело ответа бэкенда:

```
--- Proxy Info ---
Backend URL      : http://my-backend:8081/some/path?q=1
Backend Status   : 200
Backend Response Time: 42.3ms
--- Backend Response ---
<полное тело ответа бэкенда>
```

В заголовках ответа также присутствуют:

| Заголовок                 | Описание                                    |
|---------------------------|---------------------------------------------|
| `X-Backend-Status-Code`   | HTTP-код ответа, возвращённый бэкендом      |
| `X-Backend-Response-Time` | Время, за которое бэкенд ответил на запрос  |

### Пример

```bash
curl -v http://localhost:8080/test?foo=bar -H "X-My-Header: hello"
```

```
< HTTP/1.1 200 OK
< X-Backend-Status-Code: 200
< X-Backend-Response-Time: 3.812ms

--- Proxy Info ---
Backend URL      : http://localhost:8081/test?foo=bar
Backend Status   : 200
Backend Response Time: 3.812ms
--- Backend Response ---
Server Name: ping_pong_server
URL: http://localhost:8081/test?foo=bar
...
```

---

## API

| Путь       | Описание                                  |
|------------|-------------------------------------------|
| `/healthz` | Проверка работоспособности, возвращает `ok` |
| `/`        | Прокси — пересылает запрос на бэкенд      |

### Проверка работоспособности

```bash
curl http://localhost:8080/healthz
# ok
```
