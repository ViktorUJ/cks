#!/usr/bin/env bats
# ICA Mock Exam - Task 26: mTLS with workload selector
# Validates PeerAuthentication with workload selector

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="crimson"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 26: mTLS with workload selector (2 points)

@test "26.1 PeerAuthentication exists in crimson namespace" {
  echo '0.97' >> /var/work/tests/result/all
  kubectl get peerauthentication -n $NAMESPACE --context $CONTEXT -o name | grep -q "peerauthentication"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "26.2 PeerAuthentication has workload selector for app=space" {
  echo '1.51' >> /var/work/tests/result/all
  # Check if selector has app=space label
  pa_selector=$(kubectl get peerauthentication -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.selector.matchLabels.app}')
  result=1
  if [[ "$pa_selector" == "space" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "26.3 mTLS mode is STRICT" {
  echo '1.51' >> /var/work/tests/result/all
  pa_mode=$(kubectl get peerauthentication -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.mtls.mode}')
  result=1
  if [[ "$pa_mode" == "STRICT" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 4 points for Task
