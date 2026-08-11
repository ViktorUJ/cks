#!/bin/bash
# *** worker pc, EKS course lab 114 (observability: Container Insights and AMP) ***
# Ничего не сеем заранее: metrics-server, Container Insights, kube-prometheus-stack и
# приложение студент ставит сам в рамках заданий (helm уже установлен на рабочей машине).
# terraform уже создал AMP workspace - его alias предсказуем и записан в файл-подсказку.
export KUBECONFIG=/root/.kube/config

PREFIX="eks-task114"
AMP_ALIAS="${PREFIX}-amp"
HINTS_FILE="/home/ubuntu/lab114_hints.txt"

echo "*** eks course lab 114 ***"

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

echo "Waiting for the eks_amp_workspace terraform component..."
AMP_WORKSPACE_ID=""
AMP_ENDPOINT=""
for i in $(seq 1 60); do
  AMP_WORKSPACE_ID=$(aws amp list-workspaces --alias "$AMP_ALIAS" \
    --query 'workspaces[0].workspaceId' --output text 2>/dev/null)
  if [[ -n "$AMP_WORKSPACE_ID" ]] && [[ "$AMP_WORKSPACE_ID" != "None" ]]; then
    AMP_ENDPOINT=$(aws amp describe-workspace --workspace-id "$AMP_WORKSPACE_ID" \
      --query 'workspace.prometheusEndpoint' --output text 2>/dev/null)
    break
  fi
  sleep 5
done

CLUSTER_NAME=$(kubectl config current-context 2>/dev/null | sed 's|.*/||')

cat > "$HINTS_FILE" <<EOF
Lab 114 - observability (Container Insights and Amazon Managed Prometheus). AMP workspace
уже создан terraform-ом, имя предсказуемо из alias - этот файл только для удобства.

cluster_name        = ${CLUSTER_NAME}
amp_workspace_alias  = ${AMP_ALIAS}
amp_workspace_id     = ${AMP_WORKSPACE_ID}
amp_prometheus_endpoint = ${AMP_ENDPOINT}

Как найти то же самое самостоятельно, если файл потеряется:
  aws amp list-workspaces --alias ${AMP_ALIAS} --output table
  aws amp describe-workspace --workspace-id <id> \\
    --query "workspace.prometheusEndpoint" --output text
EOF
chown ubuntu:ubuntu "$HINTS_FILE"
chmod 644 "$HINTS_FILE"

echo "*** cluster is ready, hints are in $HINTS_FILE, you can start lab 114 ***"
