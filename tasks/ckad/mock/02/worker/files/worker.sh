#!/bin/bash
echo " *** worker pc mock-1  "
export KUBECONFIG=/root/.kube/config

# Helm installation
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

mkdir -p /opt/logs/ /opt/17/
chmod a+w /opt/logs/ /opt/17/

address=$(kubectl get no -l work_type=infra_core --context cluster1-admin@cluster1 -o json  | jq -r '.items[] | select(.kind == "Node") | .status.addresses[] | select(.type == "InternalIP") | .address')
echo "$address ckad.local">>/etc/hosts

mkdir -p /var/work/5/
cd /var/work/5/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/worker/files/5/Dockerfile
chmod 777 -R /var/work/5/

mkdir -p /var/work/19/
cd /var/work/19/
wget https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/ingress_nginx_conf.yaml
chmod 777 ingress_nginx_conf.yaml

mkdir -p /var/work/21/
cd /var/work/21/
wget https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ckad/mock/02/worker/files/21/app-21.yaml
chmod 777 app-21.yaml
