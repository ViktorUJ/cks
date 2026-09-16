#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-101"
LEGACY_NS="cks-101-legacy"
CONTROL_NS="cks-101-checker-control-$$"
IMDS_URL=http://169.254.169.254/
IMDS_CIDR=169.254.169.254/32
CHECKER_LABEL="cks.lab/checker=101"

setup() {
  CHECKER_PREFIX="cks-101-checker-${BATS_TEST_NUMBER}-$$"
  CONTROL_CREATED=false
}

teardown() {
  cleanup
}

cleanup() {
  local namespace
  for namespace in "$NS" "$LEGACY_NS"; do
    kubectl --context "$CTX" -n "$namespace" delete pod -l "$CHECKER_LABEL" \
      --ignore-not-found --wait=false >/dev/null 2>&1 || true
    kubectl --context "$CTX" -n "$namespace" delete networkpolicy -l "$CHECKER_LABEL" \
      --ignore-not-found --wait=true >/dev/null 2>&1 || true
  done
  if [[ "${CONTROL_CREATED:-false}" == true ]]; then
    kubectl --context "$CTX" delete namespace "$CONTROL_NS" \
      --ignore-not-found --wait=true >/dev/null 2>&1 || true
  fi
}

create_probe() {
  local namespace=$1 name=$2 labels=$3 image=${4:-curlimages/curl:8.11.1}
  kubectl --context "$CTX" -n "$namespace" run "$name" --restart=Never --image="$image" \
    --labels="$labels,$CHECKER_LABEL" --command -- sh -c 'sleep 300' >/dev/null
  kubectl --context "$CTX" -n "$namespace" wait --for=condition=Ready "pod/$name" --timeout=90s >/dev/null
}

