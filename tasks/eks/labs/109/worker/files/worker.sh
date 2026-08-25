#!/bin/bash
# *** worker pc, EKS course lab 109 (Ingress via ALB: ACM, external-dns, Route 53) ***
# Ничего не сеем заранее: студент ставит LBC и external-dns и создаёт объекты сам.
# terraform уже создал IAM-роли (lbc-irsa, extdns-irsa), приватную hosted zone и
# самоподписанный сертификат в ACM - их имена и ARN не предсказуемы без чтения AWS API
# (zone_id и certificate_arn генерируются AWS), поэтому собираем подсказки в файл.
export KUBECONFIG=/root/.kube/config

ZONE_DOMAIN="eks-task109.internal"
CERT_CN="app.eks-task109.internal"
HINTS_FILE="/home/ubuntu/lab109_hints.txt"

echo "*** eks course lab 109 ***"

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

echo "Waiting for the extdns-irsa IAM role created by terraform..."
EXTDNS_ROLE_ARN=""
for i in $(seq 1 60); do
  EXTDNS_ROLE_ARN=$(aws iam list-roles \
    --query "Roles[?contains(RoleName,'extdns-irsa')].Arn" --output text 2>/dev/null)
  [[ -n "$EXTDNS_ROLE_ARN" ]] && break
  sleep 5
done

echo "Waiting for the private hosted zone ${ZONE_DOMAIN}..."
ZONE_ID=""
for i in $(seq 1 60); do
  ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${ZONE_DOMAIN}" \
    --query "HostedZones[0].Id" --output text 2>/dev/null | sed 's|/hostedzone/||')
  [[ -n "$ZONE_ID" ]] && [[ "$ZONE_ID" != "None" ]] && break
  sleep 5
done

echo "Waiting for the self-signed ACM certificate for ${CERT_CN}..."
CERT_ARN=""
for i in $(seq 1 60); do
  CERT_ARN=$(aws acm list-certificates \
    --query "CertificateSummaryList[?DomainName=='${CERT_CN}'].CertificateArn" \
    --output text 2>/dev/null)
  [[ -n "$CERT_ARN" ]] && break
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 109 - Ingress через ALB, ACM, external-dns и Route 53. IAM-роли, приватная зона и
сертификат уже созданы terraform-ом - этот файл только для удобства.

cluster_name       = ${CLUSTER_NAME}
lbc_role_arn       = ${LBC_ROLE_ARN}
extdns_role_arn    = ${EXTDNS_ROLE_ARN}
zone_domain        = ${ZONE_DOMAIN}
zone_id            = ${ZONE_ID}
cert_common_name   = ${CERT_CN}
cert_arn           = ${CERT_ARN}

Как найти то же самое самостоятельно, если файл потеряется:
  aws iam list-roles --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text
  aws iam list-roles --query "Roles[?contains(RoleName,'extdns-irsa')].Arn" --output text
  aws route53 list-hosted-zones-by-name --dns-name ${ZONE_DOMAIN}
  aws acm list-certificates --query "CertificateSummaryList[?DomainName=='${CERT_CN}']"
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 109 ***"
