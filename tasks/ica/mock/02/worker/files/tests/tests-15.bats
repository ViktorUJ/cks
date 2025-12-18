#!/usr/bin/env bats
# ICA Mock Exam - Task 31: AuthorizationPolicy in navy namespace
# Validates AuthorizationPolicy allowing /pluto path from turquoise namespace

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="navy"

@test "15.1 AuthorizationPolicy allow-get-policy exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.2 AuthorizationPolicy action is ALLOW" {
  echo '0.5' >> /var/work/tests/result/all
  action=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.action}')
  result=1
  if [[ "$action" == "ALLOW" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "15.3 AuthorizationPolicy allows /pluto path" {
  echo '0.5' >> /var/work/tests/result/all
  paths=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].to[*].operation.paths[*]}')
  result=1
  if echo "$paths" | grep -q "/pluto"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "15.4 AuthorizationPolicy allows from turquoise namespace" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if source namespace is turquoise
  namespaces=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.namespaces[*]}')
  principals=$(kubectl get authorizationpolicy allow-get-policy -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].from[*].source.principals[*]}')
  result=1
  if echo "$namespaces" | grep -q "turquoise" || echo "$principals" | grep -q "turquoise"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

