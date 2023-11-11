#!/bin/bash
echo " *** worker pc mock-1  "

# Helm installation
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

mkdir -p /opt/logs/ /opt/18/
chmod a+w /opt/logs/ /opt/18/

address=$(k get no -l work_type=infra_core -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address ckad.local">>/etc/hosts