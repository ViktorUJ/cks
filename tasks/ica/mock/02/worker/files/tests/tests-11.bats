#!/usr/bin/env bats
# ICA Mock Exam - Task 23: Gateway routing for specific path
# Validates VirtualService routing for /moon path

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="sapphire"


@test "11.1 Gateway demo-gateway exists in istio-system" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get gateway demo-gateway -n istio-system --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "11.2 VirtualService exists in sapphire namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o name | grep -q "virtualservice"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "11.3 VirtualService routes to echo service" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if VirtualService has echo in destination host
  vs_host=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.http[*].route[*].destination.host}')
  result=1
  if echo "$vs_host" | grep -q "echo"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "11.4 VirtualService has /moon path configured" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if /moon path is configured
  vs_path=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.http[*].match[*].uri.prefix}')
  result=1
  if echo "$vs_path" | grep -q "/moon"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "11.5 VirtualService references demo-gateway" {
  echo '0.5' >> /var/work/tests/result/all
  # Check if gateway reference includes demo-gateway
  vs_gateway=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.gateways[*]}')
  result=1
  if echo "$vs_gateway" | grep -q "demo-gateway"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

