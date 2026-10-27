#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-114"
NODEPORT=30114
BASE="/var/lib/cks-lab114-checker"
TRUSTED_CONFIG="$BASE/expected-kubeconfig"

setup() {
  CHECKER_PREFIX="cks-114-checker-${BATS_TEST_NUMBER}-$$"
  PROBE_POD=""
  PENDING_SUCCESS=false
}

teardown() {
  local attempt reason
  if [[ -n "$PROBE_POD" ]]; then
    for attempt in $(seq 1 8); do
      kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" -n "$NS" delete pod "$PROBE_POD" \
        --ignore-not-found --wait=true --timeout=20s >/dev/null 2>&1 || true
      reason=$(kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" -n "$NS" \
        get pod "$PROBE_POD" -o name 2>&1) && rc=0 || rc=$?
      if [[ "$rc" -ne 0 && "$reason" == *NotFound* ]]; then PROBE_POD=""; break; fi
      sleep 1
    done
    if [[ -n "$PROBE_POD" ]]; then
      echo "FATAL: probe Pod $PROBE_POD could not be confirmed deleted" >&2
      return 1
    fi
  fi
  # Bats teardown FAIL must also prevent result/ok from recording a PASS.
  if [[ "$PENDING_SUCCESS" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  fi
  return 0
}
create_probe() {
  local namespace=$1 name=$2
  PROBE_POD=$name
  kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" -n "$namespace" run "$name" \
    --restart=Never --image=curlimages/curl:8.11.1 \
    --labels='cks.lab/checker=114' --command -- sleep 300 >/dev/null || return 1
  kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" -n "$namespace" wait \
    --for=condition=Ready "pod/$name" --timeout=90s >/dev/null
}

curl_probe_in_cluster() {
  local pod=$1 destination=$2
  kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" -n "$NS" exec "$pod" -- sh -c \
    "set +e; code=\$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 '$destination'); rc=\$?; printf 'CURL_EXIT:%s\\nHTTPCODE:%s\\n' \"\$rc\" \"\$code\"; exit 0"
}

curl_probe_local() {
  local destination=$1 code rc
  set +e
  code=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 "$destination")
  rc=$?
  set -e
  printf 'CURL_EXIT:%s\nHTTPCODE:%s\n' "$rc" "$code"
}

assert_http_200() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$rc" == 0 && "$code" == 200 ]]
}

assert_transport_denied() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$code" == 000 && "$rc" =~ ^(7|28)$ ]]
}

node_internal_ip() {
  kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" --context "$CTX" get nodes \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
}

norm() { tr -d '[:space:]' <<<"$1"; }

backend_contract() {
  /usr/local/bin/cks114-backend-contract "$1"
}

default_kubernetes_unchanged() {
  local expected current
  expected=$(cat "$BASE/default-kubernetes-sha256" 2>/dev/null) || return 1
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || return 1
  current=$(kubectl --request-timeout=8s --kubeconfig "$TRUSTED_CONFIG" \
    --context "$CTX" -n default get svc kubernetes -o json 2>/dev/null | \
    jq -cS '{uid:.metadata.uid,spec:.spec}' | sha256sum | cut -d' ' -f1) || return 1
  [[ "$current" == "$expected" ]]
}

historical_phase_matches() {
  local live=$1 mark="$BASE/nodeport-phase-seen" svc_uid dep_uid seen
  [[ -s "$mark" ]] || return 1
  svc_uid=$(sed -n 's/^SERVICE_UID=//p' "$mark")
  dep_uid=$(sed -n 's/^DEPLOYMENT_UID=//p' "$mark")
  seen=$(sed -n 's/^SEEN_AT=//p' "$mark")
  [[ "$svc_uid" =~ ^[0-9a-f-]{36}$ && "$dep_uid" =~ ^[0-9a-f-]{36}$ && "$seen" =~ ^[0-9]{10,}$ ]] || return 1
  grep -Fxq "SERVICE_UID=$svc_uid" <<<"$live" && \
    grep -Fxq "DEPLOYMENT_UID=$dep_uid" <<<"$live"
}

poll_external_up() {
  local url=$1 sample i
  for i in $(seq 1 15); do
    sample=$(curl_probe_local "$url")
    if assert_http_200 "$sample"; then return 0; fi
    sleep 2
  done
  return 1
}

poll_external_down() {
  local url=$1 sample i
  for i in $(seq 1 15); do
    sample=$(curl_probe_local "$url")
    if assert_transport_denied "$sample"; then return 0; fi
    sleep 2
  done
  return 1
}

@test "0 Init" {
  mkdir -p /var/work/tests/result /var/work/tests/artifacts
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
}

