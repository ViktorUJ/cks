#!/bin/bash
echo "*** worker node cka lab-117 k8s-1"

# Даём ноде присоединиться и стать Ready, затем ломаем kubelet:
# добавляем drop-in с несуществующим флагом -> kubelet падает в crashloop,
# нода уходит в NotReady. Починка: удалить drop-in, daemon-reload, restart kubelet.
sleep 90

mkdir -p /etc/systemd/system/kubelet.service.d
cat >/etc/systemd/system/kubelet.service.d/99-broken.conf <<'EOF'
[Service]
Environment="KUBELET_EXTRA_ARGS=--totally-invalid-flag=true"
EOF

systemctl daemon-reload
systemctl restart kubelet || true
