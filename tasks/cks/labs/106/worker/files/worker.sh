#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 106"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# work_pc_v2 supplies node names through /etc/hosts and the shared SSH key.
# Fail early if that required lab access path is not usable.
for attempt in {1..24}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 control-plane 'sudo -n true' >/dev/null 2>&1; then
    echo "*** SSH access to workload node control-plane is ready"
    exit 0
  fi
  sleep 5
done

echo "SSH access to control-plane was not ready after two minutes" >&2
exit 1
