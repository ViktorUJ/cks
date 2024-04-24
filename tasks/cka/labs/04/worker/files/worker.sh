#!/bin/bash
echo " *** worker pc cka lab 2  "
export KUBECONFIG=/root/.kube/config

address=$(kubectl get no -l work_type=infra_core --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address ckad.local">>/etc/hosts
