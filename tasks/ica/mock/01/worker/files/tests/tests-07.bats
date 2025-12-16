#!/usr/bin/env bats
# ICA Mock Exam - Task 12: Configure Circuit Breaker and Connection Pool
# Validates DestinationRule with connection pool and outlier detection

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="brown"



@test "7.1 DestinationRule exists in brown namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get destinationrule -n $NAMESPACE --context $CONTEXT | grep -q "echo\|brown"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "7.2 maxConnections is set to 1" {
  echo '1' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  maxConn=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.connectionPool.tcp.maxConnections}')
  if [[ "$maxConn" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$maxConn" == "1" ]
}

@test "7.3 maxRequestsPerConnection is set to 3" {
  echo '1' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  maxReqPerConn=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.connectionPool.http.maxRequestsPerConnection}')
  if [[ "$maxReqPerConn" == "3" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$maxReqPerConn" == "3" ]
}

@test "7.4 http1MaxPendingRequests is set to 10" {
  echo '1' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  maxPending=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.connectionPool.http.http1MaxPendingRequests}')
  if [[ "$maxPending" == "10" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$maxPending" == "10" ]
}

@test "7.5 consecutive5xxErrors is set to 3" {
  echo '1' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  errors=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.outlierDetection.consecutive5xxErrors}')
  if [[ "$errors" == "3" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$errors" == "3" ]
}

@test "7.6 interval is set to 5s" {
  echo '0.5' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  interval=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.outlierDetection.interval}')
  if [[ "$interval" == "5s" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$interval" == "5s" ]
}

@test "7.7 baseEjectionTime is set to 5m" {
  echo '1' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  ejectionTime=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.outlierDetection.baseEjectionTime}')
  if [[ "$ejectionTime" == "5m" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$ejectionTime" == "5m" ]
}

@test "7.8 Connection pool generates 503 errors under load" {
  echo '1' >> /var/work/tests/result/all
  # Get Fortio pod name
  FORTIO_POD=$(kubectl get pod -n $NAMESPACE --context $CONTEXT -l app=fortio -o jsonpath='{.items[0].metadata.name}')

  # Run load test with high concurrency to overflow connection pool
  output=$(kubectl exec $FORTIO_POD -n $NAMESPACE --context $CONTEXT -- fortio load -c 20 -qps 0 -n 100 -quiet http://brown-echo/mars 2>&1)

  # Check if 503 errors occurred
  echo "$output" | grep -q "Code 503"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

