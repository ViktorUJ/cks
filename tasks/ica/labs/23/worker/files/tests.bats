#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

URL="http://myapp.local:32080/"
# base64("admin3:admin3")
AUTH="YWRtaW4zOmFkbWluMw=="

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 app pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 WasmPlugin (basic_auth) targets the ingress gateway" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get wasmplugin -A -o json | jq '[
    .items[]
    | select(.spec.selector.matchLabels.istio == "ingressgateway")
    | select((.spec.url // "") | test("basic_auth"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No WasmPlugin with a basic_auth module targeting the ingress gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 requests without credentials are rejected (401)" {
  echo '1' >> /var/work/tests/result/all

  # The Wasm module is fetched from an OCI registry at runtime; allow time for it.
  got401=0
  for i in $(seq 18); do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$URL" 2>/dev/null || true)
    if [[ "$code" == "401" ]]; then got401=1; break; fi
    sleep 5
  done

  if [[ "$got401" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "request without credentials did not return 401 (basic_auth not enforced)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 requests with valid credentials are allowed (200)" {
  echo '1' >> /var/work/tests/result/all

  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "Authorization: Basic ${AUTH}" "$URL" 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "request with valid credentials returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}
