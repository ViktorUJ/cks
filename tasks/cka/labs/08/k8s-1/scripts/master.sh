#!/bin/bash
echo " *** master node  cka lab-7  k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/labs/07/k8s-1/scripts/app.yaml

helm repo add prometheus-community  https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack  prometheus-community/kube-prometheus-stack  --version 61.6.0 -n monitoring --create-namespace  -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/labs/07/k8s-1/scripts/kube-prometheus-stack.yaml
