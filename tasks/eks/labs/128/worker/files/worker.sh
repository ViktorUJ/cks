#!/bin/bash
# *** worker pc, EKS course lab 128 (Gateway API: ALB Gateway API and VPC Lattice) ***
# Ничего не сеем заранее: студент ставит оба контроллера и создаёт объекты Gateway API сам.
# terraform уже создал IAM-роли для обоих контроллеров (lbc-irsa, vpclattice-irsa) - их
# имена предсказуемы, поэтому находим их без чтения terragrunt output и кладём в файл-
# подсказку.
export KUBECONFIG=/root/.kube/config

HINTS_FILE="/home/ubuntu/lab128_hints.txt"

echo "*** eks course lab 128 ***"

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

echo "Waiting for the lbc-irsa IAM role created by terraform..."
LBC_ROLE_ARN=""
for i in $(seq 1 60); do
  LBC_ROLE_ARN=$(aws iam list-roles \
    --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text 2>/dev/null)
  [[ -n "$LBC_ROLE_ARN" ]] && break
  sleep 5
done

echo "Waiting for the vpclattice-irsa IAM role created by terraform..."
LATTICE_ROLE_ARN=""
for i in $(seq 1 60); do
  LATTICE_ROLE_ARN=$(aws iam list-roles \
    --query "Roles[?contains(RoleName,'vpclattice-irsa')].Arn" --output text 2>/dev/null)
  [[ -n "$LATTICE_ROLE_ARN" ]] && break
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')
NODE_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
# Оба контроллера не могут определить регион и VPC сами: под LBC живёт в kube-system, то есть
# на Fargate, где IMDS нет вовсе, а под контроллера VPC Lattice стоит на EC2-ноде, но IMDSv2
# с hop limit 1 не отвечает поду (главы 10 и 19). Поэтому значения передаются флагами Helm.
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

cat > "$HINTS_FILE" <<EOF
Lab 128 - Gateway API в AWS: ALB Gateway API и VPC Lattice. IAM-роли обоих контроллеров
уже созданы terraform-ом - этот файл только для удобства.

cluster_name         = ${CLUSTER_NAME}
lbc_role_arn         = ${LBC_ROLE_ARN}
vpclattice_role_arn  = ${LATTICE_ROLE_ARN}
node_sg_id           = ${NODE_SG_ID}
vpc_id               = ${VPC_ID}
account_id           = ${ACCOUNT_ID}
region               = eu-central-1

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam list-roles --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text
  aws iam list-roles --query "Roles[?contains(RoleName,'vpclattice-irsa')].Arn" --output text
  aws ec2 describe-security-groups \\
    --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \\
    --query 'SecurityGroups[0].GroupId' --output text
  aws eks describe-cluster --name ${CLUSTER_NAME} \\
    --query 'cluster.resourcesVpcConfig.vpcId' --output text
  aws sts get-caller-identity --query Account --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 128 ***"
