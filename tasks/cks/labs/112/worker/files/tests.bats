#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="runtime-112"
FALCO_RULES="/etc/falco/falco_rules.local.yaml"
AUDIT_POLICY="/etc/kubernetes/audit/policy.yaml"
AUDIT_LOG="/var/log/kubernetes/audit/audit.log"
APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Falco is installed, active, and uses the modern eBPF engine" {
  echo '1' >> /var/work/tests/result/all
  version=$(ssh -o BatchMode=yes control-plane 'falco --version 2>/dev/null | head -1' 2>/dev/null || true)
  active=$(ssh -o BatchMode=yes control-plane 'systemctl is-active falco 2>/dev/null' 2>/dev/null || true)
  engine=$(ssh -o BatchMode=yes control-plane "sudo grep -R -E '^[[:space:]]*kind:[[:space:]]*modern_ebpf' /etc/falco 2>/dev/null" 2>/dev/null || true)
  if [[ -n "$version" && "$active" == "active" && -n "$engine" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$version" ]]; then
      echo "HINT: 'falco --version' produced no output on control-plane - check Falco is actually installed from the official repository."
    elif [[ "$active" != "active" ]]; then
      echo "HINT: Falco systemd service is not active - check 'systemctl status falco' for the actual startup error."
    else
      echo "HINT: No config file shows 'kind: modern_ebpf' - check you selected the modern eBPF engine, not the legacy kernel module, during install."
    fi
    echo "version=${version:-missing} active=${active:-missing} engine=${engine:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. A shell in the prepared container was detected by the standard Falco rule" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod falco-shell -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  image=$(jq -r '.spec.containers[]? | select(.name == "app") | .image' <<<"$pod" 2>/dev/null)
  stdin=$(jq -r '.spec.containers[]? | select(.name == "app") | .stdin == true' <<<"$pod" 2>/dev/null)
  tty=$(jq -r '.spec.containers[]? | select(.name == "app") | .tty == true' <<<"$pod" 2>/dev/null)
  artifact=/var/work/tests/artifacts/2/falco-shell.log
  journal_lines=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco-modern-bpf -b --no-pager | grep -F -e 'A shell was spawned in a container with an attached terminal' -e 'Terminal shell in container'" 2>/dev/null || true)
  artifact_line=$(tail -n1 "$artifact" 2>/dev/null || true)
  contained=false
  [[ -s /var/work/tests/artifacts/6/containment.txt ]] && contained=true
  pod_state_ok=false
  [[ "$phase" == "Running" && "$image" == "busybox:1.36" && "$stdin" == "true" && "$tty" == "true" ]] && pod_state_ok=true
  [[ -z "$phase" && "$contained" == true ]] && pod_state_ok=true
  if [[ "$pod_state_ok" == true && -n "$journal_lines" && -s "$artifact" && -n "$artifact_line" ]] \
     && grep -Fxq "$artifact_line" <<<"$journal_lines"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$pod_state_ok" != true ]]; then
      echo "HINT: Pod 'falco-shell' must be Running with image busybox:1.36, stdin: true, and tty: true - an interactive TTY session is what triggers the 'Terminal shell in container' rule."
    elif [[ -z "$journal_lines" ]]; then
      echo "HINT: No terminal-shell alert ('A shell was spawned in a container with an attached terminal') found in Falco's journal - open an actual interactive shell into the Pod (kubectl exec -it) rather than a one-shot command."
    else
      echo "HINT: falco-shell.log's last line is not an exact copy of a real journalctl line for this alert - copy the real line verbatim, do not paraphrase or hand-write it."
    fi
    echo "phase=$phase image=$image stdin=$stdin tty=$tty artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. The local Falco rule detects the controlled custom marker" {
  echo '1' >> /var/work/tests/result/all
  local_rule=$(ssh -o BatchMode=yes control-plane "sudo test -r '$FALCO_RULES' && sudo cat '$FALCO_RULES'" 2>/dev/null || true)
  active=$(ssh -o BatchMode=yes control-plane 'systemctl is-active falco 2>/dev/null' 2>/dev/null || true)
  artifact=/var/work/tests/artifacts/3/falco-custom.log
  journal_lines=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco-modern-bpf -b --no-pager | grep -F 'CKS112 custom shell marker'" 2>/dev/null || true)
  artifact_line=$(tail -n1 "$artifact" 2>/dev/null || true)
  custom_rule_block=$(awk '
    /^- rule: CKS112 Custom Shell Marker$/ { found=1 }
    found && /^- rule:/ && $0 !~ /CKS112 Custom Shell Marker/ { exit }
    found { print }
  ' <<<"$local_rule" 2>/dev/null || true)
  rule_ok=0
  if [[ "$custom_rule_block" == *'spawned_process'* ]] \
     && grep -qE 'container([^.[:alnum:]]|$)' <<<"$custom_rule_block" \
     && [[ "$custom_rule_block" == *'proc.cmdline contains "CKS112_CUSTOM_EVENT"'* \
     && "$custom_rule_block" == *'CKS112 custom shell marker'* \
     && "$custom_rule_block" == *'container=%container.id'* \
     && "$custom_rule_block" == *'pid=%proc.pid'* \
     && "$custom_rule_block" == *'ppid=%proc.ppid'* ]]; then
    rule_ok=1
  fi
  if [[ "$active" == "active" && "$rule_ok" -eq 1 && -n "$journal_lines" && -s "$artifact" ]] \
     && [[ -n "$artifact_line" ]] && grep -Fxq "$artifact_line" <<<"$journal_lines"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$rule_ok" -ne 1 ]]; then
      echo "HINT: falco_rules.local.yaml must have a rule named 'CKS112 Custom Shell Marker' whose OWN condition includes 'spawned_process' and 'container' (scoped to processes inside a container, not the host) together with 'proc.cmdline contains \"CKS112_CUSTOM_EVENT\"', and output fields container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name plus the exact phrase 'CKS112 custom shell marker'."
    elif [[ -z "$journal_lines" ]]; then
      echo "HINT: No matching alert found in Falco's journal - after adding the local rule, restart Falco, then actually run a command containing 'CKS112_CUSTOM_EVENT' inside a container."
    else
      echo "HINT: falco-custom.log is missing or its last line is not an exact copy of a real journalctl line for this alert - copy the real line verbatim, do not paraphrase or hand-write it."
    fi
    echo "falco_active=$active rule_present=$([[ -n "$local_rule" ]] && echo yes || echo no) artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

# An evidence artifact must be a genuine event from the API server audit log: its auditID has to
# be present in the log on the node (a hand-written or edited file will not be). It cannot be
# compared with the checker's own fresh request - that event has a different auditID/timestamp.
audit_artifact_is_real() {
  local id
  id=$(jq -r '.auditID // empty' "$1" 2>/dev/null) || return 1
  [[ "$id" =~ ^[0-9a-f-]{36}$ ]] || return 1
  ssh -o BatchMode=yes control-plane "sudo grep -Fq '\"auditID\":\"$id\"' '$AUDIT_LOG'" 2>/dev/null
}

@test "4. kube-apiserver audits ConfigMap at RequestResponse but Secret only at Metadata (no body)" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(ssh -o BatchMode=yes control-plane "sudo cat '$APISERVER_MANIFEST'" 2>/dev/null || true)
  policy=$(ssh -o BatchMode=yes control-plane "sudo cat '$AUDIT_POLICY'" 2>/dev/null || true)
  ready=$(kubectl get --context "$CTX" --raw=/readyz 2>/dev/null || true)
  audit_lines_before=$(ssh -o BatchMode=yes control-plane "sudo test -r '$AUDIT_LOG' && sudo wc -l < '$AUDIT_LOG'" 2>/dev/null || echo 0)
  kubectl get configmap audit-config -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  kubectl get secret audit-secret -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  sleep 3
  cm_event=$(ssh -o BatchMode=yes control-plane "sudo tail -n +$((audit_lines_before + 1)) '$AUDIT_LOG' | jq -c -e 'select(.level == \"RequestResponse\" and .objectRef.resource == \"configmaps\" and .objectRef.namespace == \"$NS\" and .objectRef.name == \"audit-config\")' | tail -1" 2>/dev/null || true)
  secret_event=$(ssh -o BatchMode=yes control-plane "sudo tail -n +$((audit_lines_before + 1)) '$AUDIT_LOG' | jq -c -e 'select(.level == \"Metadata\" and .objectRef.resource == \"secrets\" and .objectRef.namespace == \"$NS\" and .objectRef.name == \"audit-secret\" and (has(\"requestObject\") | not) and (has(\"responseObject\") | not))' | tail -1" 2>/dev/null || true)
  cm_artifact=/var/work/tests/artifacts/4/configmap-request-response.json
  secret_artifact=/var/work/tests/artifacts/4/secret-metadata.json
  if [[ "$ready" == "ok" \
        && "$manifest" == *'--audit-policy-file=/etc/kubernetes/audit/policy.yaml'* \
        && "$manifest" == *'--audit-log-path=/var/log/kubernetes/audit/audit.log'* \
        && "$manifest" == *'/etc/kubernetes/audit'* \
        && "$manifest" == *'/var/log/kubernetes/audit'* \
        && "$policy" == *'level: RequestResponse'* \
        && "$policy" == *'namespaces: ["runtime-112"]'* \
        && "$policy" == *'resources: ["configmaps"]'* \
        && "$policy" == *'resources: ["secrets"]'* \
        && -n "$cm_event" && -n "$secret_event" && -s "$cm_artifact" && -s "$secret_artifact" ]] \
     && jq -e '.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.name == "audit-config"' "$cm_artifact" >/dev/null 2>&1 \
     && jq -e '.level == "Metadata" and .objectRef.resource == "secrets" and .objectRef.name == "audit-secret" and (has("requestObject") | not) and (has("responseObject") | not)' "$secret_artifact" >/dev/null 2>&1 \
     && audit_artifact_is_real "$cm_artifact" \
     && audit_artifact_is_real "$secret_artifact"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$manifest" != *'--audit-policy-file='* || "$manifest" != *'--audit-log-path='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --audit-policy-file and/or --audit-log-path flags, or the hostPath volumes for /etc/kubernetes/audit and /var/log/kubernetes/audit."
    elif [[ "$policy" != *'namespaces: ["runtime-112"]'* || "$policy" != *'resources: ["configmaps"]'* ]]; then
      echo "HINT: policy.yaml must scope the RequestResponse rule to namespaces ['runtime-112'] and resources ['configmaps'] exactly."
    elif [[ "$policy" != *'resources: ["secrets"]'* ]]; then
      echo "HINT: policy.yaml is missing a separate rule for resources ['secrets'] at level: Metadata (never RequestResponse, to avoid logging the Secret body)."
    elif [[ -z "$cm_event" || -z "$secret_event" ]]; then
      echo "HINT: No matching audit event found in the log for the ConfigMap/Secret read - check the audit policy actually applied (API server restarted after manifest edit) BEFORE you made the read requests."
    else
      echo "HINT: One of the two saved evidence files does not match the exact expected structure - configmap-request-response.json needs level RequestResponse, secret-metadata.json needs level Metadata with NO requestObject/responseObject keys at all (proving the Secret body was never logged)."
    fi
    echo "ready=$ready cm_policy=$([[ "$policy" == *'resources: ["configmaps"]'* ]] && echo yes || echo no) secret_policy=$([[ "$policy" == *'resources: ["secrets"]'* ]] && echo yes || echo no) cm_event=$([[ -n "$cm_event" ]] && echo yes || echo no) secret_event=$([[ -n "$secret_event" ]] && echo yes || echo no)"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. immutable-app rejects rootfs writes but retains a writable emptyDir /tmp" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod immutable-app -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  readonly=$(jq -r '.spec.containers[]? | select(.name == "app") | .securityContext.readOnlyRootFilesystem == true' <<<"$pod" 2>/dev/null)
  writable_tmp=$(jq -r '([.spec.volumes[]? | select(.name == "writable-tmp" and .emptyDir != null)] | length == 1) and ([.spec.containers[]? | select(.name == "app") | .volumeMounts[]? | select(.name == "writable-tmp" and .mountPath == "/tmp" and (.readOnly // false) == false)] | length == 1)' <<<"$pod" 2>/dev/null)
  host_paths=$(jq -r '[.spec.volumes[]? | select(.hostPath != null)] | length' <<<"$pod" 2>/dev/null)
  set +e
  rootfs_output=$(kubectl exec -n "$NS" immutable-app --context "$CTX" -- sh -c 'touch /cks-112-write-denied' 2>&1)
  rootfs_status=$?
  tmp_output=$(kubectl exec -n "$NS" immutable-app --context "$CTX" -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed' 2>&1)
  tmp_status=$?
  set -e
  artifact=/var/work/tests/artifacts/5/rootfs-write-denied.log
  if [[ "$phase" == "Running" && "$readonly" == "true" && "$writable_tmp" == "true" && "$host_paths" == "0" && "$rootfs_status" -ne 0 && "$tmp_status" -eq 0 && -s "$artifact" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$readonly" != "true" ]]; then
      echo "HINT: Container 'app' must set securityContext.readOnlyRootFilesystem: true."
    elif [[ "$writable_tmp" != "true" ]]; then
      echo "HINT: An emptyDir volume 'writable-tmp' must be mounted at exactly '/tmp' without readOnly:true."
    elif [[ "$host_paths" != "0" ]]; then
      echo "HINT: Do not use hostPath for the writable mount - it must be emptyDir."
    elif [[ "$rootfs_status" -eq 0 ]]; then
      echo "HINT: Writing outside /tmp (to /cks-112-write-denied) succeeded - it should fail once readOnlyRootFilesystem is truly in effect. Check the Pod actually restarted with the new spec."
    elif [[ "$tmp_status" -ne 0 ]]; then
      echo "HINT: Writing to /tmp failed - the writable-tmp mount is not working there. Check mountPath spelling."
    fi
    echo "phase=$phase readonly=$readonly writable_tmp=$writable_tmp host_paths=$host_paths rootfs_status=$rootfs_status rootfs_output=$rootfs_output tmp_status=$tmp_status tmp_output=$tmp_output artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. Minimal containment chain correlates Falco alert through CRI, proc, audit, and isolation" {
  echo '1' >> /var/work/tests/result/all
  dir=/var/work/tests/artifacts/6
  summary="$dir/evidence-summary.txt"
  alert="$dir/falco-alert.log"
  cri_container="$dir/cri-container.json"
  cri_sandbox="$dir/cri-sandbox.json"
  audit_event="$dir/audit-exec.json"

  container_id=$(awk -F= '$1 == "container_id" {print $2}' "$summary" 2>/dev/null)
  host_pid=$(awk -F= '$1 == "host_pid" {print $2}' "$summary" 2>/dev/null)
  node=$(awk -F= '$1 == "node" {print $2}' "$summary" 2>/dev/null)
  current_node=$(kubectl get nodes --context "$CTX" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  journal=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco-modern-bpf -b --no-pager | grep -F 'CKS112 custom shell marker' | tail -20" 2>/dev/null || true)

  np=$(kubectl get networkpolicy incident-quarantine -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  quarantine=$(jq -r '(.spec.podSelector == {}) and ((.spec.policyTypes | sort) == ["Egress","Ingress"]) and ((.spec.ingress // []) | length == 0) and ((.spec.egress // []) | length == 0)' <<<"$np" 2>/dev/null)
  run kubectl get pod falco-shell -n "$NS" --context "$CTX"
  pod_absent=$status
  run kubectl exec -n "$NS" falco-shell --context "$CTX" -- sh -c 'echo CKS112_CUSTOM_EVENT'
  exec_status=$status

  evidence_ok=true
  [[ -s "$summary" && -s "$alert" && -s "$cri_container" && -s "$cri_sandbox" \
     && -s "$dir/proc-status.txt" && -s "$dir/proc-cmdline.txt" \
     && -s "$dir/proc-cgroup.txt" && -s "$dir/process-tree.txt" \
     && -s "$audit_event" && -s "$dir/containment.txt" ]] || evidence_ok=false
  [[ "$container_id" =~ ^[a-f0-9]{12,64}$ && "$host_pid" =~ ^[0-9]+$ && "$node" == "$current_node" ]] || evidence_ok=false
  grep -Fq 'CKS112 custom shell marker' "$alert" 2>/dev/null || evidence_ok=false
  grep -Fq "container=${container_id:0:12}" "$alert" 2>/dev/null || grep -Fq "container=$container_id" "$alert" 2>/dev/null || evidence_ok=false
  grep -Fq "pid=$host_pid" "$alert" 2>/dev/null || evidence_ok=false
  grep -Fq "$(tail -n1 "$alert" 2>/dev/null)" <<<"$journal" || evidence_ok=false
  grep -Fq "$container_id" "$cri_container" 2>/dev/null || evidence_ok=false
  grep -Fq 'falco-shell' "$cri_sandbox" 2>/dev/null || evidence_ok=false
  grep -Eq "^Pid:[[:space:]]+$host_pid$" "$dir/proc-status.txt" 2>/dev/null || evidence_ok=false
  grep -Fq 'CKS112_CUSTOM_EVENT' "$dir/proc-cmdline.txt" 2>/dev/null || evidence_ok=false
  grep -Fq "${container_id:0:12}" "$dir/proc-cgroup.txt" 2>/dev/null || evidence_ok=false
  grep -Eq "(^|[[:space:]])$host_pid([[:space:]]|$)" "$dir/process-tree.txt" 2>/dev/null || evidence_ok=false
  grep -q '^namespace=runtime-112$' "$summary" 2>/dev/null || evidence_ok=false
  grep -q '^pod=falco-shell$' "$summary" 2>/dev/null || evidence_ok=false
  grep -q '^runtime=containerd$' "$summary" 2>/dev/null || evidence_ok=false
  grep -q '^attack_phase=Execution$' "$summary" 2>/dev/null || evidence_ok=false
  grep -q '^technique=Container Administration Command$' "$summary" 2>/dev/null || evidence_ok=false
  grep -q '^containment=quarantine-and-delete$' "$summary" 2>/dev/null || evidence_ok=false
  jq -e '.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell" and (has("requestObject") | not) and (has("responseObject") | not)' "$audit_event" >/dev/null 2>&1 || evidence_ok=false

  if [[ "$evidence_ok" == true && "$quarantine" == true && "$pod_absent" -ne 0 && "$exec_status" -ne 0 ]] \
    && grep -Eq '^exec_exit=[1-9][0-9]*$' "$dir/containment.txt"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$evidence_ok" != true ]]; then
      echo "HINT: One of the many correlation checks failed (evidence_ok=false) - this test requires the SAME container_id/host_pid/node to appear consistently across the Falco alert, CRI inspect output, /proc files, process tree, and audit event. Start from a NEW Falco alert (not the manifest), extract container_id/host_pid from it first, then gather each piece of evidence for that exact PID/container while the process is still alive - do not mix evidence from different runs."
    elif [[ "$quarantine" != true ]]; then
      echo "HINT: NetworkPolicy 'incident-quarantine' must select all Pods ({}) with policyTypes [Ingress, Egress] and empty ingress/egress arrays - a true default-deny, applied as part of containment."
    elif [[ "$pod_absent" -eq 0 ]]; then
      echo "HINT: Pod 'falco-shell' still exists - containment requires deleting the compromised Pod after saving evidence."
    elif [[ "$exec_status" -eq 0 ]]; then
      echo "HINT: 'kubectl exec' into the (deleted) falco-shell still succeeded - the Pod must actually be gone, or NetworkPolicy/deletion did not take effect as expected."
    else
      echo "HINT: containment.txt is missing the exact line 'exec_exit=<nonzero>' - save the numeric exit code of your negative-control exec attempt in this format."
    fi
    echo "evidence_ok=$evidence_ok quarantine=$quarantine pod_absent_status=$pod_absent exec_status=$exec_status container_id=$container_id host_pid=$host_pid node=$node current_node=$current_node"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. user_expected_terminal_shell_in_container_conditions macro override suppresses ci-runner alert; output carries k8s.pod.name/k8s.ns.name via structured JSON" {
  echo '1' >> /var/work/tests/result/all
  local_rule=$(ssh -o BatchMode=yes control-plane "sudo test -r '$FALCO_RULES' && sudo cat '$FALCO_RULES'" 2>/dev/null || true)
  config_d=$(ssh -o BatchMode=yes control-plane "sudo cat /etc/falco/config.d/cks112-output.yaml" 2>/dev/null || true)
  active=$(ssh -o BatchMode=yes control-plane 'systemctl is-active falco 2>/dev/null' 2>/dev/null || true)

  ci_pod=$(kubectl get pod ci-runner -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  ci_phase=$(jq -r '.status.phase // ""' <<<"$ci_pod" 2>/dev/null)
  ci_stdin=$(jq -r '.spec.containers[]? | select(.name == "app") | .stdin == true' <<<"$ci_pod" 2>/dev/null)
  ci_tty=$(jq -r '.spec.containers[]? | select(.name == "app") | .tty == true' <<<"$ci_pod" 2>/dev/null)

  # Generate one fresh shell event in each Pod so this test does not depend on stale
  # journal/file content from earlier in the session. immutable-app (task 5) is used as
  # the positive (non-excluded) control here - falco-shell (task 2) was already deleted
  # as part of the task 6 containment chain and no longer exists at this point in the lab.
  # Use a real pseudo-TTY (via `script`) rather than a plain `sh -c`, because the
  # "Terminal shell in container" rule's condition requires an actual TTY - a plain
  # non-interactive exec is not equivalent to the student-facing `kubectl exec -it`.
  # Note: fresh-vs-stale is decided purely from the events.log line offset below, not from
  # a journalctl --since timestamp - a timestamp taken on the worker and interpreted on
  # control-plane would be fragile to clock skew between the two machines.
  events_before=$(ssh -o BatchMode=yes control-plane \
    'sudo test -f /var/log/falco/events.log && sudo wc -l < /var/log/falco/events.log || echo 0' 2>/dev/null || echo 0)

  run script -qefc \
    "kubectl exec -n '$NS' ci-runner --context '$CTX' -it -- sh -c 'echo t7-ci-runner; sleep 1'" \
    /dev/null
  ci_exec_status="$status"

  run script -qefc \
    "kubectl exec -n '$NS' immutable-app --context '$CTX' -it -- sh -c 'echo t7-immutable-app; sleep 1'" \
    /dev/null
  positive_exec_status="$status"

  sleep 3

  events_log=$(ssh -o BatchMode=yes control-plane "sudo test -f /var/log/falco/events.log && sudo tail -n +$((events_before + 1)) /var/log/falco/events.log" 2>/dev/null || true)
  ci_json=""
  positive_json=""
  if [[ -n "$events_log" ]]; then
    ci_json=$(echo "$events_log" | jq -c 'select(.rule == "Terminal shell in container") | select(.output_fields["k8s.pod.name"] == "ci-runner" and .output_fields["k8s.ns.name"] == "runtime-112")' 2>/dev/null | tail -1)
    positive_json=$(echo "$events_log" | jq -c 'select(.rule == "Terminal shell in container") | select(.output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' 2>/dev/null | tail -1)
  fi
  pod_field=$(jq -r '.output_fields["k8s.pod.name"] // ""' <<<"$positive_json" 2>/dev/null)
  ns_field=$(jq -r '.output_fields["k8s.ns.name"] // ""' <<<"$positive_json" 2>/dev/null)

  # This must target the macro that actually gates "Terminal shell in container"
  # (user_expected_terminal_shell_in_container_conditions), using k8s.pod.name/k8s.ns.name.
  # user_shell_container_exclusions gates a different rule ("Run shell untrusted") and
  # container.name identifies the container, not the Pod - both would silently pass this
  # test while not actually suppressing the intended alert.
  if [[ "$active" == "active" \
    && "$local_rule" == *'macro: user_expected_terminal_shell_in_container_conditions'* \
    && "$local_rule" == *'k8s.pod.name = "ci-runner"'* \
    && "$local_rule" == *'k8s.ns.name = "runtime-112"'* \
    && "$local_rule" != *'condition: (never_true)'* \
    && "$local_rule" != *'container.name = "ci-runner"'* \
    && "$local_rule" == *'rule: Terminal shell in container'* \
    && "$local_rule" == *'override:'*'output: append'* \
    && "$config_d" == *'json_output: true'* \
    && "$config_d" == *'/var/log/falco/events.log'* \
    && "$ci_phase" == "Running" && "$ci_stdin" == "true" && "$ci_tty" == "true" \
    && "$ci_exec_status" -eq 0 && "$positive_exec_status" -eq 0 \
    && -z "$ci_json" \
    && "$pod_field" == "immutable-app" && "$ns_field" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$local_rule" != *'macro: user_expected_terminal_shell_in_container_conditions'* ]]; then
      echo "HINT: You must override the macro 'user_expected_terminal_shell_in_container_conditions' (not 'user_shell_container_exclusions', which gates a DIFFERENT rule)."
    elif [[ "$local_rule" == *'container.name = "ci-runner"'* ]]; then
      echo "HINT: Your condition uses container.name instead of k8s.pod.name - container.name is the CONTAINER's name ('app' in this lab), not the Pod's name, and will not correctly scope to ci-runner."
    elif [[ -n "$ci_json" ]]; then
      echo "HINT: ci-runner still triggered 'Terminal shell in container' - the macro override is not suppressing it. Double check the condition uses exact k8s.pod.name/k8s.ns.name matches and that Falco was restarted after the change."
    elif [[ "$local_rule" != *'override:'*'output: append'* ]]; then
      echo "HINT: You must ALSO add a second override on the rule itself (override: {output: append}) to append %k8s.pod.name/%k8s.ns.name to the alert output - the default output for 'Terminal shell in container' does not include these fields."
    elif [[ "$pod_field" != "immutable-app" || "$ns_field" != "$NS" ]]; then
      echo "HINT: The JSON alert's output_fields does not show k8s.pod.name=immutable-app and k8s.ns.name=$NS for a FRESH alert generated just now (immutable-app from task 5 is used as the positive control - falco-shell from task 2 was already deleted in task 6) - check json_output/file_output are enabled in /etc/falco/config.d/, and that you generated a fresh alert after all config changes were applied."
    fi
    echo "active=$active macro_overridden=$([[ "$local_rule" == *'user_expected_terminal_shell_in_container_conditions'* ]] && echo yes || echo no) ci_phase=$ci_phase ci_exec_status=$ci_exec_status positive_exec_status=$positive_exec_status ci_json=${ci_json:-none} pod_field=$pod_field ns_field=$ns_field"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Audit webhook backend delivers events to the in-cluster receiver alongside the local file backend" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(ssh -o BatchMode=yes control-plane "sudo cat '$APISERVER_MANIFEST'" 2>/dev/null || true)
  webhook_config=$(ssh -o BatchMode=yes control-plane "sudo cat /etc/kubernetes/audit/webhook-config.yaml" 2>/dev/null || true)
  ready=$(kubectl get --context "$CTX" --raw=/readyz 2>/dev/null || true)

  receiver_pod=$(kubectl get deployment audit-receiver -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  receiver_available=$(jq -r '.status.availableReplicas // 0' <<<"$receiver_pod" 2>/dev/null)
  receiver_svc=$(kubectl get service audit-receiver -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  receiver_port=$(jq -r '.spec.ports[]?.port' <<<"$receiver_svc" 2>/dev/null)

  # Baseline the receiver's log length BEFORE the fresh request, so a stale delivery from
  # an earlier (possibly broken-since) prompt cannot count as evidence for this run.
  receiver_pod_name=$(kubectl get pod -n "$NS" --context "$CTX" -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  logs_before=$(kubectl logs -n "$NS" --context "$CTX" "$receiver_pod_name" 2>/dev/null | wc -l)

  kubectl get configmap audit-config -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  sleep 3
  receiver_logs=$(kubectl logs -n "$NS" --context "$CTX" "$receiver_pod_name" 2>/dev/null | tail -n +"$((logs_before + 1))")

  # The echo receiver pretty-prints the parsed body ("resource": "configmaps"), so allow optional spaces.
  logs_match=no
  if grep -Eq '"resource": ?"configmaps"' <<<"$receiver_logs" && grep -Eq '"name": ?"audit-config"' <<<"$receiver_logs"; then
    logs_match=yes
  fi

  if [[ "$ready" == "ok" \
    && "$manifest" == *'--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml'* \
    && "$manifest" == *'--audit-webhook-batch-max-wait='* \
    && "$manifest" == *'--audit-policy-file=/etc/kubernetes/audit/policy.yaml'* \
    && "$manifest" == *'--audit-log-path=/var/log/kubernetes/audit/audit.log'* \
    && "$webhook_config" == *'server: http://'* \
    && "$receiver_available" -ge 1 && -n "$receiver_port" \
    && "$logs_match" == yes ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$receiver_available" -lt 1 ]]; then
      echo "HINT: Deployment 'audit-receiver' has no available replicas - check it deployed successfully and its Service exists."
    elif [[ "$webhook_config" != *'server: http://'* ]]; then
      echo "HINT: webhook-config.yaml must be a valid kubeconfig-shaped file with a 'server: http://<receiver-ClusterIP>:8080/audit' entry."
    elif [[ "$manifest" != *'--audit-webhook-config-file='* || "$manifest" != *'--audit-webhook-batch-max-wait='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --audit-webhook-config-file and/or --audit-webhook-batch-max-wait - and make sure the EXISTING --audit-policy-file/--audit-log-path flags from task 4 are still present, the webhook is meant to complement the file backend, not replace it."
    else
      echo "HINT: A FRESH GET of configmaps/audit-config just made by this check did not show up in audit-receiver's logs written AFTER that request - a stale delivery from earlier in the session does not count. Make sure the webhook is still actually delivering events right now, and that the receiver Service selector matches its Pod."
    fi
    echo "ready=$ready webhook_flag=$([[ "$manifest" == *'audit-webhook-config-file'* ]] && echo yes || echo no) receiver_available=$receiver_available receiver_port=${receiver_port:-missing} logs_before=$logs_before fresh_logs_have_configmaps_audit_config=$logs_match"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. Kyverno blocks untrusted registry on admission and Falco detects a direct containerd bypass attempt with exact (non-prefix) allowlist semantics" {
  echo '1' >> /var/work/tests/result/all
  # Lab-owned local registry names seeded at bootstrap (ADVERSARIAL_ACCEPTANCE_STANDARD.md:
  # safe, lab-owned fixtures only - Task 9 must not depend on Docker Hub at grading time).
  registry_env=$(ssh -o BatchMode=yes control-plane "sudo test -r /etc/cks112/registry.env && sudo cat /etc/cks112/registry.env" 2>/dev/null || true)
  CKS112_REGISTRY=$(sed -n "s/^export CKS112_REGISTRY='\(.*\)'\$/\1/p" <<<"$registry_env" | tail -1)
  CKS112_TRUSTED_REPO=$(sed -n "s/^export CKS112_TRUSTED_REPO='\(.*\)'\$/\1/p" <<<"$registry_env" | tail -1)
  CKS112_TRUSTED_IMAGE=$(sed -n "s/^export CKS112_TRUSTED_IMAGE='\(.*\)'\$/\1/p" <<<"$registry_env" | tail -1)
  CKS112_UNTRUSTED_IMAGE=$(sed -n "s/^export CKS112_UNTRUSTED_IMAGE='\(.*\)'\$/\1/p" <<<"$registry_env" | tail -1)

  crd=$(kubectl get crd validatingpolicies.policies.kyverno.io -o name --context "$CTX" 2>/dev/null || true)
  policy=$(kubectl get validatingpolicy require-trusted-registry-runtime-112 -o json --context "$CTX" 2>/dev/null || true)
  policy_ok=0
  policy_message=$(jq -r '[.spec.validations[]?.message, .spec.validations[]?.messageExpression] | join(" ")' <<<"$policy" 2>/dev/null)
  policy_expr=$(jq -r '[.spec.validations[]?.expression] | join(" ")' <<<"$policy" 2>/dev/null)
  if [[ -n "$policy" ]] \
    && echo "$policy" | jq -e '.apiVersion == "policies.kyverno.io/v1" and (.spec.validationActions | index("Deny") != null)' >/dev/null 2>&1 \
    && [[ "$policy_message" == *'CKS112_TRUSTED_REPO_POLICY'* ]] \
    && [[ "$policy_expr" == *'registry()'* && "$policy_expr" == *'repository()'* ]] \
    && [[ -n "$CKS112_REGISTRY" && -n "$CKS112_TRUSTED_REPO" ]] \
    && [[ "$policy_expr" == *"'${CKS112_REGISTRY}'"* && "$policy_expr" == *"'${CKS112_TRUSTED_REPO}'"* ]] \
    && [[ "$policy_expr" != *'startsWith'* ]]; then
    policy_ok=1
  fi
  set +e
  kubectl get pod blocked-attempt -n "$NS" --context "$CTX" >/dev/null 2>&1
  blocked_absent=$?
  set -e
  deny_artifact=/var/work/tests/artifacts/9/admission-deny.txt
  bypass_artifact=/var/work/tests/artifacts/9/falco-bypass-attempt.log
  observed_artifact=/var/work/tests/artifacts/9/observed-trusted-repo.txt
  observed_repo=$(tr -d '[:space:]' < "$observed_artifact" 2>/dev/null || true)
  local_rule=$(ssh -o BatchMode=yes control-plane "sudo test -r '$FALCO_RULES' && sudo cat '$FALCO_RULES'" 2>/dev/null || true)
  bypass_rule_block=$(awk '
    /rule: CKS112 Runtime Bypass of Admission/ { found=1 }
    found && /^- rule:/ && !/CKS112 Runtime Bypass of Admission/ { exit }
    found && /^$/ && NR>1 { exit }
    found { print }
  ' <<<"$local_rule" 2>/dev/null || true)
  falco_condition_ok=0
  if [[ "$local_rule" == *'rule: CKS112 Runtime Bypass of Admission'* \
     && "$local_rule" == *'CKS112_CTR_BYPASS'* \
     && "$local_rule" == *'container.image.repository'* \
     && "$bypass_rule_block" != *'startswith'* && "$bypass_rule_block" != *'startsWith'* \
     && ( "$bypass_rule_block" == *'container.image.repository !='* || "$bypass_rule_block" == *'container.image.repository =='* ) \
     && -n "$observed_repo" \
     && "$bypass_rule_block" == *"$observed_repo"* ]]; then
    falco_condition_ok=1
  fi

  # Checker-owned fresh admission controls: the static evidence files above can be
  # hand-written, so independently re-prove BOTH sides of the same admission control with
  # probes this test creates itself - a policy that denies everything (not just untrusted
  # images) must not be able to pass just because the negative probe was denied.
  admission_probe="cks112-admission-check-${BATS_TEST_NUMBER:-9}-$$"
  admission_ok=0
  if [[ -n "$CKS112_UNTRUSTED_IMAGE" ]]; then
    run kubectl run "$admission_probe" -n "$NS" --context "$CTX" --image="$CKS112_UNTRUSTED_IMAGE" --image-pull-policy=IfNotPresent --restart=Never
    admission_rc="$status"
    admission_output="$output"
    run kubectl get pod "$admission_probe" -n "$NS" --context "$CTX"
    admission_pod_absent="$status"
    if [[ "$admission_rc" -ne 0 && "$admission_pod_absent" -ne 0 ]] \
       && grep -Fq 'CKS112_TRUSTED_REPO_POLICY' <<<"$admission_output"; then
      admission_ok=1
    fi
  fi

  trusted_admission_probe="cks112-admission-trusted-${BATS_TEST_NUMBER:-9}-$$"
  trusted_admission_ok=0
  if [[ -n "$CKS112_TRUSTED_IMAGE" ]]; then
    run kubectl run "$trusted_admission_probe" -n "$NS" --context "$CTX" --image="$CKS112_TRUSTED_IMAGE" --image-pull-policy=IfNotPresent --restart=Never --command -- sleep 30
    trusted_admission_rc="$status"
    if [[ "$trusted_admission_rc" -eq 0 ]]; then
      run kubectl get pod "$trusted_admission_probe" -n "$NS" --context "$CTX" -o json
      if [[ "$status" -eq 0 ]] && jq -e --arg img "$CKS112_TRUSTED_IMAGE" '.spec.containers[0].image == $img' <<<"$output" >/dev/null 2>&1; then
        trusted_admission_ok=1
      fi
    fi
    kubectl delete pod "$trusted_admission_probe" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi

  # Checker-owned fresh Falco runtime controls: run our own trusted/untrusted/prefix-trap
  # containers directly through containerd rather than trusting only student-saved logs.
  # Each probe carries its OWN unique marker in the process cmdline, so the outcome is
  # decided by which marker shows up in a fresh alert - not by matching student-provided
  # observed-trusted-repo.txt text, which the student could have recorded incorrectly
  # (accidentally or otherwise) without this check noticing a real false positive.
  trusted_ok=0
  untrusted_ok=0
  prefix_ok=0
  if [[ -n "$observed_repo" && -n "$CKS112_TRUSTED_IMAGE" && -n "$CKS112_UNTRUSTED_IMAGE" ]]; then
    probe_ts=$(ssh -o BatchMode=yes control-plane "date -u '+%Y-%m-%d %H:%M:%S'" 2>/dev/null || true)
    run_id="checker-${BATS_TEST_NUMBER:-9}-$$"
    trusted_id="cks112-check-trusted-$run_id"
    untrusted_id="cks112-check-untrusted-$run_id"
    prefix_id="cks112-check-prefix-$run_id"
    trusted_marker="CKS112_CTR_BYPASS_TRUSTED_${run_id}"
    untrusted_marker="CKS112_CTR_BYPASS_UNTRUSTED_${run_id}"
    prefix_marker="CKS112_CTR_BYPASS_PREFIX_${run_id}"
    case "$observed_repo" in
      */*) prefix_ref="${observed_repo}-evil:cks112-check" ;;
      *)   prefix_ref="${CKS112_REGISTRY:-cks112.local:5000}/${observed_repo}-evil:cks112-check" ;;
    esac

    ssh -o BatchMode=yes control-plane "sudo ctr -n k8s.io images tag '$CKS112_UNTRUSTED_IMAGE' '$prefix_ref'" >/dev/null 2>&1 || true

    ssh -o BatchMode=yes control-plane "sudo cks112-run '$CKS112_TRUSTED_IMAGE' '$trusted_id' 'echo $trusted_marker; sleep 4'" >/dev/null 2>&1 || true
    ssh -o BatchMode=yes control-plane "sudo cks112-run '$CKS112_UNTRUSTED_IMAGE' '$untrusted_id' 'echo $untrusted_marker; sleep 4'" >/dev/null 2>&1 || true
    ssh -o BatchMode=yes control-plane "sudo cks112-run '$prefix_ref' '$prefix_id' 'echo $prefix_marker; sleep 4'" >/dev/null 2>&1 || true
    sleep 3

    fresh_alerts=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco-modern-bpf --since '$probe_ts' --no-pager | grep -F 'CKS112 runtime bypass of admission'" 2>/dev/null || true)

    grep -Fq "$trusted_marker" <<<"$fresh_alerts" || trusted_ok=1
    grep -Fq "$untrusted_marker" <<<"$fresh_alerts" && untrusted_ok=1
    grep -Fq "$prefix_marker" <<<"$fresh_alerts" && prefix_ok=1

    for cid in "$trusted_id" "$untrusted_id" "$prefix_id"; do
      ssh -o BatchMode=yes control-plane \
        "sudo cks112-rm '$cid'" \
        >/dev/null 2>&1 || true
    done
  fi

  if [[ -n "$crd" && "$policy_ok" -eq 1 ]] \
    && [[ "$blocked_absent" -ne 0 ]] \
    && [[ -s "$deny_artifact" ]] && grep -Fq 'CKS112_TRUSTED_REPO_POLICY' "$deny_artifact" \
    && [[ -s "$observed_artifact" ]] && [[ -n "$observed_repo" ]] \
    && [[ "$falco_condition_ok" -eq 1 ]] \
    && [[ -s "$bypass_artifact" ]] && grep -Fq 'CKS112_CTR_BYPASS' "$bypass_artifact" \
    && grep -Fq "${observed_repo}-evil" "$bypass_artifact" \
    && ! grep -Fq "repo=${observed_repo} " "$bypass_artifact" \
    && [[ "$admission_ok" -eq 1 && "$trusted_admission_ok" -eq 1 && "$trusted_ok" -eq 1 && "$untrusted_ok" -eq 1 && "$prefix_ok" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$policy_ok" -ne 1 ]]; then
      echo "HINT: ValidatingPolicy 'require-trusted-registry-runtime-112' must use CEL image().registry()=='${CKS112_REGISTRY:-<lab registry>}' and image().repository()=='${CKS112_TRUSTED_REPO:-<lab trusted repo>}' (see /etc/cks112/registry.env) with exact equality (not startsWith, which would also match names like '<trusted>-evil'), and its message/messageExpression must contain the exact marker 'CKS112_TRUSTED_REPO_POLICY' so this test can distinguish it from any other admission denial."
    elif [[ "$blocked_absent" -eq 0 ]]; then
      echo "HINT: Pod 'blocked-attempt' (untrusted image) still exists - it should have been denied by the registry policy."
    elif ! grep -Fq 'CKS112_TRUSTED_REPO_POLICY' "$deny_artifact" 2>/dev/null; then
      echo "HINT: admission-deny.txt does not contain the marker 'CKS112_TRUSTED_REPO_POLICY' - the Pod may have been rejected for an unrelated reason, or your policy message text does not match exactly."
    elif [[ ! -s "$observed_artifact" || -z "$observed_repo" ]]; then
      echo "HINT: observed-trusted-repo.txt is missing or empty - before writing the Falco condition, run the lab's trusted image (\$CKS112_TRUSTED_IMAGE, see /etc/cks112/registry.env) with a temporary observe-rule and save the ACTUAL %container.image.repository value it emits, instead of assuming a literal string. Different containerd/Falco versions may format this field differently (with or without the registry hostname)."
    elif [[ "$falco_condition_ok" -ne 1 ]]; then
      echo "HINT: falco_rules.local.yaml rule 'CKS112 Runtime Bypass of Admission' must check proc.cmdline for CKS112_CTR_BYPASS AND use an EXACT comparison on container.image.repository against the value you saved in observed-trusted-repo.txt (e.g. 'container.image.repository != \"\$TRUSTED_REPO\"'), not 'startswith'/prefix matching - a startswith check would fail to catch a repository that merely begins with the allowed string, even though the Kyverno admission policy above correctly rejects it with exact equality. Both controls must use the same comparison semantics to be equivalent security properties."
    elif ! grep -Fq "${observed_repo}-evil" "$bypass_artifact" 2>/dev/null; then
      echo "HINT: falco-bypass-attempt.log does not show a detection for the prefix-trap probe (a container tagged '<observed-trusted-repo>-evil', which starts with the allowed observed repository string but is not equal to it). This is the specific evidence that proves your Falco condition uses exact comparison rather than startswith - run the extra probe from the solution and append its alert to this log."
    elif grep -Fq "repo=${observed_repo} " "$bypass_artifact" 2>/dev/null; then
      echo "HINT: falco-bypass-attempt.log contains an alert for the TRUSTED repository itself (a false positive) - your Falco condition is triggering on the trusted image, not just the untrusted/prefix-trap ones. Check the exact-comparison logic and the observed value you're comparing against."
    elif [[ "$admission_ok" -ne 1 ]]; then
      echo "HINT: A freshly created Pod with an UNTRUSTED image was not actually denied with the marker 'CKS112_TRUSTED_REPO_POLICY' when this check ran it itself - the saved admission-deny.txt evidence alone is not sufficient, the policy must still deny right now."
    elif [[ "$trusted_admission_ok" -ne 1 ]]; then
      echo "HINT: A freshly created Pod with the TRUSTED image (\$CKS112_TRUSTED_IMAGE) was NOT admitted - a policy that denies every Pod (not just untrusted ones) would incorrectly pass the negative-only check, so this test also proves the trusted image is actually allowed."
    elif [[ "$trusted_ok" -ne 1 ]]; then
      echo "HINT: A fresh checker-owned direct-containerd run of the TRUSTED image triggered your Falco bypass rule - it must not, this is a false positive on the trusted repository."
    elif [[ "$untrusted_ok" -ne 1 ]]; then
      echo "HINT: A fresh checker-owned direct-containerd run of an UNTRUSTED image did not trigger your Falco bypass rule - the rule must detect this in real time, not just replay a saved log."
    elif [[ "$prefix_ok" -ne 1 ]]; then
      echo "HINT: A fresh checker-owned direct-containerd run using the '<observed-repo>-evil' prefix-trap image did not trigger your Falco bypass rule - this proves the condition is not truly exact (==/!=) against the observed repository value."
    else
      echo "HINT: falco-bypass-attempt.log does not show a matching alert for CKS112_CTR_BYPASS - make sure you ran 'cks112-run' with a fresh, unique container ID (not reusing one from a previous attempt still running) and that Falco restarted after adding the rule."
    fi
    echo "crd=${crd:-missing} policy_ok=$policy_ok blocked_absent=$blocked_absent deny_artifact=$deny_artifact rule_present=$([[ "$local_rule" == *'CKS112 Runtime Bypass of Admission'* ]] && echo yes || echo no) bypass_artifact=$bypass_artifact observed_repo=${observed_repo:-missing} admission_ok=$admission_ok trusted_admission_ok=$trusted_admission_ok trusted_ok=$trusted_ok untrusted_ok=$untrusted_ok prefix_ok=$prefix_ok policy_message=$policy_message policy_expr=$policy_expr"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "10. A distinct file/device-open Falco condition detects /dev/mem access and mem-scanner is scaled to zero" {
  echo '1' >> /var/work/tests/result/all
  local_rule=$(ssh -o BatchMode=yes control-plane "sudo test -r '$FALCO_RULES' && sudo cat '$FALCO_RULES'" 2>/dev/null || true)
  active=$(ssh -o BatchMode=yes control-plane 'systemctl is-active falco 2>/dev/null' 2>/dev/null || true)
  artifact=/var/work/tests/artifacts/10/falco-devmem.log
  scaled_artifact=/var/work/tests/artifacts/10/scaled-down.json
  journal_lines=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco-modern-bpf -b --no-pager | grep -F 'CKS112 Container access to /dev/mem'" 2>/dev/null || true)
  artifact_line=$(tail -n1 "$artifact" 2>/dev/null || true)
  pod_from_alert=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' <<<"$artifact_line" | tail -1)
  deployment=$(kubectl get deployment mem-scanner -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  replicas=$(jq -r '.spec.replicas // -1' <<<"$deployment" 2>/dev/null)
  if [[ "$active" == "active" \
    && "$local_rule" == *'rule: CKS112 Container access to /dev/mem'* \
    && "$local_rule" == *'evt.type in (open, openat, openat2)'* \
    && "$local_rule" == *'fd.name = /dev/mem'* \
    && "$local_rule" == *'container.id != host'* \
    && "$local_rule" == *'priority: CRITICAL'* \
    && "$local_rule" == *'container_id=%container.id'* \
    && "$local_rule" == *'k8s_pod=%k8s.pod.name'* \
    && "$local_rule" == *'k8s_ns=%k8s.ns.name'* \
    && -n "$journal_lines" && -s "$artifact" && -n "$artifact_line" ]] \
    && grep -Fxq "$artifact_line" <<<"$journal_lines" \
    && [[ -n "$pod_from_alert" && "$pod_from_alert" != "<NA>" && "$pod_from_alert" == mem-scanner-* ]] \
    && [[ "$replicas" == "0" ]] \
    && [[ -s "$scaled_artifact" ]] \
    && jq -e '.spec.replicas == 0' "$scaled_artifact" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$local_rule" != *'rule: CKS112 Container access to /dev/mem'* ]]; then
      echo "HINT: falco_rules.local.yaml is missing rule 'CKS112 Container access to /dev/mem' with condition 'evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host', priority CRITICAL, and output fields container_id=%container.id k8s_pod=%k8s.pod.name k8s_ns=%k8s.ns.name."
    elif [[ "$local_rule" == *'proc.cmdline'*'/dev/mem'* ]]; then
      echo "HINT: This task requires a file/device-open condition (evt.type in open/openat/openat2 + fd.name), not a spawned_process/proc.cmdline condition like tasks 3/7/9 - those detect process launch by command line, this one must detect the open() syscall on the device itself."
    elif [[ -z "$journal_lines" ]]; then
      echo "HINT: No matching alert found in Falco's journal - after adding the rule, restart Falco and wait for mem-scanner's next periodic /dev/mem open attempt (it loops every ~15s)."
    elif [[ ! -s "$artifact" || -z "$artifact_line" ]] || ! grep -Fxq "$artifact_line" <<<"$journal_lines" 2>/dev/null; then
      echo "HINT: falco-devmem.log is missing, empty, or its last line is not an exact copy of a real journalctl line for this alert - copy the real line verbatim, do not paraphrase or hand-write it."
    elif [[ -z "$pod_from_alert" || "$pod_from_alert" == "<NA>" || "$pod_from_alert" != mem-scanner-* ]]; then
      echo "HINT: The alert's k8s_pod field is empty, <NA>, or not a mem-scanner-* Pod name - Falco must identify the actual Pod that opened /dev/mem via k8s.pod.name, not an empty/host-level event."
    elif [[ "$replicas" != "0" ]]; then
      echo "HINT: Deployment 'mem-scanner' is not scaled to 0 replicas yet - run 'kubectl scale deployment mem-scanner -n runtime-112 --replicas=0' after you have the Falco evidence saved."
    else
      echo "HINT: scaled-down.json is missing or does not show spec.replicas == 0 - save 'kubectl get deployment mem-scanner -n runtime-112 -o json' to this path after scaling down."
    fi
    echo "active=$active rule_present=$([[ -n "$local_rule" ]] && echo yes || echo no) replicas=$replicas artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}
