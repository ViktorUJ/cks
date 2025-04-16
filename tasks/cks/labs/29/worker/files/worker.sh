#!/bin/bash
echo " *** worker pc cks lab 29 "

apt-get update
apt-get -y install ca-certificates curl net-tools
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

if ! id -u user &>/dev/null; then
  useradd -m -s /bin/bash user 
fi

usermod -aG docker user

sed -i 's|ListenStream=/run/docker.sock|ListenStream=/var/run/docker.sock|' /lib/systemd/system/docker.socket
sed -i 's|^ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock|ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock|' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service