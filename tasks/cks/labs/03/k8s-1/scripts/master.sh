#!/bin/bash
echo " *** master node  "
YAML_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
sed -i '/--tls-private-key-file=\/etc\/kubernetes\/pki\/apiserver.key/a\    - --kubernetes-service-node-port=31000' "$YAML_FILE"
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
