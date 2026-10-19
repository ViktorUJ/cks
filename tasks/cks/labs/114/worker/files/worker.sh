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

# Store independent bootstrap evidence before the student begins.
# This directory is root-owned; student-writable artifacts alone are never trusted.
CHECKER=/var/lib/cks-lab114-checker
install -d -o root -g root -m 0755 "$CHECKER"
cp "$KUBECONFIG" "$CHECKER/expected-kubeconfig"
chown root:ubuntu "$CHECKER/expected-kubeconfig"
chmod 0640 "$CHECKER/expected-kubeconfig"
CERT=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' | base64 -d)
printf '%s\n' "$CERT" | openssl x509 -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':\n' | tr 'A-F' 'a-f' > "$CHECKER/initial-cert-sha256"
printf '\n' >> "$CHECKER/initial-cert-sha256"
chmod 0644 "$CHECKER/initial-cert-sha256"

# The control plane may still be converging when the worker starts. Capture the
# canonical default/kubernetes identity/spec only after a successful API read.
for attempt in $(seq 1 90); do
  baseline=$(kubectl --request-timeout=5s --context cluster1-admin@cluster1 \
    -n default get svc kubernetes -o json 2>/dev/null || true)
  if jq -e '.metadata.uid and .spec.clusterIP and .spec.ports' <<< "$baseline" >/dev/null 2>&1; then
    jq -cS '{uid:.metadata.uid,spec:.spec}' <<< "$baseline" | sha256sum | cut -d' ' -f1 > "$CHECKER/default-kubernetes-sha256"
    chmod 0644 "$CHECKER/default-kubernetes-sha256"
    break
  fi
  sleep 2
done
[[ -s "$CHECKER/default-kubernetes-sha256" ]] || { echo 'FATAL: could not capture live default/kubernetes baseline' >&2; exit 1; }

