#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 112"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

for attempt in {1..24}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 control-plane 'sudo -n true' >/dev/null 2>&1; then
    echo "*** SSH access to control-plane is ready"
    exit 0
  fi
  sleep 5
done

echo "SSH access to control-plane was not ready after two minutes" >&2
exit 1
