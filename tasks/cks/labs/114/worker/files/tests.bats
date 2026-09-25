#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-114"
NODEPORT=30114
CHECKER_LABEL="cks.lab/checker=114"

setup() {
  CHECKER_PREFIX="cks-114-checker-${BATS_TEST_NUMBER}-$$"
}

teardown() {
  kubectl --context "$CTX" -n "$NS" delete pod -l "$CHECKER_LABEL" \
    --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

create_probe() {
  local namespace=$1 name=$2 image=${3:-curlimages/curl:8.11.1}
  kubectl --context "$CTX" -n "$namespace" run "$name" --restart=Never --image="$image" \
    --labels="$CHECKER_LABEL" --command -- sh -c 'sleep 300' >/dev/null
  kubectl --context "$CTX" -n "$namespace" wait --for=condition=Ready "pod/$name" --timeout=90s >/dev/null
}

curl_probe_in_cluster() {
  local pod=$1 destination=$2
  kubectl --context "$CTX" -n "$NS" exec "$pod" -- sh -c \
    "set +e; code=\$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 '$destination'); rc=\$?; printf 'CURL_EXIT:%s\\nHTTPCODE:%s\\n' \"\$rc\" \"\$code\"; exit 0"
}

curl_probe_local() {
  local destination=$1 code rc
  set +e
  code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 "$destination")
  rc=$?
  set -e
  printf 'CURL_EXIT:%s\nHTTPCODE:%s\n' "$rc" "$code"
}

assert_reachable() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$rc" == 0 && "$code" =~ ^[1-5][0-9][0-9]$ ]]
}

assert_transport_denied() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$code" == 000 && "$rc" =~ ^(7|28)$ ]]
}

node_internal_ip() {
  kubectl --context "$CTX" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
}

norm() {
  # Strip all whitespace so KEY=VALUE artifact lines tolerate formatting/spacing
  # differences from the student while still requiring the same underlying data.
  tr -d '[:space:]' <<<"$1"
}

@test "0 Init" {
  mkdir -p /var/work/tests/result /var/work/tests/artifacts
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
}

