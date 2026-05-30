keda workshop

кластер eks , + karpenter и веб приложение (сейчас 5 под статических) .  +  прометей собирает метрики с приложения 

необходимо установить   кеда  ,  и сделать скалирование приложения в зависимости от  среднего количества запросов

---

проверяем какие ноде пулы есть 

```
k get nodepools.karpenter.sh 
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s

```

у нас подготовленны 2 нодепулы , мониторинг - для  прометеус,  keda , metric 

default - для тестового приложения

```
#  k get nodepools.karpenter.sh monitoring -o yaml 
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  annotations:
    karpenter.sh/nodepool-hash: "3585001658261092566"
    karpenter.sh/nodepool-hash-version: v3
  creationTimestamp: "2026-05-30T08:27:40Z"
  generation: 1
  name: monitoring
  resourceVersion: "3100"
  uid: e59fb225-6ca9-4477-a06e-e016967e1f19
spec:
  disruption:
    budgets:
    - nodes: 33%
    consolidateAfter: 300s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 100
  template:
    metadata:
      labels:
        work_type: monitoring
    spec:
      expireAfter: 720h
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: monitoring
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - spot
        - on-demand
      - key: karpenter.k8s.aws/instance-category
        operator: In
        values:
        - t
        - m
        - r
        - c
      - key: karpenter.k8s.aws/instance-generation
        operator: Gt
        values:
        - "2"
      - key: karpenter.k8s.aws/instance-size
        operator: In
        values:
        - small
        - medium
        - large
        - xlarge
        - 2xlarge
        - 4xlarge
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring

```

---

## Установка Prometheus Operator

Устанавливаем kube-prometheus-stack (официальный оператор) и metrics-server через helm.  
Grafana отключена. Все поды размещаются на nodepool `monitoring`.

```bash
# Добавляем helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Создаём values файл
cat <<'EOF' > prometheus-values.yaml
# WARNING: LoadBalancer для Prometheus открыт без аутентификации.
# Это сделано в рамках лабораторной работы для удобства доступа.
# В production окружении Prometheus должен быть защищён:
# - аутентификация (basic auth, OAuth2 proxy)
# - ограничение доступа по IP (Security Groups, NetworkPolicy)
# - использование Ingress с TLS

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

# Создаём values для metrics-server
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

# Устанавливаем prometheus operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# Устанавливаем metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

---

### Проверка

```bash
# Проверяем что поды запустились на нодах с label work_type=monitoring
kubectl get pods -n monitoring -o wide

# Проверяем что ноды из nodepool monitoring поднялись
kubectl get nodes -l work_type=monitoring

# Проверяем что metrics-server работает
kubectl top nodes

# Получаем адрес LoadBalancer для доступа к Prometheus UI
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo 
```


установливаем приложение 
```
k apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-143/tasks/eks/labs/03/worker/files/tasks/1.yaml

```

проверяем что риложение запустилось
```
 k get po -n team-19 
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s

```
посморим какие нодеклэймы у нас существуют
```
k get nodeclaims.karpenter.sh 
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m

```
отдельныя нода для мониторинга и отдельная нода для под приложения

---

## Настройка сбора метрик с приложения

Приложение `ping_pong` экспортирует prometheus метрики на порту `9090` по пути `/metrics`.  
Метрики: `requests_total`, `requests_per_second`, `requests_per_minute`, `goroutines`.

Нужно добавить порт метрик в Service и создать ServiceMonitor:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: team19-metrics
  namespace: team-19
  labels:
    app: team19
spec:
  ports:
  - name: metrics
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    app: team19
---
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

### Проверка что Prometheus видит target

```bash
# Через Prometheus UI -> Status -> Targets
# Или через API:
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl "http://${PROM_URL}:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.namespace=="team-19")'
```

### Проверка что метрики приложения появились в Prometheus

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Проверяем метрику requests_total
curl -s "http://${PROM_URL}:9090/api/v1/query?query=requests_total" | jq '.data.result'

# Проверяем requests_per_second
curl -s "http://${PROM_URL}:9090/api/v1/query?query=requests_per_second" | jq '.data.result'

# Проверяем requests_per_minute
curl -s "http://${PROM_URL}:9090/api/v1/query?query=requests_per_minute" | jq '.data.result'
```

Если результат пустой `[]` — значит ServiceMonitor ещё не подхвачен. Проверяем:

```bash
# Target должен быть в состоянии UP
curl -s "http://${PROM_URL}:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

Также можно открыть в браузере `http://<PROM_URL>:9090` и в поле Expression ввести `requests_total`.


---

## Установка KEDA

KEDA размещается на тех же нодах что и Prometheus (nodepool `monitoring`).

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
# Проверяем что поды KEDA запустились на monitoring нодах
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# Проверяем что CRD установлены
kubectl get crd | grep keda
```

---

## Настройка автоскейлинга через KEDA

### Доступные метрики приложения

Приложение `ping_pong` экспортирует следующие Prometheus метрики (порт 9090, path /metrics):

| Метрика | Тип | Описание |
|---------|-----|----------|
| `requests_total` | Counter | Общее количество запросов |
| `requests_per_second` | Gauge | Текущий RPS (запросов в секунду) |
| `requests_per_minute` | Gauge | Текущий RPM (запросов в минуту) |
| `goroutines` | Gauge | Количество горутин |

Для скейлинга используем `requests_per_second` — это Gauge метрика, показывающая текущий RPS на каждом поде.

### ScaledObject для KEDA

Правило: если среднее количество запросов в секунду на под превышает 5 — скейлим вверх.

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
  pollingInterval: 15
  cooldownPeriod: 30
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      query: avg(requests_per_second{namespace="team-19", service="team19-metrics"})
      threshold: "5"
      activationThreshold: "1"
EOF
```

### Проверка ScaledObject

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```

---

## Генератор трафика

Запускаем под который будет генерировать нагрузку на наше приложение:

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
        wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        sleep 0.1
      done
EOF
```

### Наблюдаем за скейлингом

```bash
# Смотрим как растёт количество подов
kubectl get pods -n team-19 -w

# Смотрим HPA
kubectl get hpa -n team-19 -w

# Проверяем метрику в Prometheus
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://${PROM_URL}:9090/api/v1/query?query=avg(requests_per_second{namespace=\"team-19\"})" | jq '.data.result'
```

### Остановка генератора трафика

```bash
kubectl delete pod traffic-generator -n team-19
```

После остановки трафика, через `cooldownPeriod` (30 сек) KEDA начнёт скейлить обратно до `minReplicaCount: 1`.
