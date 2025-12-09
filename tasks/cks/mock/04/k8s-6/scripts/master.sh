#!/bin/bash
echo " *** master node  mock-4  k8s-6"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# ingress-nginx installation
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install ingress-nginx  ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.12.0 \
  -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/mock/04/k8s-6/scripts/ingress_nginx_conf.yaml \
  --wait --timeout 5m

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'



kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task4.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task5.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task6.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task7.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task8.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task9.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/k8s-6/scripts/task10.yaml
