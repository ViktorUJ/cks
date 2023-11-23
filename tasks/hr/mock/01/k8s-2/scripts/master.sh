#!/bin/bash
echo " *** master node  mock-1  k8s-2"
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

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/hr/mock/01/k8s-2/scripts/2.yaml
