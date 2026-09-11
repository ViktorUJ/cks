#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config
echo "*** CKS lab 105: preparing intentionally insecure control-plane host"

# The lab is single-node; permit ordinary workloads if a student uses kubectl while working.
kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule- || true

# Task 1: an unnecessary enabled service.
cat >/etc/systemd/system/cks-lab105-unused.service <<'EOF'
[Unit]
Description=CKS lab 105 intentionally unnecessary service

[Service]
Type=simple
ExecStart=/bin/sh -c 'while true; do sleep 3600; done'

[Install]
WantedBy=multi-user.target
EOF

# Task 2: an intentionally exposed non-Kubernetes port.
cat >/etc/systemd/system/cks-lab105-port.service <<'EOF'
[Unit]
Description=CKS lab 105 intentionally exposed TCP/8080 service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /tmp
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now cks-lab105-unused.service cks-lab105-port.service

# Task 3 starts with UFW installed but disabled and without the required policy.
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ufw
ufw --force disable || true

# Task 4: a sensitive kubeconfig with deliberately unsafe ownership and permissions.
chown ubuntu:ubuntu /etc/kubernetes/admin.conf
chmod 0644 /etc/kubernetes/admin.conf

# Task 5: explicitly permit direct root SSH until the student hardens sshd.
sed -i -E '/^[[:space:]]*PermitRootLogin[[:space:]]+/d' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >>/etc/ssh/sshd_config
sshd -t
systemctl reload ssh || true

# Task 7: load an unused kernel module (sctp) that the student must blacklist and unload.
# sctp is not required by kubeadm/containerd/Calico in this lab and is a common exam-style
# attack-surface item (also dccp, cramfs, freevxfs in the same family).
modprobe sctp || true

# Task 8: an insecure sysctl the student must correct, and a kubelet not yet hardened with
# protectKernelDefaults. sysctl is applied through a file so it is reproducible and greppable.
mkdir -p /etc/sysctl.d
cat >/etc/sysctl.d/98-cks-lab105-insecure.conf <<'EOF'
kernel.unprivileged_bpf_disabled = 0
EOF
sysctl --system >/dev/null 2>&1 || true

# Task 9: an extra SUID binary that is not required for this node's Kubernetes role. The
# student must find it among genuine system SUID binaries and remove only this bit.
cp /bin/true /usr/local/bin/cks-lab105-suid-tool
chmod 4755 /usr/local/bin/cks-lab105-suid-tool
chown root:root /usr/local/bin/cks-lab105-suid-tool

echo "*** CKS lab 105 control-plane preparation complete"
