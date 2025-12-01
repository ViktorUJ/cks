#!/usr/bin/env bats
# ICA Mock Exam - Task 04: Configure Sidecar to Allow Egress Connections
# Validates Sidecar configuration for egress traffic control

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="black"
SIDECAR_NAME="default"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 04: Configure Sidecar to Allow Egress Connections (3 points)

@test "4.1 Sidecar resource exists in black namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get sidecar $SIDECAR_NAME -n $NAMESPACE --context $CONTEXT
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 Sidecar egress includes current namespace (./*)" {
  echo '0.5' >> /var/work/tests/result/all
  hosts=$(kubectl get sidecar $SIDECAR_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  echo "$hosts" | grep -q '\./\*'
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.3 Sidecar egress includes green namespace (green/*)" {
  echo '0.7' >> /var/work/tests/result/all
  hosts=$(kubectl get sidecar $SIDECAR_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  echo "$hosts" | grep -q 'green/\*'
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.7' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.4 Sidecar egress includes istio-system namespace (istio-system/*)" {
  echo '0.7' >> /var/work/tests/result/all
  hosts=$(kubectl get sidecar $SIDECAR_NAME -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.egress[*].hosts[*]}')
  echo "$hosts" | grep -q 'istio-system/\*'
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.7' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.5 Pods can communicate within black namespace" {
  echo '0.3' >> /var/work/tests/result/all
  # Test connectivity from test-client to black-echo-service
  kubectl exec sleep-black -n $NAMESPACE --context $CONTEXT -- curl -s --max-time 5 http://black-echo-service:8080 > /dev/null
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.3' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.6 Pods can reach services in green namespace" {
  echo '0.3' >> /var/work/tests/result/all
  # Test connectivity from black namespace to green namespace
  kubectl exec sleep-black -n $NAMESPACE --context $CONTEXT -- curl -s --max-time 5 http://green-echo-service.green.svc.cluster.local:8080 > /dev/null
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.3' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# Total: 3 points for Task 04
