#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker node bootstrap: CKS lab 113 (kubeadm upgrade)"
until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 5; done

echo "*** worker node starting Kubernetes version:"
kubelet --version
kubectl get node "$(hostname)" -o wide

echo "*** worker node bootstrap for lab 113 is complete"
