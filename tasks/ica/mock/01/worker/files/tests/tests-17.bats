#!/usr/bin/env bats
# ICA Mock Exam - Task 32: Sidecar with workload selector in coral
# Validates Sidecar resource with workload selector

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="coral"


@test "17.1 Sidecar named default exists in coral namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get sidecar default -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "17.2 Sidecar has workloadSelector for app=space" {
  echo '0.5' >> /var/work/tests/result/all
  selector=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.workloadSelector.labels.app}')
  result=1
  if [[ "$selector" == "space" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "17.3 Sidecar egress includes lime namespace" {
  echo '0.5' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "lime"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "17.4 Sidecar egress includes turquoise namespace" {
  echo '0.5' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "turquoise"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "17.5 Sidecar egress includes istio-system namespace" {
  echo '0.5' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "istio-system"; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

