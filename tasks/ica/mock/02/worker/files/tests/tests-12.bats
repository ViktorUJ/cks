#!/usr/bin/env bats
# ICA Mock Exam - Task 25: ServiceEntry with STATIC resolution
# Validates ServiceEntry with STATIC resolution mode

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="turquoise"


@test "12.1 ServiceEntry nginx-test exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get serviceentry nginx-test -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "12.2 ServiceEntry has nginx-test.ica host" {
  echo '0.5' >> /var/work/tests/result/all
  se_host=$(kubectl get serviceentry nginx-test -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.hosts[*]}')
  result=1
  if echo "$se_host" | grep -q "nginx-test.ica"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "12.3 ServiceEntry resolution is STATIC and has addresses 240.240.0.100" {
  echo '0.5' >> /var/work/tests/result/all
  se_resolution=$(kubectl get serviceentry nginx-test -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.resolution}')
  se_addresses=$(kubectl get serviceentry nginx-test -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.addresses[*]}')
  result=1
  if [[ "$se_resolution" == "STATIC" ]] && echo "$se_addresses" | grep -q "240.240.0.100"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "12.4 ServiceEntry has port 8082" {
  echo '0.5' >> /var/work/tests/result/all
  se_port=$(kubectl get serviceentry nginx-test -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.ports[0].number}')
  result=1
  if [[ "$se_port" == "8082" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "12.5 VirtualService nginx-test-vs exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice nginx-test-vs -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

