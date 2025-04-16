#!/bin/bash
echo " *** master node cks lab-28 k8s-1"
export KUBECONFIG=/root/.kube/config

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list

apt-get update -y

export FALCO_FRONTEND=noninteractive
export FALCO_DRIVER_CHOICE=ebpf
export FALCOCTL_ENABLED=''

DEBIAN_FRONTEND=noninteractive apt install -y dkms make linux-headers-$(uname -r) clang llvm dialog falco

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Install deployments
kubectl apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/0.20.1/tasks/cks/labs/28/k8s-1/scripts/app.yaml
