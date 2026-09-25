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

# Tasks 3 and 4 describe two successive states of the same Service (NodePort, then ClusterIP),
# so at the end of the lab only one of them can be observed. This checker-owned monitor records
# that the NodePort phase really happened (Service type NodePort/30114 answering from the worker),
# so test 3 can be satisfied after the Service was reduced to ClusterIP in task 4.
CHECKER=/var/lib/cks-lab114-checker
install -d -o root -g root -m 0755 "$CHECKER"
cat >/usr/local/bin/cks114-monitor <<'MON_EOF'
#!/usr/bin/env bash
set -u
export KUBECONFIG=/home/ubuntu/.kube/config
CTX=cluster1-admin@cluster1
MARK=/var/lib/cks-lab114-checker/nodeport-phase-seen
while true; do
  if [[ ! -s "$MARK" ]]; then
    svc=$(kubectl --context "$CTX" -n cks-114 get svc kubernetes-public -o json 2>/dev/null || true)
    if [[ -n "$svc" ]] && jq -e '.spec.type == "NodePort" and .spec.ports[0].nodePort == 30114' <<<"$svc" >/dev/null 2>&1; then
      node_ip=$(kubectl --context "$CTX" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
      code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "http://${node_ip}:30114/" 2>/dev/null || true)
      if [[ "$code" =~ ^[1-5][0-9][0-9]$ ]]; then
        printf '%s nodeport=30114 http=%s node=%s\n' "$(date +%s)" "$code" "$node_ip" > "$MARK"
      fi
    fi
  fi
  sleep 2
done
MON_EOF
chmod 0755 /usr/local/bin/cks114-monitor
cat >/etc/systemd/system/cks114-monitor.service <<'UNIT_EOF'
[Unit]
Description=CKS lab 114 checker-owned NodePort phase monitor
After=network-online.target

[Service]
ExecStart=/usr/local/bin/cks114-monitor
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
UNIT_EOF
systemctl daemon-reload
systemctl enable --now cks114-monitor

echo "*** lab 114 kubeconfig ready, contexts: $(kubectl config get-contexts -o name | tr '\n' ' ')"
