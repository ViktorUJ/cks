#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

URL="http://myapp.local:32080/"

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

@test "2.1 EnvoyFilter injects a Lua HTTP filter on the ingress gateway" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get envoyfilter -A -o json | jq '[
    .items[]
    | select(.spec.workloadSelector.labels.istio == "ingressgateway")
    | select([.. | .name? // empty] | index("envoy.filters.http.lua"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No EnvoyFilter with a Lua HTTP filter targeting the ingress gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Lua adds the x-lua-lab response header" {
  echo '1' >> /var/work/tests/result/all

  found=0
  for i in $(seq 12); do
    hdrs=$(curl -s -D - -o /dev/null --max-time 8 "$URL" 2>/dev/null || true)
    if echo "$hdrs" | grep -qi 'x-lua-lab'; then found=1; break; fi
    sleep 5
  done

  if [[ "$found" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "response is missing the x-lua-lab header added by Lua"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Lua blocks requests carrying x-block:yes (403)" {
  echo '1' >> /var/work/tests/result/all

  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 -H "x-block: yes" "$URL" 2>/dev/null || true)
  if [[ "$code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "request with x-block:yes returned '$code' (expected 403 from Lua)"
    result=1
  fi

  [ "$result" == "0" ]
}
