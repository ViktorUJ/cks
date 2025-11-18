#!/usr/bin/env bats
# ICA Mock Exam - Task 32: Sidecar with workload selector in coral
# Validates Sidecar resource with workload selector

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="coral"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 32: Sidecar with workload selector in coral (2 points)

@test "32.1 Sidecar named default exists in coral namespace" {
  echo '0.82' >> /var/work/tests/result/all
  kubectl get sidecar default -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "32.2 Sidecar has workloadSelector for app=space" {
  echo '1.06' >> /var/work/tests/result/all
  selector=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.workloadSelector.labels.app}')
  result=1
  if [[ "$selector" == "space" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "32.3 Sidecar egress includes lime namespace" {
  echo '0.71' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "lime"; then
    echo '0.33' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "32.4 Sidecar egress includes turquoise namespace" {
  echo '0.71' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "turquoise"; then
    echo '0.34' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "32.5 Sidecar egress includes istio-system namespace" {
  echo '0.71' >> /var/work/tests/result/all
  egress_hosts=$(kubectl get sidecar default -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  result=1
  if echo "$egress_hosts" | grep -q "istio-system"; then
    echo '0.33' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 4 points for Task 32
