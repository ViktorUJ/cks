#!/bin/bash
# *** worker pc, EKS course lab 132 (Cilium CNI chaining over VPC CNI) ***
# Ничего не сеем заранее: студент создаёт все объекты и ставит Cilium сам.
# Второй NodePool cilium-demo (taint dedicated=cilium-demo) уже есть в кластере
# как код, но нода в нём появится только когда придёт под с toleration.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 132 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 132 ***"
echo "*** helm is already installed on this machine, use it to install Cilium ***"
echo "*** installing Cilium via Helm and waiting for the DaemonSet may take ***"
echo "*** 1-2 minutes after the cilium-demo node is up - be patient in task 3 ***"
