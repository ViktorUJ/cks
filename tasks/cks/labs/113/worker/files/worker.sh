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

export KUBECONFIG=/root/.kube/config
LOG=/var/lib/cks-lab113-checker/upgrade-monitor.log
STATE=/var/lib/cks-lab113-checker/order-state

cp_done_seen=0
order_violation=0

while true; do
  ts=$(date +%s)

  available=$(
    kubectl get deployment canary -n upgrade-113 \
      -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true
  )
  available=${available:-unknown}

  cp_canary=$(
    ssh -o BatchMode=yes -o ConnectTimeout=3 \
      k8s113_controlPlane_1 \
      "sudo crictl ps --name '^canary$' -q 2>/dev/null | wc -l" \
      2>/dev/null || echo 0
  )
  worker_canary=$(
    ssh -o BatchMode=yes -o ConnectTimeout=3 \
      k8s113_node_worker1 \
      "sudo crictl ps --name '^canary$' -q 2>/dev/null | wc -l" \
      2>/dev/null || echo 0
  )

  [[ "$cp_canary" =~ ^[0-9]+$ ]] || cp_canary=0
  [[ "$worker_canary" =~ ^[0-9]+$ ]] || worker_canary=0

  canary_running=$((cp_canary + worker_canary))

  api=$(
    kubectl version -o json 2>/dev/null |
      jq -r '.serverVersion.gitVersion // "unknown"' 2>/dev/null
  )

  # Node objects are named after the instance hostnames (ip-10-...), not after the ssh aliases.
  cp_node=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  worker_node=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  cp_kubelet=$(
    kubectl get node "$cp_node" \
      -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true
  )
  worker_kubelet=$(
    kubectl get node "$worker_node" \
      -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null || true
  )

  cp_ready=$(
    kubectl get node "$cp_node" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true
  )
  worker_ready=$(
    kubectl get node "$worker_node" \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true
  )

  cp_unsched=$(
    kubectl get node "$cp_node" \
      -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true
  )
  worker_unsched=$(
    kubectl get node "$worker_node" \
      -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true
  )

  [[ "$cp_unsched" == "true" ]] || cp_unsched=false
  [[ "$worker_unsched" == "true" ]] || worker_unsched=false

  cp_kubeadm=$(
    ssh -o BatchMode=yes -o ConnectTimeout=3 \
      k8s113_controlPlane_1 'kubeadm version -o short' 2>/dev/null || echo unknown
  )
  worker_kubeadm=$(
    ssh -o BatchMode=yes -o ConnectTimeout=3 \
      k8s113_node_worker1 'kubeadm version -o short' 2>/dev/null || echo unknown
  )

  if [[ "$api" == v1.36.* && "$cp_kubeadm" == v1.36.* && "$cp_kubelet" == v1.36.* \
        && "$cp_ready" == "True" && "$cp_unsched" == "false" ]]; then
    cp_done_seen=1
  fi

  if [[ ( "$worker_kubeadm" == v1.36.* || "$worker_kubelet" == v1.36.* ) \
        && "$cp_done_seen" -ne 1 ]]; then
    order_violation=1
  fi

  printf 'cp_done_seen=%s\norder_violation=%s\n' \
    "$cp_done_seen" "$order_violation" \
    >"$STATE.tmp"
  mv "$STATE.tmp" "$STATE"
  chmod 0644 "$STATE"

  printf '%s available=%s canary_running=%s api=%s cp_kubeadm=%s cp_kubelet=%s cp_ready=%s cp_unsched=%s worker_kubeadm=%s worker_kubelet=%s worker_ready=%s worker_unsched=%s\n' \
    "$ts" "$available" "$canary_running" "$api" \
    "$cp_kubeadm" "$cp_kubelet" "$cp_ready" "$cp_unsched" \
    "$worker_kubeadm" "$worker_kubelet" "$worker_ready" "$worker_unsched" \
    >>"$LOG"

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
