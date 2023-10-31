#!/bin/bash
echo " *** master node  mock-1  k8s-1"
export KUBECONFIG=/root/.kube/config

acrh=$(uname -m)
case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac

mkdir -p /opt/logs/
chmod o+w /opt/logs

BRANCH="CKAD-mock-questions"

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task4.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task5.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task6.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task8.yaml
