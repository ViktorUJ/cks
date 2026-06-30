#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

EXT_HOST="httpbin.org"
BLOCKED_HOST="example.com"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 mesh-client pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  # istio-proxy may be a regular container or a native sidecar (initContainer with restartPolicy: Always)
  count=$(kubectl get pods -n default -l app=mesh-client -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$count" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "mesh-client has no istio-proxy sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 ServiceEntry registers the external host with DNS resolution" {
  echo '1' >> /var/work/tests/result/all

  se=$(kubectl get serviceentry -n default -o json | jq -r --arg h "$EXT_HOST" '
    .items[]
    | select((.spec.hosts // []) | index($h))
    | select((.spec.resolution // "") == "DNS")
    | .metadata.name' | wc -l)

  if [[ "$se" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No ServiceEntry for $EXT_HOST with resolution DNS found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Egress Gateway exposes the external host" {
  echo '1' >> /var/work/tests/result/all

  gw=$(kubectl get gateway -n default -o json | jq -r --arg h "$EXT_HOST" '
    .items[]
    | select((.spec.selector.istio // "") == "egressgateway")
    | select([ .spec.servers[]?.hosts[]? ] | index($h))
    | .metadata.name' | wc -l)

  if [[ "$gw" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No egress Gateway (selector istio=egressgateway) for $EXT_HOST found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 VirtualService routes the external host through the egress gateway" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r --arg h "$EXT_HOST" '
    .items[]
    | select((.spec.hosts // []) | index($h))
    | . as $v
    | select([ $v.spec.http[]?.route[]?.destination.host ] | any(test("egressgateway")))
    | $v.metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService routing $EXT_HOST via istio-egressgateway found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 Sidecar limits egress with REGISTRY_ONLY" {
  echo '1' >> /var/work/tests/result/all

  sc=$(kubectl get sidecar -n default -o json | jq -r '
    .items[]
    | select((.spec.outboundTrafficPolicy.mode // "") == "REGISTRY_ONLY")
    | .metadata.name' | wc -l)

  if [[ "$sc" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Sidecar with outboundTrafficPolicy.mode REGISTRY_ONLY found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "5.1 mesh-client can reach the approved external host (200)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/mesh-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 15 "http://${EXT_HOST}/status/200" 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "mesh-client -> $EXT_HOST returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "5.2 mesh-client is blocked from an unregistered external host" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/mesh-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 15 "http://${BLOCKED_HOST}/" 2>/dev/null || true)

  # REGISTRY_ONLY makes Envoy return 502 (BlackHoleCluster); anything that is not 200 means blocked
  if [[ "$code" != "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "mesh-client -> $BLOCKED_HOST returned '$code' (expected to be blocked)"
    result=1
  fi

  [ "$result" == "0" ]
}
