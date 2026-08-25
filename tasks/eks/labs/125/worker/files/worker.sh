#!/bin/bash
# *** worker pc, EKS course lab 125 (EKS Auto Mode versus own stack) ***
# Ничего не сеем в кластер заранее: студент проверяет режим Auto Mode, создаёт namespace,
# нагрузку и свой NodePool сам. Ждём готовности кластера - в Auto Mode ноды под системные
# компоненты появляются автоматически, без Fargate-профиля и без внешнего Karpenter.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 125 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for the AWS CLI identity to resolve..."
while ! aws sts get-caller-identity >/dev/null 2>&1; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 125 ***"
echo "This cluster runs EKS Auto Mode: check 'aws eks describe-cluster --query"
echo "cluster.computeConfig' and 'kubectl get nodepools' to see the built-in NodePools."
