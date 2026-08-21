#!/bin/bash
# *** worker pc, EKS course lab 115 (logging: Fluent Bit, CloudWatch Logs, filtering, retention) ***
# Ничего не сеем в кластер заранее: студент ставит Fluent Bit, ловит симптом и чинит его сам.
# Ждём готовности кластера и ноды, затем находим по предсказуемому имени роль IRSA, которую
# уже создал terraform (eks_v2_fluentbit_irsa), и кладём её ARN и имя лог-группы в файл-подсказку.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task115"
ROLE_NAME="${PREFIX}-fluentbit-irsa-role"
HINTS_FILE="/home/ubuntu/lab115_hints.txt"

echo "*** eks course lab 115 ***"

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

echo "Waiting for the fluentbit_irsa terraform component (IAM role)..."
ROLE_ARN=""
for i in $(seq 1 60); do
  ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.Arn' --output text 2>/dev/null)
  if [[ -n "$ROLE_ARN" ]] && [[ "$ROLE_ARN" != "None" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')
LOG_GROUP_NAME="/aws/eks/${CLUSTER_NAME}/application"

cat > "$HINTS_FILE" <<EOF
Lab 115 - логирование: Fluent Bit в CloudWatch Logs, фильтрация и retention. Все имена
предсказуемы, они собраны из префикса ${PREFIX} - при желании их можно пересчитать
самостоятельно, этот файл только для удобства.

cluster_name    = ${CLUSTER_NAME}
region          = eu-central-1
role_name       = ${ROLE_NAME}
role_arn        = ${ROLE_ARN}
log_group_name  = ${LOG_GROUP_NAME}

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam get-role --role-name ${ROLE_NAME} --query 'Role.Arn' --output text
  kubectl config current-context | sed 's|.*/||'
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 115 ***"
