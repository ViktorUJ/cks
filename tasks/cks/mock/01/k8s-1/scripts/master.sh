#!/bin/bash
echo " *** master node  mock-1  k8s-1"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/mock_12_05_2023/tasks/cks/mock/01/k8s-1/scripts/task1.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/mock_12_05_2023/tasks/cks/mock/01/k8s-1/scripts/task2.yaml
