#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
printf '%s\n' '*** control-plane bootstrap CKS lab 111'
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done
# CKA-style one-node infrastructure: the control-plane is deliberately usable for lab workloads.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl label node "$(hostname)" cks.io/lab=111 --overwrite
