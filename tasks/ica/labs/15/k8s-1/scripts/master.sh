#!/bin/bash
echo " *** master node ica lab-15 k8s-1"
export KUBECONFIG=/root/.kube/config

# Installation of metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json \
-p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]]'

# Untaint master node so Istio and workloads can be scheduled
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-

# NOTE: Istio is intentionally NOT installed here.
# Installing and customizing Istio (IstioOperator profile + MeshConfig +
# an extra ingress gateway) is the task of this lab — see README.MD.
