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
  if [[ -s "$report" ]] && grep -Eq '\[(PASS|WARN|FAIL)\]' "$report"; then
    result=0
  else
    echo "Missing or invalid kube-bench report: $report"
    result=1
  fi
  record_result 1 "$result"
}

@test "2. kubelet disables read-only port and anonymous authentication on the node" {
  run node_ssh "sudo awk '/^[[:space:]]*readOnlyPort:[[:space:]]*0[[:space:]]*$/ {port=1} /^[[:space:]]*anonymous:[[:space:]]*$/ {anonymous=1; next} anonymous && /^[[:space:]]*enabled:[[:space:]]*false[[:space:]]*$/ {auth=1} END {exit !(port && auth)}' /var/lib/kubelet/config.yaml && sudo systemctl is-active --quiet kubelet"
  result=$status
  if [[ "$result" -ne 0 ]]; then
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
    echo "secret type=$secret_type host=$host secret=$secret_name backend=$service"
    result=1
  fi
  record_result 4 "$result"
}

@test "5. TLS 1.3 and cipher hardening are active in control-plane manifests" {
  report=/var/work/tests/artifacts/5/tls13.txt
  run node_ssh "sudo grep -qx -- '    - --tls-min-version=VersionTLS13' /etc/kubernetes/manifests/kube-apiserver.yaml && sudo grep -qx -- '    - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384' /etc/kubernetes/manifests/kube-apiserver.yaml && sudo grep -qx -- '    - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384' /etc/kubernetes/manifests/etcd.yaml"
  manifest_status=$status
  manifest_output=$output
  ready=$(kubectl get --raw='/readyz' --context "$CTX" 2>/dev/null)
  etcd_phase=$(kubectl get pods -n kube-system --context "$CTX" -l component=etcd -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [[ "$manifest_status" -eq 0 && "$ready" == "ok" && "$etcd_phase" == "Running" ]] && grep -Eq 'TLSv1[.]3' "$report"; then
    result=0
  else
    echo "$manifest_output"
    echo "readyz=$ready etcd_phase=$etcd_phase"
    result=1
  fi
  record_result 5 "$result"
}

@test "6. kubelet and kubectl SHA-256 verification succeeded" {
  report=/var/work/tests/artifacts/6/binaries.sha256.txt
  if [[ -s "$report" ]] && grep -Eq 'kubelet.*: OK' "$report" && grep -Eq 'kubectl.*: OK' "$report"; then
    result=0
  else
    echo "Expected successful kubelet and kubectl checks in $report"
    result=1
  fi
  record_result 6 "$result"
}
