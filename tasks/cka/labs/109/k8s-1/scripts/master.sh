#!/bin/bash
echo " *** master node cka lab-109 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# сид-под для задания «экспортировать логи»
kubectl create namespace app-logs || true
kubectl -n app-logs run app-xyz3322 --image=busybox --restart=Never -- /bin/sh -c 'i=0; while true; do echo "log line $i"; i=$((i+1)); sleep 5; done' || true
