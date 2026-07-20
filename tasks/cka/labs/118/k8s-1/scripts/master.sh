#!/bin/bash
echo " *** master node cka lab-118 k8s-1"
export KUBECONFIG=/root/.kube/config

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true

# === сид-поломка сети: гасим CoreDNS ===
# Симптом: резолвинг имён в кластере не работает (DNS "лежит").
# Починка: вернуть реплики CoreDNS.
sleep 20
kubectl -n kube-system scale deployment coredns --replicas=0 || true
