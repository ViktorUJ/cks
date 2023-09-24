#!/bin/bash
echo " *** master node  mock-1  k8s-7"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/move-to-spot-fleet/tasks/cks/mock/01/k8s-7/scripts/task1.yaml
