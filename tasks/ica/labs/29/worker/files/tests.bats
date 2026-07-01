#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 ping-pong pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ping-pong pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Gateway has a MUTUAL and a PASSTHROUGH server" {
  echo '1' >> /var/work/tests/result/all

  modes=$(kubectl get gateway -n app -o json | jq -r '[.items[].spec.servers[]?.tls.mode] | join(",")')
  if echo "$modes" | grep -q 'MUTUAL' && echo "$modes" | grep -q 'PASSTHROUGH'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Gateway TLS modes are '$modes' (expected both MUTUAL and PASSTHROUGH)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 MUTUAL: request without a client certificate is rejected" {
  echo '1' >> /var/work/tests/result/all

  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 https://myapp.local:32443/ 2>/dev/null || true)
  if [[ "$code" != "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "request without a client cert returned '$code' (expected rejection, not 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 MUTUAL: request with a valid client certificate is allowed (200)" {
  echo '1' >> /var/work/tests/result/all

  kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt 2>/dev/null
  kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key 2>/dev/null

  code=""
  for i in $(seq 12); do
    code=$(curl -sk --cert /tmp/c.crt --key /tmp/c.key -o /dev/null -w "%{http_code}" --max-time 8 https://myapp.local:32443/ 2>/dev/null || true)
    [[ "$code" == "200" ]] && break
    sleep 5
  done

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "request with a client cert returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.3 PASSTHROUGH: TLS terminates at the backend (secure-ok)" {
  echo '1' >> /var/work/tests/result/all

  body=""
  for i in $(seq 12); do
    body=$(curl -sk --max-time 8 https://passthrough.local:32443/ 2>/dev/null || true)
    echo "$body" | grep -q 'secure-ok' && break
    sleep 5
  done

  if echo "$body" | grep -q 'secure-ok'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "passthrough request did not reach the backend (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}
