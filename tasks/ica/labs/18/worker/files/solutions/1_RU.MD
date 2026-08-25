[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 18 - Эталонное решение

Установлен Istio `1.29.1` (ingress gateway на NodePort `32080`) с распределенной
трассировкой, подключенной к провайдеру расширения `zipkin` (`zipkin.istio-system:9411`).
Аддон **Jaeger** развернут в качестве бэкенда трассировки. Приложение `ping-pong` развернуто
в пространстве имен `app` и доступно по адресу `http://myapp.local:32080/`. Логирование
доступа **отключено** по умолчанию, и ресурс `Telemetry` пока не существует.

## Цель

Используйте **Telemetry API**, чтобы:
- включить логирование доступа Envoy для пространства имен `app` (встроенный провайдер `envoy`);
- включить трассировку через провайдер `zipkin` с выборкой 100%, чтобы трассы действительно
  собирались в Jaeger.

## Шаг 1. Убедитесь, что журналы доступа ВЫКЛЮЧЕНЫ

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
curl -s -o /dev/null http://myapp.local:32080/
kubectl logs -n app "$POD" -c istio-proxy --tail=50   # no access log lines
```

## Шаг 2. Настройте журналы и трассы через Telemetry

```bash
cat > telemetry.yaml <<'EOF'
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: app-telemetry
  namespace: app
spec:
  accessLogging:
    - providers:
        - name: envoy
  tracing:
    - providers:
        - name: zipkin
      randomSamplingPercentage: 100.0
EOF

kubectl apply -f telemetry.yaml
```

## Шаг 3. Сгенерируйте трафик

```bash
for i in $(seq 30); do curl -s -o /dev/null http://myapp.local:32080/; done
```

## Шаг 4. Проверьте сбор данных

Журналы доступа (в stdout sidecar):

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n app "$POD" -c istio-proxy --tail=50 | grep 'GET / HTTP'
```

Трассы (в Jaeger, запрос изнутри кластера):

```bash
kubectl exec -n app deploy/curl-client -- \
  curl -s 'http://tracing.istio-system:80/jaeger/api/services' | tr ',' '\n' | grep ping-pong
```

Также можно выполнить перенаправление портов для UI Jaeger:

```bash
kubectl -n istio-system port-forward svc/tracing 16686:80
# open http://localhost:16686/jaeger and pick the ping-pong service
```

## Куда поступают журналы и трассы

| Сигнал | Провайдер | Назначение |
|---|---|---|
| Журналы доступа | `envoy` (встроенный) | stdout sidecar → `kubectl logs -c istio-proxy` |
| Трассы | провайдер расширения `zipkin` | Jaeger (`zipkin.istio-system:9411`) → UI Jaeger |

## Как это работает

- **Telemetry API** (`telemetry.istio.io`) декларативно настраивает журналы, метрики
  и трассы, а также поддерживает иерархию области действия: вся сетка (корневое пространство имен) → пространство имен →
  рабочая нагрузка (`selector`).
- **`accessLogging.providers.name: envoy`** записывает журналы доступа в stdout sidecar.
- **`tracing.providers.name: zipkin`** направляет спаны в провайдер расширения `zipkin`,
  объявленный в `meshConfig.extensionProviders`, который перенаправляет их в Jaeger.
  Без ссылки на провайдер политике выборки было бы некуда отправлять спаны.
- **`randomSamplingPercentage: 100`** трассирует каждый запрос (в рабочей среде используйте
  небольшое значение, чтобы контролировать накладные расходы).
