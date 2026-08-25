#!/bin/bash
# *** worker pc, EKS course lab 130 (ECR and supply chain) ***
# Ничего не сеем заранее: студент создаёт репозитории, секреты и cache rules сам через
# AWS CLI. Ждём, пока кластер станет доступен и появится хотя бы одна нода (задание 5
# деплоит под, ссылающийся на образ из приватного ECR по digest).
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 130 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the AWS CLI identity to resolve..."
while ! aws sts get-caller-identity >/dev/null 2>&1; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 130 ***"
