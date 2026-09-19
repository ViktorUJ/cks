#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** master node cks lab 108 k8s-1"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Лаба одноузловая: пользовательские тестовые Pod допускаются на control-plane.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: policy-108
  labels:
    purpose: cks-kyverno-lab
EOF

# Checker-owned baseline for task 6: record the --enable-admission-plugins value that
# kubeadm actually configured BEFORE the student edits the static manifest to add
# ImagePolicyWebhook. Task 6 explicitly requires ADDING to this list, not replacing it -
# a checker that only greps for the substring 'ImagePolicyWebhook' cannot tell whether
# any originally-enabled plugin (e.g. NodeRestriction, if kubeadm set it explicitly) was
# dropped in the process. This file is read-only evidence of the pre-change state;
# tests.bats parses it alongside the CURRENT manifest to require every originally-listed
# plugin to still be present. If the flag is absent entirely in the baseline (kubeadm on
# this Kubernetes version may rely on built-in defaults without an explicit
# --enable-admission-plugins flag), the file records that explicitly so the checker does
# not require preserving a flag that never existed pre-change.
baseline_flag=$(grep -oE -- '--enable-admission-plugins=[^"[:space:]]*' /etc/kubernetes/manifests/kube-apiserver.yaml || true)
mkdir -p /var/lib/cks-lab108-checker
if [[ -n "$baseline_flag" ]]; then
  echo "${baseline_flag#--enable-admission-plugins=}" > /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
else
  echo "" > /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
fi
chown root:root /var/lib/cks-lab108-checker /var/lib/cks-lab108-checker/baseline-admission-plugins.txt
chmod 0755 /var/lib/cks-lab108-checker
chmod 0644 /var/lib/cks-lab108-checker/baseline-admission-plugins.txt

echo "*** CKS lab 108 bootstrap is ready; install Kyverno from the worker ***"
