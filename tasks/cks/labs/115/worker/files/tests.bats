#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
APP_NS="app-115"
INGRESS_NS="ingress-115"
POLICY_NAME="backend-auth-required"
CHECKER_LABEL="cks.lab/checker=115"

setup() {
  RUN_ID="$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-12)"
  CHECKER_PREFIX="cks-115-${RUN_ID}"
  CHECKER_NS="${CHECKER_PREFIX}"
  CREATED_CHECKER_NS=false
  RUN_SELECTOR="cks.lab/run=${RUN_ID}"
  MIRROR_POLICY=""
  MIRROR_SERVICE=""
  TEMP_NAMESPACE=""
  MUTATED=false
  PENDING_SUCCESS=false
}

k() { kubectl --context "$CTX" "$@"; }

ensure_checker_ns() {
  local msg
  if msg=$(k get namespace "$CHECKER_NS" -o name 2>&1); then
    [[ "$CREATED_CHECKER_NS" == true ]]
    return
  fi
  [[ "$msg" == *"NotFound"* ]] || return 1
  CREATED_CHECKER_NS=true
  k create namespace "$CHECKER_NS" >/dev/null
}

# A failed cleanup must fail the test: orphaned test workloads or policy rules can
# alter future checks. Never delete a student-owned policy or workload.
teardown() {
  local bad=0 namespace ns_output
  # These temporary objects are checker-owned; do not allow a second signal to
  # interrupt their cleanup. Every API call still has a bounded timeout.
  trap '' INT TERM
  if [[ -n "$MIRROR_POLICY" ]]; then
    timeout 90s kubectl --context "$CTX" -n "$CHECKER_NS" delete ciliumnetworkpolicy "$MIRROR_POLICY" --ignore-not-found --wait=true --timeout=60s >/dev/null || bad=1
  fi
  if [[ -n "$MIRROR_SERVICE" ]]; then
    timeout 90s kubectl --context "$CTX" -n "$CHECKER_NS" delete service "$MIRROR_SERVICE" --ignore-not-found --wait=true --timeout=60s >/dev/null || bad=1
  fi
  if [[ "$MUTATED" == true ]]; then
    for namespace in "$APP_NS" "$INGRESS_NS" "$CHECKER_NS"; do
      if ns_output=$(timeout 30s kubectl --context "$CTX" get namespace "$namespace" -o name 2>&1); then
        timeout 120s kubectl --context "$CTX" -n "$namespace" delete pod -l "$RUN_SELECTOR" --ignore-not-found --wait=true --timeout=90s >/dev/null || bad=1
        local remaining
        remaining=$(timeout 30s kubectl --context "$CTX" -n "$namespace" get pod -l "$RUN_SELECTOR" -o json 2>/dev/null | jq '.items|length') || bad=1
        [[ "$remaining" == "0" ]] || bad=1
      elif [[ "$ns_output" != *"NotFound"* ]]; then
        bad=1
      fi
    done
  fi
  if [[ -n "$TEMP_NAMESPACE" ]]; then
    timeout 150s kubectl --context "$CTX" delete namespace "$TEMP_NAMESPACE" --ignore-not-found --wait=true --timeout=120s >/dev/null || bad=1
    if ns_output=$(timeout 30s kubectl --context "$CTX" get namespace "$TEMP_NAMESPACE" -o name 2>&1); then
      bad=1
    elif [[ "$ns_output" != *"NotFound"* ]]; then
      bad=1
    fi
  fi
  if [[ "$CREATED_CHECKER_NS" == true ]]; then
    timeout 150s kubectl --context "$CTX" delete namespace "$CHECKER_NS" --ignore-not-found --wait=true --timeout=120s >/dev/null || bad=1
    if ns_output=$(timeout 30s kubectl --context "$CTX" get namespace "$CHECKER_NS" -o name 2>&1); then
      bad=1
    elif [[ "$ns_output" != *"NotFound"* ]]; then
      bad=1
    fi
  fi
  if ((bad)); then
    echo "FATAL: Lab 115 checker cleanup is incomplete (run=$RUN_ID); inspect checker-owned resources." >&2
    return 1
  fi
  if [[ "$PENDING_SUCCESS" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  fi
  return 0
}

create_probe() {
  local namespace=$1 name=$2
  MUTATED=true
  k -n "$namespace" run "$name" --restart=Never --image=curlimages/curl:8.11.1 \
    --labels="$CHECKER_LABEL,$RUN_SELECTOR" --command -- sh -c 'sleep 300' >/dev/null || return 1
  k -n "$namespace" wait --for=condition=Ready "pod/$name" --timeout=120s >/dev/null
}

curl_probe() {
  local namespace=$1 pod=$2 destination=$3
  k -n "$namespace" exec "$pod" -- sh -c \
    "code=\$(curl -sSk -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 8 '$destination'); rc=\$?; printf 'CURL_EXIT:%s\\nHTTPCODE:%s\\n' \"\$rc\" \"\$code\"; exit 0"
}

curl_probe_retry() {
  local namespace=$1 pod=$2 destination=$3 output attempt
  for attempt in {1..12}; do
    output=$(curl_probe "$namespace" "$pod" "$destination") || return 1
    if assert_http_ok "$output"; then printf '%s\n' "$output"; return 0; fi
    sleep 3
  done
  printf '%s\n' "$output"
  return 1
}

assert_http_ok() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$rc" == 0 && "$code" =~ ^2[0-9][0-9]$ ]]
}

assert_api_http() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$rc" == 0 && "$code" =~ ^(200|401|403)$ ]]
}

