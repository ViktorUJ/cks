#!/bin/bash
echo " *** master node  task 07"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace

kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/07-25.03.2023/tasks/cks/07/scripts/task.yaml  --kubeconfig=/root/.kube/config