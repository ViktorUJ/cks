#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker PC CKS lab 105"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
chown -R ubuntu:ubuntu /var/work/tests/artifacts

# Cache recovery context before the firewall exercise. A correct source-scoped rule keeps
# worker -> API available; the cached name remains useful if a student makes a mistake.
kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}' > /var/work/tests/cp-name 2>/dev/null || true
chown ubuntu:ubuntu /var/work/tests/cp-name 2>/dev/null || true

# A real workload is part of the firewall health check. It must stay Ready and retain an
# HTTP path to kubernetes.default.svc after UFW is enabled.
kubectl create namespace cks-105-health --dry-run=client -o yaml | kubectl apply -f -
kubectl create deployment health-probe -n cks-105-health \
  --image=curlimages/curl:8.11.1 --dry-run=client -o yaml -- sleep 3600 | kubectl apply -f -
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=180s

echo "*** cluster and SSH targets are ready; use check_result after completing the tasks"