assert_transport_denied() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$code" == "000" && "$rc" =~ ^(7|28)$ ]]
}

# Reject unused auth-required rules, extra allowed sources, extra ingress rules,
# selectors that do not match the backend, and all policy variants with an
# additional path admitting non-authenticated traffic. The required contract is
# the reference policy: one exact source namespace, one TCP/80 ingress rule.
check_policy_shape() {
  jq -e '
    .apiVersion == "cilium.io/v2" and .kind == "CiliumNetworkPolicy" and
    .metadata.namespace == "app-115" and .metadata.name == "backend-auth-required" and
    (.spec | keys - ["endpointSelector","ingress","description"] | length == 0) and
    .spec.endpointSelector == {"matchLabels":{"app":"backend"}} and
    (.spec.ingress | type == "array" and length == 1) and
    (.spec.ingress[0] | keys - ["fromEndpoints","toPorts","authentication"] | length == 0) and
    .spec.ingress[0].fromEndpoints == [{"matchLabels":{"k8s:io.kubernetes.pod.namespace":"ingress-115"}}] and
    .spec.ingress[0].authentication == {"mode":"required"} and
    .spec.ingress[0].toPorts == [{"ports":[{"port":"80","protocol":"TCP"}]}]
  ' >/dev/null
}

# This standalone lab expects no additional allow path targeting the backend.
# Additional namespaced/global policies can mask a broken target rule or allow
# identities other than ingress-115; they are not part of this lab's contract.
check_policy_isolation() {
  local cnps ccnps knps
  cnps=$(k -n "$APP_NS" get ciliumnetworkpolicies -o json) || return 1
  ccnps=$(k get ciliumclusterwidenetworkpolicies -o json) || return 1
  knps=$(k -n "$APP_NS" get networkpolicies -o json) || return 1
  jq -e '[.items[].metadata.name] == ["backend-auth-required"]' <<<"$cnps" >/dev/null &&
    jq -e '.items | length == 0' <<<"$ccnps" >/dev/null &&
    jq -e '.items | length == 0' <<<"$knps" >/dev/null
}

