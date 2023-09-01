#!/bin/bash
echo " *** master node  task 11"
ns="team-green"
kubeconfig="--kubeconfig=/root/.kube/config"

export RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)
wget https://github.com/etcd-io/etcd/releases/download/${RELEASE}/etcd-${RELEASE}-linux-amd64.tar.gz
tar xvf etcd-${RELEASE}-linux-amd64.tar.gz
cd etcd-${RELEASE}-linux-amd64

mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"

kubectl create ns $ns  $kubeconfig
kubectl  create secret generic  database-access  --from-literal pass=VerryStrongPassword1234567890  --namespace $ns  $kubeconfig
