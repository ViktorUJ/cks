#!/bin/bash
echo " *** master node cka lab-110 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# Ingress-controller (ingress-nginx), NodePort 30102 для HTTP
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/baremetal/deploy.yaml
sleep 20
kubectl -n ingress-nginx patch svc ingress-nginx-controller --type=json \
  -p='[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/0/nodePort","value":30102}]' || true

# сид-неймспейсы для NetworkPolicy
kubectl create namespace prod-db || true
kubectl create namespace prod || true
kubectl label namespace prod role=prod --overwrite || true
kubectl create namespace stage || true
kubectl -n prod-db run db --image=viktoruj/ping_pong:alpine --labels="app=db" || true

# Gateway API: CRD + реализация (NGINX Gateway Fabric)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml || true
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.4.0/nginx-gateway.yaml || true

# сид-Ingress для задания «миграция на Gateway API»
kubectl create namespace gw || true
kubectl -n gw create deployment shop --image=viktoruj/ping_pong:alpine || true
kubectl -n gw expose deployment shop --name=shop --port=8080 --target-port=8080 || true
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ingress
  namespace: gw
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: shop.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: shop
            port: {number: 8080}
EOF
