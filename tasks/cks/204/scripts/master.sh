#!/bin/bash
echo " *** master node  task 204"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config
export ns='prod'
kubectl create ns $ns
kubectl  create secret generic  database-access-1  --from-literal pass=VerryStrongPassword1  --namespace $ns
kubectl  create secret generic  database-access-2  --from-literal pass=VerryStrongPassword2  --namespace $ns
kubectl  create secret generic  database-access-3  --from-literal pass=VerryStrongPassword3 --namespace $ns