#!/bin/bash
echo " *** master node cks lab-28 k8s-1"
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

if [ -f /etc/falco/falco.yaml ]; then
  awk '
  {
    if (inside) {
      if ($0 ~ /^[[:space:]]/) { next }
      else { inside=0 }
    }
    if ($0 ~ /^k8s:/ || $0 ~ /^kubernetes:/) { inside=1; next }
    print
  }
  END {
    print "k8s:";
    print "  enabled: false";
    print "kubernetes:";
    print "  enabled: false";
  }' /etc/falco/falco.yaml > /tmp/falco.yaml.new && mv /tmp/falco.yaml.new /etc/falco/falco.yaml
else
  cat >/etc/falco/falco.yaml <<'YAML'
# Falco main config (generated)
# Disable Kubernetes metadata enrichment
k8s:
  enabled: false
kubernetes:
  enabled: false
YAML
fi

# Clean any stale classic eBPF probe cache (harmless if missing)
rm -f /root/.falco/falco-bpf.o || true

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Install deployments
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/labs/28/k8s-1/scripts/app.yaml
