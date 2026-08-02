#!/bin/bash
# cp1 — ПЕРВЫЙ control plane. Скрипт полностью поднимает его так, чтобы к нему можно
# было присоединить вторую control-plane ноду: init с --control-plane-endpoint и
# --upload-certs, затем установка CNI. Присоединение cp2 выполняет СТУДЕНТ.
set -x
echo " *** cka lab-124 (cp1): bootstrap HA-ready control plane"

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

# --- containerd (пакет containerd.io ставит шаблон): конфиг с CRI + SystemdCgroup ---
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

# --- init control plane С endpoint балансировщика и upload-certs ---
# В лабе роль стабильного endpoint играет приватный IP cp1 (в проде — балансировщик).
PRIVATE_IP=$(hostname -I | awk '{print $1}')
kubeadm init \
  --control-plane-endpoint "${PRIVATE_IP}:6443" \
  --upload-certs \
  --pod-network-cidr=192.168.0.0/16 \
  --ignore-preflight-errors=NumCPU,Mem

# kubeconfig для root и ubuntu
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
mkdir -p /home/ubuntu/.kube
cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# --- CNI: Calico (pod CIDR должен совпадать с --pod-network-cidr) ---
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

echo " *** cp1 поднят как первый control plane (endpoint ${PRIVATE_IP}:6443, upload-certs, CNI)."
echo " *** Присоединение cp2 как второй control-plane ноды — задача студента."
