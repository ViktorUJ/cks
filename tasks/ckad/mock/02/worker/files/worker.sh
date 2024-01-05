#!/bin/bash
echo " *** worker pc mock-1  "
export KUBECONFIG=/root/.kube/config

# Helm installation
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

mkdir -p /opt/logs/ /opt/18/
chmod a+w /opt/logs/ /opt/18/

address=$(kubectl get no -l work_type=infra_core --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address ckad.local">>/etc/hosts
