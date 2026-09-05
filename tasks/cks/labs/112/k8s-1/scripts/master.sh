#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane / workload node CKS lab 112 bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# This is a one-node lab; workloads used to generate Falco events run on the control plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: runtime-112
---
apiVersion: v1
kind: Secret
metadata:
  name: audit-secret
  namespace: runtime-112
type: Opaque
stringData:
  token: cks-112-audit-value
EOF

# Falco and audit logging are intentionally not configured. The packages below only make
# the intended administration work reproducible on a fresh Ubuntu control-plane node.
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  ca-certificates curl gpg jq apt-transport-https
install -d -m 0755 /etc/kubernetes/audit /var/log/kubernetes/audit
chmod 0750 /var/log/kubernetes/audit

echo "*** CKS lab 112 prerequisites are ready: namespace runtime-112 and audit-secret"
