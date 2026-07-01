#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 ping-pong pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n default -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ping-pong pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Gateway terminates TLS (HTTPS, mode SIMPLE, credentialName)" {
  echo '1' >> /var/work/tests/result/all

  gw=$(kubectl get gateway -n default -o json | jq -r '
    .items[]
    | select(any(.spec.servers[]?;
        ((.port.protocol // "") | ascii_upcase) == "HTTPS"
        and (.tls.mode // "") == "SIMPLE"
        and (.tls.credentialName // "") != ""))
    | .metadata.name' | wc -l)

  if [[ "$gw" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Gateway with an HTTPS server (tls SIMPLE + credentialName) found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 TLS credential secret exists in istio-system" {
  echo '1' >> /var/work/tests/result/all

  cred=$(kubectl get gateway -n default -o json | jq -r '.items[].spec.servers[]? | select((.tls.mode // "") == "SIMPLE") | .tls.credentialName' 2>/dev/null | head -1)
  type=$(kubectl get secret "$cred" -n istio-system -o jsonpath='{.type}' 2>/dev/null)

  if [[ "$type" == "kubernetes.io/tls" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "secret '$cred' in istio-system is not a kubernetes.io/tls secret (got '$type')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.3 VirtualService for myapp.local is bound to the gateway" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | select((.spec.hosts // []) | index("myapp.local"))
    | select((.spec.gateways // []) | length > 0)
    | .metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService for myapp.local bound to a gateway"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 App is reachable over HTTPS (TLS terminated at the edge)" {
  echo '1' >> /var/work/tests/result/all

  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 https://myapp.local:32443/ 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HTTPS request returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}
