#!/bin/bash
echo "*** worker node cka lab-117 k8s-1"

# Даём ноде присоединиться и стать Ready, затем ломаем kubelet:
# подменяем путь к конфигу в drop-in -> kubelet не может стартовать,
# нода уходит в NotReady. Починка: удалить drop-in, daemon-reload, restart kubelet.
sleep 90

mkdir -p /etc/systemd/system/kubelet.service.d
cat >/etc/systemd/system/kubelet.service.d/99-broken.conf <<'EOF'
[Service]
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/NONEXISTENT-config.yaml"
EOF

systemctl daemon-reload
systemctl restart kubelet || true
