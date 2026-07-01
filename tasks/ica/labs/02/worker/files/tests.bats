#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All ping-pong pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer)
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

@test "2.1 DestinationRule defines subsets v1, v2, v3" {
  echo '1' >> /var/work/tests/result/all

  dr=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^ping-pong(\\.|$)"))
    | select([ .spec.subsets[]?.name ] | (index("v1") and index("v2") and index("v3")))
    | .metadata.name' | wc -l)

  if [[ "$dr" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule for ping-pong with subsets v1/v2/v3"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 VirtualService routes the x-user:tester header to subset v3" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | . as $v
    | $v.spec.http[]?
    | select(([ .match[]?.headers["x-user"].exact ] | index("tester")) and ([ .route[]?.destination.subset ] | index("v3")))
    | $v.metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService routing header x-user:tester to subset v3"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Testers (x-user:tester) reach v3" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 12 -H "x-user: tester" http://myapp.local:32080/ 2>/dev/null || true)

  if echo "$body" | grep -q "V3"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "tester request did not reach v3"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Regular users never reach v3 (canary v1/v2 only)" {
  echo '1' >> /var/work/tests/result/all

  v3hits=0
  ok=0
  for i in $(seq 10); do
    body=$(curl -s --max-time 12 http://myapp.local:32080/ 2>/dev/null || true)
    echo "$body" | grep -q "Server Name" && ok=1
    echo "$body" | grep -q "V3" && v3hits=$((v3hits+1))
  done

  if [[ "$ok" -eq 1 ]] && [[ "$v3hits" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "regular traffic reached v3 $v3hits times (expected 0), got-response=$ok"
    result=1
  fi

  [ "$result" == "0" ]
}
