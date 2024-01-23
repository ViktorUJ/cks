#!/bin/bash
echo " *** master node  mock-2  k8s-1"
export KUBECONFIG=/root/.kube/config

acrh=$(uname -m)
export RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)
case $acrh in
x86_64)
  etcdctl_url="https://github.com/etcd-io/etcd/releases/download/${RELEASE}/etcd-${RELEASE}-linux-amd64.tar.gz"
;;
aarch64)
  etcdctl_url="https://github.com/etcd-io/etcd/releases/download/${RELEASE}/etcd-${RELEASE}-linux-arm64.tar.gz"
;;
esac


wget -O etcd.tar.gz $etcdctl_url
tar xvf etcd.tar.gz
etcd_dir=$(ls  | grep linux | tr -d '\n')
cd $etcd_dir
mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'


acrh=$(uname -m)
case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac

# ingress-nginx installation
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install ingress-nginx  ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.8.3 \
  -f https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/ingress_nginx_conf.yaml

kubectl patch ingressclass nginx --patch '{"metadata": {"annotations": {"ingressclass.kubernetes.io/is-default-class": "true"}}}'

# tasks
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task1.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task2.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task6.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task8.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task12.yaml
kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-1/scripts/task15.yaml
