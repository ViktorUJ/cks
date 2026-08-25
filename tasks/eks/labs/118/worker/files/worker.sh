#!/bin/bash
# *** worker pc, EKS course lab 118 (GitOps: Argo CD, drift and self-heal) ***
# Ничего не сеем заранее: студент ставит Argo CD и Application сам.
# Ждём, пока кластер станет доступен и появится хотя бы одна нода.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 118 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 118 ***"
echo "Manifests for the Argo CD Application live in this repo, path:"
echo "  tasks/eks/labs/118/gitops-demo/"
