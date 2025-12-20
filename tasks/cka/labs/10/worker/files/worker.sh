#!/bin/bash
echo " *** worker pc cka lab 10  "
export KUBECONFIG=/root/.kube/config

address=$(kubectl get no -l work_type=system --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address cka.local">>/etc/hosts
echo "$address dev-cka.local">>/etc/hosts
echo "$address weight-cka.local">>/etc/hosts
echo "$address header-cka.local">>/etc/hosts
echo "$address non-domain.example">>/etc/hosts