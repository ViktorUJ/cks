#!/usr/bin/env bats
# ICA Mock Exam - Task 21: Egress Gateway
# Validates egress gateway configuration for external traffic

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="emerald"

@test "10.1 Egress Gateway exists in emerald namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get gateway echo-egress -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "10.2 Gateway selector is app=istio-egressgateway" {
  echo '0.5' >> /var/work/tests/result/all
  selector=$(kubectl get gateway echo-egress -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.selector.app}')
  result=1
  if [[ "$selector" == "istio-egressgateway" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "10.3 Gateway has echo.free.beeceptor.com in hosts" {
  echo '0.5' >> /var/work/tests/result/all
  hosts=$(kubectl get gateway echo-egress -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.servers[*].hosts[*]}' | grep -c "echo.free.beeceptor.com")
  result=1
  if [[ "$hosts" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "10.4 VirtualService echo-egress-vs exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice echo-egress-vs -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "10.5 VirtualService has echo.free.beeceptor.com in hosts" {
  echo '0.5' >> /var/work/tests/result/all
  hosts=$(kubectl get virtualservice echo-egress-vs -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.hosts[*]}' | grep -c "echo.free.beeceptor.com")
  result=1
  if [[ "$hosts" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "10.6 VirtualService has mesh and gateway in gateways" {
  echo '0.5' >> /var/work/tests/result/all
  gateways=$(kubectl get virtualservice echo-egress-vs -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.gateways[*]}')
  mesh_exists=$(echo "$gateways" | grep -c "mesh")
  gateway_exists=$(echo "$gateways" | grep -c "echo-egress")
  result=1
  if [[ "$mesh_exists" -ge "1" ]] && [[ "$gateway_exists" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "10.7 DestinationRule egressgateway-for-echo exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get destinationrule egressgateway-for-echo -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "10.8 DestinationRule points to egress gateway" {
  echo '0.5' >> /var/work/tests/result/all
  host=$(kubectl get destinationrule egressgateway-for-echo -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.host}')
  result=1
  if echo "$host" | grep -q "egress"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "10.9 Can access echo.free.beeceptor.com from sleep-emerald pod" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl exec sleep-emerald -n $NAMESPACE --context $CONTEXT -- curl -I --max-time 10 http://echo.free.beeceptor.com > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

