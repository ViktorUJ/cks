#!/bin/bash
echo " *** master node  mock-1  k8s-6"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# ingress-nginx installation
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install ingress-nginx  ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.8.3 \
  -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/labs/03/k8s-1/scripts/ingress_nginx_conf.yaml \
  --wait --timeout 5m


kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task1.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task5.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task8.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task9.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task10.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task11.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/AG-92/tasks/cks/mock/02/k8s-6/scripts/task15.yaml
