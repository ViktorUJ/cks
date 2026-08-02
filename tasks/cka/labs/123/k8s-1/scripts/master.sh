#!/bin/bash
echo " *** master node cka lab-123 k8s-1 (CNI НЕ установлен)"
export KUBECONFIG=/root/.kube/config

# Разрешаем планирование на control plane, чтобы netprobe мог разъехаться по двум нодам.
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# Пробное приложение для проверки меж-нодовой сети.
# Пока CNI не установлен, поды будут в Pending/ContainerCreating.
kubectl create namespace netlab || true
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: netprobe, namespace: netlab}
spec:
  replicas: 2
  selector: {matchLabels: {app: netprobe}}
  template:
    metadata: {labels: {app: netprobe}}
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {app: netprobe}
            topologyKey: kubernetes.io/hostname
      containers:
      - {name: web, image: viktoruj/ping_pong:latest}
EOF
