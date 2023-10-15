#!/bin/bash
echo " *** master node  task 22"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config


kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/labs/22/k8s-1/scripts/task.yaml  --kubeconfig=/root/.kube/config
