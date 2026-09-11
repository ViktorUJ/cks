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
  [[ -n "$node" ]] && [[ "$(kubectl get node "$node" --context "$CTX" -o jsonpath="{.metadata.labels['${label}']}" 2>/dev/null)" == "$value" ]]
}

@test "0 Init" {
  : > /var/work/tests/result/all
  : > /var/work/tests/result/ok
  : > /var/work/tests/result/requests
}

@test "1. containerd runsc runtime is repaired in config.toml and RuntimeClass gvisor selects it" {
  rc=$(kubectl get runtimeclass gvisor --context "$CTX" -o json 2>/dev/null)
  handler=$(jq -r '.handler // empty' <<<"$rc")
  node_selector=$(jq -r '.scheduling.nodeSelector["sandbox.runtime/gvisor"] // empty' <<<"$rc")
  toml_check=$(ssh k8s110_node_gvisor 'sudo systemctl is-active containerd && sudo grep -A1 "runtimes.runsc" /etc/containerd/config.toml' 2>/dev/null || true)
  if [[ "$handler" == "runsc" && "$node_selector" == "true" ]] \
    && [[ "$toml_check" == *"active"* && "$toml_check" == *'runtime_type = "io.containerd.runsc.v1"'* ]] \
    && grep -Fqx 'RuntimeClass gvisor: handler runsc' "$ARTIFACTS/1/runsc-runtime.txt"; then
    result=0
  else
    if [[ "$handler" != "runsc" ]]; then
      echo "HINT: RuntimeClass 'gvisor' must have handler: runsc exactly, matching the name registered in containerd's config.toml."
    elif [[ "$node_selector" != "true" ]]; then
      echo "HINT: RuntimeClass 'gvisor' scheduling.nodeSelector must include 'sandbox.runtime/gvisor: true' - without this, a Pod requesting this RuntimeClass could be scheduled on a node that never got runsc installed."
    elif [[ "$toml_check" != *"active"* ]]; then
      echo "HINT: containerd is not active on the gVisor node after your config.toml edit - check for a TOML syntax error."
    else
      echo "HINT: config.toml's [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runsc] section is missing or has the wrong runtime_type - it must be exactly 'io.containerd.runsc.v1'."
    fi
    echo "handler=${handler:-missing} sandbox_selector=${node_selector:-missing} toml_check=$toml_check; expected $ARTIFACTS/1/runsc-runtime.txt"
    result=1
  fi
  record_result "$result"
}

@test "2. gVisor Pod is Running on the sandbox node and exposes a distinct kernel view" {
  phase=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  runtime_class=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)
  release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- uname -r 2>/dev/null || true)
  dmesg_output=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- dmesg 2>/dev/null || true)
  if [[ "$phase" == "Running" && "$runtime_class" == "gvisor" && -n "$release" ]] \
    && pod_node_has_label gvisor-sandbox "$SANDBOX_NS" sandbox.runtime/gvisor true \
    && grep -Fq "gvisor uname -r: $release" "$ARTIFACTS/2/gvisor-kernel.txt" \
    && [[ "$dmesg_output" == *"Starting gVisor"* ]] \
    && grep -Fq "Starting gVisor" "$ARTIFACTS/2/gvisor-kernel.txt"; then
    result=0
  else
    if [[ "$runtime_class" != "gvisor" ]]; then
      echo "HINT: Pod 'gvisor-sandbox' must set spec.runtimeClassName: gvisor."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: Pod is not Running. Check the Pod was scheduled on the labelled gVisor node, and that containerd's runsc handler is actually working (see test 1)."
    elif [[ "$dmesg_output" != *"Starting gVisor"* ]]; then
      echo "HINT: dmesg inside the Pod does not show 'Starting gVisor' - this is the tell-tale sign the Pod is really running under the gVisor sandbox kernel, not runc. Check runtimeClassName took effect."
    else
      echo "HINT: The kernel/dmesg evidence looks correct but gvisor-kernel.txt is missing the exact expected lines - save both the uname -r output and the dmesg 'Starting gVisor' line."
    fi
    echo "phase=$phase runtimeClass=$runtime_class release=${release:-missing} dmesg=${dmesg_output:0:80}; gVisor artifact or placement is invalid"
    result=1
  fi
  record_result "$result"
}

