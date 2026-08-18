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
# Проверяем СТАТУС АДДОНА, а не поды: s3-csi-node - это DaemonSet, а нод у него нет, пока в
# кластере нет EC2-нод (системные поды лабы живут на Fargate). Прежняя проверка на Running-под
# не выполнялась никогда и просто добавляла 5 минут к загрузке воркера (поймано на стенде).
CLUSTER_FOR_ADDON=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')
for i in $(seq 1 60); do
  status=$(aws eks describe-addon --cluster-name "$CLUSTER_FOR_ADDON" \
    --addon-name aws-mountpoint-s3-csi-driver --query 'addon.status' --output text 2>/dev/null)
  echo "addon status: ${status:-unknown}"
  if [ "$status" == "ACTIVE" ]; then
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

# Файл подсказок: имя бакета нужно и в задании 2, и в разделе "Удаление" (там оно читается
# именно из этого файла). Раньше файл не создавался вовсе, и процедура удаления брала пустое
# имя бакета - поймано при проверке лабы на стенде.
HINTS_FILE="/home/ubuntu/lab129_hints.txt"
CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 129 - Mountpoint for S3. Бакет с versioning и объектом readme.txt уже создан terraform-ом,
драйвер aws-mountpoint-s3-csi-driver установлен как managed addon с ролью через IRSA.

cluster_name = ${CLUSTER_NAME}
bucket_name  = ${BUCKET}
region       = eu-central-1

Как найти бакет самостоятельно, если файл потеряется:
  aws s3api list-buckets --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, bucket=$BUCKET, hints are in $HINTS_FILE, you can start lab 129 ***"
