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
  automount=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
  no_token_volume=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o json | jq -r '[.spec.volumes[]? | .projected.sources[]? | select(.serviceAccountToken != null)] | length == 0' 2>/dev/null)
  release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- uname -r 2>/dev/null || true)
  dmesg_output=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- dmesg 2>/dev/null || true)
  if [[ "$phase" == "Running" && "$runtime_class" == "gvisor" && -n "$release" && "$automount" == "false" && "$no_token_volume" == "true" ]] \
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
    elif [[ "$automount" != "false" || "$no_token_volume" != "true" ]]; then
      echo "HINT: Pod 'gvisor-sandbox' must set automountServiceAccountToken: false with no kube-api-access token volume - this Pod does not need a ServiceAccount token."
    elif [[ "$dmesg_output" != *"Starting gVisor"* ]]; then
      echo "HINT: dmesg inside the Pod does not show 'Starting gVisor' - this is the tell-tale sign the Pod is really running under the gVisor sandbox kernel, not runc. Check runtimeClassName took effect."
    else
      echo "HINT: The kernel/dmesg evidence looks correct but gvisor-kernel.txt is missing the exact expected lines - save both the uname -r output and the dmesg 'Starting gVisor' line."
    fi
    echo "phase=$phase runtimeClass=$runtime_class release=${release:-missing} automount=${automount:-missing} dmesg=${dmesg_output:0:80}; gVisor artifact or placement is invalid"
    result=1
  fi
  record_result "$result"
}

@test "3. Default-runc comparison Pod runs outside the sandbox and records the difference" {
  phase=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  runtime_class=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)
  automount=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
  no_token_volume=$(kubectl get pod runc-baseline -n "$SANDBOX_NS" --context "$CTX" -o json | jq -r '[.spec.volumes[]? | .projected.sources[]? | select(.serviceAccountToken != null)] | length == 0' 2>/dev/null)
  gvisor_release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- uname -r 2>/dev/null || true)
  runc_release=$(kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- uname -r 2>/dev/null || true)
  if [[ "$phase" == "Running" && -z "$runtime_class" && -n "$gvisor_release" && -n "$runc_release" && "$gvisor_release" != "$runc_release" && "$automount" == "false" && "$no_token_volume" == "true" ]] \
    && pod_node_has_label runc-baseline "$SANDBOX_NS" lab.cks.io/role control-plane \
    && grep -Fq "gvisor uname -r: $gvisor_release" "$ARTIFACTS/3/runtime-comparison.txt" \
    && grep -Fq "runc uname -r: $runc_release" "$ARTIFACTS/3/runtime-comparison.txt"; then
    result=0
  else
    if [[ -n "$runtime_class" ]]; then
      echo "HINT: Pod 'runc-baseline' must NOT set runtimeClassName at all - it should use the cluster's default runc runtime for comparison."
    elif [[ "$automount" != "false" || "$no_token_volume" != "true" ]]; then
      echo "HINT: Pod 'runc-baseline' must set automountServiceAccountToken: false with no kube-api-access token volume - this Pod does not need a ServiceAccount token."
    elif [[ "$gvisor_release" == "$runc_release" ]]; then
      echo "HINT: uname -r reports the SAME kernel release for both Pods - gVisor's runsc should expose a distinct kernel version string from the host's real kernel. Check gvisor-sandbox is really using runtimeClassName: gvisor."
    else
      echo "HINT: Runtime placement or the release comparison looks correct, but runtime-comparison.txt is missing one of the two required 'uname -r' lines with the exact prefix 'gvisor uname -r:' / 'runc uname -r:'."
    fi
    echo "phase=$phase runtimeClass=${runtime_class:-default-runc} automount=${automount:-missing} gvisor=$gvisor_release runc=$runc_release"
    result=1
  fi
  record_result "$result"
}

