#!/usr/bin/env bash
set -euo pipefail

echo "*** CKS lab 105: preparing intentionally insecure Docker host"

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  >/etc/apt/sources.list.d/docker.list
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io

id -u developer >/dev/null 2>&1 || useradd --create-home --shell /bin/bash developer
usermod -aG docker developer

# Task 6 starts with unauthenticated remote Docker API on TCP/2375.
mkdir -p /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
EOF

systemctl daemon-reload
systemctl enable docker.service docker.socket
systemctl restart docker.socket
systemctl restart docker.service

# The socket is intentionally owned by the privileged docker group at the start of the lab.
chown root:docker /var/run/docker.sock
chmod 0660 /var/run/docker.sock

echo "*** Docker is deliberately listening on TCP/2375; developer belongs to docker"
