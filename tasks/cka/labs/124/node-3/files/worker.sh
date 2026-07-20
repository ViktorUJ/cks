#!/bin/bash
# cp3 — чистый КАНДИДАТ в control plane (симметрично cp2). Скрипт готовит ноду
# (prerequisites, containerd с SystemdCgroup, пакеты kubeadm/kubelet/kubectl),
# но НЕ делает join — присоединение выполняет СТУДЕНТ (задание лабы).
set -x
echo " *** cka lab-124 (cp3): подготовка кандидата в control plane (без join)"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y ca-certificates curl gnupg 2>/dev/null || true

# --- prerequisites ---
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# --- containerd: конфиг с CRI + SystemdCgroup ---
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- пакеты Kubernetes v1.35 ---
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo " *** cp3 готов (prerequisites + containerd + kubeadm/kubelet/kubectl). Join как control plane — задача студента."
