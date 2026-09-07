#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

control_plane() {
  kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

node_ssh() {
  ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 "$(control_plane)" "$@"
}

record_result() {
  local number="$1"
  local result="$2"
  echo '1' >> /var/work/tests/result/all
  if [[ "$result" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  return "$result"
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. kube-bench report was collected from the control-plane" {
  report=/var/work/tests/artifacts/1/kube-bench.txt
  if [[ -s "$report" ]] \
    && grep -Eq '^kubernetes_version=v1[.]36([.]|$)' "$report" \
    && grep -Eq '^kube_bench_version=v?0[.]16[.]0$' "$report" \
    && grep -qx 'benchmark=cis-1.12' "$report" \
    && grep -qx 'mapping_status=forced-approximate' "$report" \
    && grep -Eq '\[(PASS|WARN|FAIL)\]' "$report"; then
    result=0
  else
    if ! [[ -s "$report" ]]; then
      echo "HINT: kube-bench.txt is missing or empty - save the report at exactly $report."
    elif ! grep -Eq '^kubernetes_version=v1[.]36([.]|$)' "$report"; then
      echo "HINT: Report must include a line 'kubernetes_version=v1.36.x' - check kube-bench actually detected this cluster's version."
    elif ! grep -Eq '^kube_bench_version=v?0[.]16[.]0$' "$report"; then
      echo "HINT: Report must include 'kube_bench_version=v0.16.0' (or without 'v') matching the tool version installed in this lab."
    elif ! grep -qx 'benchmark=cis-1.12' "$report"; then
      echo "HINT: Report must include a line 'benchmark=cis-1.12' exactly - this pinned kube-bench 0.16.0 has no profile newer than cis-1.12 (its version_mapping tops out at '1.34': 'cis-1.12'; there is no cis-2.0 in this release at all), so cis-1.12 is the closest existing profile to run explicitly."
    elif ! grep -qx 'mapping_status=forced-approximate' "$report"; then
      echo "HINT: Report must include 'mapping_status=forced-approximate' exactly - this documents that v1.36 is newer than kube-bench's built-in version map."
    else
      echo "HINT: Report must contain at least one line with [PASS], [WARN], or [FAIL] - check kube-bench actually ran the full scan, not just the config check."
    fi
    echo "Report must record Kubernetes, kube-bench, CIS config, forced/approximate mapping, and scan results: $report"
    result=1
  fi
  record_result 1 "$result"
}

@test "2. kubelet disables read-only port and anonymous authentication on the node" {
  run node_ssh "sudo awk '/^[[:space:]]*readOnlyPort:[[:space:]]*0[[:space:]]*$/ {port=1} /^[[:space:]]*anonymous:[[:space:]]*$/ {anonymous=1; next} anonymous && /^[[:space:]]*enabled:[[:space:]]*false[[:space:]]*$/ {auth=1} END {exit !(port && auth)}' /var/lib/kubelet/config.yaml && sudo systemctl is-active --quiet kubelet"
  result=$status
  if [[ "$result" -ne 0 ]]; then
    echo "HINT: Either readOnlyPort: 0 or authentication.anonymous.enabled: false is missing from /var/lib/kubelet/config.yaml (or kubelet failed to restart cleanly). Check indentation matters here - the awk pattern expects the exact YAML nesting used by kubelet's own config file."
    echo "$output"
  fi
  record_result 2 "$result"
}

@test "3. kube-apiserver has profiling disabled and is healthy" {
  run node_ssh "sudo grep -qx -- '    - --profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
  manifest_status=$status
  manifest_output=$output
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=kube-apiserver -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [[ "$manifest_status" -eq 0 && "$ready" == "ok" && "$phase" == "Running" ]]; then
    result=0
  else
    if [[ "$manifest_status" -ne 0 ]]; then
      echo "HINT: /etc/kubernetes/manifests/kube-apiserver.yaml must contain the exact line '    - --profiling=false' (4-space indent, matching the existing flag list format)."
    elif [[ "$ready" != "ok" ]]; then
      echo "HINT: API server is not ready after the manifest edit. Wait longer for kubelet to pick up the change and restart the static Pod, or check for a YAML syntax error in the manifest."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: kube-apiserver Pod is not Running (phase=$phase). Check 'kubectl describe pod' events on this Pod for the actual startup error."
    fi
    echo "$manifest_output"
    echo "readyz=$ready phase=$phase"
    result=1
  fi
  record_result 3 "$result"
}

@test "4. TLS Secret and secure Ingress are configured" {
  secret_type=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.type}' 2>/dev/null)
  cert=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
  key=$(kubectl get secret secure-ingress-tls -n cks-103 --context "$CTX" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
  host=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.tls[0].hosts[0]}' 2>/dev/null)
  secret_name=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null)
  service=$(kubectl get ingress secure-ingress -n cks-103 --context "$CTX" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  if [[ "$secret_type" == "kubernetes.io/tls" && -n "$cert" && -n "$key" && "$host" == "secure.cks.local" && "$secret_name" == "secure-ingress-tls" && "$service" == "secure-app" ]]; then
    result=0
  else
    if [[ "$secret_type" != "kubernetes.io/tls" ]]; then
      echo "HINT: Secret 'secure-ingress-tls' must have type 'kubernetes.io/tls' - a generic Opaque Secret with tls.crt/tls.key keys does not satisfy Ingress TLS requirements the same way."
    elif [[ -z "$cert" || -z "$key" ]]; then
      echo "HINT: Secret 'secure-ingress-tls' is missing tls.crt or tls.key data - both must be present and base64-encoded (kubectl handles this automatically with 'kubectl create secret tls')."
    elif [[ "$host" != "secure.cks.local" ]]; then
      echo "HINT: Ingress 'secure-ingress' spec.tls[0].hosts[0] must be exactly 'secure.cks.local'."
    elif [[ "$secret_name" != "secure-ingress-tls" ]]; then
      echo "HINT: Ingress 'secure-ingress' spec.tls[0].secretName must reference 'secure-ingress-tls' exactly."
    elif [[ "$service" != "secure-app" ]]; then
      echo "HINT: Ingress backend service.name must be 'secure-app' exactly."
    fi
    echo "secret type=$secret_type host=$host secret=$secret_name backend=$service"
    result=1
  fi
  record_result 4 "$result"
}

@test "5. TLS 1.3 is active and TLS 1.2 is rejected by the control plane" {
  report=/var/work/tests/artifacts/5/tls13.txt
  run node_ssh "sudo grep -qx -- '    - --tls-min-version=VersionTLS13' /etc/kubernetes/manifests/kube-apiserver.yaml && sudo grep -qx -- '    - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384' /etc/kubernetes/manifests/kube-apiserver.yaml && sudo grep -qx -- '    - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384' /etc/kubernetes/manifests/etcd.yaml"
  manifest_status=$status
  manifest_output=$output
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  etcd_phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=etcd -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  run node_ssh "openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null"
  tls12_status=$status
  tls12_output=$output
  if [[ "$manifest_status" -eq 0 && "$ready" == "ok" && "$etcd_phase" == "Running" && "$tls12_status" -ne 0 ]] \
    && grep -Eq 'TLSv1[.]3' "$report" \
    && grep -Fq 'TLS 1.2 correctly rejected' "$report"; then
    result=0
  else
    if [[ "$manifest_status" -ne 0 ]]; then
      echo "HINT: kube-apiserver.yaml and/or etcd.yaml are missing the exact TLS flag lines. Check --tls-min-version, --tls-cipher-suites on kube-apiserver, and --cipher-suites on etcd match the required strings byte-for-byte, including indentation."
    elif [[ "$ready" != "ok" || "$etcd_phase" != "Running" ]]; then
      echo "HINT: API server or etcd is not healthy after the TLS change. A too-restrictive cipher list can break internal component communication - double check the exact cipher suite strings for typos."
    elif [[ "$tls12_status" -eq 0 ]]; then
      echo "HINT: A TLS 1.2 handshake to :6443 succeeded - it should be rejected once --tls-min-version=VersionTLS13 is active. Confirm the static Pod actually restarted with the new manifest."
    else
      echo "HINT: TLS handshake succeeded/failed as expected, but the evidence file $report does not contain 'TLSv1.3' and/or 'TLS 1.2 correctly rejected' - save both proofs in that exact wording."
    fi
    echo "$manifest_output"
    echo "readyz=$ready etcd_phase=$etcd_phase tls12_exit=$tls12_status"
    echo "$tls12_output"
    result=1
  fi
  record_result 5 "$result"
}

@test "6. kubelet and kubectl SHA-256 verification succeeded" {
  report=/var/work/tests/artifacts/6/binaries.sha256.txt
  if [[ -s "$report" ]] && grep -Eq 'kubelet.*: OK' "$report" && grep -Eq 'kubectl.*: OK' "$report"; then
    result=0
  else
    echo "HINT: binaries.sha256.txt must contain lines matching 'kubelet...: OK' and 'kubectl...: OK' - this is the standard 'sha256sum --check' output format. If a check shows FAILED, the downloaded binary does not match the expected checksum - re-download from the official source."
    echo "Expected successful kubelet and kubectl checks in $report"
    result=1
  fi
  record_result 6 "$result"
}

@test "7. kube-bench check 1.1.1 goes from FAIL to PASS after fixing manifest permissions" {
  before=/var/work/tests/artifacts/7/before.txt
  after=/var/work/tests/artifacts/7/after.txt
  perm=$(node_ssh "sudo stat -c '%a' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null)
  if [[ -s "$before" ]] && grep -q '1.1.1' "$before" && grep -q '\[FAIL\]' "$before" \
    && [[ -s "$after" ]] && grep -q '1.1.1' "$after" && grep -q '\[PASS\]' "$after" \
    && ! grep -A2 '1.1.1' "$after" | grep -q '\[FAIL\]' \
    && [[ "$perm" == "600" ]]; then
    result=0
  else
    if ! [[ -s "$before" ]] || ! grep -q '1.1.1' "$before" || ! grep -q '\[FAIL\]' "$before"; then
      echo "HINT: before.txt must be captured BEFORE any fix, containing check 1.1.1 with a [FAIL] result - this is the CIS check for kube-apiserver manifest file permissions."
    elif [[ "$perm" != "600" ]]; then
      echo "HINT: /etc/kubernetes/manifests/kube-apiserver.yaml permissions are '$perm', not 600. Run 'chmod 600' on this file - CIS 1.1.1 requires it to be readable/writable only by its owner."
    else
      echo "HINT: after.txt must show check 1.1.1 as [PASS] with no lingering [FAIL] nearby - re-run kube-bench after the chmod and save the fresh output."
    fi
    echo "Expected FAIL in $before and PASS in $after for check 1.1.1, and node permission exactly 600 (actual: ${perm:-missing})"
    result=1
  fi
  record_result 7 "$result"
}
