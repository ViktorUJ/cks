#!/bin/bash
# *** worker pc, EKS course lab 102 (cluster access: IAM, RBAC, access entries) ***
# Ничего не сеем заранее: студент создаёт все объекты (тестовую роль, access entry,
# RBAC) сам. Ждём, пока кластер станет доступен.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 102 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "*** cluster is ready, you can start lab 102 ***"
