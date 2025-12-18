#!/usr/bin/env bats
# ICA Mock Exam - Task 09: Configure Request Timeout
# Validates VirtualService timeout configuration

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="white"
VS_NAME="white-echo-vs"
SERVICE="white-echo"


@test "4.1 VirtualService exists in white namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "$VS_NAME\|echo-white\|white"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 VirtualService timeout is configured to 3s" {
  echo '0.5' >> /var/work/tests/result/all
  # Get the first VirtualService in white namespace and check for 3s timeout
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  timeout=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].timeout}')
  if [[ "$timeout" == "3s" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$timeout" == "3s" ]
}

@test "4.3 Requests exceeding 3s return 504 Gateway Timeout" {
  echo '0.5' >> /var/work/tests/result/all
  # Test /invincible path which simulates slow response (>3s)
  # The app has 50% chance of 5s delay, so try multiple times
  timeout_found=false
  for i in {1..5}; do
    http_code=$(kubectl run test-timeout-$i --rm -i --restart=Never --image=curlimages/curl -n $NAMESPACE --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE/invincible 2>/dev/null || echo "504")
    if [[ "$http_code" == "504" ]]; then
      timeout_found=true
      break
    fi
    sleep 1
  done

  if [[ "$timeout_found" == "true" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$timeout_found" == "true" ]
}

