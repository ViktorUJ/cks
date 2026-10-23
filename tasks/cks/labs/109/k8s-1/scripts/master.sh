#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** CKS lab 109 control-plane bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# This is an intentionally single-node learning cluster; exercise Pods may schedule here.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl create namespace encryption-109 --dry-run=client -o yaml | kubectl apply -f -

# It is created BEFORE EncryptionConfiguration is configured. It is harmless, unique lab
# data used only to prove that base64 Kubernetes Secret data is plaintext in raw etcd.
kubectl -n encryption-109 create secret generic legacy-secret \
  --from-literal=token='cks-109-legacy-plaintext' \
  --dry-run=client -o yaml | kubectl apply -f -

echo "*** legacy-secret is intentionally plaintext in etcd until the learner completes the lab"
