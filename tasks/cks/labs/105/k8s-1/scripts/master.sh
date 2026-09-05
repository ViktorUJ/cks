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

echo "*** CKS lab 105 control-plane preparation complete"