@test "3. Default-runc comparison Pod runs outside the sandbox and records the difference" {
  phase=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  runtime_class=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)
  gvisor_release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- uname -r 2>/dev/null || true)
  runc_release=$(kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- uname -r 2>/dev/null || true)
  if [[ "$phase" == "Running" && -z "$runtime_class" && -n "$gvisor_release" && -n "$runc_release" && "$gvisor_release" != "$runc_release" ]] \
    && pod_node_has_label runc-baseline "$SANDBOX_NS" lab.cks.io/role control-plane \
    && grep -Fq "gvisor uname -r: $gvisor_release" "$ARTIFACTS/3/runtime-comparison.txt" \
    && grep -Fq "runc uname -r: $runc_release" "$ARTIFACTS/3/runtime-comparison.txt"; then
    result=0
  else
    if [[ -n "$runtime_class" ]]; then
      echo "HINT: Pod 'runc-baseline' must NOT set runtimeClassName at all - it should use the cluster's default runc runtime for comparison."
    elif [[ "$gvisor_release" == "$runc_release" ]]; then
      echo "HINT: uname -r reports the SAME kernel release for both Pods - gVisor's runsc should expose a distinct kernel version string from the host's real kernel. Check gvisor-sandbox is really using runtimeClassName: gvisor."
    else
      echo "HINT: Runtime placement or the release comparison looks correct, but runtime-comparison.txt is missing one of the two required 'uname -r' lines with the exact prefix 'gvisor uname -r:' / 'runc uname -r:'."
    fi
    echo "phase=$phase runtimeClass=${runtime_class:-default-runc} gvisor=$gvisor_release runc=$runc_release"
    result=1
  fi
  record_result "$result"
}

@test "4. Cilium WireGuard transparent encryption is enabled and status is saved" {
  agent=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  encrypt_status=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium-dbg encrypt status 2>&1 || true)
  agent_status=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium-dbg status --all-encryption 2>&1 || true)
  status="$encrypt_status"$'\n'"$agent_status"
  client_version=$(cilium version --client 2>&1 || true)
  versions="$ARTIFACTS/4/tool-versions.txt"
  if [[ -n "$agent" && "$status" =~ [Ww]ire[Gg]uard ]] \
    && ! grep -Eqi 'IPsec.*enabled|Encryption:.*IPsec' <<<"$status" \
    && [[ "$client_version" == *0.19.7* ]] \
    && grep -Eq 'Kubernetes[=: ]+v?1[.]36' "$versions" \
    && grep -Eqi 'Cilium agent=.*cilium' "$versions" \
    && grep -Eq 'Cilium CLI[=: ]+v?0[.]19[.]7' "$versions" \
    && grep -Fq 'cilium-dbg encrypt status' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Fq 'cilium-dbg status --all-encryption' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Eqi 'WireGuard|Encryption:.*Wireguard' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Eqi 'peer|allowed[ -]?ip|remote node' "$ARTIFACTS/4/cilium-encrypt-status.txt"; then
    result=0
  else
    if [[ -z "$agent" ]]; then
      echo "HINT: No cilium-agent Pod found in kube-system - check Cilium is actually installed and running."
    elif ! [[ "$status" =~ [Ww]ire[Gg]uard ]]; then
      echo "HINT: 'cilium-dbg encrypt status' does not mention WireGuard - enable transparent encryption in the Cilium Helm values (encryption.enabled=true, encryption.type=wireguard) and restart the agents."
    elif grep -Eqi 'IPsec.*enabled|Encryption:.*IPsec' <<<"$status"; then
      echo "HINT: IPsec appears enabled instead of/alongside WireGuard - this task specifically requires WireGuard mode."
    else
      echo "HINT: Runtime status looks correct, but one of the evidence files (tool-versions.txt / cilium-encrypt-status.txt) is missing a required exact line - check Kubernetes/Cilium/CLI version strings and the WireGuard peer/allowed-ip details are all saved."
    fi
    echo "cilium_agent=${agent:-missing}; status=$status"
    result=1
  fi
  record_result "$result"
}

