#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 Kubernetes Gateway API CRDs are installed" {
  echo '1' >> /var/work/tests/result/all

  if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
     && kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Gateway API CRDs (gateways/httproutes) not found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.2 app pods (v1 and v2) have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -ge 2 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Gateway 'web-gateway' uses gatewayClassName istio and is auto-provisioned" {
  echo '1' >> /var/work/tests/result/all

  class=$(kubectl get gateway web-gateway -n app -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
  ready=$(kubectl get deploy web-gateway-istio -n app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

  if [[ "$class" == "istio" ]] && [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Gateway class='$class', web-gateway-istio ready='${ready:-0}'"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 HTTPRoute 'ping-pong-route' is attached to web-gateway" {
  echo '1' >> /var/work/tests/result/all

  ref=$(kubectl get httproute ping-pong-route -n app -o json 2>/dev/null | jq -r '[.spec.parentRefs[]?.name] | index("web-gateway")')

  if [[ "$ref" != "null" ]] && [[ -n "$ref" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HTTPRoute ping-pong-route is not attached to web-gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Default traffic reaches v1 (Stable)" {
  echo '1' >> /var/work/tests/result/all

  nodeport=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
  body=$(curl -s --max-time 12 "http://myapp.local:${nodeport}/" 2>/dev/null || true)

  if echo "$body" | grep -q "V1"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "default request did not reach v1 (nodeport=$nodeport, body=$body)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Header x-version:canary reaches v2 (Canary)" {
  echo '1' >> /var/work/tests/result/all

  nodeport=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}' 2>/dev/null)
  body=$(curl -s --max-time 12 -H "x-version: canary" "http://myapp.local:${nodeport}/" 2>/dev/null || true)

  if echo "$body" | grep -q "V2"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "canary header did not reach v2 (nodeport=$nodeport, body=$body)"
    result=1
  fi

  [ "$result" == "0" ]
}
