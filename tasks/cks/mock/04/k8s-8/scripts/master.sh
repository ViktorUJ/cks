#!/bin/bash
echo " *** master node cks mock4 k8s-8"
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

tmp=$(mktemp)
awk '{
  if ($0 ~ /^append_output:$/) {
    if (getline nl) {
      if (nl ~ /^[[:space:]]*- suggested_output: true$/) {
        print "- suggested_output: false"
      } else {
        print $0
        print nl
      }
    } else {
      print $0
    }
  } else {
    print $0
  }
}' /etc/falco/falco.yaml > "$tmp" && mv "$tmp" /etc/falco/falco.yaml

tmp2=$(mktemp)
awk '{
  if ($0 ~ /^[[:space:]]*- name: k8saudit[[:space:]]*$/) {
    print "# " $0
    in_block=1
    next
  }
  if (in_block) {
    if ($0 ~ /^[[:space:]]+/) {
      print "# " $0
      next
    } else {
      in_block=0
    }
  }
  print $0
}' /etc/falco/falco.yaml > "$tmp2" && mv "$tmp2" /etc/falco/falco.yaml

tmp3=$(mktemp)
awk '{
  if ($0 ~ /^[[:space:]]*load_plugins:[[:space:]]*$/) {
    if (getline nl) {
      if (nl ~ /^[[:space:]]*-[[:space:]]*k8smeta[[:space:]]*$/) {
        print "# " $0
        print "# " nl
      } else {
        print $0
        print nl
      }
    } else {
      print $0
    }
  } else {
    print $0
  }
}' /etc/falco/falco.yaml > "$tmp3" && mv "$tmp3" /etc/falco/falco.yaml

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# Install deployments
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/mock/04/k8s-8/scripts/app.yaml
