#!/bin/bash
# *** worker pc, EKS course lab 120 (troubleshooting: broken networking, unhealthy targets) ***
# Ничего не сеем в кластер заранее: студент создаёт namespace, нагрузку, LBC и Service сам.
# Terraform уже создал "битую" security group (компонент eks_network_break_demo, без
# inbound-правил) и IAM-роль для AWS Load Balancer Controller (eks_lbc_irsa). Оба имени
# предсказуемы (собраны из prefix и app_name), поэтому находим их без terragrunt output и
# кладём в файл-подсказку на рабочей машине.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task120"
SG_NAME="${PREFIX}-network-break-sg"
HINTS_FILE="/home/ubuntu/lab120_hints.txt"

echo "*** eks course lab 120 ***"

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

echo "Waiting for the eks_network_break_demo terraform component (broken SG)..."
SG_ID=""
for i in $(seq 1 60); do
  SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [[ -n "$SG_ID" ]] && [[ "$SG_ID" != "None" ]]; then
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')
LBC_ROLE_NAME="${CLUSTER_NAME}-lbc-irsa"
NODE_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

cat > "$HINTS_FILE" <<EOF
Lab 120 - troubleshooting сети: unhealthy targets в NLB из-за security group (глава 46).
Имена ресурсов предсказуемы, они собраны из префикса ${PREFIX}.

cluster_name   = ${CLUSTER_NAME}
broken_sg_name = ${SG_NAME}
broken_sg_id   = ${SG_ID}
lbc_role_name  = ${LBC_ROLE_NAME}
node_sg_id     = ${NODE_SG_ID}

Security group ${SG_ID} уже создана terraform (компонент eks_network_break_demo). У
неё корректное описание, allow-all egress и НИ ОДНОГО inbound-правила. Это и есть
поломка: SG - stateful firewall на уровне ENI, поэтому ответы на разрешённый исходящий
трафик проходят сами, но входящий трафик (например health check от NLB) - это НОВОЕ
соединение, и без отдельного inbound-правила оно не пройдёт (глава 46.3, 46.6).

По инструкции задания 4 эта SG становится собственной security group балансировщика
(аннотация service.beta.kubernetes.io/aws-load-balancer-security-groups). Роль IAM для
AWS Load Balancer Controller создана компонентом eks_lbc_irsa, её имя ${LBC_ROLE_NAME}.

Найти ARN роли LBC:
  aws iam get-role --role-name ${LBC_ROLE_NAME} --query 'Role.Arn' --output text

Как найти SG и SG нод заново, если файл потеряется:
  aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \\
    --query 'SecurityGroups[0].GroupId' --output text
  aws ec2 describe-security-groups \\
    --filters "Name=tag:karpenter.sh/discovery,Values=${CLUSTER_NAME}" \\
    --query 'SecurityGroups[0].GroupId' --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 120 ***"
