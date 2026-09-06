#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker pc cks lab 104 k8s-1"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

install -d -m 0755 /var/work/tests/artifacts/6 /var/work/tests/artifacts/7 /var/work/tests/artifacts/9
chown -R ubuntu:ubuntu /var/work/tests/artifacts

echo "*** cluster is ready; run check_result after completing the tasks ***"