@test "1. Student switched to the authentic live cluster1 context" {
  echo 1 >> /var/work/tests/result/all
  current=$(kubectl config current-context 2>/dev/null)
  contexts=$(kubectl config get-contexts -o name 2>/dev/null | sort)
  expected_contexts=$(printf '%s\n' cluster9-admin@cluster1 legacy-admin@legacy staging-admin@staging "$CTX" | sort)
  # Pin connectivity/authentication wiring, but allow a harmless default namespace
  # on a context: it does not change which API or user credentials are selected.
  kube_projection='{
    clusters: ([.clusters[] | {name,cluster:.cluster}] | sort_by(.name)),
    users: ([.users[] | {name,user:.user}] | sort_by(.name)),
    contexts: ([.contexts[] | {name,cluster:.context.cluster,user:.context.user}] | sort_by(.name))
  }'
  fixture=$(kubectl --kubeconfig "$TRUSTED_CONFIG" config view --raw -o json 2>/dev/null | jq -cS "$kube_projection")
  student=$(kubectl config view --raw -o json 2>/dev/null | jq -cS "$kube_projection")
  live=$(kubectl --context "$CTX" get --raw /version 2>/dev/null | jq -r 'has("gitVersion")' 2>/dev/null || echo false)
  nodes=$(kubectl --context "$CTX" get nodes -o json 2>/dev/null | jq -r '(.items|length)>0' 2>/dev/null || echo false)
  if [[ "$current" == "$CTX" && "$contexts" == "$expected_contexts" && -n "$fixture" && \
        "$student" == "$fixture" && "$live" == true && "$nodes" == true ]]; then
    PENDING_SUCCESS=true
  else
    echo "HINT: use-context $CTX and keep the original four-context kubeconfig, its cluster connection and client credentials intact." >&2
    return 1
  fi
}

@test "2. Certificate evidence matches the original bootstrap fixture" {
  echo 1 >> /var/work/tests/result/all
  artifact=/var/work/tests/artifacts/task2-cert.txt
  if [[ ! -s "$artifact" ]]; then
    echo "HINT: write SHA256_FP/SUBJECT/ISSUER/NOTBEFORE/NOTAFTER to $artifact." >&2
    return 1
  fi
  fixture_fp=$(cat "$BASE/initial-cert-sha256" 2>/dev/null)
  cert_pem=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' 2>/dev/null | base64 -d 2>/dev/null)
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
  if [[ "$fixture_fp" =~ ^[0-9a-f]{64}$ && "$expected_fp" == "$fixture_fp" && \
        "$(norm "$student_fp")" == "$(norm "$expected_fp")" && \
        "$(norm "$student_subject")" == *cluster9-admin* && \
        "$(norm "$student_subject")" == "$(norm "$expected_subject")" && \
        "$(norm "$student_issuer")" == "$(norm "$expected_issuer")" && \
        "$(norm "$student_notbefore")" == "$(norm "$expected_notbefore")" && \
        "$(norm "$student_notafter")" == "$(norm "$expected_notafter")" ]]; then
    PENDING_SUCCESS=true
  else
    echo "HINT: values must match the original cluster9-admin certificate, independently pinned during bootstrap." >&2
    return 1
  fi
}

@test "3. The same backend had a verified NodePort 30114 and internal DNS HTTP 200 phase" {
  echo 1 >> /var/work/tests/result/all
  if ! default_kubernetes_unchanged; then
    echo "HINT: default/kubernetes was modified from its bootstrap identity/specification." >&2
    return 1
  fi
  node_ip=$(node_internal_ip)
  create_probe "$NS" "${CHECKER_PREFIX}-in-cluster" || return 1
  in_cluster=$(curl_probe_in_cluster "$PROBE_POD" "http://kubernetes-public.$NS.svc.cluster.local/")
  if ! assert_http_200 "$in_cluster"; then
    echo "HINT: the in-cluster Service DNS must return HTTP 200 from a Ready backend." >&2
    return 1
  fi
  nodeport=$(backend_contract NodePort 2>/dev/null || true)
  if [[ -n "$nodeport" ]]; then
    if poll_external_up "http://$node_ip:$NODEPORT/"; then
      PENDING_SUCCESS=true
      return 0
    fi
  fi
  clusterip=$(backend_contract ClusterIP 2>/dev/null || true)
  if [[ -n "$clusterip" ]] && historical_phase_matches "$clusterip"; then
    PENDING_SUCCESS=true
  else
    echo "HINT: the trusted monitor must have captured HTTP 200 via NodePort 30114 AND Service DNS for this exact Service/Deployment before the ClusterIP switch." >&2
    return 1
  fi
}

@test "4. ClusterIP preserves the same backend and closes node:30114 transport" {
  echo 1 >> /var/work/tests/result/all
  if ! default_kubernetes_unchanged; then
    echo "HINT: default/kubernetes must remain untouched from its initial spec and UID." >&2
    return 1
  fi
  clusterip=$(backend_contract ClusterIP 2>/dev/null || true)
  if [[ -z "$clusterip" ]] || ! historical_phase_matches "$clusterip"; then
    echo "HINT: require ClusterIP with backend Deployment and ready EndpointSlices, linked to an authentic earlier NodePort phase." >&2
    return 1
  fi
  node_ip=$(node_internal_ip)
  external_denied=false
  poll_external_down "http://$node_ip:$NODEPORT/" && external_denied=true
  create_probe "$NS" "${CHECKER_PREFIX}-in-cluster" || return 1
  in_cluster=$(curl_probe_in_cluster "$PROBE_POD" "http://kubernetes-public.$NS.svc.cluster.local/")
  if [[ "$external_denied" == true ]] && assert_http_200 "$in_cluster"; then
    PENDING_SUCCESS=true
  else
    echo "HINT: 30114 must be transport-denied (curl 7/28, HTTP 000), and Service DNS must still return HTTP 200." >&2
    return 1
  fi
}
