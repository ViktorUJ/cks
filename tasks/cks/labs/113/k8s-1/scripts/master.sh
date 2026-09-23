#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane bootstrap: CKS lab 113 (kubeadm upgrade)"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# Эта лаба про operational upgrade, а не про break/fix: сознательно не портим
# конфигурацию. Задача студента - реально выполнить minor upgrade control-plane
# и worker в правильном порядке, а не восстановить сломанное состояние.
echo "*** starting Kubernetes version:"
kubeadm version -o short
kubectl get nodes -o wide

# Лаба - двухузловая (control-plane + один worker). Чтобы canary с 2 репликами
# и required anti-affinity вообще могло уместиться на кластере, control-plane
# должна быть допустимой target node - снимаем стандартный NoSchedule taint.
CP_NODE=$(
  kubectl get nodes \
    -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}'
)

kubectl taint node "$CP_NODE" \
  node-role.kubernetes.io/control-plane:NoSchedule- \
  2>/dev/null || true

# Небольшая рабочая нагрузка, чтобы у upgrade был реальный workload для проверки
# доступности во время drain/uncordon (а не пустой кластер). required podAntiAffinity
# гарантирует, что 2 реплики окажутся на разных nodes, а PodDisruptionBudget не даёт
# drain увести обе реплики одновременно.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: upgrade-113
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
  namespace: upgrade-113
  labels:
    app: canary
spec:
  replicas: 2
  selector:
    matchLabels:
      app: canary
  template:
    metadata:
      labels:
        app: canary
    spec:
      automountServiceAccountToken: false
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: canary
            topologyKey: kubernetes.io/hostname
      containers:
      - name: canary
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: canary
  namespace: upgrade-113
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: canary
EOF

echo "*** control-plane bootstrap for lab 113 is complete"
