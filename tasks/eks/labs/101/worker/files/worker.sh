#!/bin/bash
# *** worker pc, EKS course lab 101 (cluster as code) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# Ждём, пока кластер станет доступен и появятся ноды.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 101 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 101 ***"
