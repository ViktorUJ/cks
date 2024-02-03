#!/bin/bash
echo " *** master node  cka lab-1  k8s-1"
export KUBECONFIG=/root/.kube/config


sed -i '/--advertise-address=/a \    - --new-option2=value' /etc/kubernetes/manifests/kube-apiserver.yaml

sed -i 's/Pod/PoD/g'  /etc/kubernetes/manifests/kube-apiserver.yaml
service kubelet restart
sleep 10
systemctl disable kubelet
service kubelet stop
