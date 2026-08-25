#!/bin/bash
# *** worker pc, EKS course lab 119 (troubleshooting: node does not reach Ready) ***
# Ничего не сеем заранее: студент создаёт тестовую роль и self-managed EC2-инстанс
# сам. Managed node group лабы (Karpenter) должна быть здоровой сама по себе, поэтому
# просто ждём, пока кластер и хотя бы одна нода станут доступны.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 119 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 119 ***"
