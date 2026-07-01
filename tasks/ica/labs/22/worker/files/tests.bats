#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

URL="http://httpsvc.external.svc.cluster.local/"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 in-mesh client has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=app-client --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=app-client -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app-client pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 DestinationRule originates TLS (SIMPLE) to the external service" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get destinationrule -A -o json | jq '[
    .items[]
    | select((.spec.host // "") | test("^httpsvc\\.external"))
    | select([.spec.trafficPolicy.portLevelSettings[]?.tls.mode] | index("SIMPLE"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule with TLS origination (SIMPLE) for httpsvc.external"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 client reaches the HTTPS-only backend via TLS origination (200)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n app deploy/app-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null || true)

  # With origination: sidecar upgrades plaintext:80 to TLS:8443 -> 200.
  # Without origination: plaintext hits the TLS port -> 400 (bad request).
  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "client got HTTP code '$code' (expected 200 via TLS origination)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 backend response body confirms the secure endpoint" {
  echo '1' >> /var/work/tests/result/all

  body=$(kubectl exec -n app deploy/app-client -c curl -- \
    curl -s --max-time 10 "$URL" 2>/dev/null || true)

  if echo "$body" | grep -q 'secure-ok'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "unexpected body from backend: '$body'"
    result=1
  fi

  [ "$result" == "0" ]
}
