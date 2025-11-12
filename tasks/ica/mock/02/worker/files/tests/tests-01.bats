#!/usr/bin/env bats
# ICA Mock Exam - Task 02: Istio Installation with Helm
# Validates Istio is installed via Helm with correct configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster1-admin@cluster1"

@test "0 Init" {
  # Removed truncation - check_result clears files
  [ "1" -eq "1" ]
}

# Task 02: Istio Installation with Helm (5 points)

@test "2.1 Istio - istio-system namespace exists" {
  echo '0.68' >> /var/work/tests/result/all
  kubectl get namespace istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.2 Istio - Helm chart version is 1.26.3" {
  echo '1.36' >> /var/work/tests/result/all
  helm list -n istio-system --kube-context $CONTEXT | grep "istiod-1.26.3"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.3 Istio - istiod deployment exists" {
  echo '1.36' >> /var/work/tests/result/all
  kubectl get deployment istiod -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.4 Istio - istiod replica count is 1" {
  echo '0.68' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "1" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "2.5 Istio - istiod CPU request is 100m" {
  echo '1.36' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
  if [[ "$result" == "100m" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "100m" ]
}

@test "2.6 Istio - istiod memory request is 256Mi or 256Mi" {
  echo '1.36' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
  if [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]
}

@test "2.7 Istio - istiod CPU limit is 100m" {
  echo '1.36' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}')
  if [[ "$result" == "100m" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "100m" ]
}

@test "2.8 Istio - istiod memory limit is 256Mi or 256Mi" {
  echo '1.36' >> /var/work/tests/result/all
  result=$(kubectl get deployment istiod -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
  if [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$result" == "256Mi" ]] || [[ "$result" == "256Mi" ]]
}

@test "2.9 Istio - ingress gateway istio-demo-ingress exists" {
  echo '2.05' >> /var/work/tests/result/all
  kubectl get deployment istio-demo-ingress -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.10 Istio - egress gateway istio-demo-egress exists" {
  echo '2.05' >> /var/work/tests/result/all
  kubectl get deployment istio-demo-egress -n istio-system --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.11 Istio - istiod pod is running" {
  echo '1.36' >> /var/work/tests/result/all
  kubectl get pods -n istio-system -l app=istiod --context $CONTEXT | grep Running
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# Total: 15 points for Task 02
