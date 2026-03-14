#!/bin/bash
echo " *** worker pc cks lab 30 k8s-1"  "
export KUBECONFIG=/root/.kube/config
address=$(kubectl get no -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address myapp.local">>/etc/hosts
