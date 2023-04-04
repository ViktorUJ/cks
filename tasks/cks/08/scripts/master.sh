#!/bin/bash
echo " *** master node task 08 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/08-04.04.2023/tasks/cks/08/scripts/task.yaml  --kubeconfig=/root/.kube/config