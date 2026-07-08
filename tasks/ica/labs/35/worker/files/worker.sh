#!/bin/bash
echo " *** worker pc ica lab 35 k8s (multicluster mesh)"
export KUBECONFIG=/root/.kube/config

# The worker PC has kubeconfig contexts for BOTH clusters (cluster1 and
# cluster2) so you can drive them from one place. Nothing is pre-installed —
# generating the shared CA and installing istioctl / Istio on both clusters is
# part of the task (see README.MD).
echo "available contexts:"
kubectl config get-contexts -o name 2>/dev/null || true
