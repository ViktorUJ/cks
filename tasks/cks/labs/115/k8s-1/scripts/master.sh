#!/bin/bash
set -euo pipefail

echo "*** master node cks lab 115 k8s-1 (kube-proxy-free, no CNI yet) ***"
export KUBECONFIG=/root/.kube/config

# One-node lab: allow the application Pods to be scheduled on the control plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

echo "*** intentionally not installing Cilium here - that is task 2 of this lab ***"
kubectl -n kube-system get ds kube-proxy 2>&1 || echo "*** confirmed: no kube-proxy DaemonSet ***"
