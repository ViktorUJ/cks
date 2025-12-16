#!/usr/bin/env bats
# ICA Mock Exam - Task 01: Istio Installation Validation
# Validates Istio is installed with correct configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster1-admin@cluster1"


# Task 01: Istio Installation Validation (10 points)

@test "1.1 Istio - istio-system namespace exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get namespace istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.2 Istio - istiod deployment exists" {
  echo '1 >> /var/work/tests/result/all
  kubectl get deployment istiod -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.3 Istio - istiod replica count is 1" {
  echo '0.5' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.4 Istio - istiod CPU request is 100m" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
  if [[ "$result" == "100m" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "100m" ]
}

@test "1.5 Istio - istiod memory request is 256Mi or 256Mi" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
  if [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]
}

@test "1.6 Istio - istiod CPU limit is 100m" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}')
  if [[ "$result" == "100m" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "100m" ]
}

@test "1.7 Istio - istiod memory limit is 256Mi or 256Mi" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
  if [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]
}

@test "1.8 Istio - ingress gateway istio-demo-ingress exists" {
  echo '1' >> /var/work/tests/result/all
  kubectl get deployment istio-demo-ingress -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.9 Istio - egress gateway istio-demo-egress exists" {
  echo '1' >> /var/work/tests/result/all
  kubectl get deployment istio-demo-egress -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.10 Istio - istiod pod is running" {
  echo '1' >> /var/work/tests/result/all
  kubectl get pods -n istio-system -l app=istiod --context $CONTEXT | grep Running
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


