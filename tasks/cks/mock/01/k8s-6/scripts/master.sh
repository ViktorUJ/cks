#!/bin/bash
echo " *** master node  mock-1  k8s-6"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task1.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task5.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task9.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task10.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task11.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/k8s-6/scripts/task15.yaml