#!/usr/bin/env bats
# ICA Mock Exam - Task 10: Fault Injection - HTTP Abort
# Validates VirtualService fault injection with HTTP abort

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="purple"
SERVICE="purple-echo"


@test "6.1 VirtualService exists in purple namespace" {
  echo '1' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "purple\|echo"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.2 VirtualService has fault abort configured" {
  echo '1' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o yaml | grep -q "abort"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.3 Abort percentage is 100%" {
  echo '1' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  percentage=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].fault.abort.percentage.value}')
  if [[ "$percentage" == "100" ]] || [[ "$percentage" == "100.0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [[ "$percentage" == "100" ]] || [[ "$percentage" == "100.0" ]]
}

@test "6.4 HTTP status is 503" {
  echo '1' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  status=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[*].fault.abort.httpStatus}')
  if [[ "$status" == "503" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$status" == "503" ]
}

@test "6.5 All requests return 503 Service Unavailable" {
  echo '1' >> /var/work/tests/result/all
  http_code=$(kubectl exec -n red sleep-red --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://$SERVICE.$NAMESPACE.svc.cluster.local/mars)
  if [[ "$http_code" == "503" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$http_code" == "503" ]
}

