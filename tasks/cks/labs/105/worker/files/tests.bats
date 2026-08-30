#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
ARTIFACTS="/var/work/tests/artifacts"
SSH_OPTS=(-oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=8)

control_plane() {
  kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
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

@test "3. UFW permits SSH only and denies other incoming traffic" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw status verbose; sudo ufw status'
  firewall="$output"
  if [[ "$status" -eq 0 ]] \
    && grep -q 'Status: active' <<<"$firewall" \
    && grep -q 'Default: deny (incoming)' <<<"$firewall" \
    && grep -Eq '^22/tcp[[:space:]]+ALLOW' <<<"$firewall" \
    && grep -q 'Status: active' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'Default: deny (incoming)' "$ARTIFACTS/3/ufw.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "UFW is not active with default incoming deny and an allow rule for 22/tcp"
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
