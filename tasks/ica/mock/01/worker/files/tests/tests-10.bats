#!/usr/bin/env bats
# ICA Mock Exam - Task 17: Configure Load Balancing
# Validates DestinationRule with ROUND_ROBIN load balancing and subsets

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="cyan"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 17: Configure Load Balancing (2 points)

@test "17.1 DestinationRule exists in cyan namespace" {
  echo '0.77' >> /var/work/tests/result/all
  kubectl get destinationrule -n $NAMESPACE --context $CONTEXT | grep -q "cyan"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "17.2 Load balancer algorithm is ROUND_ROBIN" {
  echo '1.19' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  lb_algo=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.trafficPolicy.loadBalancer.simple}')
  if [[ "$lb_algo" == "ROUND_ROBIN" ]]; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  [ "$lb_algo" == "ROUND_ROBIN" ]
}

@test "17.3 DestinationRule has v1 and v2 subsets" {
  echo '0.77' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  subsets=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.subsets[*].name}')
  if echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"
}

@test "17.4 Subset v1 has correct label selector" {
  echo '0.43' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  v1_label=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o json | jq -r '.spec.subsets[] | select(.name == "v1") | .labels.version')
  if [[ "$v1_label" == "v1" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$v1_label" == "v1" ]
}

@test "17.5 Subset v2 has correct label selector" {
  echo '0.43' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  v2_label=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o json | jq -r '.spec.subsets[] | select(.name == "v2") | .labels.version')
  if [[ "$v2_label" == "v2" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$v2_label" == "v2" ]
}

@test "17.6 Service is accessible and returns 200" {
  echo '0.43' >> /var/work/tests/result/all
  http_code=$(kubectl exec sleep-red -n red --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://cyan-echo.cyan.svc.cluster.local/mars)
  if [[ "$http_code" == "200" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$http_code" == "200" ]
}

# Total: 4 points for Task
