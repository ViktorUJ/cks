#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All ping-pong pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n default -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer with restartPolicy: Always)
  pods_with_sidecar=$(kubectl get pods -n default -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total_pods" -gt 0 ]] && [[ "$total_pods" -eq "$pods_with_sidecar" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 DestinationRule defines subsets v1/v2 and a load balancer" {
  echo '1' >> /var/work/tests/result/all

  dr=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^ping-pong(\\.|$)"))
    | select([ .spec.subsets[]?.name ] | (index("v1") and index("v2")))
    | select((.spec.trafficPolicy.loadBalancer.simple // "") != "")
    | .metadata.name' | wc -l)

  if [[ "$dr" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule for ping-pong with subsets v1/v2 and a loadBalancer.simple found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 DestinationRule has a port-level load balancer override" {
  echo '1' >> /var/work/tests/result/all

  override=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^ping-pong(\\.|$)"))
    | select([ .spec.trafficPolicy.portLevelSettings[]?.loadBalancer.simple ] | length > 0)
    | .metadata.name' | wc -l)

  if [[ "$override" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No portLevelSettings load balancer override found on the ping-pong DestinationRule"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 VirtualService mirrors traffic to subset v2" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | . as $v
    | select([ $v.spec.http[]?.mirror | select(. != null) | "\(.host)/\(.subset)" ] | any(test("ping-pong/v2$")))
    | $v.metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService mirroring traffic to host ping-pong subset v2 found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 Primary traffic is served by a v1 pod (200)" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 12 http://myapp.local:32080 || true)
  name=$(echo "$body" | grep 'Server Name' | awk '{print $NF}' | tail -1)

  if echo "$name" | grep -q "ping-pong-v1"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Primary response served by '$name' (expected a ping-pong-v1 pod)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.2 v2 receives mirrored traffic" {
  echo '1' >> /var/work/tests/result/all

  # generate some primary traffic; each request is mirrored to v2
  for i in $(seq 15); do curl -s -o /dev/null --max-time 8 http://myapp.local:32080 || true; done
  sleep 2

  rq=$(kubectl exec -n default deploy/ping-pong-v2 -c istio-proxy -- pilot-agent request GET stats 2>/dev/null \
    | grep -E 'inbound\|8080.*(rq_total|rq_completed)' \
    | awk -F: '{gsub(/ /,"",$2); s+=$2} END{print s+0}')

  if [[ "${rq:-0}" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "v2 inbound request counter is 0 (no mirrored traffic detected)"
    result=1
  fi

  [ "$result" == "0" ]
}
