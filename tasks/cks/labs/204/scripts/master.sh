#!/bin/bash
echo " *** master node  task 204"
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

export KUBECONFIG=/root/.kube/config
export ns='prod'
kubectl create ns $ns
kubectl  create secret generic  database-access-1  --from-literal pass=VerryStrongPassword1  --namespace $ns
kubectl  create secret generic  database-access-2  --from-literal pass=VerryStrongPassword2  --namespace $ns
kubectl  create secret generic  database-access-3  --from-literal pass=VerryStrongPassword3 --namespace $ns

export RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)
wget https://github.com/etcd-io/etcd/releases/download/${RELEASE}/etcd-${RELEASE}-linux-amd64.tar.gz
tar xvf etcd-${RELEASE}-linux-amd64.tar.gz
cd etcd-${RELEASE}-linux-amd64

mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"
