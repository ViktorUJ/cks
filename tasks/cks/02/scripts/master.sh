#!/bin/bash
echo " *** master node task 02 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl apply  --kubeconfig=/root/.kube/config -f https://raw.githubusercontent.com/ViktorUJ/cks/02-11.03.2023/tasks/cks/02/scripts/task.yaml