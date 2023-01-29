#!/bin/bash
echo " *** master node  "
curl "https://raw.githubusercontent.com/ViktorUJ/cks/TASK_02/tasks/cks/03/scripts/kube-apiserver.yaml" -o "kube-apiserver.yaml"
cp kube-apiserver.yaml /etc/kubernetes/manifests/
sleep 30
kubectl get node --kubeconfig=/root/.kube/config
while test $? -gt 0
  do
   sleep 5
   echo "Trying again..."
   kubectl get node   --kubeconfig=/root/.kube/config
  done
date
kubectl delete  svc kubernetes   --kubeconfig=/root/.kube/config