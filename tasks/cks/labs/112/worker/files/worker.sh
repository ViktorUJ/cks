#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 112"
until kubectl get nodes --no-headers >/dev/null 2>&1; do sleep 5; done

# README/solution use "ssh control-plane", but the shared worker template creates no alias
# and root login is keyed on the node for ubuntu only. Map the alias to ubuntu for both root
# (this script, root-run tooling) and the student user.
CONTROL_PLANE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
grep -q ' control-plane$' /etc/hosts || printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts
for ssh_home in /root /home/ubuntu; do
  install -d -m 0700 "$ssh_home/.ssh"
  printf 'Host control-plane\n  User ubuntu\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> "$ssh_home/.ssh/config"
  chmod 0600 "$ssh_home/.ssh/config"
done
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

for attempt in {1..24}; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 control-plane 'sudo -n true' >/dev/null 2>&1; then
    echo "*** SSH access to control-plane is ready"
    exit 0
  fi
  sleep 5
done

echo "SSH access to control-plane was not ready after two minutes" >&2
exit 1
