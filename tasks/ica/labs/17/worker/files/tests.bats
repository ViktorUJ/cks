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

@test "2.1 EnvoyFilter enables local_ratelimit on the ingress gateway" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get envoyfilter -A -o json | jq '[
    .items[]
    | select(.spec.workloadSelector.labels.istio == "ingressgateway")
    | select([.. | .name? // empty] | index("envoy.filters.http.local_ratelimit"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No EnvoyFilter with local_ratelimit targeting the ingress gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 App is reachable through the gateway (200)" {
  echo '1' >> /var/work/tests/result/all

  # Wait for a token to be available (bucket may be refilling), up to ~75s.
  ok200=0
  for i in $(seq 15); do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$URL" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then ok200=1; break; fi
    sleep 5
  done

  if [[ "$ok200" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app never returned 200 through the gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Rate limit is enforced under burst (429)" {
  echo '1' >> /var/work/tests/result/all

  limited=0
  for i in $(seq 25); do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$URL" 2>/dev/null || true)
    [[ "$code" == "429" ]] && limited=$((limited+1))
  done

  if [[ "$limited" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "burst of 25 requests produced no 429 (rate limit not enforced)"
    result=1
  fi

  [ "$result" == "0" ]
}
