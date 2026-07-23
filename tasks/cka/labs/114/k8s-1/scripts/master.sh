#!/bin/bash
echo " *** master node cka lab-114 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# === сид-поломки для troubleshooting ===

# 1) ReplicaSet со сломанным образом (ImagePullBackOff)
kubectl create namespace rsapp || true
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata: {name: rs-app2223, namespace: rsapp}
spec:
  replicas: 2
  selector: {matchLabels: {app: rsapp}}
  template:
    metadata: {labels: {app: rsapp}}
    spec:
      containers:
      - {name: c, image: viktoruj/ping_pong:doesnotexist123}
EOF

# 2) Service с неверным селектором (пустые Endpoints)
kubectl create namespace tsvc || true
kubectl -n tsvc create deployment tapp --image=viktoruj/ping_pong:latest || true
kubectl -n tsvc get deploy tapp -o yaml | sed 's/app: tapp/app: web/g' | kubectl apply -f - || true
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: {name: svc-broken, namespace: tsvc}
spec:
  selector: {app: WRONG}
  ports:
  - {port: 80, targetPort: 8080}
EOF

# 3) Deployment ссылается на несуществующий ConfigMap (CreateContainerConfigError)
kubectl create namespace cfgapp || true
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: {name: capp, namespace: cfgapp}
spec:
  replicas: 1
  selector: {matchLabels: {app: capp}}
  template:
    metadata: {labels: {app: capp}}
    spec:
      containers:
      - name: c
        image: viktoruj/ping_pong:latest
        envFrom:
        - configMapRef: {name: missing-config}
EOF
