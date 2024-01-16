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

mkdir /var/work/tests/artifacts/20/ -p
chmod -R 777  /var/work

kubectl  create secret generic etcd-check --from-literal aa=aa
sleep 5

ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  snapshot save  /var/work/tests/artifacts/20/etcd-backup_old.db

kubectl  delete secret etcd-check
