[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 124 - эталонное решение (HPA, KEDA, Prometheus)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl и helm уже настроены
(kubeconfig собран через `aws eks update-kubeconfig` при загрузке машины).

## Задание 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## Задание 2. kube-prometheus-stack в namespace `monitoring`

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

Три флага здесь не косметика. Grafana и Alertmanager лабе не нужны, а Grafana - самый
тяжёлый под чарта (около 325 MiB на стенде). Явные `requests` переводят Prometheus из
`BestEffort` в `Burstable`: его потребность видит и планировщик, и Karpenter, который
выбирает размер ноды по сумме `requests`. Без этого стек мониторинга уезжает на самый
дешёвый инстанс, и kubelet выселяет Prometheus по memory pressure - подробный разбор в
README лабы.

Ждём готовности подов:

```bash
kubectl get pods -n monitoring -w
```

Дожидаемся, пока все поды перейдут в `Running` и `1/1` (или `2/2`) Ready - обычно это
занимает 2-3 минуты. Проверяем Service, на который будет смотреть KEDA, и класс QoS пода:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

Ожидаемый вывод второй команды - `Burstable`.

## Задание 3. KEDA в namespace `keda`

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

Проверяем, что оператор и metrics apiserver подняты:

```bash
kubectl get pods -n keda
```

Ожидаемый результат: поды с именами вида `keda-operator-...` и
`keda-operator-metrics-apiserver-...` в статусе `Running`.

## Задание 4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## Задание 5. ScaledObject со scaler `prometheus`

Метрика cAdvisor `container_cpu_usage_seconds_total` собирается kube-prometheus-stack со
всех подов из коробки, без ServiceMonitor. Считаем суммарный CPU usage подов ГЕНЕРАТОРА
нагрузки из задания 6, а не самого `demo-app`: приложение масштабируется по чужой нагрузке,
и обычный HPA по CPU так не умеет - ровно за этим и нужны внешние метрики.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

Проверить, что запрос вообще что-то возвращает, можно прямо из кластера (пока генератора
нет, ответ будет пустым, и это нормально - KEDA в таком случае отдаёт HPA ноль):

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

Проверяем, что KEDA взяла ScaledObject под контроль и создала HPA:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

HPA называется `keda-hpa-demo-app` - это доказательство, что KEDA не подменяет HPA, а
создаёт и ведёт обычный `HorizontalPodAutoscaler` под капотом.

## Задание 6. Нагрузочный тест: масштабирование вверх

Сначала фиксируем состояние до нагрузки:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

Создаём генератор нагрузки. Метка у него своя (`app=stress-generator`) - PromQL-запрос из
задания 5 отбирает поды по ИМЕНИ, а не по метке, поэтому подмешивать генератор в селектор
`demo-app` не нужно и вредно: два Deployment с пересекающимися селекторами - анти-паттерн.
`limits.cpu` обязателен, иначе четыре CPU-воркера отбирают процессор у kubelet и нода
уходит в `NotReady`. `nodeSelector` нужен потому, что `polinux/stress` собран только под
`amd64`, а NodePool лабы разрешает и `arm64`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

Наблюдаем, как растёт метрика и число реплик:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Ждём 1-2 минуты (KEDA опрашивает Prometheus, HPA считает реплики, Karpenter при
необходимости добавляет ноду). На стенде это выглядело так:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

Как только `REPLICAS` стало больше `1`, сохраняем:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## Задание 7. Снятие нагрузки: масштабирование вниз

```bash
kubectl delete deployment stress-generator -n eks-124
```

Поды генератора исчезают, их серий в Prometheus больше нет, KEDA отдаёт HPA ноль. Значение
`TARGETS` обнуляется секунд за 30, а вот реплики держатся: `stabilizationWindowSeconds` для
scaleDown у HPA по умолчанию равен 300 секундам. Замер со стенда - метрика ноль в 06:40:07,
реплики `5 -> 2 -> 1` в 06:44:40 и 06:45:07:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Как только `REPLICAS` вернулось к `1`, сохраняем артефакт:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## Задание 8. Обычный HPA против HPA, созданного KEDA

```bash
kubectl get hpa -A
```

В выводе HPA `keda-hpa-demo-app` ничем не отличается по колонкам от обычного HPA - те же
`TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`. Разница только в имени (префикс `keda-hpa-`) и
в том, кто им управляет: обычный HPA создаёт и правит инженер напрямую манифестом
`HorizontalPodAutoscaler`, а `keda-hpa-demo-app` создан и управляется KEDA operator по
ресурсу `ScaledObject` - удалите `ScaledObject`, и KEDA удалит этот HPA вместе с ним.

Сохраняем объяснение в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
В kubectl get hpa -A обычный HPA и HPA keda-hpa-demo-app выглядят одинаково по колонкам
TARGETS/MINPODS/MAXPODS/REPLICAS - разница только в имени и происхождении объекта.

KEDA не заменяет HPA: operator KEDA следит за ScaledObject и сам создаёт и управляет
обычным HorizontalPodAutoscaler с именем keda-hpa-<имя ScaledObject>, а metrics adapter
KEDA поставляет туда значение метрики через external.metrics.k8s.io. Реплики считает
тот же механизм HPA, что и всегда.
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## Быстрая проверка

```bash
check_result
```
