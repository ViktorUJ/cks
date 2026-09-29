#!/usr/bin/env bash
set -euo pipefail

echo "*** worker pc cks lab 103 k8s-1"
export KUBECONFIG=/root/.kube/config
CTX="cluster1-admin@cluster1"

# Do not prepare the lab until the control-plane node is visible through the same context
# used by tests and students. The cluster now also has a worker node (items[0] is not
# guaranteed to be control-plane once a second node exists), so select by role explicitly.
echo "Waiting for the control-plane node..."
until kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | grep -q .; do
  sleep 5
done
CONTROL_PLANE_IP=$(kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts
# Task 4's Ingress host, resolved directly to a real node IP - same pattern as the mock
# exams (see tasks/cks/mock/04/worker/files/worker.sh): NodePort is exposed on EVERY node
# regardless of which one actually runs the ingress-nginx-controller Pod, so this works
# without depending on scheduling, and lets students curl by domain name straight from
# this machine instead of SSHing into a cluster node.
printf '%s secure.cks.local\n' "$CONTROL_PLANE_IP" >> /etc/hosts
# kube-bench itself is NOT installed on this bastion: it lives on control-plane (installed
# there directly by k8s-1/scripts/master.sh, matching the real exam where it is already
# present on nodes) and, as a real student-run install, on the worker k8s node for task 10.
# Nothing here ever needs its own local copy or scp's one anywhere.

# README/solution use bare "ssh control-plane" (and, for task 10, "ssh $WORKER_NODE" with the
# real k8s node name, ip-10-...) with no ssh flags at all - without this, the very first such
# command fails with "Host key verification failed" on a fresh instance. Cover both the
# "control-plane" alias above and any node's real hostname (ip-10-*) in one go.
for ssh_home in /root /home/ubuntu; do
  install -d -m 0700 "$ssh_home/.ssh"
  printf 'Host control-plane ip-10-*\n  User ubuntu\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> "$ssh_home/.ssh/config"
  chmod 0600 "$ssh_home/.ssh/config"
done
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

mkdir -p /var/work/tests/artifacts/{1,5,6}
chown -R ubuntu:ubuntu /var/work/tests/artifacts

# Trusted checksum fixture для проверки задания 6: checker должен сравнивать реально
# установленные бинарники с независимо полученными официальными суммами, а не доверять
# student-owned artifact на слово. Загружаем их один раз при bootstrap в checker-only
# каталог, недоступный из student-facing README/solution.
mkdir -p /var/work/tests/checker-fixtures
curl -fsSL -o /var/work/tests/checker-fixtures/kubelet.sha256 \
  "https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256"
curl -fsSL -o /var/work/tests/checker-fixtures/kubectl.sha256 \
  "https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256"
