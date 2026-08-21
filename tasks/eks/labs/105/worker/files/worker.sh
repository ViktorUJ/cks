#!/bin/bash
# *** worker pc, EKS course lab 105 (secrets: KMS envelope encryption, External Secrets) ***
# Ничего не сеем в кластер заранее: студент ставит ESO, создаёт SecretStore, ExternalSecret
# и поды сам. Ждём готовности кластера, затем находим по предсказуемому имени ресурсы,
# которые уже создал terraform (секрет Secrets Manager, роль IRSA контроллера ESO), и
# кладём их имена и ARN в файл-подсказку на рабочей машине - без ручного terragrunt output.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task105"
REGION="eu-central-1"
SECRET_NAME="${PREFIX}-eso-demo-secret"
ROLE_NAME="${PREFIX}-eso-irsa-role"
HINTS_FILE="/home/ubuntu/lab105_hints.txt"

echo "*** eks course lab 105 ***"

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

echo "Waiting for the eso_secret terraform component (secret, IRSA role)..."
ROLE_ARN=""
SECRET_ARN=""
for i in $(seq 1 60); do
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null)
  SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" \
    --region "$REGION" --query 'ARN' --output text 2>/dev/null)
  if [[ -n "$ROLE_ARN" ]] && [[ -n "$SECRET_ARN" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 105 - secrets: KMS envelope encryption and External Secrets Operator. Все имена
предсказуемы, они собраны из префикса ${PREFIX} - при желании их можно пересчитать
самостоятельно, этот файл только для удобства.

cluster_name = ${CLUSTER_NAME}
region       = ${REGION}
secret_name  = ${SECRET_NAME}
secret_arn   = ${SECRET_ARN}
role_name    = ${ROLE_NAME}
role_arn     = ${ROLE_ARN}

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text
  aws secretsmanager describe-secret --secret-id ${SECRET_NAME} --query 'ARN' --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 105 ***"
