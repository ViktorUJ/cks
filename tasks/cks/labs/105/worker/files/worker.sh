#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker PC CKS lab 105"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,8,9,10}
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

# Checker-owned baseline for task 3 (UFW), captured BEFORE the lab is handed to the
# student and BEFORE any UFW change exists on the node. This is independent of anything
# the student can write into their own artifacts/3/preflight.txt: a fabricated or
# post-hardening "baseline" line cannot substitute for this bootstrap-time evidence, and
# tests.bats compares the post-hardening state against THIS file, not just the student's.
CP_NAME=$(cat /var/work/tests/cp-name 2>/dev/null || true)
NODE_IP=$(kubectl get node "$CP_NAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
if [[ -n "$NODE_IP" ]]; then
  set +e
  BOOTSTRAP_KUBELET_CODE=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 \
    "https://${NODE_IP}:10250/healthz")
  BOOTSTRAP_KUBELET_RC=$?
  set -e
else
  BOOTSTRAP_KUBELET_RC=1
  BOOTSTRAP_KUBELET_CODE="000"
fi
printf 'node_ip=%s\nbootstrap baseline kubelet 10250: CURL_EXIT=%s HTTPCODE=%s\n' \
  "$NODE_IP" "$BOOTSTRAP_KUBELET_RC" "$BOOTSTRAP_KUBELET_CODE" \
  > /var/work/tests/bootstrap-baseline-3.txt
chown ubuntu:ubuntu /var/work/tests/bootstrap-baseline-3.txt 2>/dev/null || true

echo "*** cluster and SSH targets are ready; use check_result after completing the tasks"
