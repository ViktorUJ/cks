# Lab 04. Мониторинг EKS: Prometheus, metrics-server и сбор метрик с Fargate

## 1. Устанавливаем приложение

```bash
k apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-144/tasks/eks/labs/04/worker/files/tasks/1.yaml
```

## 2. Устанавливаем Prometheus и metrics-server

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
  enabled: true
  # Доступ к Grafana через LoadBalancer, по аналогии с Prometheus.
  # ВНИМАНИЕ: internet-facing LoadBalancer открыт на 0.0.0.0/0 — только для лабы.
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  # Пароль администратора (логин по умолчанию: admin). В production используйте Secret.
  adminPassword: "prom-operator"
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

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

# Managed control plane EKS — AWS не выставляет эти компоненты для скрейпинга,
# их таргеты всегда были бы в состоянии down. Отключаем, чтобы не было ложных
# алертов TargetDown.
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
kubeEtcd:
  enabled: false
# kube-proxy на Fargate отсутствует, а на EC2-нодах по умолчанию слушает метрики
# на 127.0.0.1. Включай только если выставил metricsBindAddress: 0.0.0.0.
kubeProxy:
  enabled: false

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

```bash
# Получаем адрес LoadBalancer Prometheus (UI Prometheus на порту 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo

# Получаем адрес LoadBalancer Grafana (UI Grafana на порту 80, логин admin)
kubectl get svc -n monitoring prometheus-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo

# Пароль admin для Grafana (если не задан явно в values)
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d ; echo
```

## 3. Сбор метрик с подов на Fargate (Security Groups)

После установки часть таргетов в Prometheus будет в состоянии `down` с ошибкой
`context deadline exceeded` — это касается компонентов, которые работают на Fargate
(CoreDNS, kubelet Fargate-нод).

Причина сетевая, а не «Fargate не отдаёт метрики»:

- Поды на **Fargate** используют **primary cluster security group**
  (`cluster.resourcesVpcConfig.clusterSecurityGroupId`).
- Prometheus работает на **EC2-нодах Karpenter** и обращается к таргетам из
  **node security group**.
- По умолчанию между этими SG нет правил на метрик-порты, поэтому скрейп упирается
  в таймаут.

Решение — разрешить ingress с node SG на primary SG на нужных портах. Правила добавлены
в `terraform/modules/eks_v2_control_plane/eks.tf`:

| Компонент | Порт | Правило |
|-----------|------|---------|
| kubelet (Fargate-ноды) | 10250/TCP | `nodes_to_fargate_kubelet` |
| CoreDNS metrics | 9153/TCP | `nodes_to_fargate_coredns_metrics` |
| CoreDNS DNS | 53 TCP/UDP | `nodes_to_fargate_dns_*` |

```bash
terraform plan
terraform apply
```

Проверка достижимости с EC2-ноды (или debug-пода на ней):

```bash
# kubelet Fargate-ноды
nc -vz -w 5 <fargate-node-ip> 10250

# метрики CoreDNS (узнать IP пода: kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide)
nc -vz -w 5 <coredns-pod-ip> 9153
```

После `apply` таргеты `kubelet` (`fargate-ip-*`) и `coredns` должны перейти в `up`.

### Что НЕ чинится security group'ами

- **node-exporter с Fargate-нод** — на Fargate не запускаются DaemonSet'ы, поэтому
  node-level метрик с этих нод не будет. Это архитектурное ограничение.
- **Managed control plane EKS** (kube-controller-manager, kube-scheduler, kube-etcd)
  и **kube-proxy** уже отключены в `prometheus-values.yaml` выше — AWS не выставляет
  control plane для скрейпинга, а kube-proxy на Fargate отсутствует.

## 4. Дальнейшие шаги

- [ ] Установить Grafana и подключить Prometheus как источник данных.
- [ ] Настроить сбор метрик нашего приложения (ServiceMonitor/PodMonitor) и проверить
      наличие метрик в Prometheus.
- [ ] Установить VictoriaMetrics и проверить наличие метрик.
- [ ] Проверить работу алертов после миграции на VictoriaMetrics.
