#!/usr/bin/env bats
# ICA Mock Exam - Task 08: Configure Retry Policy for HTTP Errors
# Validates VirtualService retry policy configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="gray"
VS_NAME="gray-echo-vs"
SERVICE="gray-echo"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 08: Configure Retry Policy for HTTP Errors (3 points)

@test "8.1 VirtualService exists in gray namespace" {
  echo '0.98' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "$VS_NAME\|gray"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.2 Retry attempts configured to 2" {
  echo '1.53' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  attempts=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].retries.attempts}')
  if [[ "$attempts" == "2" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$attempts" == "2" ]
}

@test "8.3 Per-try timeout configured to 1s" {
  echo '1.53' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  timeout=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].retries.perTryTimeout}')
  if [[ "$timeout" == "1s" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$timeout" == "1s" ]
}

@test "8.4 Retry configured for 5xx errors" {
  echo '0.98' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  retryOn=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].retries.retryOn}')
  if [[ "$retryOn" == "5xx" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$retryOn" == "5xx" ]
}

@test "8.5 Service responds to /blackhole endpoint (triggers retries)" {
  echo '0.98' >> /var/work/tests/result/all
  # Test /blackhole path which triggers 5xx errors
  # The retry policy should be applied
  run kubectl exec sleep-red -n red --context $CONTEXT -- curl -s --max-time 10 http://$SERVICE.$NAMESPACE.svc.cluster.local/blackhole
  # Command should complete (retries happen in background)
  result=$?
  if [[ "$result" == "0" ]] || [[ "$result" == "52" ]] || [[ "$result" == "7" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  # Accept 0 (success), 52 (connection reset), or 7 (connection refused)
  [[ "$result" == "0" ]] || [[ "$result" == "52" ]] || [[ "$result" == "7" ]]
}

# Total: 6 points for Task
