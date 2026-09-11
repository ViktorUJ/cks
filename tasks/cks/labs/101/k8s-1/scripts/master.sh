#!/bin/bash
set -euo pipefail

echo "*** master node cks lab 101 k8s-1"
export KUBECONFIG=/root/.kube/config

# One-node lab: allow the application Pods to be scheduled on the control plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
