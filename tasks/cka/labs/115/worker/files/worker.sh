#!/bin/bash
echo " *** worker pc cka lab 115 k8s-1"
export KUBECONFIG=/root/.kube/config

# установить helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || true

# подготовить kustomize: base + overlay
mkdir -p /var/work/115/kustomize/base /var/work/115/kustomize/overlays/dev
cat > /var/work/115/kustomize/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kapp
spec:
  replicas: 1
  selector:
    matchLabels: {app: kapp}
  template:
    metadata:
      labels: {app: kapp}
    spec:
      containers:
      - name: kapp
        image: viktoruj/ping_pong:alpine
EOF
cat > /var/work/115/kustomize/base/kustomization.yaml <<'EOF'
resources:
- deployment.yaml
EOF
cat > /var/work/115/kustomize/overlays/dev/kustomization.yaml <<'EOF'
resources:
- ../../base
namespace: kustns
replicas:
- name: kapp
  count: 3
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
