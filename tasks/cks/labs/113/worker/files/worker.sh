#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/root/.kube/config

echo "*** worker PC CKS lab 113"
until kubectl get nodes --no-headers 2>/dev/null | wc -l | grep -q '^2$'; do sleep 5; done

# The lab nodes are reached as "ssh k8s113_controlPlane_1" / "ssh k8s113_node_worker1" (aliases in
# /etc/hosts). Their host keys are not in any known_hosts and the nodes accept only the ubuntu
# user, so every non-interactive ssh - this script, the root-run cks113-monitor and the
# BatchMode calls in check_result - would fail. Configure both root and the student user.
for ssh_home in /root /home/ubuntu; do
  install -d -m 0700 "$ssh_home/.ssh"
  printf 'Host k8s113_*\n  User ubuntu\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n' >> "$ssh_home/.ssh/config"
  chmod 0600 "$ssh_home/.ssh/config"
done
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

for host in k8s113_controlPlane_1 k8s113_node_worker1; do
  for attempt in {1..24}; do
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'sudo -n true' >/dev/null 2>&1; then
      echo "*** SSH access to $host is ready"
      break
    fi
    if [[ "$attempt" -eq 24 ]]; then
      echo "SSH access to $host was not ready after two minutes" >&2
      exit 1
    fi
    sleep 5
  done
done

echo "*** waiting for canary Deployment to become available and spread across both nodes"
kubectl rollout status deployment/canary \
  -n upgrade-113 \
  --timeout=180s

canary_nodes=$(
  kubectl get pods \
    -n upgrade-113 \
    -l app=canary \
    -o jsonpath='{.items[*].spec.nodeName}' \
    | tr ' ' '\n' \
    | sed '/^$/d' \
    | sort -u \
    | wc -l
)

[[ "$canary_nodes" -eq 2 ]] || {
  echo "Canary replicas are not spread across both nodes" >&2
  exit 1
}

echo "*** installing checker-owned upgrade monitor (independent of student evidence)"
CHECKER=/var/lib/cks-lab113-checker
install -d -o root -g root -m 0755 "$CHECKER"

cat >/usr/local/bin/cks113-monitor <<'EOF'
#!/usr/bin/env bash
set -u
umask 077

export KUBECONFIG=/root/.kube/config
DIR=/var/lib/cks-lab113-checker
LOG="$DIR/upgrade-monitor.log"
STATE="$DIR/order-state"

# Exactly one writer; the previous state survives systemd restarts.
exec 9>"$DIR/monitor.lock"
flock -n 9 || exit 1

state_value() {
  local key="$1" raw
  [[ -f "$STATE" ]] || { printf '0'; return; }
  raw=$(sed -n "s/^${key}=\([0-9][0-9]*\)$/\1/p" "$STATE" | tail -n 1)
  [[ "$raw" =~ ^[0-9]+$ ]] || { echo "Corrupt or missing monitor state: $key" >&2; exit 1; }
  printf '%s' "$raw"
}

baseline_seen=$(state_value baseline_seen)
cp_done_seen=$(state_value cp_done_seen)
order_violation=$(state_value order_violation)
worker_target_seen=$(state_value worker_target_seen)
canary_outage_seen=$(state_value canary_outage_seen)
canary_unknown_seen=$(state_value canary_unknown_seen)
history_gap_seen=$(state_value history_gap_seen)
healthy_samples=$(state_value healthy_samples)
last_ts=$(state_value last_ts)
cp_done_at=$(state_value cp_done_at)
worker_target_at=$(state_value worker_target_at)

