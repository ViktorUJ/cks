#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 All app pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.2 Cluster nodes are labelled with at least two topology zones" {
  echo '1' >> /var/work/tests/result/all

  zones=$(kubectl get nodes -o json | jq -r '.items[].metadata.labels["topology.kubernetes.io/zone"] // empty' | sort -u | wc -l)

  if [[ "$zones" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "found $zones distinct topology zones (need >= 2)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 DestinationRule enables locality LB with outlier detection" {
  echo '1' >> /var/work/tests/result/all

  dr=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^ping-pong(\\.|$)"))
    | select(.spec.trafficPolicy.outlierDetection != null)
    | select(.spec.trafficPolicy.loadBalancer.localityLbSetting.enabled == true)
    | .metadata.name' | wc -l)

  if [[ "$dr" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule for ping-pong with outlierDetection + localityLbSetting.enabled"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Locality preference: client in zone A is served by Zone-A" {
  echo '1' >> /var/work/tests/result/all

  a=0
  for i in $(seq 5); do
    body=$(kubectl exec -n default deploy/curl-client -c curl -- curl -s --max-time 10 http://ping-pong:8080/ 2>/dev/null || true)
    echo "$body" | grep 'Server Name' | grep -q 'Zone-A' && a=$((a+1))
  done

  if [[ "$a" -eq 5 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "only $a/5 requests served by Zone-A (locality preference not effective)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 Failover: when Zone-A is down, client is served by Zone-B" {
  echo '1' >> /var/work/tests/result/all

  # take the local (zone A) backend down
  kubectl scale deployment ping-pong-a -n default --replicas=0 >/dev/null 2>&1
  kubectl wait --for=delete pod -l app=ping-pong,zone=a -n default --timeout=60s >/dev/null 2>&1
  sleep 5

  b=0
  for i in $(seq 5); do
    body=$(kubectl exec -n default deploy/curl-client -c curl -- curl -s --max-time 10 http://ping-pong:8080/ 2>/dev/null || true)
    echo "$body" | grep 'Server Name' | grep -q 'Zone-B' && b=$((b+1))
  done

  # restore
  kubectl scale deployment ping-pong-a -n default --replicas=1 >/dev/null 2>&1

  if [[ "$b" -ge 4 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "only $b/5 requests failed over to Zone-B"
    result=1
  fi

  [ "$result" == "0" ]
}
