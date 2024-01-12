#!/bin/bash
echo " *** master node  mock-2  k8s-4"
export KUBECONFIG=/root/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-