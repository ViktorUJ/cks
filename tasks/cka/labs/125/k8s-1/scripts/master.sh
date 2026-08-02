#!/bin/bash
echo " *** master node cka lab-125 k8s-1 (DNS)"
export KUBECONFIG=/root/.kube/config

# single-node: разрешаем планирование на control plane
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true
