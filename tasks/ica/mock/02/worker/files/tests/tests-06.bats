#!/usr/bin/env bats
# ICA Mock Exam - Task 14: Configure Traffic Splitting (50/50)
# Validates VirtualService with 50/50 traffic split between v1 and v2

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="gold"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 14: Configure Traffic Splitting 50/50 (3 points)

@test "14.1 VirtualService exists in gold namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "gold"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "14.2 DestinationRule exists with v1 and v2 subsets" {
  echo '0.5' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  subsets=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.subsets[*].name}')
  if echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"
}

@test "14.3 VirtualService has two route destinations" {
  echo '0.25' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  route_count=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].route[*]}' | wc -w)
  if [[ "$route_count" -ge 2 ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$route_count" -ge 2 ]
}

@test "14.4 v1 subset has 50% weight" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')

  # Find v1 weight
  v1_weight=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o json | \
    jq -r '.spec.http[0].route[] | select(.destination.subset == "v1") | .weight')

  if [[ "$v1_weight" == "50" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$v1_weight" == "50" ]
}

@test "14.5 v2 subset has 50% weight" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')

  # Find v2 weight
  v2_weight=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o json | \
    jq -r '.spec.http[0].route[] | select(.destination.subset == "v2") | .weight')

  if [[ "$v2_weight" == "50" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$v2_weight" == "50" ]
}

@test "14.6 Service is accessible and returns 200" {
  echo '0.25' >> /var/work/tests/result/all
  http_code=$(kubectl exec sleep-gold -n gold --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://gold-echo/mars)
  if [[ "$http_code" == "200" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$http_code" == "200" ]
}

# Total: 3 points for Task 14
