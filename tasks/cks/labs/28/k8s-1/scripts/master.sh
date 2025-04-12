#!/bin/bash
echo " *** master node cks lab-28 k8s-1"
export KUBECONFIG=/root/.kube/config

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list

apt-get update -y

DEBIAN_FRONTEND=noninteractive apt install -y dkms make linux-headers-$(uname -r) clang llvm dialog falco

kubectl apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/cks-new-labs-added/tasks/cks/labs/28/k8s-1/scripts/app.yaml
