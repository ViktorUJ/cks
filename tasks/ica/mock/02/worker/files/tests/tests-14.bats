#!/usr/bin/env bats
# ICA Mock Exam - Task 29: Configure external access for echo service
# Validates Gateway and VirtualService for external access

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="silver"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 29: Configure external access for echo service (2 points)

@test "29.1 VirtualService echo-vs exists in silver namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice echo-vs -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "29.2 VirtualService has test.gateway.ica host" {
  echo '0.5' >> /var/work/tests/result/all
  vs_host=$(kubectl get virtualservice echo-vs -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.hosts[*]}')
  result=1
  if echo "$vs_host" | grep -q "test.gateway.ica"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "29.3 Gateway echo-gateway exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get gateway echo-gateway -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "29.4 Gateway has test.gateway.ica host" {
  echo '0.5' >> /var/work/tests/result/all
  gw_host=$(kubectl get gateway echo-gateway -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.servers[*].hosts[*]}')
  result=1
  if echo "$gw_host" | grep -q "test.gateway.ica"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 2 points for Task 29
