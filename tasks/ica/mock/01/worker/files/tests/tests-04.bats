#!/usr/bin/env bats
# ICA Mock Exam - Task 06: Configure AuthorizationPolicy for Specific Paths
# Validates AuthorizationPolicy for path-based access control

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="blue"
POLICY_NAME="sun-and-moon"
SERVICE="echo-version-v1"



@test "4.1 AuthorizationPolicy exists in blue namespace" {
  echo '1' >> /var/work/tests/result/all
  kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 AuthorizationPolicy name is 'sun-and-moon'" {
  echo '1' >> /var/work/tests/result/all
  name=$(kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.name}')
  if [[ "$name" == "sun-and-moon" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$name" == "sun-and-moon" ]
}

@test "4.3 AuthorizationPolicy action is ALLOW" {
  echo '1' >> /var/work/tests/result/all
  action=$(kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.action}')
  if [[ "$action" == "ALLOW" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$action" == "ALLOW" ]
}

@test "4.4 AuthorizationPolicy paths include /sun and /moon" {
  echo '1' >> /var/work/tests/result/all
  paths=$(kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.rules[*].to[*].operation.paths[*]}')
  echo "$paths" | grep -q "/sun" && echo "$paths" | grep -q "/moon"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.5 Access to /sun is allowed (200)" {
  echo '0.5' >> /var/work/tests/result/all
  http_code=$(kubectl exec sleep-blue -n $NAMESPACE --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE/sun 2>/dev/null | tr -d '\r\n')
  result=1
  if [[ "$http_code" == "200" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "4.6 Access to /moon is allowed (200)" {
  echo '0.5' >> /var/work/tests/result/all
  http_code=$(kubectl exec sleep-blue -n $NAMESPACE --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE/moon 2>/dev/null | tr -d '\r\n')
  result=1
  if [[ "$http_code" == "200" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "4.7 Access to /pluto is denied (403)" {
  echo '0.5' >> /var/work/tests/result/all
  http_code=$(kubectl exec sleep-blue -n $NAMESPACE --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE/pluto 2>/dev/null | tr -d '\r\n')
  result=1
  if [[ "$http_code" == "403" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

