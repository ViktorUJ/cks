#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

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

@test "2.1 VirtualService defines a request timeout for slow" {
  echo '1' >> /var/work/tests/result/all

  vs=$(kubectl get virtualservice -n default -o json | jq -r '
    .items[]
    | select((.spec.hosts // []) | index("slow"))
    | select([ .spec.http[]?.timeout ] | map(select(. != null)) | length > 0)
    | .metadata.name' | wc -l)

  if [[ "$vs" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService for host slow with http.timeout found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Slow backend exceeds the timeout and returns 504" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 20 http://slow:8080/ 2>/dev/null || true)

  if [[ "$code" == "504" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "GET slow returned '$code' (expected 504 Gateway Timeout)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 DestinationRule sets a connection pool limit for backend" {
  echo '1' >> /var/work/tests/result/all

  dr=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^backend(\\.|$)"))
    | select(.spec.trafficPolicy.connectionPool != null)
    | .metadata.name' | wc -l)

  if [[ "$dr" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule for backend with trafficPolicy.connectionPool found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 DestinationRule enables outlier detection for backend" {
  echo '1' >> /var/work/tests/result/all

  dr=$(kubectl get destinationrule -n default -o json | jq -r '
    .items[]
    | select((.spec.host // "") | test("^backend(\\.|$)"))
    | select(.spec.trafficPolicy.outlierDetection != null)
    | .metadata.name' | wc -l)

  if [[ "$dr" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No DestinationRule for backend with trafficPolicy.outlierDetection found"
    result=1
  fi

  [ "$result" == "0" ]
}
