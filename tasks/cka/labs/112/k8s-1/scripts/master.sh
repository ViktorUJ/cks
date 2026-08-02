#!/bin/bash
echo " *** master node cka lab-112 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# установить etcd-client (etcdctl) на control plane
apt-get update -y >/dev/null 2>&1
apt-get install -y etcd-client >/dev/null 2>&1 || true

# снапшоты снимает сам студент в ходе лабы (кластер к этому моменту полностью готов,
# поэтому снапшот содержит все RBAC-объекты kubeadm)
