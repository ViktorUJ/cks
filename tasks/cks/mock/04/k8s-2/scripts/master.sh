#!/bin/bash
echo " *** master node  mock-4  k8s-2"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/mock/04/k8s-2/scripts/task1.yaml
