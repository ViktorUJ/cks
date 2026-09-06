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
    if [[ "$state" != "disabled inactive" ]]; then
      echo "HINT: Service 'cks-lab105-unused.service' must be BOTH disabled (systemctl disable) AND stopped/inactive (systemctl stop) - one without the other still leaves the attack surface open on the next reboot or right now."
    else
      echo "HINT: artifacts/1/service.txt does not contain the exact line 'disabled inactive'. Save the output of your two 'systemctl is-enabled'/'is-active' checks joined with a single space, exactly matching the state you observed."
    fi
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
    if [[ "$listener_status" -eq 0 ]]; then
      echo "HINT: Something is still listening on TCP/8080. Find the owning process/service and stop it - closing the port at the firewall alone is not what this task checks, the listener itself must be gone."
    else
      echo "HINT: artifacts/2/port-8080.txt does not contain the exact line 'tcp/8080: closed'. Save your verification command's outcome in this exact text."
    fi
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
    if [[ "$firewall_status" -ne 0 ]] || ! grep -q 'Status: active' <<<"$firewall"; then
      echo "HINT: UFW is not active. Enable it with 'sudo ufw --force enable' AFTER adding the required allow rules - never enable a default-deny firewall before you have an SSH rule in place, you can lock yourself out."
    elif [[ -n "$broad_rule" ]]; then
      echo "HINT: Found a broad 'Anywhere' allow rule for port 22 or 6443 - these should be scoped to the specific worker IP ($worker_ip), not open to any source."
    elif ! grep -Eq "^22/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${worker_ip//./\\.}([[:space:]]|$)" <<<"$firewall"; then
      echo "HINT: No UFW rule allows TCP/22 from the worker IP ($worker_ip) specifically. Add it BEFORE enabling default-deny, otherwise you lose SSH access."
    elif ! grep -Eq "^6443/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${worker_ip//./\\.}([[:space:]]|$)" <<<"$firewall"; then
      echo "HINT: No UFW rule allows TCP/6443 (API server) from the worker IP. Without it, kubectl from the worker station will stop working once UFW is enabled."
    elif ! grep -Fq "$pod_cidr" <<<"$firewall"; then
      echo "HINT: No rule references the Pod CIDR ($pod_cidr) - CNI traffic between nodes needs this, or Pod networking will break under default-deny."
    elif [[ "$ready" != "ok" || "$node_ready" != "True" ]]; then
      echo "HINT: The cluster is not healthy after your firewall change (readyz=$ready node_ready=$node_ready). Something you allowed/blocked is breaking control-plane or node communication - check kubelet-to-apiserver and CNI ports too."
    elif [[ "${workload_ready:-0}" -lt 1 || -z "$pod_http" || "$pod_http" == "000" ]]; then
      echo "HINT: The health-probe workload cannot reach the API server from inside a Pod (pod_http=$pod_http). This proves in-cluster traffic, distinct from your own SSH session - check your rules do not accidentally block Pod-originated traffic."
    elif [[ "$kubelet_status" -eq 0 && "$kubelet_http" != "000" ]]; then
      echo "HINT: Port 10250 (kubelet API) is reachable directly from the worker station - this task expects it to stay blocked from outside sources that are not the control plane itself."
    else
      echo "HINT: Firewall behavior is correct, but one of the evidence files (ufw.txt/preflight.txt/recovery.txt) is missing the required exact content - check each file's expected line individually."
    fi
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
    echo "HINT: /etc/kubernetes/admin.conf must be owner root, group root, mode 600. Use 'chown root:root' and 'chmod 600'. It currently reports '$output'."
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
    echo "HINT: sshd's EFFECTIVE PermitRootLogin (via 'sshd -T', not just the config file text) must be 'no'. A setting later in the file, an Include directive, or a Match block can override an earlier 'PermitRootLogin no' line - check the effective value, not just what you wrote."
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
    echo "HINT: All four sub-checks must pass together: no TCP listener on 2375, docker.sock owned root:root mode 660, user 'developer' NOT in the 'docker' group, and 'sudo -u developer docker ps' must fail. Check each condition separately with the same commands used here."
    echo "Docker host must close 2375, set socket root:root 660, and remove developer from docker"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. sctp kernel module is unloaded and blacklisted with an install override" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo lsmod | grep -c sctp || true; sudo modprobe --show-config 2>/dev/null | grep -c 'install sctp /bin/true' || true; sudo cat /etc/modprobe.d/60-cks-sctp.conf 2>/dev/null"
  output_combined="$output"
  lsmod_count=$(printf '%s\n' "$output_combined" | sed -n '1p')
  install_count=$(printf '%s\n' "$output_combined" | sed -n '2p')
  if [[ "$status" -eq 0 && "$lsmod_count" == "0" && "$install_count" -ge 1 ]] \
    && grep -Fq 'blacklist sctp' <<<"$output_combined" \
    && grep -Fq 'install sctp /bin/true' <<<"$output_combined" \
    && grep -qx 'lsmod: absent' "$ARTIFACTS/7/sctp.txt" \
    && grep -Fq 'install sctp /bin/true' "$ARTIFACTS/7/sctp.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$lsmod_count" != "0" ]]; then
      echo "HINT: sctp module is still loaded (lsmod shows it). Run 'sudo modprobe -r sctp' to unload it right now, in addition to the persistent blacklist config."
    elif [[ "$install_count" -lt 1 ]]; then
      echo "HINT: No 'install sctp /bin/true' override found. A plain 'blacklist sctp' line only stops auto-loading via alias resolution - a direct 'modprobe sctp' can still succeed unless you also override the install command."
    else
      echo "HINT: Both the blacklist and install override look correct on the node, but the evidence file /var/work/tests/artifacts/7/sctp.txt is missing the expected exact lines 'lsmod: absent' and 'install sctp /bin/true'."
    fi
    echo "lsmod_count=$lsmod_count install_count=$install_count output=$output_combined"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. sysctl hardening is applied and kubelet runs with protectKernelDefaults" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sysctl -n kernel.unprivileged_bpf_disabled; sysctl -n vm.overcommit_memory; sudo cat /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; sudo grep -c 'protectKernelDefaults: true' /var/lib/kubelet/config.yaml 2>/dev/null || true; sudo systemctl is-active kubelet"
  bpf_value=$(printf '%s\n' "$output" | sed -n '1p')
  overcommit_value=$(printf '%s\n' "$output" | sed -n '2p')
  kubelet_active=$(printf '%s\n' "$output" | tail -n1)
  node_ready=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  if [[ "$status" -eq 0 && "$bpf_value" == "1" && "$overcommit_value" == "1" && "$kubelet_active" == "active" && "$node_ready" == "True" ]] \
    && grep -Fq 'kernel.unprivileged_bpf_disabled' <<<"$output" \
    && grep -Fq 'vm.overcommit_memory' <<<"$output" \
    && grep -Fq 'protectKernelDefaults: true' <<<"$output"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$bpf_value" != "1" || "$overcommit_value" != "1" ]]; then
      echo "HINT: sysctl values are wrong at runtime. Both kernel.unprivileged_bpf_disabled and vm.overcommit_memory must equal 1 - set them in /etc/sysctl.d/99-kubernetes.conf and apply with 'sysctl --system' or a reboot, do not just run 'sysctl -w' once."
    elif ! grep -Fq 'protectKernelDefaults: true' <<<"$output"; then
      echo "HINT: kubelet config.yaml is missing 'protectKernelDefaults: true'. This flag makes kubelet REFUSE to start if the required sysctls do not match its expectations - it must be set for the check to matter."
    elif [[ "$kubelet_active" != "active" || "$node_ready" != "True" ]]; then
      echo "HINT: kubelet is not active or the node is NotReady after your sysctl change (kubelet=$kubelet_active node_ready=$node_ready). If protectKernelDefaults is true but the sysctls do not match kubelet's expected defaults, kubelet will refuse to start - set the sysctls BEFORE enabling this flag."
    fi
    echo "bpf=$bpf_value overcommit=$overcommit_value kubelet_active=$kubelet_active node_ready=$node_ready"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. Extra SUID lab binary is remediated without touching system SUID binaries" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo stat -c '%a' /usr/local/bin/cks-lab105-suid-tool; sudo stat -c '%a' /usr/bin/sudo 2>/dev/null || sudo stat -c '%a' /bin/sudo 2>/dev/null"
  mode_output="$output"
  tool_mode=$(printf '%s\n' "$mode_output" | sed -n '1p')
  sudo_mode=$(printf '%s\n' "$mode_output" | sed -n '2p')
  if [[ "$status" -eq 0 && "$tool_mode" == "755" && "$sudo_mode" == 4[0-9][0-9][0-9] ]] \
    && grep -Fq 'cks-lab105-suid-tool' "$ARTIFACTS/9/suid-before.txt" \
    && grep -qx '755' "$ARTIFACTS/9/suid-after.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$tool_mode" != "755" ]]; then
      echo "HINT: /usr/local/bin/cks-lab105-suid-tool must end up at mode 755 (SUID bit removed: 'chmod 755' or 'chmod u-s'). Current mode is '$tool_mode'."
    elif [[ "$sudo_mode" != 4[0-9][0-9][0-9] ]]; then
      echo "HINT: /usr/bin/sudo (or /bin/sudo) lost its SUID bit ($sudo_mode) - this task requires you to fix ONLY the lab-planted binary, not legitimate system SUID binaries like sudo. Restore its mode to 4xxx."
    else
      echo "HINT: The fix on the node looks correct, but evidence files are missing the expected content - suid-before.txt must mention the tool name, suid-after.txt must contain exactly '755'."
    fi
    echo "tool_mode=$tool_mode sudo_mode=$sudo_mode"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "10. Core dumps are disabled and fs.suid_dumpable is 0" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sysctl -n fs.suid_dumpable; sudo cat /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; sudo cat /etc/security/limits.conf 2>/dev/null; su - ubuntu -c 'ulimit -c'"
  combined="$output"
  dumpable_value=$(printf '%s\n' "$combined" | sed -n '1p')
  ulimit_value=$(printf '%s\n' "$combined" | tail -n1)
  if [[ "$status" -eq 0 && "$dumpable_value" == "0" && "$ulimit_value" == "0" ]] \
    && grep -Fq 'fs.suid_dumpable = 0' <<<"$combined" \
    && grep -Fq '* hard core 0' <<<"$combined" \
    && grep -Fq '* soft core 0' <<<"$combined" \
    && grep -qx '0' "$ARTIFACTS/10/coredump.txt" \
    && grep -Fq 'fs.suid_dumpable = 0' "$ARTIFACTS/10/coredump.txt" \
    && grep -Fq 'hard core 0' "$ARTIFACTS/10/coredump.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$dumpable_value" != "0" ]]; then
      echo "HINT: fs.suid_dumpable must be 0 at runtime. Set it in /etc/sysctl.d/99-kubernetes.conf and reload with 'sysctl --system' - a config file entry alone does not change the live kernel value until applied."
    elif [[ "$ulimit_value" != "0" ]]; then
      echo "HINT: 'ulimit -c' for a normal user must be 0. Add BOTH '* hard core 0' and '* soft core 0' to /etc/security/limits.conf - only the soft limit is not enough, a process can raise it back up to the hard limit."
    else
      echo "HINT: Runtime values look correct, but the evidence file coredump.txt is missing one of the required exact lines: '0', 'fs.suid_dumpable = 0', or 'hard core 0'."
    fi
    echo "dumpable_value=$dumpable_value ulimit_value=$ulimit_value combined=$combined"
    result=1
  fi
  [ "$result" -eq 0 ]
}
