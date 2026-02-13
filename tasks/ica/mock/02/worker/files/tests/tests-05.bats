#!/usr/bin/env bats
# ICA Mock Exam - Task 11: Fault Injection - Fixed Delay
# Validates VirtualService fault injection with fixed delay

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="pink"
SERVICE="pink-echo"


@test "5.1 VirtualService exists in pink namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "pink\|echo"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.2 VirtualService has fault delay configured" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o yaml | grep -q "delay"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.3 Delay percentage is 100%" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  percentage=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].fault.delay.percentage.value}')
  if [[ "$percentage" == "100" ]] || [[ "$percentage" == "100.0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$percentage" == "100" ]] || [[ "$percentage" == "100.0" ]]
}

@test "5.4 Fixed delay is 3s" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  delay=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].fault.delay.fixedDelay}')
  if [[ "$delay" == "3s" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$delay" == "3s" ]
}

@test "5.5 Requests are delayed by approximately 3 seconds" {
  echo '0.5' >> /var/work/tests/result/all
  # Measure request time
  start=$(date +%s)
  kubectl exec -n pink sleep-pink --context $CONTEXT -- curl -s -o /dev/null http://$SERVICE/mars
  end=$(date +%s)
  duration=$((end - start))
  # Check if duration is between 2 and 5 seconds (allowing some margin)
  if [[ "$duration" -ge 2 ]] && [[ "$duration" -le 5 ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$duration" -ge 2 ]] && [[ "$duration" -le 5 ]]
}

# Total: 3 points for Task 11
