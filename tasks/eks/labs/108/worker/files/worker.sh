#!/bin/bash
# *** worker pc, EKS course lab 108 (AWS Load Balancer Controller: NLB) ***
# Ничего не сеем заранее: студент ставит LBC и создаёт объекты сам.
# Ждём, пока кластер станет доступен и появится хотя бы одна нода.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 108 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "*** cluster is ready, you can start lab 108 ***"
echo "IAM role for the AWS Load Balancer Controller was created by terraform."
echo "Find its ARN with:"
echo "  aws iam list-roles --query \"Roles[?contains(RoleName,'lbc-irsa')].Arn\" --output text"
