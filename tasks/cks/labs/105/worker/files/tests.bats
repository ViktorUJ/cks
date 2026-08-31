#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
ARTIFACTS="/var/work/tests/artifacts"
SSH_OPTS=(-oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=8)

control_plane() {
  # Prefer the name cached before the firewall exercise so a broken student rule does not
  # make the recovery-oriented diagnostics depend on Kubernetes API availability.
  local name
  name=$(cat /var/work/tests/cp-name 2>/dev/null)
  if [[ -z "$name" ]]; then
    name=$(kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  printf '%s' "$name"
}

@test "0 Init" {
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
  : > /var/work/tests/result/requests
}

@test "1. Unused service is disabled and inactive on the control plane" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" 'enabled=$(sudo systemctl is-enabled cks-lab105-unused.service 2>/dev/null || true); active=$(sudo systemctl is-active cks-lab105-unused.service 2>/dev/null || true); printf "%s %s\n" "$enabled" "$active"'
  state="$output"
  if [[ "$status" -eq 0 && "$state" == "disabled inactive" ]] && grep -qx 'disabled inactive' "$ARTIFACTS/1/service.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "service state='$state'; expected artifact $ARTIFACTS/1/service.txt: disabled inactive"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. TCP/8080 is closed on the control plane" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ss -ltn | grep -qE "[:.]8080([[:space:]]|$)"'
  listener_status=$status
  if [[ "$listener_status" -ne 0 ]] && grep -qx 'tcp/8080: closed' "$ARTIFACTS/2/port-8080.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "tcp/8080 listener status=$listener_status; expected closed-port artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. UFW keeps source-scoped Kubernetes flows healthy and blocks worker-to-kubelet" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  worker_ip=$(ssh "${SSH_OPTS[@]}" "$cp" 'printf "%s" "${SSH_CONNECTION%% *}"' 2>/dev/null || true)
  node_ip=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  pod_cidr=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.spec.podCIDR}' 2>/dev/null || true)
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw status verbose; sudo ufw status'
  firewall="$output"
  firewall_status=$status
  ready=$(kubectl get --raw=/readyz --context "$CTX" 2>/dev/null || true)
  node_ready=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  workload_ready=$(kubectl get deployment health-probe -n cks-105-health --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
  pod_http=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz' 2>/dev/null || true)
  set +e
  kubelet_http=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "https://${node_ip}:10250/healthz" 2>/dev/null)
  kubelet_status=$?
  set -e

  broad_rule=$(grep -E '^(22|6443)/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+Anywhere([[:space:]]|$)' <<<"$firewall" || true)
  if [[ "$firewall_status" -eq 0 ]] \
    && grep -q 'Status: active' <<<"$firewall" \
    && grep -q 'Default: deny (incoming)' <<<"$firewall" \
    && grep -Eq "^22/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${worker_ip//./\\.}([[:space:]]|$)" <<<"$firewall" \
    && grep -Eq "^6443/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${worker_ip//./\\.}([[:space:]]|$)" <<<"$firewall" \
    && grep -Fq "$pod_cidr" <<<"$firewall" \
    && [[ -z "$broad_rule" && "$ready" == "ok" && "$node_ready" == "True" ]] \
    && [[ "${workload_ready:-0}" -ge 1 && -n "$pod_http" && "$pod_http" != "000" ]] \
    && [[ "$kubelet_status" -ne 0 && ( -z "$kubelet_http" || "$kubelet_http" == "000" ) ]] \
    && grep -q 'Status: active' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'Default: deny (incoming)' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'role=control-plane,workload' "$ARTIFACTS/3/preflight.txt" \
    && grep -q 'sudo ufw disable' "$ARTIFACTS/3/recovery.txt" \
    && grep -q 'sudo ufw --force enable' "$ARTIFACTS/3/recovery.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "firewall_status=$firewall_status worker_ip=$worker_ip node_ip=$node_ip pod_cidr=$pod_cidr readyz=$ready node_ready=$node_ready workload_ready=$workload_ready pod_http=$pod_http kubelet_status=$kubelet_status kubelet_http=$kubelet_http broad_rule=${broad_rule:-none}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. Kubernetes admin kubeconfig is root:root with mode 600" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo stat -c '%U %G %a' /etc/kubernetes/admin.conf"
  if [[ "$status" -eq 0 && "$output" == 'root root 600' ]] && grep -qx 'root root 600' "$ARTIFACTS/4/admin-conf.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "admin.conf='$output'; expected root root 600 and matching artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. sshd forbids direct root login" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo sshd -T | awk '\$1 == \"permitrootlogin\" {print \$2}'"
  if [[ "$status" -eq 0 && "$output" == 'no' ]] && grep -qx 'PermitRootLogin no' "$ARTIFACTS/5/sshd.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "effective PermitRootLogin='$output'; expected no and matching artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. Docker host has no TCP API and no unprivileged Docker access" {
  echo '1' >> /var/work/tests/result/all
  run ssh "${SSH_OPTS[@]}" docker-host 'set -e; ! sudo ss -ltn | grep -qE "[:.]2375([[:space:]]|$)"; test "$(sudo stat -c "%U %G %a" /var/run/docker.sock)" = "root root 660"; ! id -nG developer | tr " " "\n" | grep -qx docker; ! sudo -u developer docker ps >/dev/null 2>&1'
  if [[ "$status" -eq 0 ]] \
    && grep -qx 'tcp/2375: closed' "$ARTIFACTS/6/docker-tcp.txt" \
    && grep -qx 'root root 660' "$ARTIFACTS/6/docker-socket.txt" \
    && grep -qx 'developer docker ps: denied' "$ARTIFACTS/6/developer-access.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Docker host must close 2375, set socket root:root 660, and remove developer from docker"
    result=1
  fi
  [ "$result" -eq 0 ]
}