@test "4. Cilium WireGuard transparent encryption is enabled and status is saved" {
  agent=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  encrypt_status=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium-dbg encrypt status 2>&1 || true)
  debuginfo_json=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium-dbg debuginfo --output json 2>&1 || true)
  wireguard_section=$(jq -r '.encryption.wireguard // .Encryption.Wireguard // empty' <<<"$debuginfo_json" 2>/dev/null || true)
  status="$encrypt_status"$'\n'"$debuginfo_json"
  client_version=$(cilium version --client 2>&1 || true)
  versions="$ARTIFACTS/4/tool-versions.txt"
  # Structural source-of-truth check: this lab installation is not a Helm release, so the
  # declared config must live in the cilium-config ConfigMap (enable-wireguard: "true"),
  # not just be a transient runtime state that a restart could silently lose.
  config_wireguard=$(kubectl -n kube-system get configmap cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || true)
  # Cross-check the version artifact against the ACTUAL running DaemonSet image, rather
  # than accepting any string that merely contains "cilium".
  ds_image=$(kubectl -n kube-system get daemonset cilium --context "$CTX" -o jsonpath='{.spec.template.spec.containers[?(@.name=="cilium-agent")].image}' 2>/dev/null || true)
  version_artifact_image_line=$(grep -E '^Cilium agent=' "$versions" 2>/dev/null || true)
  image_matches_artifact=0
  if [[ -n "$ds_image" && "$version_artifact_image_line" == *"$ds_image"* ]]; then
    image_matches_artifact=1
  fi
  ds_ready=$(kubectl -n kube-system get daemonset cilium --context "$CTX" -o jsonpath='{.status.numberReady}' 2>/dev/null || true)
  ds_desired=$(kubectl -n kube-system get daemonset cilium --context "$CTX" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || true)
  daemonset_ready=0
  if [[ -n "$ds_ready" && -n "$ds_desired" && "$ds_ready" == "$ds_desired" && "$ds_ready" -ge 1 ]]; then
    daemonset_ready=1
  fi
  # Persistence-through-restart: delete the probed agent Pod and confirm the replacement
  # comes back Ready with WireGuard still active from the declared ConfigMap source of
  # truth, not from an ephemeral runtime-only toggle that a restart would lose.
  persists_after_restart=0
  if [[ "$config_wireguard" == "true" && "$daemonset_ready" -eq 1 ]]; then
    kubectl -n kube-system delete pod "$agent" --context "$CTX" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status daemonset/cilium --context "$CTX" --timeout=120s >/dev/null 2>&1 || true
    new_agent=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "$new_agent" ]]; then
      post_restart_status=$(kubectl -n kube-system exec "$new_agent" --context "$CTX" -- cilium-dbg encrypt status 2>&1 || true)
      [[ "$post_restart_status" =~ [Ww]ire[Gg]uard ]] && persists_after_restart=1
    fi
  fi
  if [[ -n "$agent" && "$status" =~ [Ww]ire[Gg]uard ]] \
    && ! grep -Eqi 'IPsec.*enabled|Encryption:.*IPsec' <<<"$status" \
    && [[ "$client_version" == *0.19.7* ]] \
    && grep -Eq 'Kubernetes[=: ]+v?1[.]36' "$versions" \
    && grep -Eqi 'Cilium agent=.*cilium' "$versions" \
    && grep -Eq 'Cilium CLI[=: ]+v?0[.]19[.]7' "$versions" \
    && grep -Fq 'cilium-dbg encrypt status' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Fq 'cilium-dbg debuginfo --output json' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Eqi 'WireGuard|Encryption:.*Wireguard' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && grep -Eqi 'peer|allowed[ -]?ip|remote node' "$ARTIFACTS/4/cilium-encrypt-status.txt" \
    && [[ "$config_wireguard" == "true" && "$image_matches_artifact" -eq 1 && "$daemonset_ready" -eq 1 && "$persists_after_restart" -eq 1 ]]; then
    result=0
  else
    if [[ -z "$agent" ]]; then
      echo "HINT: No cilium-agent Pod found in kube-system - check Cilium is actually installed and running."
    elif [[ "$config_wireguard" != "true" ]]; then
      echo "HINT: ConfigMap kube-system/cilium-config does not have enable-wireguard: \"true\" - this lab installation is not a Helm release, so the declared source-of-truth is this ConfigMap key, not just current runtime state."
    elif [[ "$image_matches_artifact" -ne 1 ]]; then
      echo "HINT: tool-versions.txt's 'Cilium agent=' line does not match the actual image running in the kube-system/cilium DaemonSet - save the real image from the DaemonSet/Pod spec, not an arbitrary string containing 'cilium'."
    elif [[ "$daemonset_ready" -ne 1 ]]; then
      echo "HINT: DaemonSet kube-system/cilium is not fully Ready - check the rollout after enabling WireGuard."
    elif [[ "$persists_after_restart" -ne 1 ]]; then
      echo "HINT: After the checker restarted one Cilium agent Pod, the replacement did not come back with WireGuard active - this means WireGuard was enabled by a transient/runtime-only action rather than the declared ConfigMap source of truth, so it does not survive an agent restart."
    elif ! [[ "$status" =~ [Ww]ire[Gg]uard ]]; then
      echo "HINT: 'cilium-dbg encrypt status' does not mention WireGuard - enable transparent encryption in the Cilium Helm values (encryption.enabled=true, encryption.type=wireguard) and restart the agents."
    elif grep -Eqi 'IPsec.*enabled|Encryption:.*IPsec' <<<"$status"; then
      echo "HINT: IPsec appears enabled instead of/alongside WireGuard - this task specifically requires WireGuard mode."
    else
      echo "HINT: Runtime status looks correct, but one of the evidence files (tool-versions.txt / cilium-encrypt-status.txt) is missing a required exact line - check Kubernetes/Cilium/CLI version strings and the WireGuard peer/allowed-ip details are all saved."
    fi
    echo "cilium_agent=${agent:-missing} config_wireguard=${config_wireguard:-missing} image_matches_artifact=$image_matches_artifact daemonset_ready=$daemonset_ready persists_after_restart=$persists_after_restart; status=$status"
    result=1
  fi
  record_result "$result"
}

