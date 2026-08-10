#!/bin/bash
# *** worker pc, EKS course lab 129 (Mountpoint for S3: file semantics, backup) ***
# Ничего не сеем заранее: студент создаёт все объекты сам.
# Драйвер aws-mountpoint-s3-csi-driver и бакет уже созданы terraform-компонентом
# eks_addon_s3_csi_irsa. Здесь только ждём готовности кластера, нод, драйвера и бакета.
export KUBECONFIG=/root/.kube/config

echo "*** eks course lab 129 ***"

echo "Waiting for the cluster API to answer..."
while ! kubectl get ns >/dev/null 2>&1; do
  echo "cluster API is not ready yet, waiting..."
  sleep 5
done

echo "Waiting for at least one node to register..."
while [ "$(kubectl get no --no-headers 2>/dev/null | wc -l)" -lt 1 ]; do
  sleep 5
done

echo "Waiting for the aws-mountpoint-s3-csi-driver addon to become ACTIVE..."
for i in $(seq 1 60); do
  status=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-mountpoint-s3-csi-driver \
    --no-headers 2>/dev/null | grep -c Running)
  if [ "$status" -ge 1 ]; then
    break
  fi
  sleep 5
done

echo "Waiting for the demo S3 bucket to exist..."
BUCKET="$(aws s3api list-buckets --query "Buckets[?contains(Name,'mountpoint-demo')].Name" \
  --output text 2>/dev/null | awk '{print $1}')"
for i in $(seq 1 30); do
  if [ -n "$BUCKET" ] && aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
    break
  fi
  sleep 5
  BUCKET="$(aws s3api list-buckets --query "Buckets[?contains(Name,'mountpoint-demo')].Name" \
    --output text 2>/dev/null | awk '{print $1}')"
done

echo "*** cluster is ready, bucket=$BUCKET, you can start lab 129 ***"
