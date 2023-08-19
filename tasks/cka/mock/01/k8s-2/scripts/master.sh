#!/bin/bash
echo " *** master node  mock-1  k8s-1"
export KUBECONFIG=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-


export RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)
wget https://github.com/etcd-io/etcd/releases/download/${RELEASE}/etcd-${RELEASE}-linux-amd64.tar.gz
tar xvf etcd-${RELEASE}-linux-amd64.tar.gz
cd etcd-${RELEASE}-linux-amd64

mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/01/k8s-1/scripts/task18.yaml