#!/usr/bin/env bats
# ICA Mock Exam - Task 05: Configure mTLS
# Validates PeerAuthentication configuration for mTLS

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="red"
PA_NAME="default"


@test "3.1 PeerAuthentication resource exists in red namespace" {
  echo '1' >> /var/work/tests/result/all
  kubectl get peerauthentication $PA_NAME -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1.0' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.2 PeerAuthentication name is 'default'" {
  echo '1' >> /var/work/tests/result/all
  kubectl get peerauthentication $PA_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.name}' | grep -q "^default$"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.3 mTLS mode is STRICT" {
  echo '1' >> /var/work/tests/result/all
  mode=$(kubectl get peerauthentication $PA_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.mtls.mode}')
  if [[ "$mode" == "STRICT" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$mode" == "STRICT" ]
}

@test "3.4 PeerAuthentication is in red namespace" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get peerauthentication $PA_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.namespace}')
  if [[ "$ns" == "red" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$ns" == "red" ]
}

@test "3.5 mTLS blocks non-mTLS traffic from black namespace" {
  echo '1' >> /var/work/tests/result/all
  # Test that connection from black namespace (non-mTLS) to red namespace (STRICT mTLS) fails
  # This proves mTLS is enforced
  run kubectl exec -n black sleep-black --context $CONTEXT -- curl -s --max-time 5 http://echo-red.red.svc.cluster.local:8080
  # Connection should fail (non-zero exit code) because mTLS is enforced
  if [[ "$status" != "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" != "0" ]
}

