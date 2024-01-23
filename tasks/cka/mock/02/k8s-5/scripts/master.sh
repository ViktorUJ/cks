#!/bin/bash
echo " *** master node  mock-2  k8s-4"
export KUBECONFIG=/root/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

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

cd /tmp/
wget -O etcd.tar.gz $etcdctl_url
tar xvf etcd.tar.gz
etcd_dir=$(ls  | grep linux | tr -d '\n')
cd $etcd_dir
mv etcd etcdctl etcdutl /usr/local/bin
echo "*** etcd = $(etcdctl version)"

kubectl  apply -f  https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cka/mock/02/k8s-5/scripts/task21.yaml
