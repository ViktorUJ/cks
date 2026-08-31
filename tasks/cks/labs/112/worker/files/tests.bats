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
        && "$policy" == *'resources: ["configmaps"]'* \
        && "$policy" == *'resources: ["secrets"]'* \
        && -n "$cm_event" && -n "$secret_event" && -s "$cm_artifact" && -s "$secret_artifact" ]] \
     && jq -e '.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.name == "audit-config"' "$cm_artifact" >/dev/null 2>&1 \
     && jq -e '.level == "Metadata" and .objectRef.resource == "secrets" and .objectRef.name == "audit-secret" and (has("requestObject") | not) and (has("responseObject") | not)' "$secret_artifact" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
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
    echo "phase=$phase readonly=$readonly writable_tmp=$writable_tmp host_paths=$host_paths rootfs_status=$rootfs_status rootfs_output=$rootfs_output tmp_status=$tmp_status tmp_output=$tmp_output artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. Falco alert is correlated through CRI, proc, audit, classification, and containment" {
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
    echo "evidence_ok=$evidence_ok quarantine=$quarantine pod_absent_status=$pod_absent exec_status=$exec_status container_id=$container_id host_pid=$host_pid node=$node current_node=$current_node"
    result=1
  fi
  [ "$result" -eq 0 ]
}
