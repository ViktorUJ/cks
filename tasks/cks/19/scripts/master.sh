#!/bin/bash
echo " *** master node task 19  "
kubectl taint nodes --all node-role.kubernetes.io/master- --kubeconfig=/root/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-  --kubeconfig=/root/.kube/config

kubectl create deployment nginx --image=nginx  --kubeconfig=/root/.kube/config

kubectl  apply -f https://raw.githubusercontent.com/ViktorUJ/cks/task_019/tasks/cks/19/scripts/deployment.yaml  --kubeconfig=/root/.kube/config