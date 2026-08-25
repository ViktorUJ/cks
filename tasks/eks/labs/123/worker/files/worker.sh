#!/bin/bash
# *** worker pc, EKS course lab 123 (Karpenter disruption) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# Ждём, пока кластер станет доступен и появятся NodePool.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 123 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for NodePools to register..."
while [ "$(kubectl get nodepools --no-headers 2>/dev/null | wc -l)" -lt 2 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 123 ***"