# Real live routing: the Service's only ready backend must be the intended Pod,
# not a decoy that happens to return an HTTP status.
check_backend_routing() {
  local pod svc slices
  pod=$(k -n "$APP_NS" get pod backend -o json) || return 1
  svc=$(k -n "$APP_NS" get service backend -o json) || return 1
  slices=$(k -n "$APP_NS" get endpointslice -l kubernetes.io/service-name=backend -o json) || return 1
  jq -e '
    .metadata.labels.app == "backend" and (.spec.hostNetwork != true) and
    ((.status.conditions // []) | any(.type=="Ready" and .status=="True")) and
    ((.status.podIP // "") | length > 0)
  ' <<<"$pod" >/dev/null || return 1
  jq -e --argjson pod "$pod" '
    .spec.type == "ClusterIP" and (.spec.selector | type=="object" and length>0) and
    ([.spec.selector | to_entries[] | . as $item | $pod.metadata.labels[$item.key] == $item.value] | all) and
    (.spec.ports | any(.port==80 and (.protocol == "TCP" or .protocol==null)))
  ' <<<"$svc" >/dev/null || return 1
  jq -e --argjson pod "$pod" '
    [.items[].endpoints[]] as $endpoints |
    ($endpoints | length > 0) and
    all($endpoints[]; .targetRef.kind == "Pod" and .targetRef.name == "backend" and
      .targetRef.uid == $pod.metadata.uid and .conditions.ready == true and
      (.addresses | index($pod.status.podIP) != null))
  ' <<<"$slices" >/dev/null
}

check_backend_routing_retry() {
  local attempt
  for attempt in {1..18}; do
    if check_backend_routing; then return 0; fi
    sleep 2
  done
  return 1
}

# Prove that the *particular* freshly-created source identity authenticated to
# the *particular* real backend identity, not that some unrelated auth entry
# exists somewhere on the node.
check_spire_pair() {
  local client=$1 src dst pods agent table attempt ds_uid ds
  ds=$(k -n kube-system get daemonset cilium -o json) || return 1
  ds_uid=$(jq -er '.metadata.uid' <<<"$ds") || return 1
  for attempt in {1..12}; do
    src=$(k -n "$INGRESS_NS" get ciliumendpoint "$client" -o jsonpath='{.status.identity.id}' 2>/dev/null) || src=""
    dst=$(k -n "$APP_NS" get ciliumendpoint backend -o jsonpath='{.status.identity.id}' 2>/dev/null) || dst=""
    if [[ "$src" =~ ^[0-9]+$ && "$dst" =~ ^[0-9]+$ ]]; then
      # BPF authentication maps are NODE-LOCAL. `kubectl exec ds/cilium` chooses
      # one arbitrary daemon and can miss an authenticated pair on another node.
      pods=$(k -n kube-system get pods -l k8s-app=cilium -o json 2>/dev/null) || pods=""
      if [[ -n "$pods" ]]; then
        while IFS= read -r agent; do
          [[ -n "$agent" ]] || continue
          table=$(k -n kube-system exec "$agent" -c cilium-agent -- cilium-dbg bpf auth list 2>/dev/null) || continue
          if awk -v src="$src" -v dst="$dst" '($1==src && $2==dst && $4=="spire") {hit=1} END {exit !hit}' <<<"$table"; then
            return 0
          fi
        done < <(jq -r --arg uid "$ds_uid" '.items[]? | select(
          .status.phase=="Running" and .metadata.deletionTimestamp==null and
          any(.metadata.ownerReferences[]?; .kind=="DaemonSet" and .controller==true and .uid==$uid)
        ) | .metadata.name' <<<"$pods")
      fi
    fi
    sleep 3
  done
  return 1
}

@test "0 Init" {
  mkdir -p /var/work/tests/result
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
}

@test "1. No kube-proxy DaemonSet and the Kubernetes API is available" {
  echo 1 >> /var/work/tests/result/all
  local output
  output=$(k -n kube-system get ds kube-proxy -o json 2>&1)
  local rc=$?
  if [[ $rc -ne 0 && "$output" == *"NotFound"* ]] && k get nodes -o json | jq -e '.items | length > 0' >/dev/null; then
    PENDING_SUCCESS=true
  else
    echo "HINT: kube-proxy DaemonSet must be NotFound on an available API; errors such as RBAC/timeout are not proof of absence." >&2
    return 1
  fi
}

@test "2. Effective kube-proxy replacement and real ClusterIP API Service" {
  echo 1 >> /var/work/tests/result/all
  local status nodes_ready api dns
  status=$(k -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status) || return 1
  grep -qE 'KubeProxyReplacement:[[:space:]]*(True|Strict)' <<<"$status" || return 1
  nodes_ready=$(k get nodes -o json | jq -re '(.items|length)>0 and all(.items[]; any(.status.conditions[]; .type=="Ready" and .status=="True"))')
  [[ "$nodes_ready" == true ]] || return 1
  ensure_checker_ns || return 1
  create_probe "$CHECKER_NS" "${CHECKER_PREFIX}-svc"
  dns=$(k -n "$CHECKER_NS" exec "${CHECKER_PREFIX}-svc" -- getent hosts kubernetes.default.svc.cluster.local) || return 1
  [[ -n "$dns" ]] || return 1
  api=$(curl_probe "$CHECKER_NS" "${CHECKER_PREFIX}-svc" 'https://kubernetes.default.svc.cluster.local/') || return 1
  assert_api_http "$api" || return 1
  PENDING_SUCCESS=true
}

@test "3. Effective WireGuard configuration and no ClusterIP regression" {
  echo 1 >> /var/work/tests/result/all
  local status regression
  status=$(k -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status) || return 1
  grep -qE 'Encryption:[[:space:]]*Wireguard' <<<"$status" || return 1
  [[ $(k -n kube-system get cm cilium-config -o json | jq -r '.data["enable-wireguard"] // "false"') == true ]] || return 1
  ensure_checker_ns || return 1
  create_probe "$CHECKER_NS" "${CHECKER_PREFIX}-wg"
  regression=$(curl_probe "$CHECKER_NS" "${CHECKER_PREFIX}-wg" 'https://kubernetes.default.svc.cluster.local/') || return 1
  assert_api_http "$regression" || return 1
  PENDING_SUCCESS=true
}

@test "4. The actual SPIRE StatefulSet and DaemonSet are Ready" {
  echo 1 >> /var/work/tests/result/all
  local server agent
  server=$(k -n cilium-spire get statefulset spire-server -o json) || return 1
  agent=$(k -n cilium-spire get daemonset spire-agent -o json) || return 1
  jq -e '.spec.replicas >= 1 and .status.readyReplicas >= .spec.replicas and .status.observedGeneration >= .metadata.generation' <<<"$server" >/dev/null || return 1
  jq -e '.status.desiredNumberScheduled >= 1 and .status.numberReady == .status.desiredNumberScheduled and .status.observedGeneration >= .metadata.generation' <<<"$agent" >/dev/null || return 1
  PENDING_SUCCESS=true
}

@test "5. Exact source/auth CiliumNetworkPolicy and live backend routing" {
  echo 1 >> /var/work/tests/result/all
  k get namespace "$APP_NS" "$INGRESS_NS" >/dev/null || return 1
  local policy_json
  policy_json=$(k -n "$APP_NS" get ciliumnetworkpolicy "$POLICY_NAME" -o json) || return 1
  check_policy_shape <<<"$policy_json" || { echo 'HINT: use one matching backend ingress rule, exact ingress-115 source, TCP/80 and required auth; extra rules and weaker paths are forbidden.' >&2; return 1; }
  check_policy_isolation || { echo 'HINT: remove other NetworkPolicy/CNP/CCNP rules from the isolated Lab 115 backend environment.' >&2; return 1; }
  check_backend_routing_retry || { echo 'HINT: backend Pod must be Ready and backend Service/EndpointSlice must route only to that Pod.' >&2; return 1; }
  PENDING_SUCCESS=true
}

@test "6. Non-disruptive baseline, real SPIRE auth pair and independent denials" {
  echo 1 >> /var/work/tests/result/all
  local policy_json actual_url mirror_url actual_ok wrong wrong2 pre_good pre_wrong after_good after_wrong
  policy_json=$(k -n "$APP_NS" get ciliumnetworkpolicy "$POLICY_NAME" -o json) || return 1
  check_policy_shape <<<"$policy_json" || return 1
  check_policy_isolation || return 1
  check_backend_routing_retry || return 1

  # Use an isolated mirror for baseline. The student's live policy is never
  # removed, patched or replaced by the checker.
  ensure_checker_ns || return 1
  MIRROR_SERVICE="mirror-${RUN_ID}"
  MUTATED=true
  k -n "$CHECKER_NS" run "$MIRROR_SERVICE" --restart=Never --image=viktoruj/ping_pong:alpine \
    --labels="$CHECKER_LABEL,$RUN_SELECTOR,app=backend" --port=80 --env=SRV_PORT=80 >/dev/null || return 1
  k -n "$CHECKER_NS" wait --for=condition=Ready "pod/$MIRROR_SERVICE" --timeout=120s >/dev/null || return 1
  k -n "$CHECKER_NS" expose pod "$MIRROR_SERVICE" --name="$MIRROR_SERVICE" --port=80 --target-port=80 >/dev/null || return 1

  create_probe "$INGRESS_NS" "${CHECKER_PREFIX}-authorized"
  create_probe "$APP_NS" "${CHECKER_PREFIX}-wrong"
  TEMP_NAMESPACE="${CHECKER_PREFIX}-outsider"
  k create namespace "$TEMP_NAMESPACE" >/dev/null || return 1
  create_probe "$TEMP_NAMESPACE" "${CHECKER_PREFIX}-outsider"

  mirror_url="http://${MIRROR_SERVICE}.${CHECKER_NS}.svc.cluster.local/"
  actual_url="http://backend.${APP_NS}.svc.cluster.local/"
  pre_good=$(curl_probe_retry "$INGRESS_NS" "${CHECKER_PREFIX}-authorized" "$mirror_url") || return 1
  pre_wrong=$(curl_probe_retry "$APP_NS" "${CHECKER_PREFIX}-wrong" "$mirror_url") || return 1
  assert_http_ok "$pre_good" && assert_http_ok "$pre_wrong" || return 1

  # The mirror is protected by a copy of the EXACT same reviewed policy,
  # while the real app-115 policy remains active throughout.
  MIRROR_POLICY="mirror-auth-${RUN_ID}"
  jq --arg name "$MIRROR_POLICY" --arg ns "$CHECKER_NS" \
    '.metadata={"name":$name,"namespace":$ns} | del(.status)' <<<"$policy_json" | k apply -f - >/dev/null || return 1

  local attempt denied=false
  for attempt in {1..12}; do
    after_wrong=$(curl_probe "$APP_NS" "${CHECKER_PREFIX}-wrong" "$mirror_url") || return 1
    if assert_transport_denied "$after_wrong"; then denied=true; break; fi
    sleep 3
  done
  [[ "$denied" == true ]] || return 1
  after_good=$(curl_probe_retry "$INGRESS_NS" "${CHECKER_PREFIX}-authorized" "$mirror_url") || return 1
  assert_http_ok "$after_good" || return 1

  # Independently check the actual protected backend, and a newly-created
  # third namespace, not just the namespace of the original wrong probe.
  actual_ok=$(curl_probe_retry "$INGRESS_NS" "${CHECKER_PREFIX}-authorized" "$actual_url") || return 1
  assert_http_ok "$actual_ok" || return 1
  wrong=$(curl_probe "$APP_NS" "${CHECKER_PREFIX}-wrong" "$actual_url") || return 1
  wrong2=$(curl_probe "$TEMP_NAMESPACE" "${CHECKER_PREFIX}-outsider" "$actual_url") || return 1
  assert_transport_denied "$wrong" && assert_transport_denied "$wrong2" || return 1
  check_spire_pair "${CHECKER_PREFIX}-authorized" || { echo 'HINT: no exact src/dst spire entry in the live Cilium BPF auth map.' >&2; return 1; }

  PENDING_SUCCESS=true
}
