#!/bin/bash
echo " *** master node  mock-1  k8s-1"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/mock_12_05_2023/tasks/cks/mock/01/k8s-1/scripts/task.yaml  --kubeconfig=/root/.kube/config