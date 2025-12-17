#!/usr/bin/env bats
# ICA Mock Exam - Task 27: Install Istio with minimal profile
# Validates minimal profile installation with custom configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 27: Install Istio with minimal profile (2 points)

@test "27.1 istiod deployment exists with revision 1-26-3" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get deployment istiod-1-26-3 -n istio-system --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "27.2 Egress gateway deployment exists" {
  echo '0.5' >> /var/work/tests/result/all
  # Check for egress gateway deployment (could be istio-egressgateway or istio-egress-gateway)
  kubectl get deployment -n istio-system --context $CONTEXT -o name | grep -q "egress"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "27.3 Pilot resources - CPU request is 100m" {
  echo '0.5' >> /var/work/tests/result/all
  cpu_request=$(kubectl get deployment istiod-1-26-3 -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
  result=1
  if [[ "$cpu_request" == "100m" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "27.4 Pilot resources - Memory request is 200Mi" {
  echo '0.5' >> /var/work/tests/result/all
  mem_request=$(kubectl get deployment istiod-1-26-3 -n istio-system --context $CONTEXT -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
  result=1
  if [[ "$mem_request" == "200Mi" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 2 points for Task 27
