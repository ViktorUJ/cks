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
grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

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

prometheus:
  prometheusSpec:
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
```


установливаем приложение 
```
k apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-143/tasks/eks/labs/03/worker/files/tasks/1.yaml

```