#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** control-plane / workload node CKS lab 106 bootstrap"
until kubectl get nodes --no-headers >/dev/null 2>&1; do
  sleep 5
done

# This one-node lab uses the control-plane as the dedicated workload node. The profile
# is node-local, so it is explicitly labelled and all exercise Pods must select it.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl label node "$(hostname)" security.cks.io/localhost-profiles-106=true --overwrite

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apparmor apparmor-utils
systemctl enable --now apparmor

profile=/etc/apparmor.d/cks-106-deny-write
cat > "$profile" <<'EOF'
#include <tunables/global>

# The exercise permits normal read/execute behaviour but denies file writes.  The
# explicit deny is intentionally retained as a visible policy statement for /work.
profile k8s-106-deny-write flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  /** rix,
  deny /work/** w,
}
EOF

# Start in complain mode. The student must change this loaded local profile to enforce.
apparmor_parser -r -W "$profile"
aa-complain "$profile"

seccomp_dir=/var/lib/kubelet/seccomp/profiles
install -d -m 0755 "$seccomp_dir"
cat > "$seccomp_dir/cks-106-deny-unshare.json" <<'EOF'
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
chmod 0644 "$seccomp_dir/cks-106-deny-unshare.json"
jq empty "$seccomp_dir/cks-106-deny-unshare.json"

echo "*** CKS lab 106 node-local profiles are ready (AppArmor is intentionally in complain mode)"
