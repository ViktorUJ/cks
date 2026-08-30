#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** gVisor workload node bootstrap: CKS lab 110"
until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 5; done

# containerd_gvizor installed runsc and its CRI handler before kubelet joined.
runsc --version
systemctl is-active --quiet containerd
kubectl label node "$(hostname)" sandbox.runtime/gvisor=true lab.cks.io/role=gvisor --overwrite

echo "*** runsc workload node is ready"
