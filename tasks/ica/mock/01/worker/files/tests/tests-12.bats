#!/usr/bin/env bats
# ICA Mock Exam - Task 22: Istio Canary Upgrade
# Validates canary upgrade with revision and tag

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="amber"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 22: Istio Canary Upgrade (3 points)

@test "22.1 New control plane with revision 1-26-3 exists" {
  echo '2.29' >> /var/work/tests/result/all
  kubectl get deployment istiod-1-26-3 -n istio-system --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1.0' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "22.2 Revision 1-26-3 is tagged as latest" {
  echo '1.15' >> /var/work/tests/result/all
  # Check if latest tag webhook exists
  webhook_exists=$(kubectl get mutatingwebhookconfigurations --context $CONTEXT 2>/dev/null | grep -c "istio-revision-tag-latest")
  result=1
  if [[ "$webhook_exists" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "22.3 Namespace amber uses revision label" {
  echo '1.78' >> /var/work/tests/result/all
  # Check namespace has istio.io/rev label
  rev_label=$(kubectl get namespace $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
  result=1
  if [[ "$rev_label" == "latest" ]] || [[ "$rev_label" == "1-26-3" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "22.4 Deployment sleep-amber exists in amber namespace" {
  echo '0.64' >> /var/work/tests/result/all
  kubectl get deployment sleep-amber -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "22.5 Pods in sleep-amber have revision annotation" {
  echo '1.15' >> /var/work/tests/result/all
  # Check if sleep-amber pods have istio.io/rev annotation
  pod_count=$(kubectl get pods -n $NAMESPACE --context $CONTEXT -l app=sleep-amber --no-headers 2>/dev/null | wc -l)
  if [[ "$pod_count" -gt "0" ]]; then
    rev_annotation=$(kubectl get pods -n $NAMESPACE --context $CONTEXT -l app=sleep-amber -o jsonpath='{.items[0].metadata.annotations.istio\.io/rev}' 2>/dev/null)
    result=1
    if [[ "$rev_annotation" == "1-26-3" ]]; then
      echo '0.5' >> /var/work/tests/result/ok
      result=0
    fi
    [ "$result" == "0" ]
  else
    [ "1" == "0" ]
  fi
}

# Total: 7 points for Task 22