kget() { kubectl --request-timeout=6s "$@" 2>/dev/null || true; }
node_field() {
  local selector="$1" field="$2" node
  node=$(kget get nodes -l "$selector" -o jsonpath='{.items[0].metadata.name}')
  [[ -n "$node" ]] || return 0
  kget get node "$node" -o "jsonpath=$field"
}
ssh_version() {
  local host="$1" command="$2"
  timeout 9s ssh -o BatchMode=yes -o ConnectTimeout=3 -o ServerAliveInterval=3 \
    -o ServerAliveCountMax=1 "$host" "$command" 2>/dev/null || echo unknown
}
canary_count() {
  local host="$1" response count
  if ! response=$(timeout 9s ssh -o BatchMode=yes -o ConnectTimeout=3 \
      -o ServerAliveInterval=3 -o ServerAliveCountMax=1 "$host" \
      'sudo -n timeout 6s crictl ps -o json' 2>/dev/null); then
    printf 'unknown'; return
  fi
  if ! count=$(printf '%s' "$response" | jq -er '
    [(.containers // [])[] |
     select(.state == "CONTAINER_RUNNING" and
            .metadata.name == "canary" and
            .labels["io.kubernetes.pod.namespace"] == "upgrade-113" and
            (.labels["io.kubernetes.pod.name"] | type == "string") and
            (.labels["io.kubernetes.pod.name"] | startswith("canary-")))] | length
  ' 2>/dev/null); then
    printf 'unknown'; return
  fi
  printf '%s' "$count"
}

# A monitor restart must not restart the tolerance window for an unresolved
# Ready=0 observation. Accept the old state format only for the first upgrade.
if [[ -f "$STATE" ]] && grep -Eq '^ambiguous_since=[0-9]+$' "$STATE"; then
  ambiguous_since=$(state_value ambiguous_since)
else
  ambiguous_since=0
fi
while true; do
  ts=$(date +%s)
  if ((last_ts > 0 && ts - last_ts > 60)); then history_gap_seen=1; fi
  last_ts=$ts

  # Kubernetes omits zero-valued availableReplicas (json omitempty). A successful
  # Deployment GET with the field absent is authoritative zero; a failed GET is
  # UNKNOWN. Do not merge these states, or downtime can be hidden by CRI processes.
  available=unknown
  deployment_json=$(kget get deployment canary -n upgrade-113 -o json)
  if [[ -n "$deployment_json" ]]; then
    available_result=$(printf '%s' "$deployment_json" | jq -er '
      if .apiVersion == "apps/v1" and .kind == "Deployment" and
         .metadata.name == "canary" and .metadata.namespace == "upgrade-113" and
         (.status.availableReplicas == null or
           ((.status.availableReplicas | type) == "number" and
            .status.availableReplicas >= 0 and
            (.status.availableReplicas | floor) == .status.availableReplicas))
      then (.status.availableReplicas // 0 | tostring)
      else "unknown" end
    ' 2>/dev/null) || available_result=unknown
    [[ "$available_result" =~ ^[0-9]+$ ]] && available=$available_result
  fi
  # (kubectl wraps list responses as kind "List"; the raw API uses PodList/ReplicaSetList.)
  # Count only Ready Pods owned by a live ReplicaSet controlled by the
  # exact canary Deployment UID. A student can create an unrelated Ready Pod
  # with app=canary; its status must never mask a real canary outage.
  pod_json=$(kget get pods -n upgrade-113 -l app=canary -o json)
  rs_json=$(kget get replicasets -n upgrade-113 -l app=canary -o json)
  ready_pods=unknown
  if [[ -n "$deployment_json" && -n "$pod_json" && -n "$rs_json" ]]; then
    ready_result=$(jq -ner \
      --argjson dep "$deployment_json" \
      --argjson rss "$rs_json" \
      --argjson pods "$pod_json" '
      if $dep.apiVersion == "apps/v1" and $dep.kind == "Deployment" and
         $dep.metadata.name == "canary" and
         $dep.metadata.namespace == "upgrade-113" and
         ($dep.metadata.uid | type) == "string" and
         ($dep.metadata.uid | length) > 0 and
         ($rss.kind == "List" or $rss.kind == "ReplicaSetList") and ($rss.items | type) == "array" and
         ($pods.kind == "List" or $pods.kind == "PodList") and ($pods.items | type) == "array"
      then
        ($rss.items | [ .[] |
          select(.metadata.namespace == "upgrade-113" and
                 (.metadata.uid | type) == "string" and
                 any(.metadata.ownerReferences[]?;
                     .kind == "Deployment" and .apiVersion == "apps/v1" and
                     .controller == true and .uid == $dep.metadata.uid)) |
          .metadata.uid ]) as $replica_set_uids
        | [ $pods.items[] |
            select(.metadata.namespace == "upgrade-113" and
                   .metadata.deletionTimestamp == null and
                   .status.phase == "Running" and
                   any(.metadata.ownerReferences[]?;
                       .kind == "ReplicaSet" and .apiVersion == "apps/v1" and
                       .controller == true and
                       (.uid as $owner_uid | $replica_set_uids | index($owner_uid) != null)) and
                   # ownerReferences are user-settable; require the exact
                   # bootstrap canary workload, not an arbitrary Ready Pod.
                   (.spec.containers | length) == 1 and
                   .spec.containers[0].name == "canary" and
                   .spec.containers[0].image == "registry.k8s.io/pause:3.9" and
                   .spec.automountServiceAccountToken == false and
                   any(.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[]?;
                       .topologyKey == "kubernetes.io/hostname" and
                       .labelSelector.matchLabels == {"app":"canary"}) and
                   any(.status.conditions[]?;
                       .type == "Ready" and .status == "True"))
          ] | length
      else "unknown" end
    ' 2>/dev/null) || ready_result=unknown
    [[ "$ready_result" =~ ^[0-9]+$ ]] && ready_pods=$ready_result
  fi
  api=$(kget version -o json | jq -r '.serverVersion.gitVersion // "unknown"' 2>/dev/null)
  [[ "$api" == v* ]] || api=unknown
  cp_kubelet=$(node_field 'node-role.kubernetes.io/control-plane' '{.status.nodeInfo.kubeletVersion}')
  worker_kubelet=$(node_field '!node-role.kubernetes.io/control-plane' '{.status.nodeInfo.kubeletVersion}')
  cp_ready=$(node_field 'node-role.kubernetes.io/control-plane' '{.status.conditions[?(@.type=="Ready")].status}')
  cp_unsched=$(node_field 'node-role.kubernetes.io/control-plane' '{.spec.unschedulable}')
  [[ "$cp_unsched" == true ]] || cp_unsched=false
  cp_kubeadm=$(ssh_version k8s113_controlPlane_1 'kubeadm version -o short')
  worker_kubeadm=$(ssh_version k8s113_node_worker1 'kubeadm version -o short')

  # Baseline and completion are accepted only with *observed* old worker versions.
  if [[ "$api" == v1.35.* && "$cp_kubeadm" == v1.35.* &&
        "$cp_kubelet" == v1.35.* && "$worker_kubeadm" == v1.35.* &&
        "$worker_kubelet" == v1.35.* ]]; then
    baseline_seen=1
  fi
  if [[ "$worker_kubeadm" == v1.36.* || "$worker_kubelet" == v1.36.* ]]; then
    worker_target_seen=1
    if ((cp_done_seen == 0)); then order_violation=1; fi
    if ((worker_target_at == 0)); then worker_target_at=$ts; fi
  fi
  if ((baseline_seen == 1 && order_violation == 0 && cp_done_seen == 0)) &&
     [[ "$api" == v1.36.* && "$cp_kubeadm" == v1.36.* &&
        "$cp_kubelet" == v1.36.* && "$cp_ready" == True && "$cp_unsched" == false &&
        "$worker_kubeadm" == v1.35.* && "$worker_kubelet" == v1.35.* ]]; then
    cp_done_seen=1
    cp_done_at=$ts
  fi

  cp_canary=$(canary_count k8s113_controlPlane_1)
  worker_canary=$(canary_count k8s113_node_worker1)
  canary_running=unknown
  if [[ "$cp_canary" =~ ^[0-9]+$ && "$worker_canary" =~ ^[0-9]+$ ]]; then
    canary_running=$((cp_canary + worker_canary))
  fi

  # Positive availability requires BOTH a Ready Pod and a Deployment with
  # availableReplicas > 0. A running CRI process or a single stale status
  # reading alone never proves Availability. During API restarts, treat these
  # incomplete observations as ambiguous for at most 240 s across restarts.
  canary_status=unknown
  # An authoritative zero from the Deployment (a successful, validated GET with
  # availableReplicas absent/0) is downtime even if some Pod looks Ready: Ready Pods can be
  # forged (user-settable ownerReferences), the Deployment status cannot. A zero Ready-Pod
  # count alone is NOT treated as downtime: while kube-apiserver restarts it can return an
  # empty Pod list although the Deployment still reports availability (observed on a real
  # upgrade); that case stays ambiguous and is bounded by the 240 s window below.
  if [[ "$available" == 0 || "$canary_running" == 0 ]]; then
    canary_status=down
    canary_outage_seen=1
    ambiguous_since=0
  elif [[ "$ready_pods" =~ ^[1-9][0-9]*$ &&
          "$available" =~ ^[1-9][0-9]*$ ]]; then
    canary_status=up
    ambiguous_since=0
    healthy_samples=$((healthy_samples + 1))
  elif [[ "$ready_pods" =~ ^[1-9][0-9]*$ ||
          "$canary_running" =~ ^[1-9][0-9]*$ ||
          "$available" =~ ^[1-9][0-9]*$ ]]; then
    canary_status=ambiguous
    if ((ambiguous_since == 0)); then ambiguous_since=$ts; fi
    if ((ts - ambiguous_since > 240)); then canary_unknown_seen=1; fi
  else
    # No authoritative Pod Ready or independent running/available observation:
    # a missing API+CRI snapshot is NOT an available canary.
    canary_unknown_seen=1
  fi

  tmp=$(mktemp "$DIR/order-state.XXXXXXXX") || exit 1
  printf 'baseline_seen=%s\ncp_done_seen=%s\norder_violation=%s\nworker_target_seen=%s\ncanary_outage_seen=%s\ncanary_unknown_seen=%s\nhistory_gap_seen=%s\nhealthy_samples=%s\nlast_ts=%s\ncp_done_at=%s\nworker_target_at=%s\nambiguous_since=%s\n' \
    "$baseline_seen" "$cp_done_seen" "$order_violation" "$worker_target_seen" \
    "$canary_outage_seen" "$canary_unknown_seen" "$history_gap_seen" \
    "$healthy_samples" "$last_ts" "$cp_done_at" "$worker_target_at" "$ambiguous_since" >"$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$STATE"
  printf '%s available=%s ready_pods=%s cp_canary=%s worker_canary=%s canary_running=%s canary_status=%s api=%s cp_kubeadm=%s cp_kubelet=%s cp_ready=%s cp_unsched=%s worker_kubeadm=%s worker_kubelet=%s\n' \
    "$ts" "$available" "$ready_pods" "$cp_canary" "$worker_canary" "$canary_running" \
    "$canary_status" "$api" "$cp_kubeadm" "$cp_kubelet" "$cp_ready" "$cp_unsched" \
    "$worker_kubeadm" "$worker_kubelet" >>"$LOG"
  sleep 2
done
EOF

chmod 0755 /usr/local/bin/cks113-monitor
touch "$CHECKER/upgrade-monitor.log"
chmod 0644 "$CHECKER/upgrade-monitor.log"

cat >/etc/systemd/system/cks113-monitor.service <<'EOF'
[Unit]
Description=CKS Lab 113 checker-owned upgrade monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cks113-monitor
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cks113-monitor

for _ in {1..30}; do
  grep -q 'available=2 ' "$CHECKER/upgrade-monitor.log" && break
  sleep 2
done

grep -q 'available=2 ' "$CHECKER/upgrade-monitor.log" || {
  echo "checker-owned monitor did not observe a healthy baseline (available=2)" >&2
  exit 1
}

echo "*** both cluster nodes are reachable, lab 113 is ready"
