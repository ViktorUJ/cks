#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All app pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 grpc-server Service port 8079 is declared as gRPC" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get svc grpc-server -n app -o json 2>/dev/null | jq '[
    .spec.ports[]
    | select(.port==8079)
    | select( ((.name // "") | startswith("grpc")) or ((.appProtocol // "") == "grpc") )
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Service grpc-server port 8079 is not named grpc* and has no appProtocol: grpc"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 VirtualService for grpc-server defines gRPC retries" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get virtualservice -n app -o json | jq '[
    .items[]
    | select((.spec.hosts // []) | index("grpc-server"))
    | select([ .spec.http[]?
        | select((.retries.attempts // 0) >= 1)
        | select((.retries.retryOn // "") != "") ] | length > 0)
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService for grpc-server with http.retries (attempts + retryOn)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.3 VirtualService for grpc-server defines a request timeout" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get virtualservice -n app -o json | jq '[
    .items[]
    | select((.spec.hosts // []) | index("grpc-server"))
    | select([ .spec.http[]? | select(.timeout != null) ] | length > 0)
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService for grpc-server with an http.timeout"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 gRPC works through the mesh (PingPong.Echo)" {
  echo '1' >> /var/work/tests/result/all

  out=""
  for i in $(seq 12); do
    out=$(kubectl exec -n app deploy/grpc-client -c ping-pong -- \
      /app -grpc-client -target grpc-server:8079 -n 20 -quiet 2>&1 || true)
    if echo "$out" | grep -qE 'ok: [1-9]'; then break; fi
    sleep 5
  done

  ok=$(echo "$out" | sed -n 's/.*ok: \([0-9][0-9]*\).*/\1/p' | head -n1)
  if [[ "${ok:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "gRPC Echo failed (out=$(echo "$out" | tail -n 3))"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 gRPC requests are balanced per-request across backend pods" {
  echo '1' >> /var/work/tests/result/all

  out=$(kubectl exec -n app deploy/grpc-client -c ping-pong -- \
    /app -grpc-client -target grpc-server:8079 -n 180 -c 4 -quiet 2>&1 || true)

  distinct=$(echo "$out" | sed -n 's/^distinct servers: \([0-9][0-9]*\).*/\1/p' | head -n1)

  if [[ "${distinct:-0}" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Only ${distinct:-0} distinct backend pod(s) answered (expected >= 2; check port naming = grpc)"
    echo "$out" | tail -n 5
    result=1
  fi

  [ "$result" == "0" ]
}
