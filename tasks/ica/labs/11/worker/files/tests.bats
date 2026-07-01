#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

JWT_URL="https://raw.githubusercontent.com/istio/istio/release-1.29/security/tools/jwt/samples/demo.jwt"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All app pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  pods_with_sidecar=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total_pods" -gt 0 ]] && [[ "$total_pods" -eq "$pods_with_sidecar" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 RequestAuthentication validates JWT from the expected issuer" {
  echo '1' >> /var/work/tests/result/all

  ra=$(kubectl get requestauthentication -n default -o json | jq -r '
    .items[]
    | select((.spec.selector.matchLabels.app // "") == "ping-pong")
    | select([ .spec.jwtRules[]?.issuer ] | index("testing@secure.istio.io"))
    | .metadata.name' | wc -l)

  if [[ "$ra" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No RequestAuthentication for ping-pong with issuer testing@secure.istio.io"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 AuthorizationPolicy requires a valid JWT principal" {
  echo '1' >> /var/work/tests/result/all

  ap=$(kubectl get authorizationpolicy -n default -o json | jq -r '
    .items[]
    | select((.spec.selector.matchLabels.app // "") == "ping-pong")
    | select([ .spec.rules[]?.from[]?.source.requestPrincipals[]? ] | length > 0)
    | .metadata.name' | wc -l)

  if [[ "$ap" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No AuthorizationPolicy requiring requestPrincipals found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 Request WITHOUT a token is denied (403)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 12 http://ping-pong:8080/ 2>/dev/null || true)

  if [[ "$code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "no-token request returned '$code' (expected 403)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.2 Request with an INVALID token is rejected (401)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 12 -H "Authorization: Bearer not-a-real-token" http://ping-pong:8080/ 2>/dev/null || true)

  if [[ "$code" == "401" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "invalid-token request returned '$code' (expected 401)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.3 Request with a VALID token is allowed (200)" {
  echo '1' >> /var/work/tests/result/all

  TOKEN=$(curl -s --max-time 15 "$JWT_URL")
  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 12 -H "Authorization: Bearer ${TOKEN}" http://ping-pong:8080/ 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "valid-token request returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}
