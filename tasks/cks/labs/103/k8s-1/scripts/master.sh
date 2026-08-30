#!/usr/bin/env bash
set -euo pipefail

echo "*** master node cks lab 103 k8s-1"
export KUBECONFIG=/root/.kube/config

# The lab is intentionally single-node. Permit the TLS demo workload to schedule here.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
