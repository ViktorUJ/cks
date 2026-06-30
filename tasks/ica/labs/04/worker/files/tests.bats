#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All pods in default have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer with restartPolicy: Always)
  pods_with_sidecar=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total_pods" -gt 0 ]] && [[ "$total_pods" -eq "$pods_with_sidecar" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, Pods with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 STRICT mTLS enabled via PeerAuthentication in default" {
  echo '1' >> /var/work/tests/result/all

  mtls_policies=$(kubectl get peerauthentication -n default -o json | jq -r '.items[] | select(.spec.mtls.mode == "STRICT") | .metadata.name' | wc -l)

  if [[ "$mtls_policies" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Default-deny AuthorizationPolicy protects ping-pong" {
  echo '1' >> /var/work/tests/result/all

  # An ALLOW policy that selects ping-pong but has no rules == deny everything to ping-pong.
  deny=$(kubectl get authorizationpolicy -n default -o json | jq -r '
    .items[]
    | select((.spec.selector.matchLabels.app // "") == "ping-pong")
    | select((.spec.action // "ALLOW") == "ALLOW")
    | select((.spec.rules // []) | length == 0)
    | .metadata.name' | wc -l)

  if [[ "$deny" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No default-deny AuthorizationPolicy (ALLOW + no rules) selecting app=ping-pong found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 AuthorizationPolicy allows only the frontend identity with GET" {
  echo '1' >> /var/work/tests/result/all

  allow=$(kubectl get authorizationpolicy -n default -o json | jq -r '
    .items[]
    | select((.spec.action // "ALLOW") == "ALLOW")
    | select(.spec.rules != null)
    | . as $p
    | $p.spec.rules[]
    | select((.from // [])[].source.principals[]? | test("/sa/frontend$"))
    | select((.to // [])[].operation.methods[]? == "GET")
    | $p.metadata.name' | wc -l)

  if [[ "$allow" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No AuthorizationPolicy allowing principal .../sa/frontend with method GET found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 Frontend can reach the backend (Backend Status 200) via the gateway" {
  echo '1' >> /var/work/tests/result/all

  status=$(curl -s --max-time 10 http://myapp.local:32080 | grep 'Backend Status' | awk '{print $NF}' | tail -1)

  if [[ "$status" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "frontend -> backend status: '$status' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.2 Unauthorized workload is denied (403) by AuthorizationPolicy" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/unauthorized -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://ping-pong:8080/ 2>/dev/null || true)

  if [[ "$code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "unauthorized -> backend code: '$code' (expected 403)"
    result=1
  fi

  [ "$result" == "0" ]
}
