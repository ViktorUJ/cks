#!/bin/bash
echo " *** master node  mock-2  k8s-11"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-119/tasks/cks/mock/03/k8s-11/scripts/task16.yaml
