#!/usr/bin/env bats
# ICA Mock Exam - Task 30: AuthorizationPolicy in olive namespace
# Validates AuthorizationPolicy allowing /mars path from orchid namespace

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="olive"


@test "16.1 AuthorizationPolicy allow-get-policy exists" {
  echo '1' >> /var/work/tests/result/all
  kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.2 AuthorizationPolicy action is ALLOW" {
  echo '1' >> /var/work/tests/result/all
  action=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.action}')
  result=1
  if [[ "$action" == "ALLOW" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "16.3 AuthorizationPolicy has selector for app=olive" {
  echo '1' >> /var/work/tests/result/all
  selector=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.selector.matchLabels.app}')
  result=1
  if [[ "$selector" == "olive" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "16.4 AuthorizationPolicy allows /mars path" {
  echo '1' >> /var/work/tests/result/all
  paths=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].to[*].operation.paths[*]}')
  result=1
  if echo "$paths" | grep -q "/mars"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "16.5 AuthorizationPolicy allows from orchid namespace" {
  echo '1' >> /var/work/tests/result/all
  # Check if source namespace is orchid
  namespaces=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.namespaces[*]}')
  principals=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}')
  result=1
  if echo "$namespaces" | grep -q "orchid" || echo "$principals" | grep -q "orchid"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

