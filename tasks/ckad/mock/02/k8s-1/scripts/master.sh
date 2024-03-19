#!/bin/bash
echo " *** master node  ckad mock-2  k8s-1"
export KUBECONFIG=/root/.kube/config

#task 1
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task1.yaml --record

# task  3
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task3_1.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task3_2.yaml --record
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task3_3.yaml --record

# task 6
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task6.yaml

# task 7
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task7.yaml

# task 8
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task8.yaml

# task 9
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task9.yaml

# task 12
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task12.yaml

# task 16
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task16.yaml

# task 17
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task17.yaml

# task 18
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/ckad/mock/02/k8s-1/scripts/task18.yaml


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
