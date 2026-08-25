[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 25 - Эталонное решение

Установлены Istio `1.29.1` и Prometheus. **Flagger** работает в `istio-system`. Пространство имен
`test` (istio-injection) содержит демонстрационное приложение **podinfo** (`6.0.0`),
**flagger-loadtester** (генерирует трафик во время анализа), а `public-gateway` существует
в `istio-system`.

## Цель

Создать ресурс `Canary`, чтобы Flagger выполнял **постепенное развертывание**: при каждом
новом образе постепенно перенаправлять трафик на canary, проверять метрики и автоматически
продвигать его (или автоматически откатывать при сбое).

## Шаг 1. Создайте Canary

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## Шаг 2. Дождитесь инициализации Flagger

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## Шаг 3. Запустите canary-релиз

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger обнаруживает новую ревизию и запускает анализ: перенаправляет 20% → 40% → 50%
трафика на canary, проверяя `request-success-rate` и `request-duration` через каждый
интервал. Loadtester продолжает отправлять трафик, поэтому метрики существуют.

## Шаг 4. Наблюдайте за продвижением

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

Продвижение занимает примерно 2-3 минуты с указанными выше настройками. Запустите `check_result` после того,
как `podinfo-primary` будет обновлен до `6.0.1`.

## Автоматический откат (необязательно)

Запустите еще один релиз и внесите ошибки во время анализа:

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

Когда количество неудачных проверок метрик достигает порога, Flagger останавливает процесс и выполняет откат - трафик
возвращается к primary, canary масштабируется до нуля, а STATUS становится `Failed`.

## Как это работает

- Flagger отслеживает целевой `Deployment`. При изменении спецификации он создает/обновляет
  развертывание **canary** и постепенно перенаправляет трафик через веса Istio
  `VirtualService`/`DestinationRule`.
- На каждом этапе он запрашивает у **Prometheus** настроенные метрики; если они остаются в
  пределах порогов, он продвигается дальше, иначе выполняет откат после `threshold` сбоев.
- `podinfo-primary` всегда содержит «известно хорошую» версию; рабочий трафик обслуживается
  primary, пока canary полностью не пройдет проверки и не будет продвинут.
- Это превращает рискованный ручной canary (перенаправление трафика в лабораторной работе 06) в автоматизированный
  релиз с контролем по метрикам и встроенным откатом - суть постепенного развертывания.
