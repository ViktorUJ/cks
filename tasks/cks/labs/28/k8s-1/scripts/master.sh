#!/bin/bash
echo " *** master node  cks lab-28  k8s-1"
export KUBECONFIG=/root/.kube/config

apt-get install -y falco

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/cks-new-labs-added/tasks/cks/labs/28/k8s-1/scripts/app.yaml
