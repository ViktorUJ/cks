#!/bin/bash
# *** worker pc, EKS course lab 122 (AWS Backup for EKS: composite recovery point, ***
# *** namespace restore) ***
# Ничего не сеем в кластер заранее: студент создаёт namespace, нагрузку, opt-in, бэкап
# и restore сам через kubectl и AWS CLI. Terraform уже создал IAM-роль для AWS Backup и
# backup vault (компонент eks_backup_iam, модуль eks_v2_backup_iam) - их имена
# предсказуемы (собраны из имени кластера), поэтому находим их без чтения terraform
# output и кладём в файл-подсказку, как в лабах 104/105/115.
export KUBECONFIG=/root/.kube/config

HINTS_FILE="/home/ubuntu/lab122_hints.txt"

echo "*** eks course lab 122 ***"

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

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')
BACKUP_ROLE_NAME="${CLUSTER_NAME}-backup"
BACKUP_VAULT_NAME="${CLUSTER_NAME}-vault"

echo "Waiting for the eks_backup_iam terraform component (IAM role, backup vault)..."
# ARN роли собираем из account id, а не только через iam:GetRole: имя роли предсказуемо, и
# такой способ не зависит от того, разрешён ли воркеру iam:GetRole на эту роль.
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
BACKUP_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${BACKUP_ROLE_NAME}"
VAULT_ARN=""
for i in $(seq 1 60); do
  VAULT_ARN=$(aws backup describe-backup-vault --backup-vault-name "$BACKUP_VAULT_NAME" \
    --query 'BackupVaultArn' --output text 2>/dev/null)
  if [[ -n "$VAULT_ARN" ]] && [[ "$VAULT_ARN" != "None" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_ARN=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query 'cluster.arn' --output text 2>/dev/null)

cat > "$HINTS_FILE" <<EOF
Lab 122 - AWS Backup for EKS. Имя роли и vault собраны terraform из имени кластера
(компонент eks_backup_iam, модуль eks_v2_backup_iam) - при желании их можно пересчитать
самостоятельно, этот файл только для удобства.

cluster_name    = ${CLUSTER_NAME}
cluster_arn     = ${CLUSTER_ARN}
backup_role_arn = ${BACKUP_ROLE_ARN}
vault_name      = ${BACKUP_VAULT_NAME}
vault_arn       = ${VAULT_ARN}

Как найти то же самое самостоятельно, если файл потеряется:
  CLUSTER=\$(kubectl config current-context | sed 's|.*/||')
  aws iam get-role --role-name "\${CLUSTER}-backup" --query 'Role.Arn' --output text
  aws backup describe-backup-vault --backup-vault-name "\${CLUSTER}-vault"
  aws eks describe-cluster --name "\$CLUSTER" --query 'cluster.arn' --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 122 ***"
