#!/bin/bash
echo " *** master node  task 201"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config


kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/mock-19.04.2023/tasks/cks/201/scripts/task.yaml  --kubeconfig=/root/.kube/config