@test "1. Student switched to the real, live cluster1 context out of several kubeconfig contexts" {
  echo 1 >> /var/work/tests/result/all
  current=$(kubectl config current-context 2>/dev/null)
  contexts=$(kubectl config get-contexts -o name 2>/dev/null | sort)
  expected_contexts=$(printf '%s\n' cluster9-admin@cluster1 legacy-admin@legacy staging-admin@staging "$CTX" | sort)
  server=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="cluster1")].cluster.server}' 2>/dev/null)
  live=$(kubectl --context "$CTX" get --raw /version 2>/dev/null | jq -r 'has("gitVersion")' 2>/dev/null || echo false)
  if [[ "$current" == "$CTX" && "$contexts" == "$expected_contexts" && \
        "$server" =~ ^https://.+:6443$ && "$live" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: run 'kubectl config get-contexts', find the context that actually reaches the API server (not the decoy staging/legacy ones), and 'kubectl config use-context $CTX'." >&2
    false
  fi
}

@test "2. Extracted cluster9-admin client certificate matches the checker's own extraction" {
  echo 1 >> /var/work/tests/result/all
  artifact=/var/work/tests/artifacts/task2-cert.txt
  if [[ ! -s "$artifact" ]]; then
    echo "HINT: write SHA256_FP=/SUBJECT=/ISSUER=/NOTBEFORE=/NOTAFTER= lines to $artifact after extracting the cluster9-admin client certificate." >&2
    false
  fi

  cert_pem=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' 2>/dev/null | base64 -d 2>/dev/null)
  if [[ -z "$cert_pem" ]]; then
    echo "HINT: kubectl config view --raw ... | base64 -d must decode to a real client-certificate-data for user cluster9-admin." >&2
    false
  fi

  expected_fp=$(openssl x509 -in <(printf '%s' "$cert_pem") -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2 | tr -d ':' | tr 'A-F' 'a-f')
  expected_subject=$(openssl x509 -in <(printf '%s' "$cert_pem") -noout -subject 2>/dev/null)
  expected_issuer=$(openssl x509 -in <(printf '%s' "$cert_pem") -noout -issuer 2>/dev/null)
  expected_notbefore=$(openssl x509 -in <(printf '%s' "$cert_pem") -noout -startdate 2>/dev/null)
  expected_notafter=$(openssl x509 -in <(printf '%s' "$cert_pem") -noout -enddate 2>/dev/null)

  student_fp=$(grep -m1 '^SHA256_FP=' "$artifact" | cut -d= -f2- | tr 'A-F' 'a-f')
  student_subject=$(grep -m1 '^SUBJECT=' "$artifact" | cut -d= -f2-)
  student_issuer=$(grep -m1 '^ISSUER=' "$artifact" | cut -d= -f2-)
  student_notbefore=$(grep -m1 '^NOTBEFORE=' "$artifact" | cut -d= -f2-)
  student_notafter=$(grep -m1 '^NOTAFTER=' "$artifact" | cut -d= -f2-)

  fp_ok=false; [[ "$(norm "$student_fp")" == "$(norm "$expected_fp")" && -n "$expected_fp" ]] && fp_ok=true
  subject_ok=false; [[ "$(norm "$student_subject")" == *"cluster9-admin"* && "$(norm "$student_subject")" == "$(norm "$expected_subject")" ]] && subject_ok=true
  issuer_ok=false; [[ "$(norm "$student_issuer")" == "$(norm "$expected_issuer")" ]] && issuer_ok=true
  notbefore_ok=false; [[ "$(norm "$student_notbefore")" == "$(norm "$expected_notbefore")" ]] && notbefore_ok=true
  notafter_ok=false; [[ "$(norm "$student_notafter")" == "$(norm "$expected_notafter")" ]] && notafter_ok=true

  if [[ "$fp_ok" == true && "$subject_ok" == true && "$issuer_ok" == true && "$notbefore_ok" == true && "$notafter_ok" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: SHA256_FP/SUBJECT/ISSUER/NOTBEFORE/NOTAFTER in $artifact must match 'openssl x509 -noout -fingerprint -sha256/-subject/-issuer/-startdate/-enddate' run on the actual decoded cluster9-admin certificate, not a placeholder." >&2
    false
  fi
}

@test "3. kubernetes-public NodePort Service exposes the backend on the node and in-cluster, default/kubernetes untouched" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then
    echo "HINT: create namespace $NS with a backend Deployment and a kubernetes-public NodePort Service before task 3 validation." >&2
    false
  fi

  default_svc_ok=$(kubectl --context "$CTX" get svc kubernetes -n default -o jsonpath='{.spec.type}' 2>/dev/null)
  svc_json=$(kubectl --context "$CTX" -n "$NS" get svc kubernetes-public -o json 2>/dev/null)
  shape=$(jq -r '.spec.type == "NodePort" and (.spec.ports[0].nodePort == 30114)' <<<"$svc_json" 2>/dev/null)
  ready=$(kubectl --context "$CTX" -n "$NS" get pod -l app=backend -o json 2>/dev/null | jq -r '
    (.items | length > 0) and ([.items[] | (.status.conditions // []) | any(.type == "Ready" and .status == "True")] | any)')

  node_ip=$(node_internal_ip)
  external=$(curl_probe_local "http://$node_ip:$NODEPORT/")

  create_probe "$NS" "${CHECKER_PREFIX}-in-cluster"
  in_cluster=$(curl_probe_in_cluster "${CHECKER_PREFIX}-in-cluster" "http://kubernetes-public.$NS.svc.cluster.local/")

  # Task 4 turns the Service into ClusterIP, so once it is done the NodePort state can no longer
  # be probed live. The checker-owned monitor (cks114-monitor) records that the Service really was
  # NodePort/30114 and answered from the worker; that record also satisfies this test.
  nodeport_phase_seen=false
  [[ -s /var/lib/cks-lab114-checker/nodeport-phase-seen ]] && nodeport_phase_seen=true

  live_ok=false
  if [[ "$shape" == true && "$ready" == true ]] && assert_reachable "$external" && assert_reachable "$in_cluster"; then
    live_ok=true
  fi

  if [[ "$default_svc_ok" == "ClusterIP" ]] && [[ "$live_ok" == true || "$nodeport_phase_seen" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: kubernetes-public must be type NodePort with nodePort 30114, reachable both via <node-internal-ip>:30114 from the worker and via the in-cluster Service DNS name; default/kubernetes Service must stay ClusterIP. The NodePort phase must have really happened (it is recorded by a checker-owned monitor), so do task 3 before reducing the Service to ClusterIP in task 4." >&2
    false
  fi
}

@test "4. kubernetes-public reduced to ClusterIP: NodePort path denied, in-cluster path still allowed" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then
    echo "HINT: complete task 3 before reducing kubernetes-public to ClusterIP." >&2
    false
  fi

  svc_json=$(kubectl --context "$CTX" -n "$NS" get svc kubernetes-public -o json 2>/dev/null)
  shape=$(jq -r '.spec.type == "ClusterIP" and ([.spec.ports[] | has("nodePort")] | any | not)' <<<"$svc_json" 2>/dev/null)
  ready=$(kubectl --context "$CTX" -n "$NS" get pod -l app=backend -o json 2>/dev/null | jq -r '
    (.items | length > 0) and ([.items[] | (.status.conditions // []) | any(.type == "Ready" and .status == "True")] | any)')

  node_ip=$(node_internal_ip)
  external=$(curl_probe_local "http://$node_ip:$NODEPORT/")

  create_probe "$NS" "${CHECKER_PREFIX}-in-cluster"
  in_cluster=$(curl_probe_in_cluster "${CHECKER_PREFIX}-in-cluster" "http://kubernetes-public.$NS.svc.cluster.local/")

  if [[ "$shape" == true && "$ready" == true ]] && \
     assert_transport_denied "$external" && assert_reachable "$in_cluster"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: kubernetes-public must become type ClusterIP with no nodePort on any port (node:30114 must now be transport-denied), while the in-cluster Service DNS path must remain reachable and the backend Pod stays healthy." >&2
    false
  fi
}
