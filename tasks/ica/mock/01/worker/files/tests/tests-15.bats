#!/usr/bin/env bats
# ICA Mock Exam - Task 28: Sidecar egress in lime namespace
# Validates Sidecar resource with egress configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="lime"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 28: Sidecar egress in lime (2 points)

@test "28.1 Sidecar named default exists in lime namespace" {
  echo '1.0' >> /var/work/tests/result/all
  kubectl get sidecar default -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "28.2 Sidecar egress includes olive namespace" {
  echo '1.0' >> /var/work/tests/result/all
  # Check if egress hosts include olive/*
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "olive"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "28.3 Sidecar egress includes lime namespace (itself)" {
  echo '1.0' >> /var/work/tests/result/all
  # Check if egress hosts include lime/* or ./*
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -qE "(lime|\./\*)"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "28.4 Sidecar egress includes istio-system namespace" {
  echo '1.0' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "istio-system"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 4 points for Task 28
