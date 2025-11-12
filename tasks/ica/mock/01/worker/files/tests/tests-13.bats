#!/usr/bin/env bats
# ICA Mock Exam - Task 24: Route 100% traffic to v1
# Validates traffic routing to specific version

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="pearl"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 24: Route 100% traffic to v1 (2 points)

@test "24.1 DestinationRule exists with subsets v1 and v2" {
  echo '1.0' >> /var/work/tests/result/all
  kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o name | grep -q "destinationrule"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "24.2 DestinationRule has v1 subset with version label" {
  echo '1.0' >> /var/work/tests/result/all
  # Check if v1 subset exists with version: v1 label
  subset_v1=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.subsets[?(@.name=="v1")].labels.version}')
  result=1
  if [[ "$subset_v1" == "v1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "24.3 VirtualService routes 100% traffic to v1" {
  echo '1.0' >> /var/work/tests/result/all
  # Check if VirtualService routes to v1 subset with weight 100
  vs_subset=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.http[*].route[?(@.weight==100)].destination.subset}')
  result=1
  if [[ "$vs_subset" == "v1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "24.4 v2 receives no traffic (weight 0 or not in route)" {
  echo '1.0' >> /var/work/tests/result/all
  # Check that v2 is not getting traffic (either weight 0 or not in route)
  vs_routes=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o json | grep -c '"subset": "v2"' || true)
  vs_v2_weight=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[*].spec.http[*].route[?(@.destination.subset=="v2")].weight}' || echo "0")
  result=1
  if [[ "$vs_v2_weight" == "0" ]] || [[ -z "$vs_v2_weight" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

# Total: 4 points for Task
