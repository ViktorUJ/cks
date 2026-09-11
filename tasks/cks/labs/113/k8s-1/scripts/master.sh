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

# Небольшая рабочая нагрузка, чтобы у upgrade был реальный workload для проверки
# доступности во время drain/uncordon (а не пустой кластер).
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
      containers:
      - name: canary
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: "10m"
            memory: "16Mi"
EOF

echo "*** control-plane bootstrap for lab 113 is complete"
