#!/bin/bash
set -euo pipefail

echo "*** worker pc cks lab 114: kubeconfig fixtures"
export KUBECONFIG=/home/ubuntu/.kube/config

if ! kubectl config get-clusters 2>/dev/null | grep -q '^cluster1$'; then
  echo "FATAL: expected cluster 'cluster1' not found in kubeconfig, module bootstrap likely failed" >&2
  exit 1
fi

# Task 1 fixture: two decoy contexts pointing at unreachable clusters, so the
# real exam workflow (inspect contexts, find the working one, switch to it) has
# something to search through instead of a kubeconfig with a single entry.
kubectl config set-cluster staging --server=https://staging.cks114.invalid:6443 --insecure-skip-tls-verify=true >/dev/null
kubectl config set-credentials staging-admin --token=fake-staging-token >/dev/null
kubectl config set-context staging-admin@staging --cluster=staging --user=staging-admin >/dev/null

kubectl config set-cluster legacy --server=https://10.114.9.9:6443 --insecure-skip-tls-verify=true >/dev/null
kubectl config set-credentials legacy-admin --token=fake-legacy-token >/dev/null
kubectl config set-context legacy-admin@legacy --cluster=legacy --user=legacy-admin >/dev/null

# Task 2 fixture: a real, freshly generated, self-signed client certificate
# embedded directly in the kubeconfig under a dedicated user. It grants no RBAC
# access (nothing on the API server trusts this CA) - the task only asks the
# student to extract and read it, never to authenticate with it.
work_dir=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -keyout "$work_dir/client.key" -out "$work_dir/client.crt" \
  -days 825 -noenc -subj "/CN=cluster9-admin/O=cks-lab114" >/dev/null 2>&1
kubectl config set-credentials cluster9-admin \
  --client-certificate="$work_dir/client.crt" --client-key="$work_dir/client.key" --embed-certs=true >/dev/null
kubectl config set-context cluster9-admin@cluster1 --cluster=cluster1 --user=cluster9-admin >/dev/null
rm -rf "$work_dir"

# Broken by design: current-context points at a decoy cluster on handoff,
# matching the real exam experience of being handed a multi-context kubeconfig.
kubectl config use-context staging-admin@staging >/dev/null

chown ubuntu:ubuntu "$KUBECONFIG"
cp "$KUBECONFIG" /root/.kube/config

echo "*** lab 114 kubeconfig ready, contexts: $(kubectl config get-contexts -o name | tr '\n' ' ')"
