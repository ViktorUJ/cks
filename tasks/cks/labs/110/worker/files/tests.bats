#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
SANDBOX_NS="sandbox-110"
ARTIFACTS="/var/work/tests/artifacts"

record_result() {
  echo '1' >> /var/work/tests/result/all
  if [[ "$1" -eq 0 ]]; then echo '1' >> /var/work/tests/result/ok; fi
  return "$1"
}

pod_node_has_label() {
  local pod="$1" namespace="$2" label="$3" value="$4"
  local node
  node=$(kubectl get pod "$pod" -n "$namespace" --context "$CTX" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  # jsonpath with ['a.b/c'] returns an empty string for label keys containing dots, so use jq.
  [[ -n "$node" ]] && [[ "$(kubectl get node "$node" --context "$CTX" -o json 2>/dev/null | jq -r --arg l "$label" '.metadata.labels[$l] // empty')" == "$value" ]]
}

wireguard_peers_on_all_nodes() {
  local nodes agents daemon ds_uid n agent info status node_ip remote_ip peer_key
  local -a names=() ips=() keys=() wg_interfaces=()
  nodes=$(kubectl get nodes --context "$CTX" -o json) || return 1
  jq -e '(.items | length) == 2 and
    ([.items[].metadata.labels["lab.cks.io/role"]] | sort) == ["control-plane","gvisor"]' \
    <<<"$nodes" >/dev/null || return 1
  daemon=$(kubectl -n kube-system get daemonset cilium --context "$CTX" -o json) || return 1
  ds_uid=$(jq -er '.metadata.uid | select(type == "string" and length > 0)' <<<"$daemon") || return 1
  agents=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o json) || return 1

  while IFS= read -r n; do
    [[ -n "$n" ]] || return 1
    agent=$(jq -er --arg node "$n" --arg owner "$ds_uid" '
      [.items[] | select(
        .spec.nodeName == $node and .status.phase == "Running" and
        .metadata.deletionTimestamp == null and
        any(.status.conditions[]?; .type == "Ready" and .status == "True") and
        any(.metadata.ownerReferences[]?;
          .kind == "DaemonSet" and .controller == true and .uid == $owner)
      )] | if length == 1 then .[0].metadata.name else empty end
    ' <<<"$agents") || return 1
    [[ -n "$agent" ]] || return 1
    info=$(kubectl -n kube-system exec "$agent" -c cilium-agent --context "$CTX" -- cilium-dbg debuginfo --output json) || return 1
    status=$(kubectl -n kube-system exec "$agent" -c cilium-agent --context "$CTX" -- cilium-dbg status) || return 1
    peer_key=$(jq -er '
      [.encryption.wireguard.interfaces[]? | select(
        .name == "cilium_wg0" and .["listen-port"] == 51871 and
        (.["peer-count"] // 0) >= 1 and
        (.["public-key"] | type == "string" and length > 0)
      )] | if length == 1 then .[0]["public-key"] else empty end
    ' <<<"$info") || return 1
    grep -Eq 'Encryption:[[:space:]]*Wireguard.*Peers:[[:space:]]*[1-9]' <<<"$status" || return 1
    ! grep -Eqi 'Encryption:.*IPsec' <<<"$status" || return 1
    node_ip=$(jq -er --arg node "$n" '
      [.items[] | select(.metadata.name == $node) |
        .status.addresses[]? | select(.type == "InternalIP") | .address] |
      if length == 1 then .[0] else empty end
    ' <<<"$nodes") || return 1
    names+=("$n")
    ips+=("$node_ip")
    keys+=("$peer_key")
    wg_interfaces+=("$info")
  done < <(jq -r '.items[].metadata.name' <<<"$nodes")
  [[ ${#names[@]} -eq 2 && "${keys[0]}" != "${keys[1]}" ]] || return 1

  # In a two-node cluster every peer must be the actual OTHER node, not an
  # unrelated/stale peer entry. Compare the remote endpoint and public key
  # against the other genuine Cilium agent's live interface.
  for i in 0 1; do
    local other=$((1-i))
    jq -e --arg ip "${ips[$other]}" --arg key "${keys[$other]}" '
      [.encryption.wireguard.interfaces[]? | select(.name == "cilium_wg0") |
       .peers[]? | select(.["public-key"] == $key and
        .endpoint == ($ip + ":51871") and
        ((.["allowed-ips"] // []) | length > 0))] | length >= 1
    ' <<<"${wg_interfaces[$i]}" >/dev/null || return 1
  done
}

@test "0 Init" {
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
  : > /var/work/tests/result/requests
}

@test "1. RuntimeClass gvisor uses an active, exactly configured containerd runsc handler" {
  local rc handler selector toml_ok
  rc=$(kubectl get runtimeclass gvisor --context "$CTX" -o json 2>/dev/null || true)
  handler=$(jq -r '.handler // empty' <<<"$rc" 2>/dev/null || true)
  selector=$(jq -r '.scheduling.nodeSelector["sandbox.runtime/gvisor"] // empty' <<<"$rc" 2>/dev/null || true)
  toml_ok=$(ssh -o BatchMode=yes -o ConnectTimeout=8 k8s110_node_gvisor 'sudo systemctl is-active --quiet containerd && sudo python3 - <<"PY"
import re
from pathlib import Path
text = Path("/etc/containerd/config.toml").read_text()
header = r"\[plugins\.\"io\.containerd\.grpc\.v1\.cri\"\.containerd\.runtimes\.runsc\]"
sections = re.findall(r"(?ms)^" + header + r"[ \t]*\n(.*?)(?=^\[|\Z)", text)
valid = len(sections) == 1 and re.search(r"(?m)^\s*runtime_type\s*=\s*\"io\.containerd\.runsc\.v1\"\s*$", sections[0]) is not None
print("ok" if valid else "invalid")
PY' 2>/dev/null || true)
  if [[ "$handler" == runsc && "$selector" == true && "$toml_ok" == ok ]] \
    && grep -Fqx 'RuntimeClass gvisor: handler runsc' "$ARTIFACTS/1/runsc-runtime.txt"; then
    record_result 0
  else
    echo "HINT: require exactly one runsc containerd section with the exact runtime_type, active daemon, RuntimeClass handler and scheduler selector; handler=$handler selector=$selector toml=$toml_ok"
    record_result 1
  fi
}

@test "2. gVisor Pod uses runsc, has no API token and is selected by the live Service" {
  local pod svc slices phase release dmesg_output pod_ok svc_ok
  pod=$(kubectl -n "$SANDBOX_NS" get pod gvisor-sandbox --context "$CTX" -o json 2>/dev/null || true)
  svc=$(kubectl -n "$SANDBOX_NS" get service gvisor-echo --context "$CTX" -o json 2>/dev/null || true)
  slices=$(kubectl -n "$SANDBOX_NS" get endpointslices --context "$CTX" -l kubernetes.io/service-name=gvisor-echo -o json 2>/dev/null || true)
  phase=$(jq -r '.status.phase // empty' <<<"$pod" 2>/dev/null || true)
  pod_ok=$(jq -r '
    .spec.runtimeClassName == "gvisor" and
    .spec.automountServiceAccountToken == false and
    (.spec.containers | length == 1) and
    (.spec.containers[0].name == "app") and
    (.spec.containers[0].image == "busybox:1.36") and
    ([.spec.volumes[]? | select(((.projected.sources // []) | any(.serviceAccountToken != null)) or (.secret.secretName != null))] | length == 0)
  ' <<<"$pod" 2>/dev/null || true)
  svc_ok=$(jq -r --arg ip "$(jq -r '.status.podIP // empty' <<<"$pod" 2>/dev/null)" '
    .kind == "Service" and
    .spec.selector == {"app":"gvisor-echo"} and
    ([.spec.ports[]? | select(.port == 8080 and (.targetPort == 8080 or .targetPort == "http"))] | length == 1)
  ' <<<"$svc" 2>/dev/null || true)
  local endpoint_ok
  endpoint_ok=$(jq -r --arg ip "$(jq -r '.status.podIP // empty' <<<"$pod" 2>/dev/null)" '
    [.items[]?.endpoints[]? | select(.conditions.ready == true) | .addresses[]? | select(. == $ip)] | length > 0
  ' <<<"$slices" 2>/dev/null || true)
  release=$(kubectl -n "$SANDBOX_NS" exec gvisor-sandbox --context "$CTX" -c app -- uname -r 2>/dev/null || true)
  dmesg_output=$(kubectl -n "$SANDBOX_NS" exec gvisor-sandbox --context "$CTX" -c app -- dmesg 2>/dev/null || true)
  if [[ "$phase" == "Running" && "$pod_ok" == "true" && "$svc_ok" == "true" && "$endpoint_ok" == "true" && -n "$release" ]] \
    && pod_node_has_label gvisor-sandbox "$SANDBOX_NS" sandbox.runtime/gvisor true \
    && [[ "$dmesg_output" == *"Starting gVisor"* ]] \
    && grep -Fqx "gvisor uname -r: $release" "$ARTIFACTS/2/gvisor-kernel.txt" \
    && grep -Fq "Starting gVisor" "$ARTIFACTS/2/gvisor-kernel.txt"; then
    record_result 0
  else
    echo "HINT: require the exact running busybox:1.36 app under gvisor, no mounted token, ready gvisor-echo EndpointSlice, and live kernel evidence; phase=$phase pod=$pod_ok service=$svc_ok endpoint=$endpoint_ok"
    record_result 1
  fi
}

@test "3. Baseline Pod runs default runc on the control-plane with the prescribed image" {
  local pod phase ok gvisor_release runc_release
  pod=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o json 2>/dev/null || true)
  phase=$(jq -r '.status.phase // empty' <<<"$pod" 2>/dev/null || true)
  ok=$(jq -r '
    ((.spec.runtimeClassName == null) or .spec.runtimeClassName == "") and
    .spec.automountServiceAccountToken == false and
    .spec.nodeSelector["lab.cks.io/role"] == "control-plane" and
    (.spec.containers | length == 1) and
    (.spec.containers[0].name == "app") and
    (.spec.containers[0].image == "busybox:1.36") and
    ([.spec.volumes[]? | select(((.projected.sources // []) | any(.serviceAccountToken != null)) or (.secret.secretName != null))] | length == 0)
  ' <<<"$pod" 2>/dev/null || true)
  gvisor_release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox -c app --context "$CTX" -- uname -r 2>/dev/null || true)
  runc_release=$(kubectl exec -n "$SANDBOX_NS" runc-baseline -c app --context "$CTX" -- uname -r 2>/dev/null || true)
  if [[ "$phase" == "Running" && "$ok" == "true" && -n "$gvisor_release" && -n "$runc_release" && "$gvisor_release" != "$runc_release" ]] \
    && pod_node_has_label runc-baseline "$SANDBOX_NS" lab.cks.io/role control-plane \
    && grep -Fqx "gvisor uname -r: $gvisor_release" "$ARTIFACTS/3/runtime-comparison.txt" \
    && grep -Fqx "runc uname -r: $runc_release" "$ARTIFACTS/3/runtime-comparison.txt"; then
    record_result 0
  else
    echo "HINT: require exact runc-baseline app/image/selector/no-token, Running on control-plane, and distinct live kernels; pod_ok=$ok phase=$phase"
    record_result 1
  fi
}

@test "4. Cilium encryption is live on both nodes and survives agent recreation" {
  local versions ds_json ds_image ds_ready ds_desired config_version cli_version agents nodes n pod info status valid
  versions="$ARTIFACTS/4/tool-versions.txt"
  ds_json=$(kubectl -n kube-system get ds cilium --context "$CTX" -o json 2>/dev/null || true)
  ds_image=$(jq -r '.spec.template.spec.containers[]? | select(.name=="cilium-agent") | .image' <<<"$ds_json" 2>/dev/null)
  ds_ready=$(jq -r '.status.numberReady // 0' <<<"$ds_json" 2>/dev/null)
  ds_desired=$(jq -r '.status.desiredNumberScheduled // 0' <<<"$ds_json" 2>/dev/null)
  config_version=$(kubectl -n kube-system get cm cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || true)
  cli_version=$(cilium version --client 2>&1 || true)
  agents=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o json 2>/dev/null || true)
  nodes=$(kubectl get nodes --context "$CTX" -l 'lab.cks.io/role' -o json 2>/dev/null || true)
  valid=1
  [[ "$config_version" == "true" && "$ds_ready" == "$ds_desired" && "$ds_desired" -ge 2 && -n "$ds_image" ]] || valid=0
  [[ "$cli_version" == *0.19.7* ]] || valid=0
  grep -Eq '^Kubernetes=v?1[.]36' "$versions" 2>/dev/null || valid=0
  grep -Fqx "Cilium agent=$ds_image" "$versions" 2>/dev/null || valid=0
  grep -Eq '^Cilium CLI=v?0[.]19[.]7$' "$versions" 2>/dev/null || valid=0
  grep -Fq 'cilium-dbg encrypt status' "$ARTIFACTS/4/cilium-encrypt-status.txt" 2>/dev/null || valid=0
  grep -Fq 'cilium-dbg debuginfo --output json' "$ARTIFACTS/4/cilium-encrypt-status.txt" 2>/dev/null || valid=0
  # Independently enumerate ALL real nodes, checking the expected two role labels and
  # a live WireGuard peer on each. Removing a node label must never skip a node.
  wireguard_peers_on_all_nodes || valid=0
  # Restart a *known* agent and wait for its exact UID to change before inspecting its replacement.
  pod=$(jq -r '.items[]? | select(.status.phase=="Running") | .metadata.name' <<<"$agents" 2>/dev/null | head -n1)
  n=$(jq -r --arg p "$pod" '.items[]? | select(.metadata.name == $p) | .spec.nodeName' <<<"$agents" 2>/dev/null)
  if [[ "$valid" -eq 1 && -n "$pod" && -n "$n" ]]; then
    kubectl -n kube-system delete pod "$pod" --context "$CTX" --wait=true --timeout=90s >/dev/null 2>&1 || valid=0
    kubectl -n kube-system rollout status ds/cilium --context "$CTX" --timeout=180s >/dev/null 2>&1 || valid=0
    agents=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o json 2>/dev/null || true)
    pod=$(jq -r --arg node "$n" --arg old "$pod" '.items[]? | select(.spec.nodeName==$node and .metadata.name!=$old and .status.phase=="Running") | .metadata.name' <<<"$agents" 2>/dev/null | head -n1)
    [[ -n "$pod" ]] || valid=0
    if [[ -n "$pod" ]]; then
      # After the recreated agent is Running, revalidate BOTH physical nodes,
      # including actual allowed-IP peers (not just the restarted agent's peer-count).
      wireguard_peers_on_all_nodes || valid=0
    fi
  fi
  if [[ "$valid" -eq 1 ]]; then
    record_result 0
  else
    echo "HINT: both Cilium agents must report live WireGuard peers and allowed IPs, versions must match, and recreated agent must retain peers"
    record_result 1
  fi
}

@test "5. The same cross-node flow is plaintext with WireGuard disabled and encrypted after restoration" {
  local gvisor_node remote_ip remote_iface baseline_capture post_capture before_response after_response
  local baseline_rc post_rc baseline_ok=0 post_ok=0 restore_ok=1 wg_mutated=0 current
  gvisor_node=$(kubectl -n "$SANDBOX_NS" get pod gvisor-sandbox --context "$CTX" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
  remote_ip=$(kubectl get node "$gvisor_node" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  remote_iface=$(ssh -o BatchMode=yes -o ConnectTimeout=8 k8s110_controlPlane_1 "ip route get '$remote_ip'" 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
  if [[ ! "$remote_ip" =~ ^[0-9.]+$ || ! "$remote_iface" =~ ^[a-zA-Z0-9_.:-]+$ || "$remote_iface" =~ ^(any|cilium|lxc|veth) ]]; then
    echo 'HINT: exact physical egress interface and remote node IPv4 are required; never use tcpdump -i any or a pre-filtered UDP-only capture'
    record_result 1
    return
  fi
  current=$(kubectl -n kube-system get cm cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || true)
  if [[ "$current" != true ]]; then
    echo "HINT: begin with WireGuard enabled, got '${current:-unreadable}'; refusing to disable networking"
    record_result 1
    return
  fi
  # JSON Patch test/replace prevents clobbering an unrelated concurrent configuration change.
  wg_transition() {
    local from="$1" to="$2" payload
    printf -v payload '[{"op":"test","path":"/data/enable-wireguard","value":"%s"},{"op":"replace","path":"/data/enable-wireguard","value":"%s"}]' "$from" "$to"
    kubectl -n kube-system patch cm cilium-config --context "$CTX" --type=json -p "$payload" --request-timeout=12s >/dev/null 2>&1
  }
  wg_rollout() {
    kubectl -n kube-system rollout restart ds/cilium --context "$CTX" --request-timeout=12s >/dev/null 2>&1 &&
    kubectl -n kube-system rollout status ds/cilium --context "$CTX" --timeout=180s >/dev/null 2>&1
  }
  wg_restore() {
    local attempt seen
    [[ "$wg_mutated" -eq 1 ]] || return 0
    trap '' INT TERM
    for attempt in $(seq 1 15); do
      seen=$(kubectl -n kube-system get cm cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' --request-timeout=12s 2>/dev/null) || { sleep 2; continue; }
      if [[ "$seen" == false ]]; then
        wg_transition false true || { sleep 2; continue; }
      elif [[ "$seen" != true ]]; then
        echo "FATAL: cilium-config concurrently changed to '$seen'; manual reconciliation required" >&2
        return 1
      fi
      if wg_rollout && [[ "$(kubectl -n kube-system get cm cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' --request-timeout=12s 2>/dev/null)" == true ]]; then
        wg_mutated=0
        return 0
      fi
      sleep 2
    done
    echo 'FATAL: WireGuard restoration unverified after 15 retries; examine cilium-config and DaemonSet immediately' >&2
    return 1
  }
  trap 'wg_restore || true' EXIT
  trap 'wg_restore || true; exit 130' INT
  trap 'wg_restore || true; exit 143' TERM
  baseline_capture=$(mktemp); post_capture=$(mktemp)
  wg_mutated=1
  if wg_transition true false; then
    if wg_rollout; then
      ssh -o BatchMode=yes -o ConnectTimeout=8 k8s110_controlPlane_1 "sudo timeout 18 tcpdump -s 0 -nnAi '$remote_iface' 'host $remote_ip'" >"$baseline_capture" 2>&1 &
      local pid=$!
      sleep 3
      set +e
      before_response=$(kubectl -n "$SANDBOX_NS" exec runc-baseline -c app --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 2>&1)
      baseline_rc=$?
      set -e
      wait "$pid" 2>/dev/null || true
      [[ "$baseline_rc" -eq 0 && "$before_response" == *CKS110-WIREGUARD-MARKER* ]] && grep -Fq 'CKS110-WIREGUARD-MARKER' "$baseline_capture" && baseline_ok=1
    fi
  fi
  if ! wg_restore; then
    restore_ok=0
  fi
  trap 'wg_restore || true; exit 130' INT
  trap 'wg_restore || true; exit 143' TERM
  # Fail closed until every Cilium agent has a live WireGuard peer: a first-Pod
  # check can pass while the other node still sends unencrypted traffic.
  local peer_ok=0
  for _ in $(seq 1 30); do
    if wireguard_peers_on_all_nodes; then peer_ok=1; break; fi
    sleep 2
  done
  if [[ "$restore_ok" -eq 1 && "$peer_ok" -eq 1 && "$baseline_ok" -eq 1 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=8 k8s110_controlPlane_1 "sudo timeout 18 tcpdump -s 0 -nnAi '$remote_iface' 'host $remote_ip'" >"$post_capture" 2>&1 &
    local pid=$!
    sleep 3
    set +e
    after_response=$(kubectl -n "$SANDBOX_NS" exec runc-baseline -c app --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 2>&1)
    post_rc=$?
    set -e
    wait "$pid" 2>/dev/null || true
    # Require actual 51871 -> 51871 traffic; a generic UDP packet is NOT WireGuard evidence.
    if [[ "$post_rc" -eq 0 && "$after_response" == *CKS110-WIREGUARD-MARKER* ]] \
      && grep -Eqi 'IP .*\.51871 > .*\.51871: UDP' "$post_capture" \
      && ! grep -Fq 'CKS110-WIREGUARD-MARKER' "$post_capture"; then post_ok=1; fi
  fi
  local student_capture="$ARTIFACTS/5/wireguard-tcpdump.txt"
  if [[ "$baseline_ok" -eq 1 && "$post_ok" -eq 1 && "$restore_ok" -eq 1 && "$wg_mutated" -eq 0 ]] \
    && grep -Eqi 'IP .*\.51871 > .*\.51871: UDP' "$student_capture" \
    && ! grep -Fq 'CKS110-WIREGUARD-MARKER' "$student_capture"; then
    result=0
  else
    echo "HINT: need marker on identical plaintext capture, working same-node-pair request, actual UDP 51871 peer packets without marker, and verified WireGuard restoration; baseline=$baseline_ok post=$post_ok restore=$restore_ok"
    result=1
  fi
  rm -f "$baseline_capture" "$post_capture"
  if [[ "$wg_mutated" -eq 0 ]]; then trap - EXIT INT TERM; fi
  record_result "$result"
}

@test "6. Exact Istio STRICT policy is live, mesh uses sidecars, and plaintext is denied only by mTLS" {
  local policy ns istiod_image ap cp op svc pods endpoint_ok workload_ok outside_ok=0 inside_ok=0 baseline_ok=0 restored_ok=0
  local baseline_code outside_code inside_code outside_rc initial_mode selected_policy
  policy=$(kubectl -n market get peerauthentication market-strict --context "$CTX" -o json 2>/dev/null || true)
  initial_mode=$(jq -r '.spec.mtls.mode // empty' <<<"$policy" 2>/dev/null || true)
  selected_policy=$(jq -r '(.spec.selector == null) and (.spec.portLevelMtls == null)' <<<"$policy" 2>/dev/null || true)
  ns=$(kubectl get namespace market --context "$CTX" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || true)
  istiod_image=$(kubectl -n istio-system get deploy istiod --context "$CTX" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
  ap=$(kubectl -n market get pods -l app=market-api --context "$CTX" -o json 2>/dev/null || true)
  cp=$(kubectl -n market get pods -l app=market-client --context "$CTX" -o json 2>/dev/null || true)
  op=$(kubectl -n default get pod mesh-outside --context "$CTX" -o json 2>/dev/null || true)
  svc=$(kubectl -n market get svc market-api --context "$CTX" -o json 2>/dev/null || true)
  endpoint_ok=$(jq -r '.spec.selector == {"app":"market-api"} and ([.spec.ports[]? | select(.name=="http" and .port==80 and (.targetPort==8080 or .targetPort=="http"))] | length == 1)' <<<"$svc" 2>/dev/null || true)
  workload_ok=$(jq -r '[.items[]? | select(.status.phase=="Running" and ([.status.containerStatuses[]? | select(.ready==true)]|length)>=2 and ([.spec.containers[]? | select(.name=="istio-proxy")]|length)==1)] | length >= 1' <<<"$ap" 2>/dev/null || true)
  [[ "$workload_ok" == true ]] && workload_ok=$(jq -r '[.items[]? | select(.status.phase=="Running" and ([.status.containerStatuses[]? | select(.ready==true)]|length)>=2 and ([.spec.containers[]? | select(.name=="istio-proxy")]|length)==1)] | length >= 1' <<<"$cp" 2>/dev/null || true)
  [[ "$workload_ok" == true ]] && workload_ok=$(jq -r '.status.phase=="Running" and ([.spec.containers[]? | select(.name=="istio-proxy")]|length)==0' <<<"$op" 2>/dev/null || true)
  # A more-specific PeerAuthentication can override the namespace-wide STRICT policy.
  local other_policies
  other_policies=$(kubectl -n market get peerauthentications --context "$CTX" -o json 2>/dev/null | jq -r '[.items[]? | select(.metadata.name != "market-strict" and .spec.selector != null)] | length' 2>/dev/null || echo 1)
  if [[ "$initial_mode" != STRICT || "$selected_policy" != true || "$ns" != enabled || "$istiod_image" != *1.30.4* || "$workload_ok" != true || "$endpoint_ok" != true || "$other_policies" != 0 ]]; then
    echo "HINT: require exact namespace-wide market-strict STRICT, two injected Ready workloads, non-injected outside Pod, correct HTTP Service and no overriding workload policy"
    record_result 1
    return
  fi
  # Obtain a live application HTTP status, keeping curl's transport exit code separate.
  inside_code=$(kubectl -n market exec deploy/market-client -c app --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' --max-time 10 http://market-api 2>/dev/null || true)
  set +e
  outside_code=$(kubectl -n default exec mesh-outside -c app --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' --max-time 10 http://market-api.market.svc.cluster.local 2>/dev/null)
  outside_rc=$?
  set -e
  [[ "$inside_code" == 200 ]] && inside_ok=1
  [[ "$outside_code" != 2?? && "$outside_code" != 3?? ]] && outside_ok=1
  [[ "$outside_rc" -ne 0 ]] || outside_ok=0
  # The mutation is guarded by an atomic JSON Patch and must be undone before scoring.
  policy_transition() {
    local from="$1" to="$2" payload
    printf -v payload '[{"op":"test","path":"/spec/mtls/mode","value":"%s"},{"op":"replace","path":"/spec/mtls/mode","value":"%s"}]' "$from" "$to"
    kubectl -n market patch peerauthentication market-strict --context "$CTX" --type=json -p "$payload" --request-timeout=12s >/dev/null 2>&1
  }
  local mutated=0
  restore_policy() {
    local attempt seen
    [[ "$mutated" -eq 1 ]] || return 0
    trap '' INT TERM
    for attempt in $(seq 1 15); do
      seen=$(kubectl -n market get peerauthentication market-strict --context "$CTX" -o jsonpath='{.spec.mtls.mode}' --request-timeout=12s 2>/dev/null) || { sleep 2; continue; }
      if [[ "$seen" == PERMISSIVE ]]; then
        policy_transition PERMISSIVE STRICT || { sleep 2; continue; }
      elif [[ "$seen" != STRICT ]]; then
        echo "FATAL: PeerAuthentication concurrently changed to '$seen'; manual reconciliation required" >&2
        return 1
      fi
      [[ "$(kubectl -n market get peerauthentication market-strict --context "$CTX" -o jsonpath='{.spec.mtls.mode}' --request-timeout=12s 2>/dev/null)" == STRICT ]] && { mutated=0; return 0; }
      sleep 2
    done
    echo 'FATAL: failed to restore market-strict STRICT after 15 retries' >&2
    return 1
  }
  trap 'restore_policy || true' EXIT
  trap 'restore_policy || true; exit 130' INT
  trap 'restore_policy || true; exit 143' TERM
  mutated=1
  if policy_transition STRICT PERMISSIVE; then
    # Wait for Envoy propagation; a fixed three-second sleep is not a reliability guarantee.
    for _ in $(seq 1 20); do
      baseline_code=$(kubectl -n default exec mesh-outside -c app --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://market-api.market.svc.cluster.local 2>/dev/null || true)
      [[ "$baseline_code" == 200 ]] && { baseline_ok=1; break; }
      sleep 2
    done
  fi
  if restore_policy; then
    restored_ok=1
  fi
  trap 'restore_policy || true; exit 130' INT
  trap 'restore_policy || true; exit 143' TERM
  # Recheck the *effective* post-rollback policy outcome (not only the YAML field).
  local again=0
  if [[ "$restored_ok" -eq 1 ]]; then
    for _ in $(seq 1 20); do
      set +e
      outside_code=$(kubectl -n default exec mesh-outside -c app --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://market-api.market.svc.cluster.local 2>/dev/null)
      outside_rc=$?
      set -e
      if [[ "$outside_rc" -ne 0 && "$outside_code" != 2?? && "$outside_code" != 3?? ]]; then again=1; break; fi
      sleep 2
    done
  fi
  if [[ "$inside_ok" -eq 1 && "$outside_ok" -eq 1 && "$baseline_ok" -eq 1 && "$restored_ok" -eq 1 && "$again" -eq 1 && "$mutated" -eq 0 ]] \
    && grep -Eq '^HTTP/1[.]1 200' "$ARTIFACTS/6/market-inside.txt" \
    && grep -Eq '^exit_code=0$' "$ARTIFACTS/6/market-inside.txt" \
    && grep -Eq '^exit_code=[1-9][0-9]*$' "$ARTIFACTS/6/market-outside.txt" \
    && ! grep -Eq 'HTTP/[0-9.]+ 2[0-9][0-9]' "$ARTIFACTS/6/market-outside.txt"; then
    result=0
  else
    echo "HINT: require real sidecars, STRICT denied, PERMISSIVE allowed, and restored STRICT denied; inside=$inside_ok outside=$outside_ok permissive=$baseline_ok restored=$restored_ok observed=$again"
    result=1
  fi
  if [[ "$mutated" -eq 0 ]]; then trap - EXIT INT TERM; fi
  record_result "$result"
}
