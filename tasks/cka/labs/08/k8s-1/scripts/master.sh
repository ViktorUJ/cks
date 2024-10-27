#!/bin/bash
echo " *** master node  cka lab-8  k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cka/labs/08/k8s-1/scripts/app.yaml
