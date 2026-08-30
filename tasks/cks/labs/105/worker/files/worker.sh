#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker PC CKS lab 105"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
chown -R ubuntu:ubuntu /var/work/tests/artifacts

echo "*** cluster and SSH targets are ready; use check_result after completing the tasks"
