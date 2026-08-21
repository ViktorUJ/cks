#!/bin/bash
# *** worker pc, EKS course lab 116 (hardening: IMDSv2 hop limit, PSA, private endpoint) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# Ждём, пока кластер станет доступен и появится хотя бы одна нода.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 116 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 116 ***"
