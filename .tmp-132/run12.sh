#!/bin/bash
# Задания 1-2 лабы 132.
set -u
kubectl create namespace eks-132

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132 --timeout=900s
kubectl rollout status deployment/client -n eks-132 --timeout=900s
kubectl get po -n eks-132 -o wide 2>&1 | cut -c1-120
kubectl get nodes -L work_type --no-headers 2>&1 | grep -v fargate | cut -c1-100

mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
echo "--- artifact 2 ---"; cat /var/work/tests/artifacts/2/connectivity_before.txt
