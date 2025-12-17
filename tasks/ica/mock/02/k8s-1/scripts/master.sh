#!/bin/bash
echo "  *** master node  mock-1  k8s-1"
acrh=$(uname -m)
case $acrh in
x86_64)
  arc_name="amd64"
;;
aarch64)
  arc_name="arm64"
;;
esac

export KUBECONFIG=/root/.kube/config

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-
