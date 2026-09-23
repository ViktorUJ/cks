#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
APP_NS="app-115"
INGRESS_NS="ingress-115"
POLICY_NAME="backend-auth-required"
CHECKER_LABEL="cks.lab/checker=115"
CHECKER_NS="cks-115-checker"

setup() {
  CHECKER_PREFIX="cks-115-checker-${BATS_TEST_NUMBER}-$$"
}

teardown() {
  local namespace
  for namespace in "$APP_NS" "$INGRESS_NS" "$CHECKER_NS"; do
    kubectl --context "$CTX" -n "$namespace" delete pod -l "$CHECKER_LABEL" \
      --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done
}

create_probe() {
  local namespace=$1 name=$2 image=${3:-curlimages/curl:8.11.1}
  kubectl --context "$CTX" -n "$namespace" run "$name" --restart=Never --image="$image" \
    --labels="$CHECKER_LABEL" --command -- sh -c 'sleep 300' >/dev/null
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

@test "0 Init" {
  mkdir -p /var/work/tests/result
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
}

@test "1. Baseline: kubeadm cluster is kube-proxy-free before any CNI is installed" {
  echo 1 >> /var/work/tests/result/all
  no_kube_proxy=false
  kubectl --context "$CTX" -n kube-system get ds kube-proxy >/dev/null 2>&1 || no_kube_proxy=true
  if [[ "$no_kube_proxy" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: this lab's kubeadm init used --skip-phases=addon/kube-proxy; kube-proxy DaemonSet must not exist at any point." >&2
    false
  fi
}

@test "2. Cilium installed with kube-proxy replacement and the Service datapath works" {
  echo 1 >> /var/work/tests/result/all
  status=$(cilium status 2>&1) || true
  kpr_ok=false
  grep -qE 'KubeProxyReplacement:\s*(True|Strict)' <<<"$status" && kpr_ok=true
  nodes_ready=$(kubectl --context "$CTX" get nodes -o json 2>/dev/null | jq -r '[.items[].status.conditions[] | select(.type=="Ready") | .status=="True"] | all')

  kubectl --context "$CTX" get namespace "$CHECKER_NS" >/dev/null 2>&1 || kubectl --context "$CTX" create namespace "$CHECKER_NS" >/dev/null
  create_probe "$CHECKER_NS" "${CHECKER_PREFIX}-svc"
  dns=$(kubectl --context "$CTX" -n "$CHECKER_NS" exec "${CHECKER_PREFIX}-svc" -- sh -c 'getent hosts kubernetes.default.svc.cluster.local' 2>&1)
  api=$(curl_probe "$CHECKER_NS" "${CHECKER_PREFIX}-svc" "https://kubernetes.default.svc.cluster.local/")

  if [[ "$kpr_ok" == true && "$nodes_ready" == true && -n "$dns" ]] && assert_reachable "$api"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: 'cilium status' must report KubeProxyReplacement True/Strict, nodes must be Ready, and a Pod must be able to resolve/reach the in-cluster kubernetes.default Service without kube-proxy." >&2
    false
  fi
}

@test "3. WireGuard transparent encryption is enabled in the effective Cilium config" {
  echo 1 >> /var/work/tests/result/all
  status=$(cilium status 2>&1) || true
  wg_ok=false
  grep -qE 'Encryption:\s*Wireguard' <<<"$status" && wg_ok=true

  kubectl --context "$CTX" get namespace "$CHECKER_NS" >/dev/null 2>&1 || kubectl --context "$CTX" create namespace "$CHECKER_NS" >/dev/null
  create_probe "$CHECKER_NS" "${CHECKER_PREFIX}-wg"
  regression=$(curl_probe "$CHECKER_NS" "${CHECKER_PREFIX}-wg" "https://kubernetes.default.svc.cluster.local/")

  if [[ "$wg_ok" == true ]] && assert_reachable "$regression"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: 'cilium status' must report Encryption: Wireguard, and the in-cluster Service path from task 2 must not have regressed." >&2
    false
  fi
}

@test "4. Cilium Mutual Authentication with SPIRE is healthy" {
  echo 1 >> /var/work/tests/result/all
  spire_pods=$(kubectl --context "$CTX" get pods -A -o json 2>/dev/null | jq -r '
    [.items[] | select(.metadata.name | test("spire-(server|agent)")) |
      ((.status.conditions // []) | any(.type == "Ready" and .status == "True"))] as $ready |
    (($ready | length) >= 2) and (all($ready[]; .))')

  if [[ "$spire_pods" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: enable Cilium's bundled SPIRE install (authentication.mutual.spire.enabled=true, authentication.mutual.spire.install.enabled=true) and wait for spire-server/spire-agent Pods to become Ready." >&2
    false
  fi
}

@test "5. CiliumNetworkPolicy requires mutual authentication between ingress-115 and app-115" {
  echo 1 >> /var/work/tests/result/all
  if ! kubectl --context "$CTX" get namespace "$APP_NS" "$INGRESS_NS" >/dev/null 2>&1; then
    echo "HINT: create namespaces $APP_NS and $INGRESS_NS with backend/client workloads before task 5 validation." >&2
    false
  fi
  shape=$(kubectl --context "$CTX" -n "$APP_NS" get ciliumnetworkpolicy "$POLICY_NAME" -o json 2>/dev/null | jq -r '
    .spec.endpointSelector.matchLabels.app == "backend" and
    (.spec.ingress | length > 0) and
    ([.spec.ingress[] |
      (.fromEndpoints[0].matchLabels["k8s:io.kubernetes.pod.namespace"] == "ingress-115") and
      (.authentication.mode == "required")] | any)')
  if [[ "$shape" == true ]]; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: $POLICY_NAME in $APP_NS must select app=backend, allow ingress from namespace $INGRESS_NS, and set ingress[].authentication.mode: required." >&2
    false
  fi
}

@test "6. Authenticated identity is allowed, wrong identity is denied, and auth-required is a real change from baseline" {
  echo 1 >> /var/work/tests/result/all
  policy_json=$(kubectl --context "$CTX" -n "$APP_NS" get ciliumnetworkpolicy "$POLICY_NAME" -o json 2>/dev/null)
  if [[ -z "$policy_json" || "$policy_json" == "null" ]]; then
    echo "HINT: complete task 5 before the positive/negative authentication controls." >&2
    false
  fi
  clean=$(jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' <<<"$policy_json")

  backend_url="http://backend.$APP_NS.svc.cluster.local/"
  create_probe "$INGRESS_NS" "${CHECKER_PREFIX}-authorized"

  kubectl --context "$CTX" delete -f - <<<"$clean" >/dev/null 2>&1
  sleep 2
  baseline=$(curl_probe "$INGRESS_NS" "${CHECKER_PREFIX}-authorized" "$backend_url")

  kubectl --context "$CTX" apply -f - <<<"$clean" >/dev/null
  sleep 3
  authorized=$(curl_probe "$INGRESS_NS" "${CHECKER_PREFIX}-authorized" "$backend_url")

  create_probe "$APP_NS" "${CHECKER_PREFIX}-wrong-ns"
  wrong=$(curl_probe "$APP_NS" "${CHECKER_PREFIX}-wrong-ns" "$backend_url")

  if assert_reachable "$baseline" && assert_reachable "$authorized" && assert_transport_denied "$wrong"; then
    echo 1 >> /var/work/tests/result/ok
  else
    echo "HINT: before the policy exists, ingress-115 must reach backend; after re-applying it, ingress-115 must still reach backend (now via mutual auth), while a probe from app-115 itself (wrong identity/namespace) must be denied." >&2
    false
  fi
}
