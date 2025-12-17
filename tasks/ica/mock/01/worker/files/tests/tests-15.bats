#!/usr/bin/env bats
# ICA Mock Exam - Task 28: Sidecar egress in lime namespace
# Validates Sidecar resource with egress configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="lime"


@test "15.1 Sidecar named default exists in lime namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get sidecar default -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.2 Sidecar egress includes olive namespace" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if egress hosts include olive/*
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "olive"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "15.3 Sidecar egress includes lime namespace (itself)" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if egress hosts include lime/* or ./*
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -qE "(lime|\./\*)"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "15.4 Sidecar egress includes istio-system namespace" {
  echo '1' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "istio-system"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

