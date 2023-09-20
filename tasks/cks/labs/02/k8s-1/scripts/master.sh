#!/bin/bash
echo " *** master node task 02 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl apply  --kubeconfig=/root/.kube/config -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/02/scripts/task.yaml
