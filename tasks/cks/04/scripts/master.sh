#!/bin/bash
echo " *** master node task 04 "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/03.04.2023-task-04/tasks/cks/04/scripts/task.yaml  --kubeconfig=/root/.kube/config