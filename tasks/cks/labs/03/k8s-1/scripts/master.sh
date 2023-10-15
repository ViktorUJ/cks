#!/bin/bash
echo " *** master node  "
curl "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/labs/03/k8s-1/scripts/kube-apiserver.yaml" -o "kube-apiserver.yaml"
cp kube-apiserver.yaml /etc/kubernetes/manifests/
echo "*** change kube api config "
sleep 30
kubectl get node --kubeconfig=/root/.kube/config
while test $? -gt 0
  do
   sleep 5
   echo "Trying again..."
   kubectl get node   --kubeconfig=/root/.kube/config
  done
date
echo "*** delete  svc kubernetes "
kubectl delete  svc kubernetes   --kubeconfig=/root/.kube/config
