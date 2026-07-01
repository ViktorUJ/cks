#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All app pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer)
  injected=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Fault injection: ping-pong aborts with HTTP 503" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | select((.spec.hosts // []) | index("ping-pong"))
    | select([ .spec.http[]?.fault.abort.httpStatus ] | index(503))
    | .metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService for ping-pong with fault.abort httpStatus 503"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 A VirtualService defines HTTP retries" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | select(any(.spec.http[]?; (.retries.attempts // 0) >= 1))
    | .metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService with an http retries block found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Retries mask the fault: client mostly gets a successful backend (200)" {
  echo '1' >> /var/work/tests/result/all

  ok200=0
  for i in $(seq 10); do
    body=$(curl -s --max-time 15 http://myapp.local:32080/ 2>/dev/null || true)
    echo "$body" | grep 'Backend Status' | grep -q '200' && ok200=$((ok200+1))
  done

  # with retries on a 50% fault, nearly all requests should succeed
  if [[ "$ok200" -ge 8 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "only $ok200/10 requests returned Backend Status 200 (retries not effective?)"
    result=1
  fi

  [ "$result" == "0" ]
}
