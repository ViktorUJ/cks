#!/bin/bash
echo " *** master node  17"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/0.3.2/tasks/cks/labs/17/k8s-2/scripts/task1.yaml
