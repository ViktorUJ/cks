#!/bin/bash
echo " *** master node  task 11"
ns="team-green"
kubeconfig="--kubeconfig=/root/.kube/config"

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

cd ~
wget -O etcd.tar.gz $etcdctl_url
tar xvf etcd.tar.gz
etcd_dir=$(ls  | grep linux | tr -d '\n')
cd $etcd_dir
mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"

kubectl create ns $ns  $kubeconfig
kubectl  create secret generic  database-access  --from-literal pass=VerryStrongPassword1234567890  --namespace $ns  $kubeconfig
