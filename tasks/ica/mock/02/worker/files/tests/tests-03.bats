#!/usr/bin/env bats
# ICA Mock Exam - Task 07: Create deny-all AuthorizationPolicy
# Validates AuthorizationPolicy that denies all traffic

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="violet"
POLICY_NAME="deny-all"


@test "3.1 AuthorizationPolicy exists in violet namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.2 AuthorizationPolicy name is 'deny-all'" {
  echo '0.5' >> /var/work/tests/result/all
  name=$(kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.name}')
  if [[ "$name" == "deny-all" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$name" == "deny-all" ]
}

@test "3.3 AuthorizationPolicy is in violet namespace" {
  echo '0.5' >> /var/work/tests/result/all
  ns=$(kubectl get authorizationpolicy $POLICY_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.namespace}')
  if [[ "$ns" == "violet" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$ns" == "violet" ]
}

@test "3.4 All traffic to violet services is denied (RBAC denied)" {
  echo '0.5' >> /var/work/tests/result/all
  # Try to access violet-echo from black namespace - should be denied with RBAC message
  run kubectl exec -n black sleep-black --context $CONTEXT -- curl -s --max-time 5 http://violet-echo.violet.svc.cluster.local:8080
  # Should get RBAC: access denied message (check output contains this string)
  if [[ "$output" == *"RBAC: access denied"* ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$output" == *"RBAC: access denied"* ]]
}

