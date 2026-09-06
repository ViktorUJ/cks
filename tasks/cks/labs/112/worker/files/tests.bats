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
  pod=$(kubectl get pod falco-shell -n "$NS" --context "$CTX" -o json 2>/dev/null)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  image=$(jq -r '.spec.containers[]? | select(.name == "app") | .image' <<<"$pod" 2>/dev/null)
  stdin=$(jq -r '.spec.containers[]? | select(.name == "app") | .stdin == true' <<<"$pod" 2>/dev/null)
  tty=$(jq -r '.spec.containers[]? | select(.name == "app") | .tty == true' <<<"$pod" 2>/dev/null)
  artifact=/var/work/tests/artifacts/2/falco-shell.log
  journal=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco -b --no-pager -n 1000 | grep -F 'Terminal shell in container' | tail -1" 2>/dev/null || true)
  contained=false
  [[ -s /var/work/tests/artifacts/6/containment.txt ]] && contained=true
  pod_state_ok=false
  [[ "$phase" == "Running" && "$image" == "busybox:1.36" && "$stdin" == "true" && "$tty" == "true" ]] && pod_state_ok=true
  [[ -z "$phase" && "$contained" == true ]] && pod_state_ok=true
  if [[ "$pod_state_ok" == true && -n "$journal" && -s "$artifact" ]] && grep -Fq 'Terminal shell in container' "$artifact"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$pod_state_ok" != true ]]; then
      echo "HINT: Pod 'falco-shell' must be Running with image busybox:1.36, stdin: true, and tty: true - an interactive TTY session is what triggers the 'Terminal shell in container' rule."
    elif [[ -z "$journal" ]]; then
      echo "HINT: No 'Terminal shell in container' line found in Falco's journal - open an actual interactive shell into the Pod (kubectl exec -it) rather than a one-shot command."
    else
      echo "HINT: falco-shell.log evidence file is missing or does not contain the exact alert text - copy the real journalctl line, do not paraphrase it."
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
  journal=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco -b --no-pager -n 1000 | grep -F 'CKS112 custom shell marker' | tail -1" 2>/dev/null || true)
  if [[ "$active" == "active" && "$local_rule" == *'rule: CKS112 Custom Shell Marker'* && "$local_rule" == *'proc.cmdline contains "CKS112_CUSTOM_EVENT"'* && "$local_rule" == *'CKS112 custom shell marker'* && "$local_rule" == *'container=%container.id'* && "$local_rule" == *'pid=%proc.pid'* && "$local_rule" == *'ppid=%proc.ppid'* && -n "$journal" && -s "$artifact" ]] && grep -Fq 'CKS112 custom shell marker' "$artifact"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$local_rule" != *'rule: CKS112 Custom Shell Marker'* ]]; then
      echo "HINT: falco_rules.local.yaml is missing rule 'CKS112 Custom Shell Marker' with condition on 'proc.cmdline contains \"CKS112_CUSTOM_EVENT\"' and output fields container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name."
    elif [[ -z "$journal" ]]; then
      echo "HINT: No matching alert found in Falco's journal - after adding the local rule, restart Falco, then actually run a command containing 'CKS112_CUSTOM_EVENT' inside a container."
    else
      echo "HINT: falco-custom.log is missing or does not contain 'CKS112 custom shell marker' - copy the real journalctl line for this alert."
    fi
    echo "falco_active=$active rule_present=$([[ -n "$local_rule" ]] && echo yes || echo no) artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. kube-apiserver audits ConfigMap at RequestResponse but Secret only at Metadata (no body)" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(ssh -o BatchMode=yes control-plane "sudo cat '$APISERVER_MANIFEST'" 2>/dev/null || true)
  policy=$(ssh -o BatchMode=yes control-plane "sudo cat '$AUDIT_POLICY'" 2>/dev/null || true)
  ready=$(kubectl get --context "$CTX" --raw=/readyz 2>/dev/null || true)
  kubectl get configmap audit-config -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  kubectl get secret audit-secret -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  sleep 3
  cm_event=$(ssh -o BatchMode=yes control-plane "sudo jq -c -e 'select(.level == \"RequestResponse\" and .objectRef.resource == \"configmaps\" and .objectRef.namespace == \"$NS\" and .objectRef.name == \"audit-config\")' '$AUDIT_LOG' | tail -1" 2>/dev/null || true)
  secret_event=$(ssh -o BatchMode=yes control-plane "sudo jq -c -e 'select(.objectRef.resource == \"secrets\" and .objectRef.namespace == \"$NS\" and .objectRef.name == \"audit-secret\")' '$AUDIT_LOG' | tail -1" 2>/dev/null || true)
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
     && jq -e '.level == "Metadata" and .objectRef.resource == "secrets" and .objectRef.name == "audit-secret" and (has("requestObject") | not) and (has("responseObject") | not)' "$secret_artifact" >/dev/null 2>&1; then
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
  pod=$(kubectl get pod immutable-app -n "$NS" --context "$CTX" -o json 2>/dev/null)
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
  journal=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco -b --no-pager -n 2000 | grep -F 'CKS112 custom shell marker' | tail -20" 2>/dev/null || true)

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
  jq -e '.level == "Metadata" and .verb == "create" and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell" and (has("requestObject") | not) and (has("responseObject") | not)' "$audit_event" >/dev/null 2>&1 || evidence_ok=false

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

  ci_pod=$(kubectl get pod ci-runner -n "$NS" --context "$CTX" -o json 2>/dev/null)
  ci_phase=$(jq -r '.status.phase // ""' <<<"$ci_pod" 2>/dev/null)
  ci_stdin=$(jq -r '.spec.containers[]? | select(.name == "app") | .stdin == true' <<<"$ci_pod" 2>/dev/null)
  ci_tty=$(jq -r '.spec.containers[]? | select(.name == "app") | .tty == true' <<<"$ci_pod" 2>/dev/null)

  # Generate one fresh shell event in each Pod so this test does not depend on stale
  # journal/file content from earlier in the session.
  kubectl exec -n "$NS" ci-runner --context "$CTX" -- sh -c 'echo t7-ci-runner; sleep 1' >/dev/null 2>&1 || true
  kubectl exec -n "$NS" falco-shell --context "$CTX" -- sh -c 'echo t7-falco-shell; sleep 1' >/dev/null 2>&1 || true
  sleep 3

  ci_alert=$(ssh -o BatchMode=yes control-plane "sudo journalctl -u falco -b --no-pager -n 500 | grep -F 'Terminal shell in container' | grep -F 'ci-runner'" 2>/dev/null || true)

  events_log=$(ssh -o BatchMode=yes control-plane "sudo test -s /var/log/falco/events.log && sudo tail -n 50 /var/log/falco/events.log" 2>/dev/null || true)
  falco_shell_json=""
  if [[ -n "$events_log" ]]; then
    falco_shell_json=$(echo "$events_log" | jq -c 'select(.rule == "Terminal shell in container") | select(.output_fields["k8s.pod.name"] == "falco-shell")' 2>/dev/null | tail -1)
  fi
  pod_field=$(jq -r '.output_fields["k8s.pod.name"] // ""' <<<"$falco_shell_json" 2>/dev/null)
  ns_field=$(jq -r '.output_fields["k8s.ns.name"] // ""' <<<"$falco_shell_json" 2>/dev/null)

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
    && -z "$ci_alert" \
    && "$pod_field" == "falco-shell" && "$ns_field" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$local_rule" != *'macro: user_expected_terminal_shell_in_container_conditions'* ]]; then
      echo "HINT: You must override the macro 'user_expected_terminal_shell_in_container_conditions' (not 'user_shell_container_exclusions', which gates a DIFFERENT rule)."
    elif [[ "$local_rule" == *'container.name = "ci-runner"'* ]]; then
      echo "HINT: Your condition uses container.name instead of k8s.pod.name - container.name is the CONTAINER's name ('app' in this lab), not the Pod's name, and will not correctly scope to ci-runner."
    elif [[ -n "$ci_alert" ]]; then
      echo "HINT: ci-runner still triggered 'Terminal shell in container' - the macro override is not suppressing it. Double check the condition uses exact k8s.pod.name/k8s.ns.name matches and that Falco was restarted after the change."
    elif [[ "$local_rule" != *'override:'*'output: append'* ]]; then
      echo "HINT: You must ALSO add a second override on the rule itself (override: {output: append}) to append %k8s.pod.name/%k8s.ns.name to the alert output - the default output for 'Terminal shell in container' does not include these fields."
    elif [[ "$pod_field" != "falco-shell" || "$ns_field" != "$NS" ]]; then
      echo "HINT: The JSON alert's output_fields does not show k8s.pod.name=falco-shell and k8s.ns.name=$NS - check json_output/file_output are enabled in /etc/falco/config.d/, and that you generated a fresh alert after all config changes were applied."
    fi
    echo "active=$active macro_overridden=$([[ "$local_rule" == *'user_expected_terminal_shell_in_container_conditions'* ]] && echo yes || echo no) ci_phase=$ci_phase ci_alert=${ci_alert:-none} pod_field=$pod_field ns_field=$ns_field"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Audit webhook backend delivers events to the in-cluster receiver alongside the local file backend" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(ssh -o BatchMode=yes control-plane "sudo cat '$APISERVER_MANIFEST'" 2>/dev/null || true)
  webhook_config=$(ssh -o BatchMode=yes control-plane "sudo cat /etc/kubernetes/audit/webhook-config.yaml" 2>/dev/null || true)
  ready=$(kubectl get --context "$CTX" --raw=/readyz 2>/dev/null || true)

  receiver_pod=$(kubectl get deployment audit-receiver -n "$NS" --context "$CTX" -o json 2>/dev/null)
  receiver_available=$(jq -r '.status.availableReplicas // 0' <<<"$receiver_pod" 2>/dev/null)
  receiver_svc=$(kubectl get service audit-receiver -n "$NS" --context "$CTX" -o json 2>/dev/null)
  receiver_port=$(jq -r '.spec.ports[]?.port' <<<"$receiver_svc" 2>/dev/null)

  kubectl get configmap audit-config -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  sleep 3
  receiver_pod_name=$(kubectl get pod -n "$NS" --context "$CTX" -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  receiver_logs=$(kubectl logs -n "$NS" --context "$CTX" "$receiver_pod_name" --tail=200 2>/dev/null || true)

  if [[ "$ready" == "ok" \
    && "$manifest" == *'--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml'* \
    && "$manifest" == *'--audit-webhook-batch-max-wait='* \
    && "$manifest" == *'--audit-policy-file=/etc/kubernetes/audit/policy.yaml'* \
    && "$manifest" == *'--audit-log-path=/var/log/kubernetes/audit/audit.log'* \
    && "$webhook_config" == *'server: http://'* \
    && "$receiver_available" -ge 1 && -n "$receiver_port" \
    && "$receiver_logs" == *'objectRef'* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$receiver_available" -lt 1 ]]; then
      echo "HINT: Deployment 'audit-receiver' has no available replicas - check it deployed successfully and its Service exists."
    elif [[ "$webhook_config" != *'server: http://'* ]]; then
      echo "HINT: webhook-config.yaml must be a valid kubeconfig-shaped file with a 'server: http://<receiver-ClusterIP>:8080/audit' entry."
    elif [[ "$manifest" != *'--audit-webhook-config-file='* || "$manifest" != *'--audit-webhook-batch-max-wait='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --audit-webhook-config-file and/or --audit-webhook-batch-max-wait - and make sure the EXISTING --audit-policy-file/--audit-log-path flags from task 4 are still present, the webhook is meant to complement the file backend, not replace it."
    elif [[ "$receiver_logs" != *'objectRef'* ]]; then
      echo "HINT: audit-receiver's logs do not contain 'objectRef' - no audit event has actually been delivered yet. Make an aduitable request AFTER the API server restarts with the webhook flag, and check the receiver Service selector matches its Pod."
    fi
    echo "ready=$ready webhook_flag=$([[ "$manifest" == *'audit-webhook-config-file'* ]] && echo yes || echo no) receiver_available=$receiver_available receiver_port=${receiver_port:-missing} logs_have_objectRef=$([[ "$receiver_logs" == *'objectRef'* ]] && echo yes || echo no)"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. Kyverno blocks untrusted registry on admission and Falco detects a direct containerd bypass attempt with exact (non-prefix) allowlist semantics" {
  echo '1' >> /var/work/tests/result/all
  crd=$(kubectl get crd validatingpolicies.policies.kyverno.io -o name --context "$CTX" 2>/dev/null)
  policy=$(kubectl get validatingpolicy require-trusted-registry-runtime-112 -o json --context "$CTX" 2>/dev/null)
  policy_ok=0
  policy_message=$(jq -r '[.spec.validations[]?.message, .spec.validations[]?.messageExpression] | join(" ")' <<<"$policy" 2>/dev/null)
  policy_expr=$(jq -r '[.spec.validations[]?.expression] | join(" ")' <<<"$policy" 2>/dev/null)
  if [[ -n "$policy" ]] \
    && echo "$policy" | jq -e '.apiVersion == "policies.kyverno.io/v1" and (.spec.validationActions | index("Deny") != null)' >/dev/null 2>&1 \
    && [[ "$policy_message" == *'CKS112_TRUSTED_REPO_POLICY'* ]] \
    && [[ "$policy_expr" == *'registry()'* && "$policy_expr" == *'repository()'* ]] \
    && [[ "$policy_expr" == *"'docker.io'"* && "$policy_expr" == *"'library/busybox'"* ]] \
    && [[ "$policy_expr" != *'startsWith'* ]]; then
    policy_ok=1
  fi
  set +e
  kubectl get pod blocked-attempt -n "$NS" --context "$CTX" >/dev/null 2>&1
  blocked_absent=$?
  set -e
  deny_artifact=/var/work/tests/artifacts/9/admission-deny.txt
  bypass_artifact=/var/work/tests/artifacts/9/falco-bypass-attempt.log
  local_rule=$(ssh -o BatchMode=yes control-plane "sudo test -r '$FALCO_RULES' && sudo cat '$FALCO_RULES'" 2>/dev/null || true)
  bypass_rule_block=$(awk '/rule: CKS112 Runtime Bypass of Admission/,/^- rule:|^$/' <<<"$local_rule" 2>/dev/null || true)
  falco_condition_ok=0
  if [[ "$local_rule" == *'rule: CKS112 Runtime Bypass of Admission'* \
     && "$local_rule" == *'CKS112_CTR_BYPASS'* \
     && "$local_rule" == *'container.image.repository'* \
     && "$bypass_rule_block" != *'startswith'* && "$bypass_rule_block" != *'startsWith'* \
     && ( "$bypass_rule_block" == *'container.image.repository !='* || "$bypass_rule_block" == *'container.image.repository =='* ) ]]; then
    falco_condition_ok=1
  fi
  if [[ -n "$crd" && "$policy_ok" -eq 1 ]] \
    && [[ "$blocked_absent" -ne 0 ]] \
    && [[ -s "$deny_artifact" ]] && grep -Fq 'CKS112_TRUSTED_REPO_POLICY' "$deny_artifact" \
    && [[ "$falco_condition_ok" -eq 1 ]] \
    && [[ -s "$bypass_artifact" ]] && grep -Fq 'CKS112_CTR_BYPASS' "$bypass_artifact" \
    && grep -Fq 'busybox-evil' "$bypass_artifact"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$policy_ok" -ne 1 ]]; then
      echo "HINT: ValidatingPolicy 'require-trusted-registry-runtime-112' must use CEL image().registry()=='docker.io' and image().repository()=='library/busybox' with exact equality (not startsWith, which would also match names like 'busybox-evil'), and its message/messageExpression must contain the exact marker 'CKS112_TRUSTED_REPO_POLICY' so this test can distinguish it from any other admission denial."
    elif [[ "$blocked_absent" -eq 0 ]]; then
      echo "HINT: Pod 'blocked-attempt' (image alpine:3.20) still exists - it should have been denied by the registry policy."
    elif ! grep -Fq 'CKS112_TRUSTED_REPO_POLICY' "$deny_artifact" 2>/dev/null; then
      echo "HINT: admission-deny.txt does not contain the marker 'CKS112_TRUSTED_REPO_POLICY' - the Pod may have been rejected for an unrelated reason, or your policy message text does not match exactly."
    elif [[ "$falco_condition_ok" -ne 1 ]]; then
      echo "HINT: falco_rules.local.yaml rule 'CKS112 Runtime Bypass of Admission' must check proc.cmdline for CKS112_CTR_BYPASS AND use an EXACT comparison on container.image.repository (e.g. 'container.image.repository != \"library/busybox\"'), not 'startswith'/prefix matching - a startswith check would fail to catch a repository like 'library/busybox-evil' that merely begins with the allowed string, even though the Kyverno admission policy above correctly rejects it with exact equality. Both controls must use the same comparison semantics to be equivalent security properties."
    elif ! grep -Fq 'busybox-evil' "$bypass_artifact" 2>/dev/null; then
      echo "HINT: falco-bypass-attempt.log does not show a detection for the prefix-trap probe (a container tagged 'library/busybox-evil', which starts with the allowed 'library/busybox' string but is not equal to it). This is the specific evidence that proves your Falco condition uses exact comparison rather than startswith - run the extra probe from the solution and append its alert to this log."
    else
      echo "HINT: falco-bypass-attempt.log does not show a matching alert for CKS112_CTR_BYPASS - make sure you ran 'ctr run' with a fresh, unique container ID (not reusing one from a previous attempt still running) and that Falco restarted after adding the rule."
    fi
    echo "crd=${crd:-missing} policy_ok=$policy_ok blocked_absent=$blocked_absent deny_artifact=$deny_artifact rule_present=$([[ "$local_rule" == *'CKS112 Runtime Bypass of Admission'* ]] && echo yes || echo no) bypass_artifact=$bypass_artifact policy_message=$policy_message policy_expr=$policy_expr"
    result=1
  fi
  [ "$result" -eq 0 ]
}
