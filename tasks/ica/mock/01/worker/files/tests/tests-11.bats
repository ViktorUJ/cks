#!/usr/bin/env bats
# ICA Mock Exam - Task 19: Manual Sidecar Injection
# Validates manual sidecar injection using istioctl kube-inject

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="indigo"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 19: Manual Sidecar Injection (2 points)

@test "19.1 Pod sleep-indigo exists in indigo namespace" {
  echo '0.54' >> /var/work/tests/result/all
  kubectl get pod sleep-indigo -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "19.2 Pod has 2 containers (app + istio-proxy)" {
  echo '1.95' >> /var/work/tests/result/all
  container_count=$(kubectl get pod sleep-indigo -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | wc -w)
  if [[ "$container_count" == "2" ]]; then
    echo '1.0' >> /var/work/tests/result/ok
  fi
  [ "$container_count" == "2" ]
}

@test "19.3 istio-proxy container exists" {
  echo '0.97' >> /var/work/tests/result/all
  proxy_exists=$(kubectl get pod sleep-indigo -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | grep -c "istio-proxy")
  if [[ "$proxy_exists" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$proxy_exists" -ge "1" ]
}

@test "19.4 Namespace does NOT have auto-injection label" {
  echo '0.54' >> /var/work/tests/result/all
  # Check that namespace does NOT have istio-injection=enabled label
  injection_label=$(kubectl get namespace $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.labels.istio-injection}')

  # Test passes if label is empty or not "enabled"
  if [[ -z "$injection_label" ]] || [[ "$injection_label" != "enabled" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi

  [[ -z "$injection_label" ]] || [[ "$injection_label" != "enabled" ]]
}

# Total: 4 points for Task
