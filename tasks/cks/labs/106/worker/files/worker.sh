#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 106"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# Task 1 and task 5 fixtures: this lab's AppArmor profile and Localhost seccomp profile
# are delivered ONLY here, on the worker - bootstrap does NOT pre-place either file on
# the workload node or pre-load the AppArmor profile into that node's kernel. The
# student must transfer each file to the node themselves (task 1: AppArmor profile to
# /etc/apparmor.d/, then load it; task 5: seccomp profile to the kubelet seccomp root)
# before the rest of this lab's tasks can proceed.
install -d -m 0755 /opt/lab106-fixtures
cat >/opt/lab106-fixtures/k8s-106-deny-write <<'EOF'
#include <tunables/global>

# The exercise permits normal read/execute behaviour everywhere, but grants read-only
# (not write) access under /work: AppArmor is a default-deny (whitelist) system, so any
# access mode not explicitly granted for a matching path is denied. The 'complain' flag
# below means this profile does not block anything yet once loaded - task 2 asks you to
# transition it to enforce.
profile k8s-106-deny-write flags=(attach_disconnected, complain, mediate_deleted) {
  #include <abstractions/base>

  /** rix,
  /work/** r,
}
EOF
chmod 0644 /opt/lab106-fixtures/k8s-106-deny-write

cat >/opt/lab106-fixtures/cks-106-deny-unshare.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["unshare"],
      "action": "SCMP_ACT_ERRNO",
      "errnoRet": 1
    }
  ]
}
EOF
chmod 0644 /opt/lab106-fixtures/cks-106-deny-unshare.json

# README/solution instruct "ssh control-plane" throughout this lab (tasks 1, 2, 6, 8) -
# without this alias the node's real hostname (e.g. k8s1_controlPlane_1) does not resolve
# from the worker at all. work_pc_v2 does not add this by itself (see lab 104's identical
# fix, commit 0224f743).
CONTROL_PLANE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
printf '%s control-plane\n' "$CONTROL_PLANE_IP" >> /etc/hosts

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
