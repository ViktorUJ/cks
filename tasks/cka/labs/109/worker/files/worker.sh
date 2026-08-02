#!/bin/bash
echo " *** worker pc cka lab 109 k8s-1"
export KUBECONFIG=/root/.kube/config

mkdir -p /var/work/artifact /var/work/109 /opt/logs

# устаревший манифест для задания про deprecations (apps/v1beta1 больше нет)
cat > /var/work/109/app-old.yaml <<'EOF'
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: app-21
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: app-21
    spec:
      containers:
      - name: app-21
        image: viktoruj/ping_pong:alpine
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