@test "5. Cross-node traffic reaches gVisor service while captured WireGuard traffic hides the marker" {
  set +e
  response=$(kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 2>&1)
  request_status=$?
  set -e
  capture="$ARTIFACTS/5/wireguard-tcpdump.txt"
  if [[ "$request_status" -eq 0 && "$response" == *"CKS110-WIREGUARD-MARKER"* ]] \
    && grep -Eq 'UDP|51871' "$capture" && ! grep -Fq 'CKS110-WIREGUARD-MARKER' "$capture"; then
    result=0
  else
    if [[ "$request_status" -ne 0 || "$response" != *"CKS110-WIREGUARD-MARKER"* ]]; then
      echo "HINT: The cross-node request from runc-baseline to the gVisor service did not succeed or did not return the expected marker - check Service DNS resolves and encryption is not breaking normal connectivity."
    elif ! grep -Eq 'UDP|51871' "$capture"; then
      echo "HINT: wireguard-tcpdump.txt does not show UDP/51871 traffic - capture packets WHILE making the cross-node request, on the interface actually carrying node-to-node traffic (not loopback)."
    else
      echo "HINT: The tcpdump capture contains the plaintext marker text 'CKS110-WIREGUARD-MARKER' - this proves traffic was NOT actually encrypted at the point you captured it. Capture on the physical NIC, not inside the Pod's veth, to see the true on-wire state."
    fi
    echo "request_status=$request_status response=$response; capture must show WireGuard UDP and no plaintext marker"
    result=1
  fi
  record_result "$result"
}

@test "6. market PeerAuthentication STRICT allows mesh client and denies plaintext client" {
  mode=$(kubectl get peerauthentication market-strict -n market --context "$CTX" -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
  injection=$(kubectl get namespace market --context "$CTX" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
  istiod_image=$(kubectl get deployment istiod -n istio-system --context "$CTX" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  outside_sidecar=$(kubectl get pod mesh-outside -n default --context "$CTX" -o json | jq -r '[.spec.containers[]? | select(.name == "istio-proxy")] | length' 2>/dev/null)
  inside=$(kubectl exec -n market deploy/market-client --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' http://market-api 2>&1 || true)
  set +e
  outside=$(kubectl exec -n default mesh-outside --context "$CTX" -- curl -sS --max-time 10 http://market-api.market.svc.cluster.local 2>&1)
  outside_status=$?
  set -e
  # Outcome-based check, not a literal socket-error string (wording is implementation- and
  # version-dependent). STRICT mTLS is proven by: policy is STRICT, in-mesh client gets 200,
  # and the plaintext outside client does NOT get a successful HTTP response (curl fails and
  # no 2xx status is returned).
  outside_ok=1
  if [[ "$outside_status" -ne 0 ]] && ! grep -Eq 'HTTP/[0-9.]+ 2[0-9][0-9]' "$ARTIFACTS/6/market-outside.txt"; then
    outside_ok=0
  fi
  if [[ "$mode" == "STRICT" && "$injection" == "enabled" && "$istiod_image" == *1.30.4* && "$outside_sidecar" == "0" && "$inside" == "200" && "$outside_ok" -eq 0 ]] \
    && grep -Fq 'HTTP/1.1 200 OK' "$ARTIFACTS/6/market-inside.txt"; then
    result=0
  else
    if [[ "$mode" != "STRICT" ]]; then
      echo "HINT: PeerAuthentication 'market-strict' spec.mtls.mode must be 'STRICT' exactly - PERMISSIVE would accept both mTLS and plaintext, defeating this task's goal."
    elif [[ "$injection" != "enabled" ]]; then
      echo "HINT: Namespace 'market' must have label istio-injection: enabled so the sidecar is actually injected into workloads there."
    elif [[ "$outside_sidecar" != "0" ]]; then
      echo "HINT: Pod 'mesh-outside' in namespace 'default' must NOT have an istio-proxy sidecar - it represents a client outside the mesh, on purpose."
    elif [[ "$inside" != "200" ]]; then
      echo "HINT: The in-mesh client (market-client, with sidecar) did not get HTTP 200 from market-api - check both Pods are actually injected and mTLS is negotiating correctly."
    elif [[ "$outside_ok" -ne 0 ]]; then
      echo "HINT: The plaintext client OUTSIDE the mesh got a successful 2xx response from market-api - STRICT mTLS should reject a client without an Istio sidecar. Check the PeerAuthentication actually applies to this namespace/workload."
    fi
    echo "mode=$mode injection=$injection istiod_image=$istiod_image outside_sidecar=$outside_sidecar inside=$inside outside_status=$outside_status outside=$outside"
    result=1
  fi
  record_result "$result"
}
