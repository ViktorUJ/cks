#!/bin/bash
# *** worker pc, EKS course lab 104 (workload identity: IRSA and Pod Identity) ***
# Ничего не сеем в кластер заранее: студент создаёт namespace, ServiceAccount и поды сам.
# Ждём готовности кластера, затем находим по предсказуемому имени ресурсы, которые уже
# создал terraform (S3 bucket, Secrets Manager secret, обе IAM-роли), и кладём их имена и
# ARN в файл-подсказку на рабочей машине - без ручного terragrunt output.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task104"
APP_NAME="workload_identity"
REGION="eu-central-1"
BUCKET_NAME="${PREFIX}-${APP_NAME}-bucket"
SECRET_NAME="${PREFIX}-${APP_NAME}-secret"
IRSA_ROLE_NAME="${PREFIX}-${APP_NAME}-irsa-role"
POD_IDENTITY_ROLE_NAME="${PREFIX}-${APP_NAME}-pod-identity-role"
HINTS_FILE="/home/ubuntu/lab104_hints.txt"

echo "*** eks course lab 104 ***"

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

echo "Waiting for the workload_identity terraform component (bucket, secret, roles)..."
IRSA_ROLE_ARN=""
POD_IDENTITY_ROLE_ARN=""
SECRET_ARN=""
for i in $(seq 1 60); do
  IRSA_ROLE_ARN=$(aws iam get-role --role-name "$IRSA_ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null)
  POD_IDENTITY_ROLE_ARN=$(aws iam get-role --role-name "$POD_IDENTITY_ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null)
  SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" \
    --region "$REGION" --query 'ARN' --output text 2>/dev/null)
  if [[ -n "$IRSA_ROLE_ARN" ]] && [[ -n "$POD_IDENTITY_ROLE_ARN" ]] && [[ -n "$SECRET_ARN" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 104 - workload identity (IRSA and Pod Identity). Все имена предсказуемы, они собраны
из префикса ${PREFIX} и имени компонента ${APP_NAME} - при желании их можно пересчитать
самостоятельно, этот файл только для удобства.

cluster_name           = ${CLUSTER_NAME}
bucket_name            = ${BUCKET_NAME}
secret_name            = ${SECRET_NAME}
secret_arn             = ${SECRET_ARN}
irsa_role_name         = ${IRSA_ROLE_NAME}
irsa_role_arn          = ${IRSA_ROLE_ARN}
pod_identity_role_name = ${POD_IDENTITY_ROLE_NAME}
pod_identity_role_arn  = ${POD_IDENTITY_ROLE_ARN}

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam get-role --role-name ${IRSA_ROLE_NAME} --query 'Role.Arn' --output text
  aws iam get-role --role-name ${POD_IDENTITY_ROLE_NAME} --query 'Role.Arn' --output text
  aws secretsmanager describe-secret --secret-id ${SECRET_NAME} --query 'ARN' --output text
  aws s3 ls s3://${BUCKET_NAME}/
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 104 ***"
