#!/usr/bin/env bats
# ICA Mock Exam - Task 03: Inject sidecar into a single pod
# Validates sidecar injection for specific pod only

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="orange"
SIDECAR_POD="sidecar-pod"
NO_SIDECAR_POD="no-sidecar-pod"

# Task 03: Inject sidecar into a single pod (3 points)

@test "3.1 Orange namespace does NOT have sidecar injection label" {
  echo '0.96' >> /var/work/tests/result/all
  result=$(kubectl get namespace $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.labels.istio-injection}')
  if [[ "$result" != "enabled" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" != "enabled" ]
}

@test "3.2 Pod sidecar-pod exists in orange namespace" {
  echo '0.54' >> /var/work/tests/result/all
  kubectl get pod $SIDECAR_POD -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.3 Pod sidecar-pod has istio-proxy container" {
  echo '1.93' >> /var/work/tests/result/all
  containers=$(kubectl get pod $SIDECAR_POD -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}')
  echo "$containers" | grep -q istio-proxy
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1.0' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.4 Pod sidecar-pod has exactly 2 containers" {
  echo '0.54' >> /var/work/tests/result/all
  result=$(kubectl get pod $SIDECAR_POD -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | wc -w)
  if [[ "$result" == "2" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

@test "3.5 Pod no-sidecar-pod exists" {
  echo '0.54' >> /var/work/tests/result/all
  kubectl get pod $NO_SIDECAR_POD -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.6 Pod no-sidecar-pod does NOT have istio-proxy container" {
  echo '0.96' >> /var/work/tests/result/all
  containers=$(kubectl get pod $NO_SIDECAR_POD -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}')
  if echo "$containers" | grep -q istio-proxy; then
    result=0
  else
    result=1
  fi
  if [[ "$result" == "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "3.7 Pod no-sidecar-pod has exactly 1 container" {
  echo '0.54' >> /var/work/tests/result/all
  result=$(kubectl get pod $NO_SIDECAR_POD -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | wc -w)
  if [[ "$result" == "1" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

# Total: 6 points for Task
