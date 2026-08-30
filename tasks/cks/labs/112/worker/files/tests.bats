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
  if [[ "$phase" == "Running" && "$image" == "busybox:1.36" && "$stdin" == "true" && "$tty" == "true" && -n "$journal" && -s "$artifact" ]] && grep -Fq 'Terminal shell in container' "$artifact"; then
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
  if [[ "$active" == "active" && "$local_rule" == *'rule: CKS112 Custom Shell Marker'* && "$local_rule" == *'proc.cmdline contains "CKS112_CUSTOM_EVENT"'* && "$local_rule" == *'CKS112 custom shell marker'* && -n "$journal" && -s "$artifact" ]] && grep -Fq 'CKS112 custom shell marker' "$artifact"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "falco_active=$active rule_present=$([[ -n "$local_rule" ]] && echo yes || echo no) artifact=$artifact"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. kube-apiserver audits Secret requests at RequestResponse and the event was saved" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(ssh -o BatchMode=yes control-plane "sudo cat '$APISERVER_MANIFEST'" 2>/dev/null || true)
  policy=$(ssh -o BatchMode=yes control-plane "sudo cat '$AUDIT_POLICY'" 2>/dev/null || true)
  ready=$(kubectl get --context "$CTX" --raw=/readyz 2>/dev/null || true)
  kubectl get secret audit-secret -n "$NS" --context "$CTX" -o json >/dev/null 2>&1 || true
  sleep 3
  event=$(ssh -o BatchMode=yes control-plane "sudo jq -c -e 'select(.level == \"RequestResponse\" and .objectRef.resource == \"secrets\" and .objectRef.namespace == \"$NS\" and .objectRef.name == \"audit-secret\")' '$AUDIT_LOG' | tail -1" 2>/dev/null || true)
  artifact=/var/work/tests/artifacts/4/secret-request-response.json
  if [[ "$ready" == "ok" && "$manifest" == *'--audit-policy-file=/etc/kubernetes/audit/policy.yaml'* && "$manifest" == *'--audit-log-path=/var/log/kubernetes/audit/audit.log'* && "$manifest" == *'/etc/kubernetes/audit'* && "$manifest" == *'/var/log/kubernetes/audit'* && "$policy" == *'level: RequestResponse'* && "$policy" == *'resources: ["secrets"]'* && -n "$event" && -s "$artifact" ]] && jq -e '.level == "RequestResponse" and .objectRef.resource == "secrets" and .objectRef.name == "audit-secret"' "$artifact" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ready=$ready manifest_audit=$([[ "$manifest" == *'--audit-policy-file='* ]] && echo yes || echo no) policy=$([[ "$policy" == *'resources: ["secrets"]'* ]] && echo yes || echo no) event=$([[ -n "$event" ]] && echo yes || echo no) artifact=$artifact"
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
