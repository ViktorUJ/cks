#!/bin/bash
echo " *** master node  ckad mock-1  k8s-1"
export KUBECONFIG=/root/.kube/config

BRANCH="master"

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task4.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task5.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task6.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task8.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/$BRANCH/tasks/ckad/mock/01/k8s-1/scripts/task11.yaml

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# ingress-nginx installation
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install ingress-nginx  ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.8.3 \
  -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/01/k8s-1/scripts/ingress_nginx_conf.yaml

kubectl patch ingressclass nginx --patch '{"metadata": {"annotations": {"ingressclass.kubernetes.io/is-default-class": "true"}}}'
