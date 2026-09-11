#!/bin/bash
set -euo pipefail

echo "*** master node cks lab 102 k8s-1 ***"
export KUBECONFIG=/root/.kube/config

# Лаба одноузловая: разрешаем учебным workload планироваться на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
