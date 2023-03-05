#!/bin/bash
echo " *** master node task 12 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/19/scripts/deployment.yaml  --kubeconfig=/root/.kube/config