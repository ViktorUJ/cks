#!/bin/bash
echo " *** worker pc cks lab 28  "
export KUBECONFIG=/root/.kube/config
address=$(kubectl get no --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address myapp.local">>/etc/hosts