[Английская версия](README.MD)


# Лабораторная работа: Автомасштабирование приложения с KEDA и Prometheus

## Описание

Эта лабораторная работа показывает, как автоматически масштабировать веб-приложение в Amazon EKS с помощью **KEDA** (Kubernetes Event-Driven Autoscaling) на основе метрик **Prometheus**. Приложение экспортирует собственные метрики запросов, Prometheus их собирает, а KEDA масштабирует деплоймент вверх и вниз в зависимости от реального количества запросов в секунду (RPS).

Кластер уже подготовлен с **Karpenter** и двумя выделенными NodePool:
- `monitoring` — для стека мониторинга (Prometheus, KEDA, metrics-server)
- `default` — для тестового приложения

**Что вы изучите:**
- Как установить официальный Prometheus Operator (kube-prometheus-stack) через Helm
- Как закрепить нагрузки за выделенными нодами с помощью nodeAffinity и tolerations
- Как опубликовать Prometheus через LoadBalancer для быстрого доступа
- Как собирать пользовательские метрики приложения через ServiceMonitor
- Как установить KEDA и настроить ScaledObject на основе запроса к Prometheus
- Как сгенерировать нагрузку и наблюдать автоматическое масштабирование вверх/вниз
- Как корректно удалить облачные ресурсы (LoadBalancer, ноды Karpenter)

