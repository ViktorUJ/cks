#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 113"
until kubectl get nodes --no-headers 2>/dev/null | wc -l | grep -q '^2$'; do sleep 5; done

for host in k8s113_controlPlane_1 k8s113_node_worker1; do
  for attempt in {1..24}; do
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'sudo -n true' >/dev/null 2>&1; then
      echo "*** SSH access to $host is ready"
      break
    fi
    if [[ "$attempt" -eq 24 ]]; then
      echo "SSH access to $host was not ready after two minutes" >&2
      exit 1
    fi
    sleep 5
  done
done

echo "*** both cluster nodes are reachable, lab 113 is ready"