@test "5. Cross-node traffic reaches gVisor service while captured WireGuard traffic hides the marker" {
  # Baseline -> change -> same probe: a filter that pre-excludes everything except
  # udp port 51871 can never prove plaintext is ABSENT (it would look identical whether
  # or not WireGuard were even active). Instead the checker captures the SAME scope
  # (host <remote-node-ip>, no port filter) before and after toggling WireGuard, so the
  # disappearance of the plaintext marker is actually observed, not assumed.
  #
  # Capturing on "any" is NOT a valid on-wire observation point for WireGuard: it also
  # sees traffic on Cilium's internal cilium_wg0 tunnel interface, which by design carries
  # the DECRYPTED inner Pod-to-Pod flow (that is the whole point of a tunnel interface -
  # WireGuard hands you cleartext there). A capture on "any" would see the marker on
  # cilium_wg0 even when node-to-node encryption on the physical NIC is working correctly,
  # causing a false FAIL. We must resolve and capture on the actual physical egress
  # interface toward the remote node.
  gvisor_node=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  remote_ip=$(kubectl get node "$gvisor_node" --context "$CTX" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
  remote_iface=""
  if [[ -n "$remote_ip" ]]; then
    remote_iface=$(ssh -o BatchMode=yes k8s110_controlPlane_1 \
      "ip route get '$remote_ip' 2>/dev/null | awk '{for (i=1;i<=NF;i++) if (\$i==\"dev\") {print \$(i+1); exit}}'" 2>/dev/null || true)
  fi
  # Reject "any" and known Cilium/veth/lxc internal interfaces - only a real physical NIC
  # is a valid observation point for the on-wire encrypted state.
  if [[ -z "$remote_iface" || "$remote_iface" == "any" || "$remote_iface" =~ ^(cilium|lxc|veth) ]]; then
    remote_iface=""
  fi

  orig_wireguard=$(kubectl -n kube-system get configmap cilium-config --context "$CTX" -o jsonpath='{.data.enable-wireguard}' 2>/dev/null || true)
  restore_wireguard() {
    kubectl -n kube-system patch configmap cilium-config --context "$CTX" --type merge \
      -p "{\"data\":{\"enable-wireguard\":\"${orig_wireguard:-true}\"}}" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout restart daemonset/cilium --context "$CTX" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status daemonset/cilium --context "$CTX" --timeout=120s >/dev/null 2>&1 || true
  }
  trap restore_wireguard RETURN

  baseline_capture_ok=0
  if [[ -n "$remote_ip" && -n "$remote_iface" ]]; then
    kubectl -n kube-system patch configmap cilium-config --context "$CTX" --type merge \
      -p '{"data":{"enable-wireguard":"false"}}' >/dev/null 2>&1 || true
    kubectl -n kube-system rollout restart daemonset/cilium --context "$CTX" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status daemonset/cilium --context "$CTX" --timeout=120s >/dev/null 2>&1 || true
    baseline_capture=$(mktemp)
    ssh -o BatchMode=yes k8s110_controlPlane_1 "sudo timeout 15 tcpdump -nni '$remote_iface' 'host $remote_ip' -A" >"$baseline_capture" 2>&1 &
    baseline_pid=$!
    sleep 3
    kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 >/dev/null 2>&1 || true
    wait "$baseline_pid" 2>/dev/null || true
    grep -Fq 'CKS110-WIREGUARD-MARKER' "$baseline_capture" && baseline_capture_ok=1
    rm -f "$baseline_capture"

    kubectl -n kube-system patch configmap cilium-config --context "$CTX" --type merge \
      -p '{"data":{"enable-wireguard":"true"}}' >/dev/null 2>&1 || true
    kubectl -n kube-system rollout restart daemonset/cilium --context "$CTX" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status daemonset/cilium --context "$CTX" --timeout=120s >/dev/null 2>&1 || true
  fi

  # `rollout status` returns before the WireGuard peers are handshaken; a capture taken in that
  # window sees plaintext or no UDP/51871 at all. Wait until the agent reports a peer, then warm
  # the tunnel with one request so the timed capture below observes the steady state.
  for _ in $(seq 1 30); do
    kubectl -n kube-system exec ds/cilium -c cilium-agent --context "$CTX" -- cilium-dbg status 2>/dev/null \
      | grep -Eq 'Encryption:\s*Wireguard.*Peers: [1-9]' && break
    sleep 2
  done
  kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 >/dev/null 2>&1 || true
  sleep 3

  # The checker performs its OWN post-change capture and its OWN request rather than
  # trusting only the student-owned wireguard-tcpdump.txt artifact (which could have been
  # captured at a different time / on different traffic). Same scope as the baseline above.
  checker_capture=$(mktemp)
  if [[ -n "$remote_ip" && -n "$remote_iface" ]]; then
    ssh -o BatchMode=yes k8s110_controlPlane_1 "sudo timeout 15 tcpdump -nni '$remote_iface' 'host $remote_ip' -A" >"$checker_capture" 2>&1 &
  else
    ssh -o BatchMode=yes k8s110_controlPlane_1 "sudo timeout 15 tcpdump -nni any 'udp port 51871' -A" >"$checker_capture" 2>&1 &
  fi
  capture_pid=$!
  sleep 3
  set +e
  response=$(kubectl exec -n "$SANDBOX_NS" runc-baseline --context "$CTX" -- wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080 2>&1)
  request_status=$?
  set -e
  wait "$capture_pid" 2>/dev/null || true
  student_capture="$ARTIFACTS/5/wireguard-tcpdump.txt"
  checker_capture_ok=0
  if grep -Eq 'UDP|51871' "$checker_capture" && ! grep -Fq 'CKS110-WIREGUARD-MARKER' "$checker_capture"; then
    checker_capture_ok=1
  fi
  if [[ "$request_status" -eq 0 && "$response" == *"CKS110-WIREGUARD-MARKER"* && "$checker_capture_ok" -eq 1 && "$baseline_capture_ok" -eq 1 ]] \
    && grep -Eq 'UDP|51871' "$student_capture" && ! grep -Fq 'CKS110-WIREGUARD-MARKER' "$student_capture"; then
    result=0
  else
    if [[ "$request_status" -ne 0 || "$response" != *"CKS110-WIREGUARD-MARKER"* ]]; then
      echo "HINT: The cross-node request from runc-baseline to the gVisor service did not succeed or did not return the expected marker - check Service DNS resolves and encryption is not breaking normal connectivity."
    elif [[ "$baseline_capture_ok" -ne 1 ]]; then
      echo "HINT: The checker's own BASELINE capture (same request, same host-scoped filter, WireGuard temporarily disabled) did not show the plaintext marker - this means the baseline/post-change comparison cannot prove causality. Check node connectivity independent of WireGuard."
    elif [[ "$checker_capture_ok" -ne 1 ]]; then
      echo "HINT: The checker's own live capture (taken during THIS request) does not show WireGuard UDP/51871, or still shows the plaintext marker - this proves encryption is not actually active on the wire for this specific traffic, regardless of what your own artifact shows."
    elif ! grep -Eq 'UDP|51871' "$student_capture"; then
      echo "HINT: wireguard-tcpdump.txt does not show UDP/51871 traffic - capture packets WHILE making the cross-node request, on the interface actually carrying node-to-node traffic (not loopback)."
    else
      echo "HINT: The tcpdump capture contains the plaintext marker text 'CKS110-WIREGUARD-MARKER' - this proves traffic was NOT actually encrypted at the point you captured it. Capture on the physical NIC, not inside the Pod's veth, to see the true on-wire state."
    fi
    echo "request_status=$request_status response=$response baseline_capture_ok=$baseline_capture_ok checker_capture_ok=$checker_capture_ok remote_ip=${remote_ip:-missing} remote_iface=${remote_iface:-missing}; capture must show WireGuard UDP and no plaintext marker"
    result=1
  fi
  rm -f "$checker_capture"
  restore_wireguard
  trap - RETURN
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
  if [[ "$outside_status" -ne 0 ]] && ! grep -Eq 'HTTP/[0-9.]+ 2[0-9][0-9]' "$ARTIFACTS/6/market-outside.txt" \
    && grep -Eq '^exit_code=[1-9][0-9]*$' "$ARTIFACTS/6/market-outside.txt"; then
    outside_ok=0
  fi
  # Baseline control: temporarily flip the SAME PeerAuthentication to PERMISSIVE (with a
  # guaranteed restore via trap), repeat the identical plaintext probe, and require 200 -
  # this proves the earlier STRICT rejection was actually CAUSED by mTLS enforcement and
  # not by an unrelated DNS/network/client problem that would fail regardless of mode.
  baseline_ok=0
  restore_policy() { kubectl patch peerauthentication market-strict -n market --context "$CTX" --type merge -p '{"spec":{"mtls":{"mode":"STRICT"}}}' >/dev/null 2>&1 || true; }
  if [[ "$mode" == "STRICT" ]]; then
    trap restore_policy RETURN
    kubectl patch peerauthentication market-strict -n market --context "$CTX" \
      --type merge -p '{"spec":{"mtls":{"mode":"PERMISSIVE"}}}' >/dev/null 2>&1 || true
    sleep 3
    set +e
    baseline_response=$(kubectl exec -n default mesh-outside --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' --max-time 10 http://market-api.market.svc.cluster.local 2>&1)
    set -e
    [[ "$baseline_response" == "200" ]] && baseline_ok=1
    restore_policy
    trap - RETURN
    sleep 3
  fi
  if [[ "$mode" == "STRICT" && "$injection" == "enabled" && "$istiod_image" == *1.30.4* && "$outside_sidecar" == "0" && "$inside" == "200" && "$outside_ok" -eq 0 && "$baseline_ok" -eq 1 ]] \
    && grep -Fq 'HTTP/1.1 200 OK' "$ARTIFACTS/6/market-inside.txt" \
    && grep -Eq '^exit_code=0$' "$ARTIFACTS/6/market-inside.txt"; then
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
      echo "HINT: The plaintext client OUTSIDE the mesh got a successful 2xx response from market-api, or market-outside.txt is missing a proper non-zero 'exit_code=' line - STRICT mTLS should reject a client without an Istio sidecar, and the artifact must record that failure's exit code, not just its text output."
    elif [[ "$baseline_ok" -ne 1 ]]; then
      echo "HINT: When the checker temporarily set the SAME policy to PERMISSIVE, the plaintext client still did not get HTTP 200 - this means the earlier STRICT failure may be caused by an unrelated DNS/network/client issue rather than mTLS enforcement itself. Check basic connectivity to market-api independent of PeerAuthentication."
    fi
    echo "mode=$mode injection=$injection istiod_image=$istiod_image outside_sidecar=$outside_sidecar inside=$inside outside_status=$outside_status outside=$outside baseline_ok=$baseline_ok"
    result=1
  fi
  record_result "$result"
}