curl_probe() {
  local namespace=$1 pod=$2 destination=$3
  kubectl --context "$CTX" -n "$namespace" exec "$pod" -- sh -c \
    "set +e; code=\$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 2 --max-time 5 '$destination'); rc=\$?; printf 'CURL_EXIT:%s\\nHTTPCODE:%s\\n' \"\$rc\" \"\$code\"; exit 0"
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

assert_observed_probe() {
  local output=$1 rc code
  rc=$(sed -n 's/^CURL_EXIT:\([0-9][0-9]*\)$/\1/p' <<<"$output" | tail -1)
  code=$(sed -n 's/^HTTPCODE:\([0-9][0-9][0-9]\)$/\1/p' <<<"$output" | tail -1)
  [[ "$rc" =~ ^[0-9]+$ && "$code" =~ ^[0-9]{3}$ ]]
}

comparison_probe_values() {
  local artifact=$1 prefix=${2:-} exits codes
  mapfile -t exits < <(grep -E "^${prefix}CURL_EXIT:[0-9]+$" "$artifact" 2>/dev/null)
  mapfile -t codes < <(grep -E "^${prefix}HTTPCODE:[0-9]{3}$" "$artifact" 2>/dev/null)
  [[ ${#exits[@]} -eq 1 && ${#codes[@]} -eq 1 ]] || return 1
  printf '%s %s\n' "${exits[0]#${prefix}CURL_EXIT:}" "${codes[0]#${prefix}HTTPCODE:}"
}

comparison_probe_values() {
  local key=$1 comparison=$2 line rc code
  line=$(sed -n "s/^${key}=//p" "$comparison" 2>/dev/null | tail -1)
  [[ -n "$line" && "$line" =~ curl_exit=([0-9]+) ]] || return 1
  rc=${BASH_REMATCH[1]}
  [[ "$line" =~ http_code=([0-9]{3}) ]] || return 1
  code=${BASH_REMATCH[1]}
  printf '%s %s\n' "$rc" "$code"
}

no_unexpected_student_policies() {
  local namespace=$1
  shift
  local expected actual
  expected=$(printf '%s\n' "$@" | sort)
  actual=$(kubectl --context "$CTX" -n "$namespace" get networkpolicy -o json 2>/dev/null | \
    jq -r '.items[].metadata.name' | sort)
  [[ "$actual" == "$expected" ]]
}

apply_checker_policy() {
  local namespace=$1 name=$2 spec=$3
  {
    cat <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: $name
  namespace: $namespace
  labels: {cks.lab/checker: "101"}
spec:
EOF
    printf '%b\n' "$spec"
  } | kubectl --context "$CTX" apply -f - >/dev/null
  # Allow Calico to observe the policy before the probe.
  sleep 2
}

create_imds_control() {
  # Create a checker-owned namespace separate from student's imds-control.
  # The student may have created imds-control themselves - we don't touch it.
  if ! kubectl --context "$CTX" get namespace "$CONTROL_NS" >/dev/null 2>&1; then
    kubectl --context "$CTX" create namespace "$CONTROL_NS" >/dev/null
    CONTROL_CREATED=true
  fi
}

control_imds_probe() {
  local name=$1 output
  create_probe "$CONTROL_NS" "$name" 'role=imds-control'
  output=$(curl_probe "$CONTROL_NS" "$name" "$IMDS_URL")
  assert_reachable "$output" || return 1
  printf '%s\n' "$output"
}

backend_ip() {
  kubectl --context "$CTX" -n "$NS" get endpoints backend -o jsonpath='{.subsets[0].addresses[0].ip}'
}

@test "0 Init" {
  mkdir -p /var/work/tests/result
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
  : > /var/work/tests/result/requests
}

@test "1. Immutable non-hostNetwork frontend and backend are ready with their live labels" {
  echo 1 >> /var/work/tests/result/all
  deployments=$(kubectl --context "$CTX" get deploy frontend backend -n "$NS" -o json 2>/dev/null | jq -r '
    (.items | length == 2) and
    ([.items[].metadata.name] | sort == ["backend", "frontend"]) and
    ([.items[].spec.replicas] == [1, 1]) and
    ([.items[] | (.status.readyReplicas // 0) >= 1] | all) and
    ([.items[].spec.template.metadata.labels.app] | sort == ["backend", "frontend"]) and
    (([.items[].spec.template.spec.hostNetwork // false] | any) | not) and
    ([.items[].spec.template.spec.containers[0].image] | unique | length == 1) and
    ([.items[].spec.template.spec.containers[0].image] | all(test("^viktoruj/ping_pong@sha256:[a-f0-9]{64}$")))')
  pods=$(kubectl --context "$CTX" get pod -n "$NS" -l 'app in (frontend,backend)' -o json 2>/dev/null | jq -r '
    [.items[] | select(.metadata.name != "hostnetwork-probe")] as $workloads |
    ($workloads | length >= 2) and
    ([$workloads[] | select(.metadata.labels.app == "frontend" or .metadata.labels.app == "backend") |
      ((.spec.hostNetwork // false) | not) and
      ((.status.conditions // []) | any(.type == "Ready" and .status == "True"))] | all)')
  service=$(kubectl --context "$CTX" get service backend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.selector == {"app":"backend"} and (.spec.ports | length == 1) and
    .spec.ports[0].protocol == "TCP" and .spec.ports[0].port == 8080 and .spec.ports[0].targetPort == 8080')
  endpoint=$(kubectl --context "$CTX" get endpoints backend -n "$NS" -o json 2>/dev/null | jq -r 'any(.subsets[]?; (.addresses // []) | length > 0)')
  if [[ "$deployments" == true && "$pods" == true && "$service" == true && "$endpoint" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: Create ready, non-hostNetwork frontend/backend pods with live app labels, one pinned image, and a TCP/8080 backend Service." >&2
    false
  fi
}

@test "2. Student default-deny blocks cks-101 while independent imds-control stays reachable" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then echo "HINT: Create namespace $NS and default-deny before checking isolation." >&2; false; fi
  shape=$(kubectl --context "$CTX" get networkpolicy default-deny -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {} and (.spec.policyTypes | sort) == ["Egress", "Ingress"] and
    ((.spec.ingress // []) | length == 0) and ((.spec.egress // []) | length == 0)')
  create_imds_control
  control_baseline=$(control_imds_probe "${CHECKER_PREFIX}-control-baseline")
  create_probe "$NS" "${CHECKER_PREFIX}-default-deny" 'role=unselected'
  denied=$(curl_probe "$NS" "${CHECKER_PREFIX}-default-deny" "$IMDS_URL")
  control_after_deny=$(control_imds_probe "${CHECKER_PREFIX}-control-after-deny")
  if [[ "$shape" == true ]] && assert_reachable "$control_baseline" && \
     assert_transport_denied "$denied" && assert_reachable "$control_after_deny"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: default-deny must yield HTTP 000 with curl 7/28 for an unselected cks-101 probe, while the checker-owned independent imds-control namespace reaches real EC2 IMDS both before and after." >&2
    false
  fi
}

@test "3. Student frontend reaches the real backend while a foreign identity is denied" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then echo "HINT: Create $NS, frontend/backend and their exact allow policies before runtime flow checks." >&2; false; fi
  frontend=$(kubectl --context "$CTX" get networkpolicy allow-frontend-egress-to-backend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"frontend"}} and .spec.policyTypes == ["Egress"] and
    .spec.egress == [{"to":[{"podSelector":{"matchLabels":{"app":"backend"}}}],"ports":[{"protocol":"TCP","port":8080}]}]')
  backend=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-frontend -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"backend"}} and .spec.policyTypes == ["Ingress"] and
    .spec.ingress == [{"from":[{"podSelector":{"matchLabels":{"app":"frontend"}}}],"ports":[{"protocol":"TCP","port":8080}]}]')
  policy_set=$(no_unexpected_student_policies "$NS" \
    default-deny allow-frontend-egress-to-backend allow-backend-ingress-from-frontend \
    allow-frontend-dns allow-backend-ingress-from-legacy && echo true || echo false)
  ip=$(backend_ip)
  [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]
  destination="http://$ip:8080/"
  create_probe "$NS" "${CHECKER_PREFIX}-frontend" 'app=frontend'
  frontend_result=$(curl_probe "$NS" "${CHECKER_PREFIX}-frontend" "$destination")
  create_probe "$NS" "${CHECKER_PREFIX}-foreign" 'app=foreign'
  apply_checker_policy "$NS" "${CHECKER_PREFIX}-foreign-egress" "  podSelector: {matchLabels: {app: foreign}}\n  policyTypes: [Egress]\n  egress:\n    - to: [{podSelector: {matchLabels: {app: backend}}}]\n      ports: [{protocol: TCP, port: 8080}]"
  foreign_result=$(curl_probe "$NS" "${CHECKER_PREFIX}-foreign" "$destination")
  if [[ "$frontend" == true && "$backend" == true && "$policy_set" == true ]] && assert_reachable "$frontend_result" && assert_transport_denied "$foreign_result"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: In cks-101, frontend must reach the actual backend:8080 and a foreign identity with checker-provided backend egress must still be rejected by backend ingress." >&2
    false
  fi
}

@test "4. DNS policy contains only full TCP/53 and UDP/53 objects and works in cks-101" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then echo "HINT: Create $NS and allow-frontend-dns before DNS runtime validation." >&2; false; fi
  shape=$(kubectl --context "$CTX" get networkpolicy allow-frontend-dns -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"frontend"}} and .spec.policyTypes == ["Egress"] and
    (.spec.egress | type == "array" and length > 0) and
    (all(.spec.egress[];
      .to == [{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"kube-system"}},"podSelector":{"matchLabels":{"k8s-app":"kube-dns"}}}] and
      (.ports | type == "array" and length > 0) and
      all(.ports[]; (keys | sort) == ["port", "protocol"] and
        (.protocol == "TCP" or .protocol == "UDP") and (.port | type == "number" and . == 53)))) and
    ([.spec.egress[].ports[] | {protocol, port}] | unique | sort_by(.protocol, .port)) ==
      [{"protocol":"TCP","port":53},{"protocol":"UDP","port":53}]')
  create_probe "$NS" "${CHECKER_PREFIX}-dns" 'app=frontend' busybox:1.36.1
  dns=$(kubectl --context "$CTX" -n "$NS" exec "${CHECKER_PREFIX}-dns" -- nslookup kubernetes.default.svc.cluster.local 2>&1)
  if [[ "$shape" == true && "$dns" == *"Name:"* ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: allow-frontend-dns must use exactly two complete NetworkPolicyPort objects (TCP/53 and UDP/53, no endPort) and permit the frontend probe DNS lookup." >&2
    false
  fi
}

@test "5. Frontend cannot reach IMDS while independent control remains reachable" {
  echo 1 >> /var/work/tests/result/all

  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then
    echo "HINT: Create $NS and the required NetworkPolicies before IMDS validation." >&2
    false
  fi

  policy_set=$(no_unexpected_student_policies "$NS" \
    default-deny allow-frontend-egress-to-backend allow-backend-ingress-from-frontend \
    allow-frontend-dns allow-backend-ingress-from-legacy && echo true || echo false)

  create_imds_control
  control_before=$(control_imds_probe "${CHECKER_PREFIX}-task5-control-before")

  create_probe "$NS" "${CHECKER_PREFIX}-metadata" 'app=frontend'
  denied=$(curl_probe "$NS" "${CHECKER_PREFIX}-metadata" "$IMDS_URL")

  control_after=$(control_imds_probe "${CHECKER_PREFIX}-task5-control-after")

  if [[ "$policy_set" == true ]] && \
     assert_reachable "$control_before" && \
     assert_transport_denied "$denied" && \
     assert_reachable "$control_after"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: frontend must receive HTTP 000 with curl 7/28 for IMDS, while checker-owned independent control must reach real EC2 IMDS before and after the probe." >&2
    false
  fi
}

@test "6. Legacy effective policy proves IMDS deny and AND ingress semantics" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$NS" "$LEGACY_NS" >/dev/null 2>&1; then echo "HINT: Create both $NS and $LEGACY_NS with legacy-client and the required AND/except policies." >&2; false; fi
  ingress=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-legacy -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"backend"}} and .spec.policyTypes == ["Ingress"] and
    .spec.ingress == [{"from":[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"cks-101-legacy"}},"podSelector":{"matchLabels":{"app":"legacy-client"}}}],"ports":[{"protocol":"TCP","port":8080}]}]')
  egress=$(kubectl --context "$CTX" get networkpolicy allow-legacy-egress -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    .spec.podSelector == {"matchLabels":{"app":"legacy-client"}} and .spec.policyTypes == ["Egress"] and
    .spec.egress == [{"to":[{"ipBlock":{"cidr":"0.0.0.0/0","except":["169.254.169.254/32"]}}]}]')
  app_policy_set=$(no_unexpected_student_policies "$NS" \
    default-deny allow-frontend-egress-to-backend allow-backend-ingress-from-frontend \
    allow-frontend-dns allow-backend-ingress-from-legacy && echo true || echo false)
  legacy_policy_set=$(no_unexpected_student_policies "$LEGACY_NS" allow-legacy-egress && echo true || echo false)
  legacy=$(kubectl --context "$CTX" get deploy legacy-client -n "$LEGACY_NS" -o json 2>/dev/null | jq -r '
    .spec.selector == {"matchLabels":{"app":"legacy-client"}} and .spec.template.metadata.labels == {"app":"legacy-client"} and
    (.spec.template.spec.hostNetwork // false | not) and .spec.template.spec.containers[0].image == "curlimages/curl:8.11.1" and
    .spec.template.spec.containers[0].command == ["sleep", "3600"] and (.status.readyReplicas // 0) >= 1')
  live_legacy=$(kubectl --context "$CTX" get pod -n "$LEGACY_NS" -l app=legacy-client -o json 2>/dev/null | jq -r '
    (.items | length > 0) and ([.items[] | ((.spec.hostNetwork // false) | not) and ((.status.conditions // []) | any(.type == "Ready" and .status == "True"))] | all)')
  ip=$(backend_ip)
  [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]
  backend_url="http://$ip:8080/"
  actual_pod=$(kubectl --context "$CTX" -n "$LEGACY_NS" get pod -l 'app=legacy-client,cks.lab/checker notin (101)' -o jsonpath='{.items[0].metadata.name}')
  metadata=$(curl_probe "$LEGACY_NS" "$actual_pod" "$IMDS_URL")
  actual=$(curl_probe "$LEGACY_NS" "$actual_pod" "$backend_url")
  create_probe "$LEGACY_NS" "${CHECKER_PREFIX}-wrong-label" 'app=wrong-label'
  apply_checker_policy "$LEGACY_NS" "${CHECKER_PREFIX}-wrong-label-egress" "  podSelector: {matchLabels: {app: wrong-label}}\n  policyTypes: [Egress]\n  egress:\n    - to: [{ipBlock: {cidr: $ip/32}}]\n      ports: [{protocol: TCP, port: 8080}]"
  wrong_label=$(curl_probe "$LEGACY_NS" "${CHECKER_PREFIX}-wrong-label" "$backend_url")
  create_probe "$NS" "${CHECKER_PREFIX}-wrong-namespace" 'app=legacy-client'
  apply_checker_policy "$NS" "${CHECKER_PREFIX}-wrong-namespace-egress" "  podSelector: {matchLabels: {app: legacy-client}}\n  policyTypes: [Egress]\n  egress:\n    - to: [{ipBlock: {cidr: $ip/32}}]\n      ports: [{protocol: TCP, port: 8080}]"
  wrong_namespace=$(curl_probe "$NS" "${CHECKER_PREFIX}-wrong-namespace" "$backend_url")
  if [[ "$ingress" == true && "$egress" == true && "$app_policy_set" == true && "$legacy_policy_set" == true && "$legacy" == true && "$live_legacy" == true ]] && \
     assert_transport_denied "$metadata" && assert_reachable "$actual" && \
     assert_transport_denied "$wrong_label" && assert_transport_denied "$wrong_namespace"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: Legacy must exclude real EC2 IMDS with literal 169.254.169.254/32; the actual legacy workload alone must reach backend, while wrong-label and wrong-namespace probes with checker egress remain denied." >&2
    false
  fi
}

@test "7. Host-network probe is measured at runtime without assuming a fixed outcome" {
  echo 1 >> /var/work/tests/result/all

  if ! kubectl --context "$CTX" get namespace "$NS" >/dev/null 2>&1; then
    echo "HINT: Create $NS and hostnetwork-probe before task 7 validation." >&2
    false
  fi

  host=$(kubectl --context "$CTX" get pod hostnetwork-probe -n "$NS" -o json 2>/dev/null | jq -r '
    .spec.hostNetwork == true and
    .metadata.labels.app == "frontend" and
    .spec.containers[0].image == "curlimages/curl:8.11.1" and
    ((.status.conditions // []) | any(.type == "Ready" and .status == "True"))')

  policy_set=$(no_unexpected_student_policies "$NS" \
    default-deny allow-frontend-egress-to-backend allow-backend-ingress-from-frontend \
    allow-frontend-dns allow-backend-ingress-from-legacy && echo true || echo false)

  create_probe "$NS" "${CHECKER_PREFIX}-task7-normal" 'app=frontend'
  normal_result=$(curl_probe "$NS" "${CHECKER_PREFIX}-task7-normal" "$IMDS_URL")
  host_result=$(curl_probe "$NS" hostnetwork-probe "$IMDS_URL")

  if [[ "$host" == true && "$policy_set" == true ]] && \
     assert_transport_denied "$normal_result" && \
     assert_observed_probe "$host_result"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: A normal frontend pod must remain denied to IMDS. hostnetwork-probe must be Ready and its real IMDS result must be measured at runtime; no fixed hostNetwork outcome is assumed." >&2
    false
  fi
}
