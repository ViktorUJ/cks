#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane bootstrap: CKS lab 110"
until [[ "$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {count++} END {print count+0}')" -ge 2 ]]; do
  echo "waiting for the gVisor worker to join and become Ready"
  sleep 5
done

# Модульный "cilium install" (template/master.sh) запускается из cloud-init, где $HOME
# не задан - cilium-cli/helm молча завершается без ошибки, ничего не установив
# ("neither $XDG_CACHE_HOME nor $HOME are defined"). Досттавляем установку здесь, с явным
# $HOME, если DaemonSet ещё не появился.
export HOME=/root
if ! kubectl -n kube-system get daemonset cilium >/dev/null 2>&1; then
  echo "*** cilium DaemonSet not found - installing cilium (module install was a no-op without \$HOME)"
  cilium install --version 1.20.1
fi
cilium status --wait

# Regular test clients run on the control-plane; sandboxed workloads select the worker
# through RuntimeClass scheduling constraints set by the student.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl label node "$(hostname)" lab.cks.io/role=control-plane --overwrite
kubectl label nodes -l node_name=gvisor sandbox.runtime/gvisor=true lab.cks.io/role=gvisor --overwrite

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tcpdump

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: sandbox-110
  labels:
    purpose: cks-runtime-and-encryption
---
apiVersion: v1
kind: Namespace
metadata:
  name: market
  labels:
    istio-injection: enabled
    purpose: cks-mtls
EOF

echo "*** CKS lab 110 bootstrap ready: control-plane + labelled runsc worker + Cilium"
