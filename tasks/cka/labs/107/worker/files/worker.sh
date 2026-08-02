#!/bin/bash
echo " *** worker pc cka lab 107 k8s-1"
export KUBECONFIG=/root/.kube/config

# установить podman и подготовить Dockerfile для задания сборки образа
apt-get update -y >/dev/null 2>&1
apt-get install -y podman >/dev/null 2>&1 || true
# иногда пакеты остаются в состоянии half-configured (iU) — доводим конфигурацию до конца
dpkg --configure -a >/dev/null 2>&1 || true
# гарантируем наличие обязательных конфигов containers-common:
# без /etc/containers/policy.json podman build падает с "open /etc/containers/policy.json: no such file or directory"
mkdir -p /etc/containers
if [ ! -f /etc/containers/policy.json ]; then
  if [ -f /etc/containers/policy.json.dpkg-new ]; then
    cp /etc/containers/policy.json.dpkg-new /etc/containers/policy.json
  else
    cat > /etc/containers/policy.json <<'POLICY'
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ]
}
POLICY
  fi
fi
if [ ! -f /etc/containers/registries.conf ] && [ -f /etc/containers/registries.conf.dpkg-new ]; then
  cp /etc/containers/registries.conf.dpkg-new /etc/containers/registries.conf
fi
mkdir -p /var/work/107
cat > /var/work/107/Dockerfile <<'EOF'
FROM alpine:3.20
RUN echo "ckad lab image" > /msg.txt
CMD ["cat", "/msg.txt"]
EOF

echo "Waiting for at least one node to be available..."
while true; do
    node_count=$(kubectl get no --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -gt 0 ]; then
        echo "Found $node_count node(s), proceeding..."
        break
    fi
    sleep 5
done
