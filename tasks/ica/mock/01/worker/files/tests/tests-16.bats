#!/usr/bin/env bats
# ICA Mock Exam - Task 30: AuthorizationPolicy in olive namespace
# Validates AuthorizationPolicy allowing /mars path from orchid namespace

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="olive"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 30: AuthorizationPolicy in olive (2 points)

@test "30.1 AuthorizationPolicy allow-get-policy exists" {
  echo '0.97' >> /var/work/tests/result/all
  kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "30.2 AuthorizationPolicy action is ALLOW" {
  echo '0.54' >> /var/work/tests/result/all
  action=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.action}')
  result=1
  if [[ "$action" == "ALLOW" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "30.3 AuthorizationPolicy has selector for app=olive" {
  echo '0.97' >> /var/work/tests/result/all
  selector=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.selector.matchLabels.app}')
  result=1
  if [[ "$selector" == "olive" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "30.4 AuthorizationPolicy allows /mars path" {
  echo '0.97' >> /var/work/tests/result/all
  paths=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].to[*].operation.paths[*]}')
  result=1
  if echo "$paths" | grep -q "/mars"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "30.5 AuthorizationPolicy allows from orchid namespace" {
  echo '0.54' >> /var/work/tests/result/all
  # Check if source namespace is orchid
  namespaces=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.namespaces[*]}')
  principals=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}')
  result=1
  if echo "$namespaces" | grep -q "orchid" || echo "$principals" | grep -q "orchid"; then
    echo '0.25' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 4 points for Task 30
