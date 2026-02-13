#!/usr/bin/env bats
# ICA Mock Exam - Task 33: Port-level load balancing
# Validates DestinationRule with port-level load balancing override

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="maroon"


@test "16.1 DestinationRule example-dr exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get destinationrule example-dr -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.2 Global load balancer is ROUND_ROBIN" {
  echo '0.5' >> /var/work/tests/result/all
  global_lb=$(kubectl get destinationrule example-dr -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.loadBalancer.simple}')
  result=1
  if [[ "$global_lb" == "ROUND_ROBIN" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "16.3 Port 443 override exists" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if port level settings for 443 exist
  port_443=$(kubectl get destinationrule example-dr -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.portLevelSettings[?(@.port.number==443)].port.number}')
  result=1
  if [[ "$port_443" == "443" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "16.4 Port 443 uses LEAST_CONN load balancer" {
  echo '0.5' >> /var/work/tests/result/all
  port_443_lb=$(kubectl get destinationrule example-dr -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.portLevelSettings[?(@.port.number==443)].loadBalancer.simple}')
  result=1
  if [[ "$port_443_lb" == "LEAST_CONN" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

