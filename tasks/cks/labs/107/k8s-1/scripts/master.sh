#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** master node cks lab 107 k8s-1"
while ! kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Одноузловая лаборатория: пользовательские workload планируются на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Namespace намеренно не имеют PSA labels: это часть практического задания.
kubectl apply -f - <<'EOF_NS'
apiVersion: v1
kind: Namespace
metadata:
  name: psa-restricted-107
---
apiVersion: v1
kind: Namespace
metadata:
  name: psa-observe-107
EOF_NS

echo "*** CKS lab 107 bootstrap is ready ***"
