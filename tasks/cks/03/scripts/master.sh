#!/bin/bash
echo " *** master node  "
curl "https://raw.githubusercontent.com/ViktorUJ/cks/TASK_02/tasks/cks/03/scripts/kube-apiserver.yaml" -o "kube-apiserver.yaml"
cp kube-apiserver.yaml /etc/kubernetes/manifests/
kubectl delete  svc kubernetes   --kubeconfig=/root/.kube/config