#!/bin/bash
echo " *** master node cka lab-101 k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server (needed for kubectl top / HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Untaint master node so pods can be scheduled on a single-node cluster
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true
