#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker pc cks lab 104 k8s-1"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

echo "*** cluster is ready; run check_result after completing the tasks ***"
