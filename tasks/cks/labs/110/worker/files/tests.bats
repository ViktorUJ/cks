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

@test "1. RuntimeClass gvisor selects the preinstalled runsc handler" {
  rc=$(kubectl get runtimeclass gvisor --context "$CTX" -o json 2>/dev/null)
  handler=$(jq -r '.handler // empty' <<<"$rc")
  node_selector=$(jq -r '.scheduling.nodeSelector["sandbox.runtime/gvisor"] // empty' <<<"$rc")
  if [[ "$handler" == "runsc" && "$node_selector" == "true" ]] \
    && grep -Fqx 'RuntimeClass gvisor: handler runsc' "$ARTIFACTS/1/runsc-runtime.txt"; then
    result=0
  else
    echo "handler=${handler:-missing} sandbox_selector=${node_selector:-missing}; expected $ARTIFACTS/1/runsc-runtime.txt"
    result=1
  fi
  record_result "$result"
}

@test "2. gVisor Pod is Running on the sandbox node and exposes a distinct kernel view" {
  phase=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  runtime_class=$(kubectl get pod gvisor-sandbox -n "$SANDBOX_NS" --context "$CTX" -o jsonpath='{.spec.runtimeClassName}' 2>/dev/null)
  release=$(kubectl exec -n "$SANDBOX_NS" gvisor-sandbox --context "$CTX" -- uname -r 2>/dev/null || true)
  if [[ "$phase" == "Running" && "$runtime_class" == "gvisor" && -n "$release" ]] \
    && pod_node_has_label gvisor-sandbox "$SANDBOX_NS" sandbox.runtime/gvisor true \
    && grep -Fq "gvisor uname -r: $release" "$ARTIFACTS/2/gvisor-kernel.txt"; then
    result=0
  else
    echo "phase=$phase runtimeClass=$runtime_class release=${release:-missing}; gVisor artifact or placement is invalid"
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
    echo "phase=$phase runtimeClass=${runtime_class:-default-runc} gvisor=$gvisor_release runc=$runc_release"
    result=1
  fi
  record_result "$result"
}

@test "4. Cilium WireGuard transparent encryption is enabled and status is saved" {
  agent=$(kubectl -n kube-system get pods --context "$CTX" -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  encrypt_status=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium encrypt status 2>&1 || true)
  agent_status=$(kubectl -n kube-system exec "$agent" --context "$CTX" -- cilium status 2>&1 || true)
  status="$encrypt_status"$'\n'"$agent_status"
  if [[ -n "$agent" && "$status" =~ [Ww]ire[Gg]uard ]] \
    && grep -Eqi 'WireGuard|Encryption:.*Wireguard' "$ARTIFACTS/4/cilium-encrypt-status.txt"; then
    result=0
  else
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
    echo "request_status=$request_status response=$response; capture must show WireGuard UDP and no plaintext marker"
    result=1
  fi
  record_result "$result"
}

@test "6. market PeerAuthentication STRICT allows mesh client (200) and resets plaintext outside client" {
  mode=$(kubectl get peerauthentication market-strict -n market --context "$CTX" -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
  injection=$(kubectl get namespace market --context "$CTX" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
  inside=$(kubectl exec -n market deploy/market-client --context "$CTX" -- curl -sS -o /dev/null -w '%{http_code}' http://market-api 2>&1 || true)
  set +e
  outside=$(kubectl exec -n default mesh-outside --context "$CTX" -- curl -sS --max-time 10 http://market-api.market.svc.cluster.local 2>&1)
  outside_status=$?
  set -e
  if [[ "$mode" == "STRICT" && "$injection" == "enabled" && "$inside" == "200" && "$outside_status" -ne 0 ]] \
    && grep -Fq 'HTTP/1.1 200 OK' "$ARTIFACTS/6/market-inside.txt" \
    && grep -Eqi 'connection reset by peer|recv failure.*reset' "$ARTIFACTS/6/market-outside.txt"; then
    result=0
  else
    echo "mode=$mode injection=$injection inside=$inside outside_status=$outside_status outside=$outside"
    result=1
  fi
  record_result "$result"
}
