#!/bin/bash
# *** worker pc, EKS course lab 110 (VPC CNI network policy) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# enableNetworkPolicy включён на аддоне vpc-cni через terraform (см. eks_addons),
# поэтому ждём, пока кластер поднимется и агент aws-network-policy-agent
# станет готов на нодах (DaemonSet aws-node в kube-system).
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 110 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the aws-node DaemonSet (network policy agent) to be ready..."
kubectl -n kube-system rollout status daemonset/aws-node --timeout=300s || true

echo "*** cluster is ready, you can start lab 110 ***"
