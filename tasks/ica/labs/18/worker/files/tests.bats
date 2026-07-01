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

@test "1.2 Jaeger tracing backend is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy jaeger -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Jaeger deployment is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Telemetry resource enables access logging with a provider" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get telemetry -A -o json | jq '[.items[].spec.accessLogging[]?.providers[]?.name] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Telemetry resource enables access logging with a provider"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Telemetry resource enables tracing via the zipkin provider" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get telemetry -A -o json | jq '[.items[].spec.tracing[]? | select([.providers[]?.name] | index("zipkin"))] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Telemetry resource references the zipkin tracing provider"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Access logs are produced by the app sidecar after traffic" {
  echo '1' >> /var/work/tests/result/all

  for i in $(seq 6); do curl -s -o /dev/null --max-time 8 "$URL" 2>/dev/null || true; done
  sleep 3

  pod=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  logs=$(kubectl logs -n app "$pod" -c istio-proxy --tail=300 2>/dev/null)

  if echo "$logs" | grep -qE 'GET / HTTP'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No access log lines found in the app sidecar (pod=$pod)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Traces are collected in Jaeger for the app" {
  echo '1' >> /var/work/tests/result/all

  # generate traffic so traces are produced
  for i in $(seq 30); do curl -s -o /dev/null --max-time 8 "$URL" 2>/dev/null || true; done
  # give the sidecars time to flush spans and Jaeger time to index them
  sleep 25

  found=0
  for attempt in $(seq 6); do
    out=$(kubectl exec -n app deploy/curl-client -- \
      curl -s --max-time 15 'http://tracing.istio-system:80/jaeger/api/services' 2>/dev/null)
    if echo "$out" | grep -q 'ping-pong'; then found=1; break; fi
    sleep 10
  done

  if [[ "$found" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Jaeger has no traces for the ping-pong service"
    result=1
  fi

  [ "$result" == "0" ]
}
