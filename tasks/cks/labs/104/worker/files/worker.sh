#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** worker pc cks lab 104 k8s-1"

until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# README/solution instruct "ssh control-plane" for tasks 5 and 9 - without this alias the
# node's real hostname (e.g. k8s1_controlPlane_1) does not resolve from the worker at all.
CONTROL_PLANE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts

# The checker runs as root (sudo check_result) and its 'ssh control-plane' would default to
# root@control-plane, where root login is not allowed. Map the alias to the ubuntu user,
# whose key (shared with root on this worker) is authorized on the node.
install -d -m 0700 /root/.ssh
printf 'Host control-plane\n  User ubuntu\n' >> /root/.ssh/config
chmod 0600 /root/.ssh/config

install -d -m 0755 /var/work/tests/artifacts/6 /var/work/tests/artifacts/7 /var/work/tests/artifacts/9 \
  /var/work/tests/artifacts/10 /var/work/tests/artifacts/12
chown -R ubuntu:ubuntu /var/work/tests/artifacts

echo "*** cluster is ready; run check_result after completing the tasks ***"
