#!/usr/bin/env bash
set -euo pipefail

echo "*** master node cks lab 103 k8s-1"
export KUBECONFIG=/root/.kube/config

# The lab is intentionally single-node. Permit the TLS demo workload to schedule here.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Стартовая уязвимость для задания 7: kube-bench проверяет права static Pod manifests
# control-plane (CIS 1.1.1) и ожидает не более 600. Лабораторная инфраструктура намеренно
# выставляет mode 0644, чтобы получить контролируемый FAIL check 1.1.1.
chmod 644 /etc/kubernetes/manifests/kube-apiserver.yaml
