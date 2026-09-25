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

  # Checker-owned bootstrap baseline (captured by worker.sh BEFORE the lab was handed to
  # the student and before any UFW rule existed). This cannot be fabricated or backdated
  # by the student, unlike their own artifacts/3/preflight.txt line - PROVIDED the trust
  # boundary actually holds. /var/work/tests itself is made world-writable (chmod -R 777)
  # by the shared work_pc_v2 bootstrap template, so a root:root 0444 file living INSIDE
  # it would NOT be a real trust boundary: a world-writable parent lets any local account
  # delete and recreate the file (Unix delete/create permission is governed by the
  # directory, not the file). This baseline therefore lives in a separate directory
  # (/var/lib/cks-lab105-checker).
  #
  # ARCHITECTURAL LIMITATION (see ADVERSARIAL_ACCEPTANCE_STANDARD.md): this lab's own
  # 'check_result' runs 'bats /var/work/tests/tests.bats' WITHOUT sudo, as the 'ubuntu'
  # account. This check itself therefore CANNOT require sudo to read the baseline -
  # otherwise the normal PASS path breaks for every student. The directory is 0711 (not
  # 0700) so 'ubuntu' can stat/cat a known filename inside it without listing the
  # directory, and the file itself is 0444 (read-only, not writable without root). This
  # is defense-in-depth against ACCIDENTAL modification, not a hardened boundary against a
  # student who deliberately escalates via sudo (which 'ubuntu' has, passwordless, on this
  # same host) - a fully tamper-proof, purely local, self-hosted baseline is not
  # achievable on this architecture.
  baseline_dir_owner_mode=$(stat -c '%U:%G %a' /var/lib/cks-lab105-checker 2>/dev/null || true)
  baseline_owner_mode=$(stat -c '%U:%G %a' /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt 2>/dev/null || true)
  baseline_trust_boundary_ok="no"
  if [[ "$baseline_dir_owner_mode" =~ ^root:root\ 0?711$ && "$baseline_owner_mode" =~ ^root:root\ 0?444$ ]]; then
    baseline_trust_boundary_ok="yes"
  fi

  bootstrap_baseline=$(cat /var/lib/cks-lab105-checker/bootstrap-baseline-3.txt 2>/dev/null || true)
  bootstrap_rc=$(printf '%s\n' "$bootstrap_baseline" | grep -oE 'CURL_EXIT=[0-9]+' | cut -d= -f2)
  bootstrap_http=$(printf '%s\n' "$bootstrap_baseline" | grep -oE 'HTTPCODE=[0-9]{3}' | cut -d= -f2)
  bootstrap_baseline_ok="no"
  if [[ "$baseline_trust_boundary_ok" == "yes" && "$bootstrap_rc" == "0" && "$bootstrap_http" =~ ^[1-5][0-9][0-9]$ ]]; then
    bootstrap_baseline_ok="yes"
  fi

  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw status verbose; sudo ufw status; echo ===ADDED===; sudo ufw show added'
  firewall_full="$output"
  firewall_status=$status
  firewall="${firewall_full%%===ADDED===*}"
  added_rules="${firewall_full#*===ADDED===}"

  ready=$(kubectl get --raw=/readyz --context "$CTX" 2>/dev/null || true)
  node_ready=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  calico_ready=$(kubectl get pods -n kube-system -l k8s-app=calico-node --context "$CTX" \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  workload_ready=$(kubectl get deployment health-probe -n cks-105-health --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
  pod_dns=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'getent hosts kubernetes.default.svc.cluster.local >/dev/null 2>&1 && echo RESOLVED || echo FAILED' 2>/dev/null || true)
  pod_http=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz' 2>/dev/null || true)
  if out=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "https://${node_ip}:10250/healthz" 2>/dev/null); then
    kubelet_status=0
  else
    kubelet_status=$?
  fi
  kubelet_http="$out"

  # Exact allow-set check via 'ufw show added': this report renders a NORMALIZED
  # representation of the rules that were run (see ufw's own get_command()) - it is not
  # guaranteed to be the literal/original command text or original order, since UFW
  # normalizes and can reorder entries. A rule only counts if it appears in this
  # normalized list with the exact port/proto/source.
  esc_worker="${worker_ip//./\\.}"
  esc_node="${node_ip//./\\.}"
  esc_pod_cidr=$(printf '%s' "$pod_cidr" | sed 's/[.[\*^$/]/\\&/g')

  rule_ssh_worker=$(grep -Eq "^ufw allow from ${esc_worker} to any port 22 proto tcp" <<<"$added_rules" && echo yes || echo no)
  rule_api_worker=$(grep -Eq "^ufw allow from ${esc_worker} to any port 6443 proto tcp" <<<"$added_rules" && echo yes || echo no)
  rule_api_node=$(grep -Eq "^ufw allow from ${esc_node} to any port 6443 proto tcp" <<<"$added_rules" && echo yes || echo no)
  rule_api_podcidr=$(grep -Eq "^ufw allow from ${esc_pod_cidr} to any port 6443 proto tcp" <<<"$added_rules" && echo yes || echo no)

  # Exact allow-set: count EVERY added rule line of ANY action (allow/deny/reject/limit,
  # including 'route ...' forms), not just allow/limit - an extra 'ufw deny'/'ufw reject'/
  # 'ufw route allow' rule must also make the total diverge from 5, even though it is not
  # itself an ALLOW. Any UFW rule line in ANY form (short 'ufw allow 8080/tcp',
  # source-scoped 'ufw allow from X to any port Y proto tcp', interface-scoped 'ufw allow
  # in on lo', or a route rule) counts. Require exactly the 4 documented source-scoped
  # allow rules plus the loopback allow rule and NOTHING else.
  total_added_allow=$(grep -cE '^ufw (allow|deny|reject|limit|route) ' <<<"$added_rules" || true)
  loopback_rule=$(grep -Eq '^ufw allow in on lo' <<<"$added_rules" && echo yes || echo no)
  exact_allow_set="no"
  if [[ "$rule_ssh_worker" == "yes" && "$rule_api_worker" == "yes" && "$rule_api_node" == "yes" \
        && "$rule_api_podcidr" == "yes" && "$loopback_rule" == "yes" && "$total_added_allow" -eq 5 ]]; then
    exact_allow_set="yes"
  fi

  # 'ufw show added' only reflects rules added through the ufw CLI. A student could bypass
  # it entirely by hand-editing the UFW framework files directly (/etc/ufw/before*.rules,
  # /etc/ufw/after*.rules) to add an extra ingress path that never shows up in 'ufw show
  # added' or in a naive 'ufw status' grep. Compare their current hash against the
  # checker-owned bootstrap-time hash (captured before the lab started) to catch this.
  # This baseline lives outside /var/work/tests (see the trust-boundary note above) and
  # is itself validated for owner/mode below, since the same world-writable-parent issue
  # would apply to it too if it were left inside /var/work/tests.
  ufw_framework_dir_owner_mode=$(stat -c '%U:%G %a' /var/lib/cks-lab105-checker 2>/dev/null || true)
  ufw_framework_file_owner_mode=$(stat -c '%U:%G %a' /var/lib/cks-lab105-checker/bootstrap-ufw-framework-baseline.txt 2>/dev/null || true)
  ufw_framework_baseline_trust_ok="no"
  if [[ "$ufw_framework_dir_owner_mode" =~ ^root:root\ 0?711$ && "$ufw_framework_file_owner_mode" =~ ^root:root\ 0?444$ ]]; then
    ufw_framework_baseline_trust_ok="yes"
  fi
  ufw_framework_baseline=$(cat /var/lib/cks-lab105-checker/bootstrap-ufw-framework-baseline.txt 2>/dev/null || true)
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo sha256sum /etc/ufw/before.rules /etc/ufw/before6.rules /etc/ufw/after.rules /etc/ufw/after6.rules 2>/dev/null | sort -k2'
  ufw_framework_current="$output"
  ufw_framework_unchanged="no"
  if [[ "$ufw_framework_baseline_trust_ok" == "yes" && -n "$ufw_framework_baseline" && "$ufw_framework_current" == "$ufw_framework_baseline" ]]; then
    ufw_framework_unchanged="yes"
  fi

  # 'ufw show added' is a DECLARATIVE view reconstructed from '### tuple ###' metadata
  # comments that ufw itself writes into user.rules/user6.rules when a rule is added
  # through the ufw CLI. UFW loads user.rules via 'iptables-restore' on enable/reload,
  # so a rule hand-added directly to user.rules WITHOUT the matching tuple metadata can
  # become part of the EFFECTIVE firewall after 'ufw reload' while being invisible to
  # 'ufw show added' and leaving all four before/after framework hashes untouched (it
  # only touches user.rules, which is a separate file). Directly inspect the ACTUAL
  # kernel-loaded ufw-user-* chains via 'ufw show user-rules' and require the rule COUNT
  # in the ufw-user-input chain specifically to match the declared allow-set count - a
  # real bypass rule loaded into the kernel but absent from 'ufw show added' makes this
  # count diverge.
  #
  # 'ufw show user-rules' output is NOT a flat list of iptables -L blocks: per ufw's own
  # get_running_raw() (rules_type == 'user'), it prints an 'IPV4 (user):' section header,
  # then Chain blocks for ufw-user-input/-forward/-output, THEN the built-in
  # ufw-user-limit-accept/ufw-user-limit chains (which always exist and have their own
  # rule rows even with zero user-added limit rules), and - whenever IPv6 is enabled on
  # the host (the common case) - a SECOND full 'IPV6:' section repeating all of the
  # above for the ufw6-user-* chains. Counting every non-header/non-blank line across the
  # whole output (as an earlier version of this check did) therefore always overcounts
  # by including the IPV4/IPV6 section header lines and the built-in limit chains' own
  # rows, causing a false FAIL even for a fully correct student solution. Extract ONLY
  # the ufw-user-input chain's rule rows (ingress traffic, which is what this task's
  # allow-set concerns) using an explicit block boundary, not a global line count.
  #
  # A bare rule COUNT is still not sufficient evidence on its own: a student could keep
  # the '### tuple ###' metadata for all 5 declared rules intact (so 'ufw show added'
  # still reports exactly the expected 5 commands) while hand-editing one of the
  # corresponding '-A ufw-user-input ...' lines in /etc/ufw/user.rules to a WIDER rule -
  # e.g. replacing the documented 'node_ip -> 6443/tcp' with 'node_ip -> any' - without
  # changing the line count at all. Five effective rules that are the wrong five rules
  # must not read as a match. Check the SEMANTIC content of each expected rule (source,
  # interface, protocol, destination port) against the real 'iptables -n -v -x -L
  # ufw-user-input' rows (that is what 'ufw show user-rules' renders), not just how many
  # rows exist.
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw show user-rules'
  ufw_user_chains_status=$status
  ufw_user_input_block=$(awk '/^Chain ufw-user-input /{flag=1; next} /^Chain /{flag=0} flag' <<<"$output")
  ufw_user_chain_rule_count=$(grep -vE '^[[:space:]]*pkts[[:space:]]|^[[:space:]]*$' <<<"$ufw_user_input_block" | grep -cE '.' || true)
  ufw6_user_input_block=$(awk '/^Chain ufw6-user-input /{flag=1; next} /^Chain /{flag=0} flag' <<<"$output")
  ufw6_user_chain_rule_count=$(grep -vE '^[[:space:]]*pkts[[:space:]]|^[[:space:]]*$' <<<"$ufw6_user_input_block" | grep -cE '.' || true)

  # Exact per-rule semantic match. 4 of the 5 documented rules use IPv4 addresses, but
  # 'ufw allow in on lo' (the loopback rule) is an INTERFACE-based rule with no IP
  # literal at all - UFW has no way to scope it to IPv4 only, so it always populates
  # BOTH ufw-user-input AND ufw6-user-input with an identical ACCEPT-all-on-lo row.
  # Confirmed live: a fully correct, by-the-book solution produces exactly one row in
  # ufw6-user-input (the v6 loopback ACCEPT), not zero. So ufw6-user-input must contain
  # EXACTLY that one row and nothing else - not "completely empty" and not "any row is a
  # fail" - any OTHER/additional row there (e.g. a raw bypass rule hand-added to
  # user6.rules) is still a fail.
  ufw_loopback_ok=$(grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+all[[:space:]]+--[[:space:]]+lo[[:space:]]+\*[[:space:]]+0\.0\.0\.0/0[[:space:]]+0\.0\.0\.0/0[[:space:]]*$' <<<"$ufw_user_input_block" && echo yes || echo no)
  ufw_ssh_worker_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_worker}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:22[[:space:]]*\$" <<<"$ufw_user_input_block" && echo yes || echo no)
  ufw_api_worker_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_worker}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$ufw_user_input_block" && echo yes || echo no)
  ufw_api_node_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_node}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$ufw_user_input_block" && echo yes || echo no)
  ufw_api_podcidr_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_pod_cidr}[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$ufw_user_input_block" && echo yes || echo no)
  ufw6_loopback_ok=$(grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+all[[:space:]]+lo[[:space:]]+\*[[:space:]]+::/0[[:space:]]+::/0[[:space:]]*$' <<<"$ufw6_user_input_block" && echo yes || echo no)

  ufw_effective_matches_declared="no"
  if [[ "$ufw_user_chains_status" -eq 0 && "$ufw_user_chain_rule_count" == "$total_added_allow" \
        && "$ufw6_user_chain_rule_count" -eq 1 && "$ufw6_loopback_ok" == "yes" && "$ufw_loopback_ok" == "yes" \
        && "$ufw_ssh_worker_ok" == "yes" && "$ufw_api_worker_ok" == "yes" \
        && "$ufw_api_node_ok" == "yes" && "$ufw_api_podcidr_ok" == "yes" ]]; then
    ufw_effective_matches_declared="yes"
  fi

  calico_all_ready=yes
  [[ -z "$calico_ready" ]] && calico_all_ready=no
  for cond in $calico_ready; do
    [[ "$cond" != "True" ]] && calico_all_ready=no
  done

  baseline_present=$(grep -Eq 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=[1-5][0-9][0-9]' "$ARTIFACTS/3/preflight.txt" 2>/dev/null && echo yes || echo no)

  # Full E2E retest AFTER an explicit 'ufw reload' - proves the ruleset survives a reload,
  # not just the in-memory state right after 'ufw enable'. Only run once the structural
  # allow-set and recovery evidence already look sane, to avoid reloading (and risking a
  # lockout window on a misconfigured firewall) when the base checks would fail anyway.
  # This repeats EVERY probe used pre-reload, including Pod DNS and the full HTTPCODE
  # contract for the negative kubelet probe - not just a subset.
  reload_ready="not-run"
  reload_node_ready="not-run"
  reload_calico_ready="not-run"
  reload_pod_dns="not-run"
  reload_pod_http="not-run"
  reload_kubelet_status="not-run"
  reload_kubelet_http="not-run"
  reload_ufw_effective_matches_declared="not-run"
  if [[ "$firewall_status" -eq 0 && "$exact_allow_set" == "yes" ]]; then
    run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw reload'
    reload_status=$status
    if [[ "$reload_status" -eq 0 ]]; then
      sleep 2
      reload_ready=$(kubectl get --raw=/readyz --context "$CTX" 2>/dev/null || true)
      reload_node_ready=$(kubectl get node "$cp" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
      reload_calico_ready=yes
      rc2=$(kubectl get pods -n kube-system -l k8s-app=calico-node --context "$CTX" \
        -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
      [[ -z "$rc2" ]] && reload_calico_ready=no
      for cond in $rc2; do [[ "$cond" != "True" ]] && reload_calico_ready=no; done
      # Same Pod DNS probe as the pre-reload check - a reload can restart kube-proxy/CNI
      # rule programming and cause a DNS-specific regression that a pure HTTP probe would
      # not catch on its own.
      reload_pod_dns=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'getent hosts kubernetes.default.svc.cluster.local >/dev/null 2>&1 && echo RESOLVED || echo FAILED' 2>/dev/null || true)
      reload_pod_http=$(kubectl exec -n cks-105-health deploy/health-probe --context "$CTX" -- sh -c 'curl -ksS -o /dev/null -w "%{http_code}" --max-time 5 https://kubernetes.default.svc/readyz' 2>/dev/null || true)
      # Same contract as the pre-reload negative probe: save BOTH exit status AND the
      # HTTP code, not just the exit status. A transport failure (exit != 0) with a
      # non-empty/non-000 HTTPCODE would indicate a partial connection, not a clean deny.
      if reload_out=$(curl -ksS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 3 "https://${node_ip}:10250/healthz" 2>/dev/null); then
        reload_kubelet_status=0
      else
        reload_kubelet_status=$?
      fi
      reload_kubelet_http="$reload_out"

      # Re-verify the effective kernel-loaded UFW user chains AFTER reload too, not only
      # right after enable - 'ufw reload' is exactly the moment a hand-edited user.rules
      # (without matching tuple metadata) would actually get loaded via
      # 'iptables-restore', so checking only pre-reload state could miss a bypass rule
      # that was added to user.rules but not yet active until this reload. Same
      # block-scoped extraction AND same per-rule semantic match as the pre-reload check
      # above - see the comments there for why a flat line count over the whole 'ufw show
      # user-rules' output (including the IPV4/IPV6 section headers and the built-in
      # ufw-user-limit-accept/ufw-user-limit chains) would overcount, and why a rule
      # COUNT alone (even block-scoped) cannot distinguish 5 correct rules from 5 rules
      # where one was quietly widened (e.g. 'node_ip -> 6443/tcp' rewritten to
      # 'node_ip -> any') while keeping the tuple metadata that 'ufw show added' relies
      # on. ufw6-user-input must stay at exactly the one v6 loopback row for the same
      # reason as pre-reload (see comment there): 'ufw allow in on lo' is interface-based
      # and always produces both a v4 and a v6 ACCEPT row - that one row is expected, any
      # OTHER row appearing there is itself a bypass, independent of the IPv4 count.
      run ssh "${SSH_OPTS[@]}" "$cp" 'sudo ufw show user-rules'
      reload_ufw_user_chains_status=$status
      reload_ufw_user_input_block=$(awk '/^Chain ufw-user-input /{flag=1; next} /^Chain /{flag=0} flag' <<<"$output")
      reload_ufw_user_chain_rule_count=$(grep -vE '^[[:space:]]*pkts[[:space:]]|^[[:space:]]*$' <<<"$reload_ufw_user_input_block" | grep -cE '.' || true)
      reload_ufw6_user_input_block=$(awk '/^Chain ufw6-user-input /{flag=1; next} /^Chain /{flag=0} flag' <<<"$output")
      reload_ufw6_user_chain_rule_count=$(grep -vE '^[[:space:]]*pkts[[:space:]]|^[[:space:]]*$' <<<"$reload_ufw6_user_input_block" | grep -cE '.' || true)

      reload_ufw_loopback_ok=$(grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+all[[:space:]]+--[[:space:]]+lo[[:space:]]+\*[[:space:]]+0\.0\.0\.0/0[[:space:]]+0\.0\.0\.0/0[[:space:]]*$' <<<"$reload_ufw_user_input_block" && echo yes || echo no)
      reload_ufw_ssh_worker_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_worker}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:22[[:space:]]*\$" <<<"$reload_ufw_user_input_block" && echo yes || echo no)
      reload_ufw_api_worker_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_worker}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$reload_ufw_user_input_block" && echo yes || echo no)
      reload_ufw_api_node_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_node}(/32)?[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$reload_ufw_user_input_block" && echo yes || echo no)
      reload_ufw_api_podcidr_ok=$(grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+tcp[[:space:]]+--[[:space:]]+\*[[:space:]]+\*[[:space:]]+${esc_pod_cidr}[[:space:]]+0\.0\.0\.0/0[[:space:]]+tcp dpt:6443[[:space:]]*\$" <<<"$reload_ufw_user_input_block" && echo yes || echo no)
      reload_ufw6_loopback_ok=$(grep -Eq '^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+ACCEPT[[:space:]]+all[[:space:]]+lo[[:space:]]+\*[[:space:]]+::/0[[:space:]]+::/0[[:space:]]*$' <<<"$reload_ufw6_user_input_block" && echo yes || echo no)

      reload_ufw_effective_matches_declared="no"
      if [[ "$reload_ufw_user_chains_status" -eq 0 && "$reload_ufw_user_chain_rule_count" == "$total_added_allow" \
            && "$reload_ufw6_user_chain_rule_count" -eq 1 && "$reload_ufw6_loopback_ok" == "yes" && "$reload_ufw_loopback_ok" == "yes" \
            && "$reload_ufw_ssh_worker_ok" == "yes" && "$reload_ufw_api_worker_ok" == "yes" \
            && "$reload_ufw_api_node_ok" == "yes" && "$reload_ufw_api_podcidr_ok" == "yes" ]]; then
        reload_ufw_effective_matches_declared="yes"
      fi
    fi
  fi

  if [[ "$bootstrap_baseline_ok" == "yes" ]] \
    && [[ "$firewall_status" -eq 0 ]] \
    && grep -q 'Status: active' <<<"$firewall" \
    && grep -q 'Default: deny (incoming)' <<<"$firewall" \
    && [[ "$exact_allow_set" == "yes" ]] \
    && [[ "$ufw_framework_unchanged" == "yes" ]] \
    && [[ "$ufw_effective_matches_declared" == "yes" ]] \
    && [[ "$ready" == "ok" && "$node_ready" == "True" && "$calico_all_ready" == "yes" ]] \
    && [[ "${workload_ready:-0}" -ge 1 && "$pod_dns" == "RESOLVED" && -n "$pod_http" && "$pod_http" != "000" ]] \
    && [[ "$kubelet_status" -ne 0 && ( -z "$kubelet_http" || "$kubelet_http" == "000" ) ]] \
    && [[ "$baseline_present" == "yes" ]] \
    && [[ "$reload_ready" == "ok" && "$reload_node_ready" == "True" && "$reload_calico_ready" == "yes" ]] \
    && [[ "$reload_pod_dns" == "RESOLVED" ]] \
    && [[ "$reload_pod_http" != "000" && -n "$reload_pod_http" ]] \
    && [[ "$reload_kubelet_status" != "0" && ( -z "$reload_kubelet_http" || "$reload_kubelet_http" == "000" ) ]] \
    && [[ "$reload_ufw_effective_matches_declared" == "yes" ]] \
    && grep -q 'Status: active' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'Default: deny (incoming)' "$ARTIFACTS/3/ufw.txt" \
    && grep -q 'role=control-plane,workload' "$ARTIFACTS/3/preflight.txt" \
    && grep -q 'sudo ufw disable' "$ARTIFACTS/3/recovery.txt" \
    && grep -q 'sudo ufw --force enable' "$ARTIFACTS/3/recovery.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$baseline_trust_boundary_ok" != "yes" ]]; then
      echo "HINT: /var/lib/cks-lab105-checker (dir='$baseline_dir_owner_mode') or its bootstrap-baseline-3.txt (file='$baseline_owner_mode') is not locked down to root:root 0711/0444 as expected - this baseline must stay checker-owned and unmodifiable by the student account. This is an infrastructure trust-boundary failure, not something you can fix from inside the lab. Contact the lab operator."
    elif [[ "$bootstrap_baseline_ok" != "yes" ]]; then
      echo "HINT: the checker's own bootstrap-time baseline for TCP/10250 (captured before the lab started, independent of your artifacts) shows the port was already unreachable before any UFW change existed on this node - this is an infrastructure precondition failure, not something you can fix from inside the lab. Contact the lab operator."
    elif [[ "$baseline_present" != "yes" ]]; then
      echo "HINT: artifacts/3/preflight.txt must contain a baseline probe of TCP/10250 recorded BEFORE UFW was enabled, in the exact form 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=<1xx-5xx>'. Without this, a post-UFW block cannot be attributed to UFW - the port might have already been unreachable for an unrelated reason."
    elif [[ "$firewall_status" -ne 0 ]] || ! grep -q 'Status: active' <<<"$firewall"; then
      echo "HINT: UFW is not active. Enable it with 'sudo ufw --force enable' AFTER adding the required allow rules - never enable a default-deny firewall before you have an SSH rule in place, you can lock yourself out."
    elif [[ "$exact_allow_set" != "yes" ]]; then
      echo "HINT: 'sudo ufw show added' does not show EXACTLY the 5 documented rules (loopback + worker->22/tcp + worker->6443/tcp + node_ip->6443/tcp + pod_cidr->6443/tcp). Any extra rule of ANY action (another allow, a deny, a reject, a route rule, an app profile, or a broad 'Anywhere' rule) or any missing one of the 5 makes this fail - 'ufw show added' shows a normalized representation of the rules you ran (not necessarily the literal/original command text or order), independent of how 'ufw status' displays them."
    elif [[ "$ufw_framework_unchanged" != "yes" ]]; then
      if [[ "$ufw_framework_baseline_trust_ok" != "yes" ]]; then
        echo "HINT: /var/lib/cks-lab105-checker (dir='$ufw_framework_dir_owner_mode') or its bootstrap-ufw-framework-baseline.txt (file='$ufw_framework_file_owner_mode') is not locked down to root:root 0711/0444 as expected. This is an infrastructure trust-boundary failure, not something you can fix from inside the lab. Contact the lab operator."
      else
        echo "HINT: /etc/ufw/before.rules, before6.rules, after.rules, or after6.rules on the control plane no longer match the checker-owned hash captured before the lab started. This task only allows managing the firewall through the 'ufw' command itself (allow/deny/reject/limit/route, then enable/reload) - directly hand-editing the UFW framework rule files to add an extra ingress path bypasses 'ufw show added' entirely and is not permitted."
      fi
    elif [[ "$ufw_effective_matches_declared" != "yes" ]]; then
      echo "HINT: the ACTUAL kernel-loaded firewall rules ('sudo ufw show user-rules', which reflects real iptables state) do not semantically match the 5 documented rules. This checks more than a count: ufw-user-input must have exactly $total_added_allow rows (got $ufw_user_chain_rule_count) AND each of the 5 rows must be the exact expected rule - loopback='$ufw_loopback_ok' worker->22/tcp='$ufw_ssh_worker_ok' worker->6443/tcp='$ufw_api_worker_ok' node_ip->6443/tcp='$ufw_api_node_ok' pod_cidr->6443/tcp='$ufw_api_podcidr_ok' - AND ufw6-user-input must contain EXACTLY the one expected v6 loopback ACCEPT row and nothing else (got $ufw6_user_chain_rule_count rows, v6 loopback match=$ufw6_loopback_ok) - 'ufw allow in on lo' is interface-based and always produces both a v4 and v6 row, so that one row is expected; any OTHER row is an unauthorized extra rule. 'ufw show added' is reconstructed from '### tuple ###' metadata comments that ufw writes when you use the 'ufw' CLI - a rule hand-added directly to /etc/ufw/user.rules or user6.rules WITHOUT that metadata (or with an existing rule's port/source WIDENED while keeping its metadata line intact) can become active in the kernel after 'ufw reload' while staying invisible to 'ufw show added', to the before/after framework file hashes, AND to a naive rule count. Only manage the firewall through the 'ufw' command itself; do not hand-edit user.rules/user6.rules."
    elif [[ "$calico_all_ready" != "yes" ]]; then
      echo "HINT: calico-node Pod(s) are not Ready after the UFW change (conditions='$calico_ready'). UFW is an iptables/nftables manager and can conflict with the rules Calico installs - see the lab-specific exception note in README and ADVERSARIAL_ACCEPTANCE_STANDARD.md."
    elif [[ "$ready" != "ok" || "$node_ready" != "True" ]]; then
      echo "HINT: The cluster is not healthy after your firewall change (readyz=$ready node_ready=$node_ready). Something you allowed/blocked is breaking control-plane or node communication - check kubelet-to-apiserver and CNI ports too."
    elif [[ "${workload_ready:-0}" -lt 1 || "$pod_dns" != "RESOLVED" || -z "$pod_http" || "$pod_http" == "000" ]]; then
      echo "HINT: The health-probe workload cannot resolve DNS and/or reach the API server from inside a Pod (pod_dns=$pod_dns pod_http=$pod_http). This proves in-cluster traffic, distinct from your own SSH session - check your rules do not accidentally block Pod-originated or DNS traffic."
    elif [[ "$kubelet_status" -eq 0 && "$kubelet_http" != "000" ]]; then
      echo "HINT: Port 10250 (kubelet API) is reachable directly from the worker station - this task expects it to stay blocked from outside sources that are not the control plane itself."
    elif [[ "$reload_ready" != "ok" || "$reload_node_ready" != "True" || "$reload_calico_ready" != "yes" || "$reload_pod_http" == "000" || -z "$reload_pod_http" || "$reload_pod_http" == "not-run" ]]; then
      echo "HINT: after 'sudo ufw reload' the same E2E checks (readyz/node Ready/calico-node Ready/Pod->API) must still pass. A ruleset that only works in-memory right after 'ufw enable' but breaks (or was never actually persisted) after a reload is not a correct fix - re-run the same commands and confirm they survive 'sudo ufw reload'."
    elif [[ "$reload_pod_dns" != "RESOLVED" ]]; then
      echo "HINT: after 'sudo ufw reload', the health-probe Pod can no longer resolve DNS (reload_pod_dns=$reload_pod_dns), even though other checks may look fine. A reload can restart kube-proxy/CNI rule programming and cause a DNS-specific regression that a plain HTTP probe would not catch - re-run the same DNS check used before the reload and confirm it still resolves."
    elif [[ "$reload_kubelet_status" == "0" || ( -n "$reload_kubelet_http" && "$reload_kubelet_http" != "000" ) ]]; then
      echo "HINT: after 'sudo ufw reload', worker->kubelet:10250 became reachable again (reload_kubelet_status=$reload_kubelet_status reload_kubelet_http=$reload_kubelet_http) - the deny rule for this flow did not survive the reload. This must match the SAME contract as the pre-reload check: a transport failure/timeout with an empty or '000' HTTP code, not just a nonzero curl exit status on its own."
    elif [[ "$reload_ufw_effective_matches_declared" != "yes" ]]; then
      echo "HINT: after 'sudo ufw reload', the ACTUAL kernel-loaded firewall rules ('sudo ufw show user-rules') no longer semantically match the 5 documented rules. ufw-user-input must have exactly $total_added_allow rows (got $reload_ufw_user_chain_rule_count) AND each of the 5 rows must be the exact expected rule - loopback='$reload_ufw_loopback_ok' worker->22/tcp='$reload_ufw_ssh_worker_ok' worker->6443/tcp='$reload_ufw_api_worker_ok' node_ip->6443/tcp='$reload_ufw_api_node_ok' pod_cidr->6443/tcp='$reload_ufw_api_podcidr_ok' - AND ufw6-user-input must stay at EXACTLY the one expected v6 loopback ACCEPT row (got $reload_ufw6_user_chain_rule_count rows, v6 loopback match=$reload_ufw6_loopback_ok). 'ufw reload' is exactly the moment a hand-edited user.rules/user6.rules entry (missing tuple metadata, or an existing rule quietly WIDENED while keeping its metadata line) gets loaded into the kernel via iptables-restore/ip6tables-restore - only manage the firewall through the 'ufw' command itself."
    else
      echo "HINT: Firewall behavior is correct, but one of the evidence files (ufw.txt/preflight.txt/recovery.txt) is missing the required exact content - check each file's expected line individually."
    fi
    echo "firewall_status=$firewall_status worker_ip=$worker_ip node_ip=$node_ip pod_cidr=$pod_cidr readyz=$ready node_ready=$node_ready calico_ready='$calico_ready' workload_ready=$workload_ready pod_dns=$pod_dns pod_http=$pod_http kubelet_status=$kubelet_status kubelet_http=$kubelet_http exact_allow_set=$exact_allow_set total_added_allow=$total_added_allow rule_ssh_worker=$rule_ssh_worker rule_api_worker=$rule_api_worker rule_api_node=$rule_api_node rule_api_podcidr=$rule_api_podcidr ufw_framework_unchanged=$ufw_framework_unchanged ufw_effective_matches_declared=$ufw_effective_matches_declared ufw_user_chain_rule_count=$ufw_user_chain_rule_count ufw6_user_chain_rule_count=$ufw6_user_chain_rule_count ufw_loopback_ok=$ufw_loopback_ok ufw_ssh_worker_ok=$ufw_ssh_worker_ok ufw_api_worker_ok=$ufw_api_worker_ok ufw_api_node_ok=$ufw_api_node_ok ufw_api_podcidr_ok=$ufw_api_podcidr_ok baseline_present=$baseline_present bootstrap_baseline_ok=$bootstrap_baseline_ok baseline_trust_boundary_ok=$baseline_trust_boundary_ok baseline_owner_mode='$baseline_owner_mode' reload_ready=$reload_ready reload_node_ready=$reload_node_ready reload_calico_ready=$reload_calico_ready reload_pod_dns=$reload_pod_dns reload_pod_http=$reload_pod_http reload_kubelet_status=$reload_kubelet_status reload_kubelet_http=$reload_kubelet_http reload_ufw_effective_matches_declared=$reload_ufw_effective_matches_declared reload_ufw_user_chain_rule_count=$reload_ufw_user_chain_rule_count reload_ufw6_user_chain_rule_count=$reload_ufw6_user_chain_rule_count"
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

@test "7. sctp kernel module is blacklisted with an install override" {
  echo '1' >> /var/work/tests/result/all
  cp=$(control_plane)
  # NOTE: a clean 'modprobe -r sctp' unload is NOT required/checked here. On a live
  # multi-pod Kubernetes node, sctp (like other core INET protocol modules) picks up a
  # persistent per-network-namespace reference (try_module_get in its pernet init) for
  # every namespace that already existed when it was loaded - confirmed live: refcount
  # stayed nonzero with an EMPTY /sys/module/sctp/holders list (no dependent module) even
  # after unloading sctp_diag and retrying repeatedly, because calico/coredns/kube-system
  # pod network namespaces were already up before this task ever runs. That state is not
  # something any student action can undo without tearing down the cluster's own
  # workloads. What IS fully within the student's control and checkable is that the
  # module cannot be (re)loaded going forward.
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo modprobe --show-config 2>/dev/null | grep -c 'install sctp /bin/true' || true; sudo modprobe --show-config 2>/dev/null | grep -c 'blacklist sctp' || true"
  output_combined="$output"
  install_count=$(printf '%s\n' "$output_combined" | sed -n '1p')
  # Effective blacklist check uses --show-config (the parsed, applied configuration),
  # NOT a plain grep of the .conf file text - a commented-out line like '# blacklist
  # sctp' would satisfy a naive text grep while doing nothing at the modprobe level.
  blacklist_effective_count=$(printf '%s\n' "$output_combined" | sed -n '2p')

  # Real retest: capture lsmod's sctp count BEFORE and AFTER a direct 'modprobe sctp'
  # call. Whatever the baseline is (loaded from before this task, or genuinely absent),
  # the install override must intercept the call and produce NO CHANGE - a naive
  # 'blacklist sctp' line alone only stops alias-based auto-loading, not a direct
  # 'modprobe sctp' invocation.
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo lsmod | grep -c sctp || true'
  lsmod_before_count="$output"
  run ssh "${SSH_OPTS[@]}" "$cp" 'sudo modprobe sctp 2>/dev/null; sudo lsmod | grep -c sctp || true'
  lsmod_after_count="$output"

  if [[ "$install_count" -ge 1 && "$blacklist_effective_count" -ge 1 ]] \
    && [[ "$lsmod_after_count" == "$lsmod_before_count" ]] \
    && grep -Eq '^lsmod: (absent|present)$' "$ARTIFACTS/7/sctp.txt" \
    && grep -Fq 'install sctp /bin/true' "$ARTIFACTS/7/sctp.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$blacklist_effective_count" -lt 1 ]]; then
      echo "HINT: 'sudo modprobe --show-config' does not show an effective 'blacklist sctp' entry - a commented-out line (e.g. '# blacklist sctp') or a typo satisfies a plain text search of the file but does nothing at the modprobe level. Check the ACTUAL parsed config, not just the file's text."
    elif [[ "$install_count" -lt 1 ]]; then
      echo "HINT: No effective 'install sctp /bin/true' override found via 'modprobe --show-config'. A plain 'blacklist sctp' line only stops auto-loading via alias resolution - a direct 'modprobe sctp' can still succeed unless you also override the install command."
    elif [[ "$lsmod_after_count" != "$lsmod_before_count" ]]; then
      echo "HINT: A direct 'sudo modprobe sctp' call changed the module's loaded state (before=$lsmod_before_count, after=$lsmod_after_count). The install override in /etc/modprobe.d/60-cks-sctp.conf is not actually intercepting a direct 'modprobe sctp' call - re-check the exact syntax 'install sctp /bin/true'."
    else
      echo "HINT: The fix looks correct on the node, but the evidence file /var/work/tests/artifacts/7/sctp.txt is missing the expected lines ('lsmod: absent' or 'lsmod: present', plus 'install sctp /bin/true')."
    fi
    echo "install_count=$install_count blacklist_effective_count=$blacklist_effective_count lsmod_before_count=$lsmod_before_count lsmod_after_count=$lsmod_after_count output=$output_combined"
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
  # /var/lib/containerd is excluded for the same reason the bootstrap baseline excludes
  # it (see k8s-1/scripts/master.sh) - its overlayfs snapshot paths are ephemeral
  # container image layer contents that churn independently of anything the student does.
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo stat -c '%a' /usr/local/bin/cks-lab105-suid-tool; sudo stat -c '%a' /usr/bin/sudo 2>/dev/null || sudo stat -c '%a' /bin/sudo 2>/dev/null; sudo find / -xdev -perm -4000 -type f -print 2>/dev/null | grep -v '^/var/lib/containerd/' | sort"
  mode_output="$output"
  tool_mode=$(printf '%s\n' "$mode_output" | sed -n '1p')
  sudo_mode=$(printf '%s\n' "$mode_output" | sed -n '2p')
  # Everything from line 3 onward is the current full SUID inventory.
  current_suid_list=$(printf '%s\n' "$mode_output" | tail -n +3)

  # grep -v containerd here too: an instance bootstrapped before this filter existed may
  # still have old containerd snapshot paths baked into its on-disk baseline file.
  run ssh "${SSH_OPTS[@]}" "$cp" "sudo cat /var/lib/cks-lab105/system-suid-baseline.txt 2>/dev/null | grep -v '^/var/lib/containerd/'"
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
  # 'su - ubuntu' without sudo always demands ubuntu's password (PAM does not skip
  # re-auth just because the target user matches the caller) - since this ssh session
  # itself already runs as ubuntu (not root), a bare 'su' here would ALWAYS fail with
  # "Authentication failure" for every student, making this check unpassable regardless
  # of the actual limits.conf state. Use 'sudo su' so root can switch without a password.
  run ssh "${SSH_OPTS[@]}" "$cp" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo cat /etc/sysctl.d/99-kubernetes.conf 2>/dev/null; sudo cat /etc/security/limits.conf 2>/dev/null; sudo su - ubuntu -c 'ulimit -c'"
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
    && grep -qx "NO_NEW_DUMP" <<<"$crash_probe_result" \
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
    elif ! grep -qx "NO_NEW_DUMP" <<<"$crash_probe_result"; then
      echo "HINT: A real SIGSEGV crash produced a NEW retained core dump (found in /var/lib/apport/coredump or /var/crash) despite your sysctl/limits settings. This proves core dumps are not actually disabled end-to-end - double check kernel.core_pattern is really applied (not just written to the file) with 'sysctl --system'."
    else
      echo "HINT: Runtime values look correct, but the evidence file coredump.txt is missing one of the required exact lines: '0', 'fs.suid_dumpable = 0', or 'hard core 0'."
    fi
    echo "dumpable_value=$dumpable_value core_pattern_value=$core_pattern_value ulimit_value=$ulimit_value crash_probe_result=$crash_probe_result combined=$combined"
    result=1
  fi
  [ "$result" -eq 0 ]
}
