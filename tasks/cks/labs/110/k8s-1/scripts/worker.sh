#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** gVisor workload node bootstrap: CKS lab 110"
until kubectl get node "$(hostname)" >/dev/null 2>&1; do sleep 5; done

# containerd_gvizor installed runsc и записал его runtime handler в config.toml.
# Лаба намеренно откатывает именно эту секцию к состоянию "runsc установлен, но
# containerd о нём не знает" - частая экзаменационная ситуация со сломанным/неполным
# config.toml. runsc и его CLI остаются нетронутыми; сдвигается только containerd wiring.
runsc --version
systemctl is-active --quiet containerd
cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
python3 - <<'PY'
import re
path = "/etc/containerd/config.toml"
text = open(path, encoding="utf-8").read()
text = re.sub(
    r'\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runsc\]\n'
    r'\s*runtime_type = "io\.containerd\.runsc\.v1"\n?',
    "",
    text,
)
open(path, "w", encoding="utf-8").write(text)
PY
systemctl restart containerd
kubectl label node "$(hostname)" sandbox.runtime/gvisor=true lab.cks.io/role=gvisor --overwrite

echo "*** runsc workload node is ready (containerd runsc handler intentionally removed for task 1)"
