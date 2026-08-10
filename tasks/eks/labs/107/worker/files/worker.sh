#!/bin/bash
# *** worker pc, EKS course lab 107 (EFS CSI: ReadWriteMany across AZ) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# EFS CSI driver уже поставлен terraform-компонентом eks_addon_efs_irsa (managed addon
# aws-efs-csi-driver, роль через IRSA), а файловая система EFS и mount target в каждой
# AZ уже созданы terraform. Здесь только ждём готовности кластера, нод и файловой системы.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 107 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the aws-efs-csi-driver addon to become ACTIVE..."
for i in $(seq 1 60); do
  status=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-efs-csi-driver \
    --no-headers 2>/dev/null | grep -c Running)
  if [ "$status" -ge 1 ]; then
    break
  fi
  sleep 5
done

echo "*** cluster is ready, you can start lab 107 ***"