# One root-owned contract verifier shared between tests and monitor.
cat >/usr/local/bin/cks114-backend-contract <<'HELPER_EOF'
#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG=/var/lib/cks-lab114-checker/expected-kubeconfig
CTX=cluster1-admin@cluster1
NS=cks-114
mode=${1:?NodePort or ClusterIP required}
[[ "$mode" == NodePort || "$mode" == ClusterIP ]] || exit 2
svc=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get svc kubernetes-public -o json)
deploy=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get deploy backend -o json)
replicas=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get rs -l app=backend -o json)
pods=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get pods -l app=backend -o json)
slices=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get endpointslices -l kubernetes.io/service-name=kubernetes-public -o json)
jq -ern --arg mode "$mode" --argjson svc "$svc" --argjson dep "$deploy" --argjson rs "$replicas" --argjson pods "$pods" --argjson slices "$slices" '
  def deployment_ok:
    ($dep.metadata.name == "backend") and
    ($dep.metadata.deletionTimestamp == null) and
    ($dep.spec.selector.matchLabels == {"app":"backend"}) and
    ($dep.spec.template.metadata.labels.app == "backend") and
    (($dep.spec.replicas // 1) >= 1) and
    (($dep.status.observedGeneration // -1) >= $dep.metadata.generation) and
    (($dep.status.availableReplicas // 0) >= 1);
  def pod_ok($p):
    ($p.metadata.deletionTimestamp == null) and
    ($p.metadata.labels.app == "backend") and
    (any($p.status.conditions[]?; .type == "Ready" and .status == "True")) and
    (any($rs.items[]?;
      .metadata.uid as $rsuid |
      (any($p.metadata.ownerReferences[]?; .kind == "ReplicaSet" and .uid == $rsuid)) and
      (any(.metadata.ownerReferences[]?; .kind == "Deployment" and .uid == $dep.metadata.uid))));
  def endpoint_ok($ep):
    ($ep.conditions.ready == true) and
    ($ep.conditions.terminating != true) and
    ($ep.targetRef.kind == "Pod") and
    (any($pods.items[]?; . as $p |
      ($p.metadata.uid == $ep.targetRef.uid) and
      (($ep.addresses | index($p.status.podIP)) != null) and pod_ok($p)));
  def slices_ok:
    (any($slices.items[]?.endpoints[]?; .conditions.ready == true)) and
    ([ $slices.items[]? |
      . as $slice |
      ($slice.metadata.labels["endpointslice.kubernetes.io/managed-by"] == "endpointslice-controller.k8s.io") and
      ($slice.metadata.labels["kubernetes.io/service-name"] == "kubernetes-public") and
      (any($slice.metadata.ownerReferences[]?; .kind == "Service" and .uid == $svc.metadata.uid)) and
      ($slice.addressType == "IPv4") and
      (($slice.ports | length) == 1) and
      ($slice.ports[0].port == 80) and
      (($slice.ports[0].protocol // "TCP") == "TCP") and
      (all($slice.endpoints[]?; .conditions.ready != true or endpoint_ok(.)))
    ] | all);
  def service_ok:
    ($svc.metadata.name == "kubernetes-public") and
    ($svc.metadata.deletionTimestamp == null) and
    ($svc.spec.type == $mode) and
    ($svc.spec.selector == {"app":"backend"}) and
    ($svc.spec.publishNotReadyAddresses != true) and
    (($svc.spec.ports | length) == 1) and
    ($svc.spec.ports[0].port == 80) and
    ($svc.spec.ports[0].targetPort == 80) and
    (($svc.spec.ports[0].protocol // "TCP") == "TCP") and
    (if $mode == "NodePort" then $svc.spec.ports[0].nodePort == 30114
     else ($svc.spec.ports[0] | has("nodePort") | not) end);
  if service_ok and deployment_ok and slices_ok then
    "SERVICE_UID=\($svc.metadata.uid)\nDEPLOYMENT_UID=\($dep.metadata.uid)"
  else empty end
'
HELPER_EOF
chmod 0755 /usr/local/bin/cks114-backend-contract

# Historical NodePort proof must belong to this exact Service and Deployment.
# The monitor proves both the worker NodePort and in-cluster Service DNS returned 200.
cat >/usr/local/bin/cks114-monitor <<'MON_EOF'
#!/usr/bin/env bash
set -u
export KUBECONFIG=/var/lib/cks-lab114-checker/expected-kubeconfig
CTX=cluster1-admin@cluster1
NS=cks-114
BASE=/var/lib/cks-lab114-checker
MARK="$BASE/nodeport-phase-seen"
LEDGER="$BASE/monitor-owned-pods"
PROBE="cks114-monitor-$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"
NONCE="$(cat /proc/sys/kernel/random/uuid | tr -d '-')"

# Only the monitor's root-owned ledger authorizes deletion. A label alone is
# student-controlled and must never authorize cluster-admin cleanup.
if [[ ! -e "$LEDGER" ]]; then
  (umask 077; : > "$LEDGER") || exit 1
fi
chmod 0600 "$LEDGER" || exit 1

cleanup() {
  local tmp name nonce actual output bad=0
  tmp=$(mktemp "$BASE/.monitor-owned-pods.XXXXXX") || return 1
  chmod 0600 "$tmp"
  while read -r name nonce; do
    [[ -n "$name" && -n "$nonce" ]] || continue
    if ! [[ "$name" =~ ^cks114-monitor-[a-z0-9-]+$ && "$nonce" =~ ^[a-f0-9]{32}$ ]]; then
      printf '%s %s\n' "$name" "$nonce" >>"$tmp"
      bad=1
      continue
    fi
    output=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get pod "$name" -o json 2>&1)
    if [[ "$?" -ne 0 ]]; then
      if [[ "$output" == *NotFound* ]]; then continue; fi
      printf '%s %s\n' "$name" "$nonce" >>"$tmp"
      bad=1
      continue
    fi
    actual=$(jq -er '.metadata.annotations["cks.lab/monitor-nonce"] // empty' <<<"$output" 2>/dev/null) || actual=""
    if [[ "$actual" != "$nonce" ]]; then
      printf '%s %s\n' "$name" "$nonce" >>"$tmp"
      bad=1
      continue
    fi
    kubectl --request-timeout=8s --context "$CTX" -n "$NS" delete pod "$name" \
      --ignore-not-found --wait=true --timeout=30s >/dev/null 2>&1 || bad=1
    output=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" get pod "$name" -o name 2>&1)
    if [[ "$?" -eq 0 || "$output" != *NotFound* ]]; then
      printf '%s %s\n' "$name" "$nonce" >>"$tmp"
      bad=1
    fi
  done <"$LEDGER"
  mv -f "$tmp" "$LEDGER" || return 1
  return "$bad"
}

on_exit() {
  local n
  trap '' INT TERM
  for n in 1 2 3 4 5; do
    cleanup && return 0
    sleep 1
  done
  echo 'FATAL: monitor-owned Pod cleanup needs recovery; root ledger preserved' >&2
  return 1
}
trap on_exit EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

# A restarted monitor reconciles its own recorded Pods; unrelated Pods with
# the same public label are never touched.
while ! cleanup; do sleep 5; done

while true; do
  # Reconcile the root-owned Pod ledger on EVERY iteration, including after
  # NodePort has already been converted to ClusterIP or the monitor found its
  # historical proof. An API error in the previous cleanup must not strand a
  # previously created probe indefinitely.
  if [[ -s "$LEDGER" ]] && ! cleanup; then
    sleep 5
    continue
  fi
  if [[ ! -s "$MARK" ]]; then
    before=$(/usr/local/bin/cks114-backend-contract NodePort 2>/dev/null || true)
    if [[ -n "$before" ]]; then
      node_ip=$(kubectl --request-timeout=8s --context "$CTX" get nodes \
        -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
      external=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
        --connect-timeout 2 --max-time 5 "http://${node_ip}:30114/" 2>/dev/null || true)
      if [[ "$external" == 200 ]]; then
        if ! cleanup; then sleep 5; continue; fi
        # Persist ownership BEFORE creation so a monitor restart can recover
        # from interruption between kubectl run and kubectl wait/exec.
        printf '%s %s\n' "$PROBE" "$NONCE" >>"$LEDGER"
        if kubectl --request-timeout=8s --context "$CTX" -n "$NS" run "$PROBE" \
             --restart=Never --image=curlimages/curl:8.11.1 \
             --labels='cks.lab/checker-monitor=114' \
             --overrides="{\"metadata\":{\"annotations\":{\"cks.lab/monitor-nonce\":\"$NONCE\"}},\"spec\":{\"terminationGracePeriodSeconds\":0}}" \
             --command -- sleep 300 >/dev/null 2>&1 && \
           kubectl --request-timeout=8s --context "$CTX" -n "$NS" wait \
             --for=condition=Ready "pod/$PROBE" --timeout=90s >/dev/null 2>&1; then
          internal=$(kubectl --request-timeout=8s --context "$CTX" -n "$NS" exec "$PROBE" -- \
            curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 \
            --max-time 5 http://kubernetes-public.cks-114.svc.cluster.local/ 2>/dev/null || true)
          after=$(/usr/local/bin/cks114-backend-contract NodePort 2>/dev/null || true)
          if [[ "$internal" == 200 && "$before" == "$after" && -n "$after" ]] && cleanup; then
            tmp=$(mktemp "$BASE/.phase.XXXXXX")
            printf '%s\n' "$after" > "$tmp"
            printf 'SEEN_AT=%s\n' "$(date +%s)" >> "$tmp"
            chmod 0644 "$tmp"
            mv -f "$tmp" "$MARK"
          fi
        fi
        cleanup || true
      fi
    fi
  fi
  sleep 5
done
MON_EOF
chmod 0755 /usr/local/bin/cks114-monitor
cat >/etc/systemd/system/cks114-monitor.service <<'UNIT_EOF'
[Unit]
Description=CKS Lab 114 verified historical NodePort proof
After=network-online.target

[Service]
ExecStart=/usr/local/bin/cks114-monitor
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT_EOF
systemctl daemon-reload
systemctl enable --now cks114-monitor

echo "*** lab 114 kubeconfig ready, contexts: $(kubectl config get-contexts -o name | tr '\n' ' ')"
