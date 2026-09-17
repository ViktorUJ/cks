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
  run ssh "${SSH_OPTS[@]}" "$cp" 'enabled=$(sudo systemctl is-enabled cks-lab105-port.service 2>/dev/null || true); active=$(sudo systemctl is-active cks-lab105-port.service 2>/dev/null || true); printf "%s %s\n" "$enabled" "$active"; sudo ss -ltn | grep -qE "[:.]8080([[:space:]]|$)" && echo LISTENING || echo CLOSED'
  service_output="$output"
  service_state=$(printf '%s\n' "$service_output" | sed -n '1p')
  listener_line=$(printf '%s\n' "$service_output" | sed -n '2p')
  if [[ "$status" -eq 0 && "$service_state" == "disabled inactive" && "$listener_line" == "CLOSED" ]] \
    && grep -qx 'disabled inactive' "$ARTIFACTS/2/service.txt" \
    && grep -qx 'tcp/8080: closed' "$ARTIFACTS/2/port-8080.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$listener_line" != "CLOSED" ]]; then
      echo "HINT: Something is still listening on TCP/8080. Find the owning process/service and stop it - closing the port at the firewall alone is not what this task checks, the listener itself must be gone."
    elif [[ "$service_state" != "disabled inactive" ]]; then
      echo "HINT: cks-lab105-port.service must be BOTH disabled AND inactive - stopping it without disabling means the listener reappears after the next reboot, even though the port looks closed right now. Use 'systemctl disable --now cks-lab105-port.service'."
    else
      echo "HINT: artifacts/2/service.txt must contain the exact line 'disabled inactive' and artifacts/2/port-8080.txt must contain 'tcp/8080: closed'. Save both pieces of evidence."
    fi
    echo "service_state='$service_state' listener='$listener_line'; expected artifacts: disabled inactive / tcp/8080: closed"
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
  calico_ready=$(kubectl get pods -n kube-system -l k8s-app=calico-node --context "$CTX" \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  workload_ready=$(kubectl get deployment health-probe -n cks-105-health --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
  pod_http=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz' 2>/dev/null || true)
  set +e
  kubelet_http=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "https://${node_ip}:10250/healthz" 2>/dev/null)
  kubelet_status=$?
  set -e

  # Exact structural allow-set check: normalize 'ufw status' into individual rule lines
  # instead of grepping for arbitrary substrings anywhere in the output. A rule only
  # counts if the exact port/proto matches AND the exact source matches.
  esc_worker="${worker_ip//./\\.}"
  esc_node="${node_ip//./\\.}"
  esc_pod_cidr=$(printf '%s' "$pod_cidr" | sed 's/[.[\*^$/]/\\&/g')

  rule_ssh_worker=$(grep -Eq "^22/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${esc_worker}([[:space:]]|$)" <<<"$firewall" && echo yes || echo no)
  rule_api_worker=$(grep -Eq "^6443/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${esc_worker}([[:space:]]|$)" <<<"$firewall" && echo yes || echo no)
  rule_api_node=$(grep -Eq "^6443/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${esc_node}([[:space:]]|$)" <<<"$firewall" && echo yes || echo no)
  rule_api_podcidr=$(grep -Eq "^6443/tcp[[:space:]]+ALLOW( IN)?[[:space:]]+${esc_pod_cidr}([[:space:]]|$)" <<<"$firewall" && echo yes || echo no)

  # Any 'ALLOW ... Anywhere' rule for ANY port (not just 22/6443) widens the allow-set
  # beyond the documented allowlist and must not exist.
  broad_rule=$(grep -E '^[0-9]+(:[0-9]+)?/(tcp|udp)[[:space:]]+ALLOW( IN)?[[:space:]]+Anywhere([[:space:]]|$)' <<<"$firewall" || true)

  calico_all_ready=yes
  [[ -z "$calico_ready" ]] && calico_all_ready=no
  for cond in $calico_ready; do
    [[ "$cond" != "True" ]] && calico_all_ready=no
  done

  baseline_present=$(grep -Eq 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=[1-5][0-9][0-9]' "$ARTIFACTS/3/preflight.txt" 2>/dev/null && echo yes || echo no)

  if [[ "$firewall_status" -eq 0 ]] \
    && grep -q 'Status: active' <<<"$firewall" \
    && grep -q 'Default: deny (incoming)' <<<"$firewall" \
    && [[ "$rule_ssh_worker" == "yes" && "$rule_api_worker" == "yes" && "$rule_api_node" == "yes" && "$rule_api_podcidr" == "yes" ]] \
    && [[ -z "$broad_rule" && "$ready" == "ok" && "$node_ready" == "True" && "$calico_all_ready" == "yes" ]] \
    && [[ "${workload_ready:-0}" -ge 1 && -n "$pod_http" && "$pod_http" != "000" ]] \
    && [[ "$kubelet_status" -ne 0 && ( -z "$kubelet_http" || "$kubelet_http" == "000" ) ]] \
    && [[ "$baseline_present" == "yes" ]] \
    && grep -q 'Status: active' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'Default: deny (incoming)' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'role=control-plane,workload' "$ARTIFACTS/3/preflight.txt" \
    && grep -q 'sudo ufw disable' "$ARTIFACTS/3/recovery.txt" \
    && grep -q 'sudo ufw --force enable' "$ARTIFACTS/3/recovery.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$baseline_present" != "yes" ]]; then
      echo "HINT: artifacts/3/preflight.txt must contain a baseline probe of TCP/10250 recorded BEFORE UFW was enabled, in the exact form 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=<1xx-5xx>'. Without this, a post-UFW block cannot be attributed to UFW - the port might have already been unreachable for an unrelated reason."
    elif [[ "$firewall_status" -ne 0 ]] || ! grep -q 'Status: active' <<<"$firewall"; then
      echo "HINT: UFW is not active. Enable it with 'sudo ufw --force enable' AFTER adding the required allow rules - never enable a default-deny firewall before you have an SSH rule in place, you can lock yourself out."
    elif [[ -n "$broad_rule" ]]; then
      echo "HINT: Found a broad 'ALLOW ... Anywhere' rule for some port - the allowlist must be scoped exactly to worker_ip/node_ip/pod_cidr, with no other port left open to any source."
    elif [[ "$rule_ssh_worker" != "yes" ]]; then
      echo "HINT: No UFW rule allows TCP/22 from the worker IP ($worker_ip) specifically. Add it BEFORE enabling default-deny, otherwise you lose SSH access."
    elif [[ "$rule_api_worker" != "yes" ]]; then
      echo "HINT: No UFW rule allows TCP/6443 (API server) from the worker IP. Without it, kubectl from the worker station will stop working once UFW is enabled."
    elif [[ "$rule_api_node" != "yes" ]]; then
      echo "HINT: No UFW rule allows TCP/6443 from the node's own InternalIP ($node_ip) - the control-plane node talks to its own apiserver over this address too, and this task requires an explicit rule for it, not just an implicit loopback allowance."
    elif [[ "$rule_api_podcidr" != "yes" ]]; then
      echo "HINT: No UFW rule allows TCP/6443 specifically from the Pod CIDR ($pod_cidr). The Pod CIDR must be scoped to port 6443 exactly - if it appears in the ufw output for a different port, or as a bare substring somewhere unrelated to 6443/tcp, that does not count."
    elif [[ "$calico_all_ready" != "yes" ]]; then
      echo "HINT: calico-node Pod(s) are not Ready after the UFW change (conditions='$calico_ready'). UFW is an iptables/nftables manager and can conflict with the rules Calico installs - see the lab-specific exception note in README and ADVERSARIAL_ACCEPTANCE_STANDARD.md."
    elif [[ "$ready" != "ok" || "$node_ready" != "True" ]]; then
      echo "HINT: The cluster is not healthy after your firewall change (readyz=$ready node_ready=$node_ready). Something you allowed/blocked is breaking control-plane or node communication - check kubelet-to-apiserver and CNI ports too."
    elif [[ "${workload_ready:-0}" -lt 1 || -z "$pod_http" || "$pod_http" == "000" ]]; then
      echo "HINT: The health-probe workload cannot reach the API server from inside a Pod (pod_http=$pod_http). This proves in-cluster traffic, distinct from your own SSH session - check your rules do not accidentally block Pod-originated traffic."
    elif [[ "$kubelet_status" -eq 0 && "$kubelet_http" != "000" ]]; then
      echo "HINT: Port 10250 (kubelet API) is reachable directly from the worker station - this task expects it to stay blocked from outside sources that are not the control plane itself."
    else
      echo "HINT: Firewall behavior is correct, but one of the evidence files (ufw.txt/preflight.txt/recovery.txt) is missing the required exact content - check each file's expected line individually."
    fi
    echo "firewall_status=$firewall_status worker_ip=$worker_ip node_ip=$node_ip pod_cidr=$pod_cidr readyz=$ready node_ready=$node_ready calico_ready='$calico_ready' workload_ready=$workload_ready pod_http=$pod_http kubelet_status=$kubelet_status kubelet_http=$kubelet_http broad_rule=${broad_rule:-none} rule_ssh_worker=$rule_ssh_worker rule_api_worker=$rule_api_worker rule_api_node=$rule_api_node rule_api_podcidr=$rule_api_podcidr baseline_present=$baseline_present"
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
  worker_ip=$(ssh "${SSH_OPTS[@]}" "$cp" 'printf "%s" "${SSH_CONNECTION%% *}"' 2>/dev/null || true)
  node_ip=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  # sshd -T WITHOUT connection context (-C) never applies Match blocks at all - per
  # sshd(8): "Optionally, Match rules may be applied by specifying the connection
  # parameters using one or more -C options." A Match block scoped to root/this address
  # could grant root login while a plain 'sshd -T' still shows the top-level 'no'.
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo sshd -T -C 'user=root,addr=${worker_ip},laddr=${node_ip},lport=22' | awk '\$1 == \"permitrootlogin\" {print \$2}'"
  if [[ "$status" -eq 0 && "$output" == 'no' ]] && grep -qx 'PermitRootLogin no' "$ARTIFACTS/5/sshd.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: sshd's EFFECTIVE PermitRootLogin for an actual root connection (checked via 'sshd -T -C user=root,addr=...', not a plain 'sshd -T' with no connection context) must be 'no'. A Match block scoped to a specific user/address can override the top-level setting for that context - 'sshd -T' alone never applies Match rules, per sshd(8): Match directives in test mode require -C connection parameters."
    echo "effective PermitRootLogin (with -C root context)='$output'; expected no and matching artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. Docker host has no TCP API and no unprivileged Docker access" {
  echo '1' >> /var/work/tests/result/all
  # Force a real daemon-reload + restart of BOTH units before checking anything - this
  # proves the fix survives a restart, not just that the currently-running process
  # happens to match. A student who only stopped Docker (instead of fixing the config)
  # would fail here because Docker must come back up and actually work afterward.
  run ssh "${SSH_OPTS[@]}" docker-host 'sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service'
  reload_status=$status
  run ssh "${SSH_OPTS[@]}" docker-host '
    set -e
    # Positive control: Docker must be genuinely UP and functional after restart, not
    # just "not listening on 2375 because the whole daemon is down".
    test "$(sudo systemctl is-active docker.service)" = "active"
    test "$(sudo systemctl is-active docker.socket)" = "active"
    sudo docker version >/dev/null
    sudo docker info >/dev/null
    # Persistent config: the effective unit must not still reference a TCP listener,
    # and the socket override must set group/mode explicitly (not rely on incidental state).
    ! systemctl cat docker.service 2>/dev/null | grep -q "H tcp://"
    systemctl cat docker.socket 2>/dev/null | grep -q "SocketGroup=root"
    systemctl cat docker.socket 2>/dev/null | grep -qE "SocketMode=0?660"
    ! sudo ss -ltn | grep -qE "[:.]2375([[:space:]]|$)"
    test "$(sudo stat -c "%U %G %a" /var/run/docker.sock)" = "root root 660"
    ! id -nG developer | tr " " "\n" | grep -qx docker
    ! sudo -u developer docker ps >/dev/null 2>&1
  '
  if [[ "$reload_status" -eq 0 && "$status" -eq 0 ]] \
    && grep -qx 'tcp/2375: closed' "$ARTIFACTS/6/docker-tcp.txt" \
    && grep -qx 'root root 660' "$ARTIFACTS/6/docker-socket.txt" \
    && grep -qx 'developer docker ps: denied' "$ARTIFACTS/6/developer-access.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$reload_status" -ne 0 ]]; then
      echo "HINT: 'systemctl daemon-reload' followed by restarting BOTH docker.socket and docker.service must succeed. If this fails, your systemd unit override likely has a syntax error."
    else
      echo "HINT: After a forced daemon-reload + restart of docker.socket and docker.service, ALL of the following must hold: docker.service/docker.socket are 'active' AND 'docker version'/'docker info' succeed (Docker must actually work, not just be stopped); the persistent unit (via 'systemctl cat') has no '-H tcp://' and the socket override sets SocketGroup=root/SocketMode=0660; no TCP listener on 2375; docker.sock is root:root mode 660; 'developer' is NOT in the docker group and 'sudo -u developer docker ps' fails. Check each condition separately with the same commands used here."
    fi
    echo "Docker host must survive a real restart with TCP/2375 closed, socket root:root 660, developer removed from docker group, and the daemon itself still functional"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. sctp kernel module is unloaded and blacklisted with an install override" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo lsmod | grep -c sctp || true; sudo modprobe --show-config 2>/dev/null | grep -c 'install sctp /bin/true' || true; sudo modprobe --show-config 2>/dev/null | grep -c 'blacklist sctp' || true"
  output_combined="$output"
  lsmod_count=$(printf '%s\n' "$output_combined" | sed -n '1p')
  install_count=$(printf '%s\n' "$output_combined" | sed -n '2p')
  # Effective blacklist check uses --show-config (the parsed, applied configuration),
  # NOT a plain grep of the .conf file text - a commented-out line like '# blacklist
  # sctp' would satisfy a naive text grep while doing nothing at the modprobe level.
  blacklist_effective_count=$(printf '%s\n' "$output_combined" | sed -n '3p')

  # Real retest: actually try to load sctp again via the normal path. It must fail to
  # appear in lsmod afterward - this proves the install override actually intercepts a
  # direct 'modprobe sctp' call, not just that the config file happens to contain the
  # right words somewhere.
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo modprobe sctp 2>/dev/null; sudo lsmod | grep -c sctp || true'
  retest_lsmod_count="$output"

  if [[ "$lsmod_count" == "0" && "$install_count" -ge 1 && "$blacklist_effective_count" -ge 1 ]] \
    && [[ "$retest_lsmod_count" == "0" ]] \
    && grep -qx 'lsmod: absent' "$ARTIFACTS/7/sctp.txt" \
    && grep -Fq 'install sctp /bin/true' "$ARTIFACTS/7/sctp.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$lsmod_count" != "0" ]]; then
      echo "HINT: sctp module is still loaded (lsmod shows it). Run 'sudo modprobe -r sctp' to unload it right now, in addition to the persistent blacklist config."
    elif [[ "$blacklist_effective_count" -lt 1 ]]; then
      echo "HINT: 'sudo modprobe --show-config' does not show an effective 'blacklist sctp' entry - a commented-out line (e.g. '# blacklist sctp') or a typo satisfies a plain text search of the file but does nothing at the modprobe level. Check the ACTUAL parsed config, not just the file's text."
    elif [[ "$install_count" -lt 1 ]]; then
      echo "HINT: No effective 'install sctp /bin/true' override found via 'modprobe --show-config'. A plain 'blacklist sctp' line only stops auto-loading via alias resolution - a direct 'modprobe sctp' can still succeed unless you also override the install command."
    elif [[ "$retest_lsmod_count" != "0" ]]; then
      echo "HINT: After re-running 'modprobe sctp' directly, the module ended up loaded again (lsmod shows it). The install override in /etc/modprobe.d/60-cks-sctp.conf is not actually intercepting a direct 'modprobe sctp' call - re-check the exact syntax 'install sctp /bin/true'."
    else
      echo "HINT: The fix looks correct on the node, but the evidence file /var/work/tests/artifacts/7/sctp.txt is missing the expected exact lines 'lsmod: absent' and 'install sctp /bin/true'."
    fi
    echo "lsmod_count=$lsmod_count install_count=$install_count blacklist_effective_count=$blacklist_effective_count retest_lsmod_count=$retest_lsmod_count output=$output_combined"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. sysctl hardening is applied and kubelet runs with protectKernelDefaults" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sysctl -n kernel.unprivileged_bpf_disabled; sysctl -n vm.overcommit_memory; sudo cat /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; sudo systemctl is-active kubelet"
  bpf_value=$(printf '%s\n' "$output" | sed -n '1p')
  overcommit_value=$(printf '%s\n' "$output" | sed -n '2p')
  kubelet_active=$(printf '%s\n' "$output" | tail -n1)
  node_ready=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  # Effective kubelet configuration, not the text of config.yaml - a commented-out line
  # like '# protectKernelDefaults: true' would satisfy a naive grep of the file while the
  # running kubelet still has this field at its default (false). /configz reflects what
  # kubelet is ACTUALLY running with.
  protect_kernel_defaults=$(kubectl get --raw="/api/v1/nodes/${cp}/proxy/configz" --context "$CTX" 2>/dev/null \
    | jq -r '.kubeletconfig.protectKernelDefaults // "missing"' 2>/dev/null || echo "unreachable")
  if [[ "$status" -eq 0 && "$bpf_value" == "1" && "$overcommit_value" == "1" && "$kubelet_active" == "active" && "$node_ready" == "True" ]] \
    && grep -Fq 'kernel.unprivileged_bpf_disabled' <<<"$output" \
    && grep -Fq 'vm.overcommit_memory' <<<"$output" \
    && [[ "$protect_kernel_defaults" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$bpf_value" != "1" || "$overcommit_value" != "1" ]]; then
      echo "HINT: sysctl values are wrong at runtime. Both kernel.unprivileged_bpf_disabled and vm.overcommit_memory must equal 1 - set them in /etc/sysctl.d/99-kubernetes.conf and apply with 'sysctl --system' or a reboot, do not just run 'sysctl -w' once."
    elif [[ "$protect_kernel_defaults" != "true" ]]; then
      echo "HINT: The EFFECTIVE kubelet configuration (queried via /api/v1/nodes/<node>/proxy/configz, not just grepping config.yaml text) does not show protectKernelDefaults=true (got '$protect_kernel_defaults'). A commented-out or malformed line in config.yaml can satisfy a plain text search while kubelet is actually still running with the default value - restart kubelet after fixing the file and re-check via configz."
    elif [[ "$kubelet_active" != "active" || "$node_ready" != "True" ]]; then
      echo "HINT: kubelet is not active or the node is NotReady after your sysctl change (kubelet=$kubelet_active node_ready=$node_ready). If protectKernelDefaults is true but the sysctls do not match kubelet's expected defaults, kubelet will refuse to start - set the sysctls BEFORE enabling this flag."
    fi
    echo "bpf=$bpf_value overcommit=$overcommit_value kubelet_active=$kubelet_active node_ready=$node_ready protect_kernel_defaults=$protect_kernel_defaults"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. Extra SUID lab binary is remediated without touching system SUID binaries" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo stat -c '%a' /usr/local/bin/cks-lab105-suid-tool; sudo stat -c '%a' /usr/bin/sudo 2>/dev/null || sudo stat -c '%a' /bin/sudo 2>/dev/null; sudo find / -xdev -perm -4000 -type f -print 2>/dev/null | sort"
  mode_output="$output"
  tool_mode=$(printf '%s\n' "$mode_output" | sed -n '1p')
  sudo_mode=$(printf '%s\n' "$mode_output" | sed -n '2p')
  # Everything from line 3 onward is the current full SUID inventory.
  current_suid_list=$(printf '%s\n' "$mode_output" | tail -n +3)

  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo cat /var/lib/cks-lab105/system-suid-baseline.txt 2>/dev/null'
  baseline_suid_list="$output"
  baseline_status=$status

  # Checker-owned diff: the current system SUID set (EXCLUDING the lab-planted tool
  # itself, which is expected to lose its bit) must be identical to the pre-lab baseline.
  # A student who strips SUID from unrelated system binaries and restores it only on
  # 'sudo' would still fail here, because other baseline entries would be missing from
  # the current set.
  current_system_suid=$(grep -Fvx '/usr/local/bin/cks-lab105-suid-tool' <<<"$current_suid_list" | sort)
  baseline_sorted=$(sort <<<"$baseline_suid_list")
  system_suid_untouched="no"
  if [[ "$baseline_status" -eq 0 && -n "$baseline_suid_list" && "$current_system_suid" == "$baseline_sorted" ]]; then
    system_suid_untouched="yes"
  fi

  if [[ "$status" -eq 0 && "$tool_mode" == "755" && "$sudo_mode" == 4[0-9][0-9][0-9] && "$system_suid_untouched" == "yes" ]] \
    && grep -Fq 'cks-lab105-suid-tool' "$ARTIFACTS/9/suid-before.txt" \
    && grep -qx '755' "$ARTIFACTS/9/suid-after.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$tool_mode" != "755" ]]; then
      echo "HINT: /usr/local/bin/cks-lab105-suid-tool must end up at mode 755 (SUID bit removed: 'chmod 755' or 'chmod u-s'). Current mode is '$tool_mode'."
    elif [[ "$sudo_mode" != 4[0-9][0-9][0-9] ]]; then
      echo "HINT: /usr/bin/sudo (or /bin/sudo) lost its SUID bit ($sudo_mode) - this task requires you to fix ONLY the lab-planted binary, not legitimate system SUID binaries like sudo. Restore its mode to 4xxx."
    elif [[ "$system_suid_untouched" != "yes" ]]; then
      echo "HINT: The current set of system SUID binaries (excluding the lab-planted tool) does not match the checker-owned baseline captured before the lab started. This means SOME legitimate system SUID binary (not just sudo) was stripped of its SUID bit and possibly not fully restored - this task only asks you to fix the lab-planted tool, not to touch any other binary on the node."
    else
      echo "HINT: The fix on the node looks correct, but evidence files are missing the expected content - suid-before.txt must mention the tool name, suid-after.txt must contain exactly '755'."
    fi
    echo "tool_mode=$tool_mode sudo_mode=$sudo_mode system_suid_untouched=$system_suid_untouched baseline_status=$baseline_status"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "10. Core dumps are disabled and fs.suid_dumpable is 0" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  run ssh "${SSH_OPTS[@]}" "$cp" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo cat /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; sudo cat /etc/security/limits.conf 2>/dev/null; su - ubuntu -c 'ulimit -c'"
  combined="$output"
  dumpable_value=$(printf '%s\n' "$combined" | sed -n '1p')
  core_pattern_value=$(printf '%s\n' "$combined" | sed -n '2p')
  ulimit_value=$(printf '%s\n' "$combined" | tail -n1)

  # Real crash probe: fs.suid_dumpable and ulimit -c alone do NOT disable core dumps on
  # Ubuntu - per core(5), RLIMIT_CORE is ignored when core_pattern pipes to a program, and
  # Ubuntu's default Apport handler intercepts crashes into /var/lib/apport/coredump/
  # regardless of ulimit. Only overriding kernel.core_pattern itself is reliable.
  run ssh "${SSH_OPTS[@]}" "$cp" '
    before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
    (sh -c "kill -SEGV \$\$") || true
    sleep 2
    after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
    if [ "$after_count" -le "$before_count" ]; then echo NO_NEW_DUMP; else echo NEW_DUMP_APPEARED; fi
  '
  crash_probe_result="$output"

  if [[ "$dumpable_value" == "0" && "$core_pattern_value" == '|/bin/false' && "$ulimit_value" == "0" ]] \
    && grep -Fq 'fs.suid_dumpable = 0' <<<"$combined" \
    && grep -Fq 'kernel.core_pattern = |/bin/false' <<<"$combined" \
    && grep -Fq '* hard core 0' <<<"$combined" \
    && grep -Fq '* soft core 0' <<<"$combined" \
    && [[ "$crash_probe_result" == "NO_NEW_DUMP" ]] \
    && grep -qx '0' "$ARTIFACTS/10/coredump.txt" \
    && grep -Fq 'fs.suid_dumpable = 0' "$ARTIFACTS/10/coredump.txt" \
    && grep -Fq 'hard core 0' "$ARTIFACTS/10/coredump.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$dumpable_value" != "0" ]]; then
      echo "HINT: fs.suid_dumpable must be 0 at runtime. Set it in /etc/sysctl.d/99-kubernetes.conf and reload with 'sysctl --system' - a config file entry alone does not change the live kernel value until applied."
    elif [[ "$core_pattern_value" != '|/bin/false' ]]; then
      echo "HINT: /proc/sys/kernel/core_pattern must be exactly '|/bin/false' (a pipe handler override). On Ubuntu, fs.suid_dumpable=0 and 'ulimit -c 0' alone do NOT disable core dumps - per 'man 5 core', RLIMIT_CORE is ignored when core_pattern pipes to a program, and Apport (Ubuntu's default handler) intercepts crashes into /var/lib/apport/coredump/ regardless of ulimit. Set kernel.core_pattern = |/bin/false in /etc/sysctl.d/99-kubernetes.conf and apply with 'sysctl --system'."
    elif [[ "$ulimit_value" != "0" ]]; then
      echo "HINT: 'ulimit -c' for a normal user must be 0. Add BOTH '* hard core 0' and '* soft core 0' to /etc/security/limits.conf - only the soft limit is not enough, a process can raise it back up to the hard limit."
    elif [[ "$crash_probe_result" != "NO_NEW_DUMP" ]]; then
      echo "HINT: A real SIGSEGV crash produced a NEW retained core dump (found in /var/lib/apport/coredump or /var/crash) despite your sysctl/limits settings. This proves core dumps are not actually disabled end-to-end - double check kernel.core_pattern is really applied (not just written to the file) with 'sysctl --system'."
    else
      echo "HINT: Runtime values look correct, but the evidence file coredump.txt is missing one of the required exact lines: '0', 'fs.suid_dumpable = 0', or 'hard core 0'."
    fi
    echo "dumpable_value=$dumpable_value core_pattern_value=$core_pattern_value ulimit_value=$ulimit_value crash_probe_result=$crash_probe_result combined=$combined"
    result=1
  fi
  [ "$result" -eq 0 ]
}