## Содержание
- [Подготовка окружения](#подготовка-окружения)
  - [Запуск лабораторной работы](#запуск-лабораторной-работы)
  - [Создаваемые ресурсы](#создаваемые-ресурсы)
  - [Предварительные требования](#предварительные-требования)
- [Просмотр NodePool](#просмотр-nodepool)
- [Установка стека мониторинга](#установка-стека-мониторинга)
  - [Prometheus Operator и metrics-server](#prometheus-operator-и-metrics-server)
  - [Проверка установки](#проверка-установки)
- [Развёртывание приложения](#развёртывание-приложения)
- [Сбор метрик приложения](#сбор-метрик-приложения)
  - [Создание ServiceMonitor](#создание-servicemonitor)
  - [Проверка таргета](#проверка-таргета)
  - [Проверка метрик в Prometheus](#проверка-метрик-в-prometheus)
- [Установка KEDA](#установка-keda)
- [Настройка автомасштабирования](#настройка-автомасштабирования)
  - [Доступные метрики приложения](#доступные-метрики-приложения)
  - [Создание ScaledObject](#создание-scaledobject)
- [Генерация нагрузки и наблюдение за масштабированием](#генерация-нагрузки-и-наблюдение-за-масштабированием)
- [Очистка ресурсов](#очистка-ресурсов)
- [Заключение](#заключение)


## Подготовка окружения

### Запуск лабораторной работы
[Запуск платформы через docker](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

Для запуска лабораторной работы выполните команду:

```bash
TASK=03 make run_eks_task
```

**Что происходит при запуске этой команды:**
- Terraform/Terragrunt автоматически разворачивает всю необходимую инфраструктуру в AWS
- Процесс занимает примерно 15-20 минут
- В выводе команды будет показана важная информация (SSH-подключение, имена ресурсов)

### Создаваемые ресурсы

При запуске команды будет развёрнута следующая инфраструктура AWS:

#### Сетевая инфраструктура (VPC)
- **VPC** с CIDR-блоком `10.10.0.0/16` в регионе `eu-central-1`
- **Публичные подсети** для ресурсов с доступом в интернет (`eks-AZ-1`, `eks-AZ-2`)
- **Приватные подсети** для нод EKS и RDS
- **NAT Gateway** для исходящего интернет-трафика из приватных подсетей

#### EKS-кластер
- **EKS Control Plane** версии `1.35`
- **Fargate-профиль** для системных подов (`kube-system`, `karpenter`) — обратите внимание: CoreDNS работает на Fargate
- **Karpenter** версии `1.8.1` (контроллер автомасштабирования)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Преднастроенные NodePool Karpenter
- **`default`** — для нагрузок приложения (консолидирует пустые ноды через 30с)
- **`monitoring`** — выделен под стек мониторинга, с taint `dedicated=monitoring:NoSchedule` и label `work_type=monitoring` (консолидирует через 300с)

#### Основной файл конфигурации

Все параметры инфраструктуры заданы в файле `tasks/eks/labs/03/env.hcl`. Чтобы изменить конфигурацию, отредактируйте соответствующие параметры в этом файле.

### Предварительные требования

Убедитесь, что у вас есть:
- **AWS CLI** с соответствующими правами доступа
- Увеличенные лимиты на ноды в регионе `eu-central-1` (при необходимости)
- Подключение к worker-ноде по SSH (строку подключения смотрите в выводе `make run_eks_task`)
- Доступные на worker-ноде `kubectl`, `helm` и `jq`


## Просмотр NodePool

Два NodePool уже подготовлены. Проверим их:

```bash
kubectl get nodepools.karpenter.sh
```

**Ожидаемый результат:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — для Prometheus, KEDA и metrics-server
- **`default`** — для тестового приложения

Посмотрим NodePool `monitoring` подробнее:

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**Ключевые части спецификации:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # используется в nodeAffinity
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # сюда попадут только поды с подходящим toleration
```

**Что это значит:** поды мониторинга должны иметь и `nodeAffinity` на `work_type=monitoring`, и `toleration` для `dedicated=monitoring:NoSchedule`. Это гарантирует, что стек мониторинга работает на своих нодах, и ничего лишнего туда не попадёт.


## Установка стека мониторинга

### Prometheus Operator и metrics-server

Устанавливаем **kube-prometheus-stack** (официальный Prometheus Operator) и **metrics-server** через Helm. Grafana отключена. Все компоненты закреплены за NodePool `monitoring` через `nodeAffinity` + `tolerations`.

> **Замечание по безопасности:** Service Prometheus ниже публикуется через публичный LoadBalancer **без аутентификации**. Это сделано только для удобства лабораторной работы. В production Prometheus должен быть защищён (аутентификация / OAuth2 proxy, ограничение по IP через Security Groups или NetworkPolicy, Ingress с TLS).

```bash
# Добавляем Helm-репозитории
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Создаём values-файл для Prometheus
cat <<'EOF' > prometheus-values.yaml
# ВНИМАНИЕ: LoadBalancer Prometheus открыт без аутентификации.
# Это только для лабораторной работы. В production защитите Prometheus
# аутентификацией, ограничением по IP (Security Groups / NetworkPolicy) и TLS.

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# Создаём values-файл для metrics-server
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# Устанавливаем Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# Устанавливаем metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**Пояснения к values:**
- `serviceMonitorSelectorNilUsesHelmValues: false` + пустые селекторы позволяют Prometheus подхватывать ServiceMonitor из **всех** namespace (нужно, чтобы позже собирать метрики приложения).
- Каждый компонент объявляет `nodeAffinity` (`work_type=monitoring`), поэтому планируется **только** на ноды мониторинга. Одного `nodeSelector` недостаточно — affinity гарантирует размещение.
- `node-exporter` получает только toleration (он должен работать на каждой ноде как DaemonSet).

### Проверка установки

```bash
# Все поды мониторинга должны быть Running на нодах мониторинга
kubectl get pods -n monitoring -o wide

# Ноды мониторинга должны подняться
kubectl get nodes -l work_type=monitoring

# metrics-server должен работать
kubectl top nodes

# Получаем адрес LoadBalancer Prometheus (UI Prometheus на порту 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Откройте `http://<LB-ADDRESS>:9090` в браузере для доступа к UI Prometheus.


## Развёртывание приложения

Разверните тестовое приложение (`ping_pong`). Service публикует два порта: `http` (80 → 8080) и `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

Проверьте, что приложение запустилось:

```bash
kubectl get po -n team-19
```

**Ожидаемый результат:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

Проверьте NodeClaim — должна быть отдельная нода для мониторинга и отдельная для приложения:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ожидаемый результат:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## Сбор метрик приложения

### Создание ServiceMonitor

Приложение экспортирует метрики Prometheus на порту `9090` по пути `/metrics`. Порт `metrics` уже определён в Service приложения, поэтому нужен только ServiceMonitor. Label `release: prometheus` позволяет Prometheus Operator подхватить его.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### Проверка таргета

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Таргет должен присутствовать и быть здоровым (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Проверка метрик в Prometheus

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Проверяем метрику requests_total
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

Если результат пустой `[]` — значит ServiceMonitor ещё не подхвачен. Подождите немного и повторите, или проверьте здоровье таргета выше.

Также можно открыть `http://<PROM_URL>:9090` в браузере и ввести `requests_total` в поле Expression.

> **Подсказка:** значение метрики возвращается как `"value": [<timestamp>, "<значение>"]`. Первое число — время скрейпа, второе (строка) — само значение. Оно будет `0`, пока к приложению не пойдёт трафик.


## Установка KEDA

KEDA работает на тех же нодах, что и Prometheus (NodePool `monitoring`). Helm-чарт KEDA применяет `tolerations` и `affinity` верхнего уровня ко **всем** своим компонентам (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# Глобальные tolerations и affinity для всех компонентов KEDA
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### Проверка KEDA

```bash
# Поды KEDA должны быть Running на нодах мониторинга
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# CRD KEDA должны быть установлены
kubectl get crd | grep keda
```

> **Примечание:** `metrics-apiserver` KEDA — это внутренний компонент KEDA (он предоставляет внешние метрики для Kubernetes HPA). Это **не** то же самое, что кластерный `metrics-server`, установленный ранее — нужны оба.


## Настройка автомасштабирования

### Доступные метрики приложения

Приложение `ping_pong` экспортирует следующие метрики Prometheus (порт 9090, путь `/metrics`):

| Метрика | Тип | Описание |
|---------|-----|----------|
| `requests_total` | Counter | Общее количество запросов |
| `requests_per_second` | Gauge | Мгновенный RPS (шумный, не сбрасывается в 0 в простое) |
| `requests_per_minute` | Gauge | Мгновенный RPM |
| `goroutines` | Gauge | Текущее количество горутин |

Для масштабирования используем **`rate(requests_total[1m])`**, а не сырой gauge `requests_per_second`. `rate()` на основе счётчика даёт настоящий сглаженный RPS, который линейно растёт с нагрузкой и честно падает к 0, когда трафик прекращается — благодаря этому порог легко подобрать.

### Создание ScaledObject

Правило: реплики = `ceil(sum(rate(requests_total[1m])) / threshold)`. Настроено быстрое уменьшение через `behavior`, чтобы поды удалялись быстро после падения нагрузки.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # Быстрое уменьшение: окно стабилизации 10с, можно убрать до 100% подов
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> настоящий RPS из счётчика; sum по всем подам.
      # реплики = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**Пояснения:**
- `threshold` — целевой RPS **на под**, который HPA старается поддерживать.
- `activationThreshold: 3` означает, что KEDA держит одну реплику, пока суммарный RPS не превысит 3, что исключает дёрганье в простое.
- В `query` используется `sum(...)` (суммарный RPS, не зависит от числа реплик), поэтому желаемое количество реплик стабильно. Использование `avg(...)` здесь приводило бы к осцилляции при добавлении подов.

Проверьте ScaledObject и созданный им HPA:

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## Генерация нагрузки и наблюдение за масштабированием

Запустите под, генерирующий нагрузку на Service приложения. Внутренний цикл отправляет N запросов, внешний `sleep 1` задаёт темп — поэтому число в `seq 1 N` примерно равно целевому RPS.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### Наблюдение за масштабированием

Один `watch` показывает поды, HPA и RPS на под из Prometheus сразу. Запрос PromQL URL-кодируется (`--data-urlencode`), иначе символы `{`, `}` и `=` ломают парсер.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**Что вы должны увидеть:** по мере роста нагрузки число подов стремится к `ceil(суммарный_rps / threshold)`. Колонка HPA `TARGETS` (RPS на под) совпадает с `rps per pod`, который выводит watch.

> **Подсказка по подбору:** подов ≈ (число в `seq 1 N`) / threshold. С `seq 1 50` и `threshold: 10` получится около 5 подов. Увеличьте число, чтобы получить больше подов.

### Остановка нагрузки

```bash
kubectl delete pod traffic-generator -n team-19
```

После остановки трафика `rate(requests_total[1m])` спадает к 0. В течение `cooldownPeriod` (10с) плюс окно стабилизации уменьшения (10с) KEDA масштабирует обратно до `minReplicaCount: 1`.


## Очистка ресурсов

### Удаление приложения

```bash
# Удаляем ScaledObject (KEDA перестанет управлять HPA)
kubectl delete scaledobject team19-scaledobject -n team-19

# Удаляем генератор трафика (если ещё запущен)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# Удаляем ServiceMonitor
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# Удаляем само приложение (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Удаление Prometheus (важно: удаляет LoadBalancer)

Удаление Helm-релиза удаляет Service типа LoadBalancer, и AWS освобождает ELB.

```bash
# Удаляем prometheus (это удалит Service LoadBalancer -> AWS ELB)
helm uninstall prometheus -n monitoring

# Удаляем metrics-server и keda
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

Проверяем, что LoadBalancer (ELB) действительно удалён:

```bash
# Service prometheus не должен существовать
kubectl get svc -n monitoring | grep prometheus

# Подтверждаем в AWS, что ELB удалён
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

Если Service по какой-то причине остался и блокирует удаление ELB, удалите его вручную:

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

Затем удалите namespace:

```bash
kubectl delete namespace monitoring
```

> **Важно:** всегда удаляйте Service типа LoadBalancer **до** удаления нод или кластера.
> Если сначала удалить ноды/кластер, AWS ELB может остаться "висеть" как orphaned-ресурс,
> и его придётся удалять вручную через консоль или CLI.

### Проверка, что Karpenter удалил все ноды

После удаления всех нагрузок ноды `default` и `monitoring` становятся пустыми, и Karpenter должен консолидировать (удалить) их.

```bash
# Наблюдаем, как количество nodeclaims уменьшается до нуля
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter удаляет пустые ноды согласно `consolidateAfter` каждого NodePool
(`default` = 30с, `monitoring` = 300с), поэтому ноды мониторинга удаляются дольше.

Ждём, пока обе команды не вернут пустой результат:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

Если нода не удаляется — проверьте поды, мешающие консолидации (например, поды без контроллера или с `karpenter.sh/do-not-disrupt`):

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### Удаление инфраструктуры

Только после того как Karpenter удалил все ноды, удалите инфраструктуру лабораторной работы:

```bash
TASK=03 make delete_eks_task
```

Введите `y` для подтверждения. Удаление занимает примерно 10-15 минут.

> Удаление инфраструктуры до того, как Karpenter удалит свои ноды, может оставить orphaned EC2-инстансы.


## Заключение

Поздравляем! Вы построили систему event-driven автомасштабирования на EKS.

**Что вы сделали:**

1. **Стек мониторинга** — установили официальный Prometheus Operator и metrics-server, закрепив их за выделенными нодами через nodeAffinity и tolerations
2. **Публикация** — опубликовали Prometheus через LoadBalancer для быстрого доступа (только для лабы, без аутентификации)
3. **Пользовательские метрики** — собрали собственные метрики запросов приложения через ServiceMonitor
4. **KEDA** — установили KEDA и настроили ScaledObject на основе запроса к Prometheus
5. **Автомасштабирование** — масштабировали приложение по реальному RPS через `rate(requests_total[1m])` с быстрым уменьшением
6. **Очистка** — корректно удалили LoadBalancer и дали Karpenter освободить ноды перед удалением инфраструктуры

**Ключевые выводы:**

- Используйте `rate()` на основе счётчика для стабильного, предсказуемого автомасштабирования вместо шумных мгновенных gauge
- Используйте `sum(...)` (а не `avg(...)`) в запросе скейлера, чтобы желаемое число реплик не осциллировало при добавлении подов
- Закрепляйте инфраструктурные нагрузки за выделенными нодами через nodeAffinity **и** tolerations
- Всегда удаляйте Service типа LoadBalancer до удаления кластера, чтобы избежать orphaned ELB

**Дополнительные ресурсы:**
- [Документация KEDA](https://keda.sh/docs/)
- [Prometheus scaler в KEDA](https://keda.sh/docs/latest/scalers/prometheus/)
- [Чарт kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Документация Karpenter](https://karpenter.sh/docs/)
