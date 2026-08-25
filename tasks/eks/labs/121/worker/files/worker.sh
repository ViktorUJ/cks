#!/bin/bash
# *** worker pc, EKS course lab 121 (troubleshooting: access denied) ***
# Ничего не сеем в кластер заранее: студент создаёт namespace, роли, SA и поды сам.
# Ждём готовности кластера, затем находим по предсказуемому имени ресурсы, которые уже
# создал terraform (S3 bucket и IRSA-роль компонента eks_irsa_break_demo), и кладём их
# имена и ARN в файл-подсказку на рабочей машине - без ручного terragrunt output.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task121"
APP_NAME="irsa-break-demo"
REGION="eu-central-1"
BUCKET_NAME="${PREFIX}-${APP_NAME}-bucket"
IRSA_ROLE_NAME="${PREFIX}-${APP_NAME}-irsa-role"
HINTS_FILE="/home/ubuntu/lab121_hints.txt"

echo "*** eks course lab 121 ***"

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

echo "Waiting for the eks_irsa_break_demo terraform component (bucket, IRSA role)..."
IRSA_ROLE_ARN=""
for i in $(seq 1 60); do
  IRSA_ROLE_ARN=$(aws iam get-role --role-name "$IRSA_ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null)
  if [[ -n "$IRSA_ROLE_ARN" ]] && [[ "$IRSA_ROLE_ARN" != "None" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 121 - troubleshooting доступа (access entries, IRSA, webhook, kubeconfig).
Все имена предсказуемы, они собраны из префикса ${PREFIX} и имени компонента ${APP_NAME}.

cluster_name  = ${CLUSTER_NAME}
bucket_name   = ${BUCKET_NAME}
irsa_role_name = ${IRSA_ROLE_NAME}
irsa_role_arn  = ${IRSA_ROLE_ARN}

Роль IRSA уже создана terraform, её trust policy доверяет ровно ServiceAccount
system:serviceaccount:eks-121:demo-reader. У роли есть s3:GetObject и s3:ListBucket на
бакет ${BUCKET_NAME} (внутри объект hello.txt).

Роль worker-а (её ARN - $(aws sts get-caller-identity --query Arn --output text 2>/dev/null))
имеет права создавать и удалять IAM-роли с именем, содержащим "-test-", и право
sts:AssumeRole на такие роли - этого достаточно для задания 2.

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam get-role --role-name ${IRSA_ROLE_NAME} --query 'Role.Arn' --output text
  aws s3 ls s3://${BUCKET_NAME}/
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 121 ***"
