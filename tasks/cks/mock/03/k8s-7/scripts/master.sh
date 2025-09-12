#!/bin/bash
echo " *** master node cks mock3 k8s-7"
export KUBECONFIG=/root/.kube/config

curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y

export FALCO_FRONTEND=noninteractive
export FALCOCTL_ENABLED=''           # keep falcoctl disabled since we'll use modern ebpf
export FALCO_DRIVER_CHOICE=modern_ebpf
DEBIAN_FRONTEND=noninteractive apt install -y dkms make linux-headers-$(uname -r) clang llvm dialog falco

install -m 0755 -d /etc/falco/config.d
cat >/etc/falco/config.d/engine-kind.yaml <<'YAML'
# Use Modern eBPF (CO-RE) engine
engine:
  kind: modern_ebpf
YAML

# Clean any stale classic eBPF probe cache (harmless if missing)
rm -f /root/.falco/falco-bpf.o || true

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Install deployments
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/mock/03/k8s-7/scripts/app.yaml
