#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** master node cks lab 108 k8s-1"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Лаба одноузловая: пользовательские тестовые Pod допускаются на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: policy-108
  labels:
    purpose: cks-kyverno-lab
EOF

echo "*** CKS lab 108 bootstrap is ready; install Kyverno from the worker ***"
