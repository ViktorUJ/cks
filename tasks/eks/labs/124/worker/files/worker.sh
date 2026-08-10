#!/bin/bash
# *** worker pc, EKS course lab 124 (application autoscaling: HPA, KEDA, Prometheus) ***
# Ничего не сеем заранее: kube-prometheus-stack, KEDA и все объекты нагрузки студент
# ставит и создаёт сам в рамках заданий (helm уже установлен на рабочей машине).
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 124 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 124 ***"
