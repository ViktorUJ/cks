#!/bin/bash
echo " *** worker pc cka lab 107 k8s-1"
export KUBECONFIG=/root/.kube/config

# установить podman и подготовить Dockerfile для задания сборки образа
apt-get update -y >/dev/null 2>&1
apt-get install -y podman >/dev/null 2>&1 || true
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
