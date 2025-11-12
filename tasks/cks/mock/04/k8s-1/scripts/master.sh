#!/bin/bash
echo " *** master node cks mock 04 k8s-1"
export KUBECONFIG=/root/.kube/config

# Untaint master node
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

