#!/usr/bin/env bats
# ICA Mock Exam - Task 13: Configure Traffic Mirroring
# Validates VirtualService with traffic mirroring to v2

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="platinum"



@test "8.1 VirtualService exists in platinum namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "platinum"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.2 DestinationRule exists with v1 and v2 subsets" {
  echo '0.5' >> /var/work/tests/result/all
  dr_name=$(kubectl get destinationrule -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  subsets=$(kubectl get destinationrule $dr_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.subsets[*].name}')
  if echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$subsets" | grep -q "v1" && echo "$subsets" | grep -q "v2"
}

@test "8.3 Primary route goes to v1 subset with 100% weight" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  subset=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].route[0].destination.subset}')
  weight=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].route[0].weight}')
  if [[ "$subset" == "v1" ]] && [[ "$weight" == "100" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$subset" == "v1" ]] && [[ "$weight" == "100" ]]
}

@test "8.4 Mirror configuration exists" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o yaml | grep -q "mirror"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8.5 Mirror target is v2 subset" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  mirror_subset=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].mirror.subset}')
  if [[ "$mirror_subset" == "v2" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$mirror_subset" == "v2" ]
}

@test "8.6 Mirror percentage is 50%" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  mirror_pct=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].mirrorPercentage.value}')
  if [[ "$mirror_pct" == "50" ]] || [[ "$mirror_pct" == "50.0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [[ "$mirror_pct" == "50" ]] || [[ "$mirror_pct" == "50.0" ]]
}

@test "8.7 v1 pod receives requests" {
  echo '0.5' >> /var/work/tests/result/all
  # Send request from red namespace
  http_code=$(kubectl exec sleep-red -n red --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" http://platinum-echo.platinum.svc.cluster.local/mars)
  if [[ "$http_code" == "200" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$http_code" == "200" ]
}

@test "8.8 Mirror ratio approximately 50% (v2 gets ~50% of v1 traffic)" {
  echo '1' >> /var/work/tests/result/all

  # Generate test traffic (20 requests)
  for i in {1..20}; do
    kubectl exec sleep-red -n red --context $CONTEXT -- curl -s http://platinum-echo.platinum.svc.cluster.local/mars > /dev/null 2>&1
  done

  # Wait for logs to be written
  sleep 2

  # Count requests in v1 (primary - gets all 100%)
  v1_count=$(kubectl logs -n $NAMESPACE --context $CONTEXT pods/platinum-echo-v1 2>/dev/null | grep -c "GET" || echo 0)

  # Count requests in v2 (mirror - should get ~50%)
  v2_count=$(kubectl logs -n $NAMESPACE --context $CONTEXT pods/platinum-echo-v2 2>/dev/null | grep -c "GET" || echo 0)

  # Calculate expected range: v2 should have 30-70% of v1's count (allowing variance)
  # With 50% mirroring and 20 requests: v1=20, v2=~10 (range 6-14 acceptable)
  if [[ "$v1_count" -gt 0 ]]; then
    # v2 should be between 30% and 70% of v1 count
    min_expected=$((v1_count * 30 / 100))
    max_expected=$((v1_count * 70 / 100))

    if [[ "$v2_count" -ge "$min_expected" ]] && [[ "$v2_count" -le "$max_expected" ]]; then
      echo '1' >> /var/work/tests/result/ok
    fi
    [[ "$v2_count" -ge "$min_expected" ]] && [[ "$v2_count" -le "$max_expected" ]]
  else
    # If v1 has no traffic, fail
    [ "$v1_count" -gt 0 ]
  fi
}

