#!/usr/bin/env bats
# ICA Mock Exam - Task 15: Create ServiceEntry for External Service
# Validates ServiceEntry for googleapis.com with HTTP and HTTPS

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="bronze"

@test "0 Init" {
  # Removed truncation - check_result clears files
  # Removed truncation - check_result clears files
  [ "$?" -eq 0 ]
}

# Task 15: Create ServiceEntry for External Service (3 points)

@test "15.1 ServiceEntry exists in bronze namespace" {
  echo '0.96' >> /var/work/tests/result/all
  kubectl get serviceentry -n $NAMESPACE --context $CONTEXT | grep -q "bronze"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.2 ServiceEntry hosts includes echo.free.beeceptor.com" {
  echo '1.5' >> /var/work/tests/result/all
  se_name=$(kubectl get serviceentry -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  hosts=$(kubectl get serviceentry $se_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.hosts[*]}')
  if echo "$hosts" | grep -q "echo.free.beeceptor.com"; then
    echo '0.75' >> /var/work/tests/result/ok
  fi
  echo "$hosts" | grep -q "echo.free.beeceptor.com"
}

@test "15.3 HTTP port (80) is configured" {
  echo '0.96' >> /var/work/tests/result/all
  se_name=$(kubectl get serviceentry -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  ports=$(kubectl get serviceentry $se_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.ports[*].number}')
  if echo "$ports" | grep -q "80"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$ports" | grep -q "80"
}

@test "15.4 HTTPS port (443) is configured" {
  echo '0.96' >> /var/work/tests/result/all
  se_name=$(kubectl get serviceentry -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  ports=$(kubectl get serviceentry $se_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.ports[*].number}')
  if echo "$ports" | grep -q "443"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$ports" | grep -q "443"
}

@test "15.5 Resolution is set to DNS" {
  echo '0.54' >> /var/work/tests/result/all
  se_name=$(kubectl get serviceentry -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  resolution=$(kubectl get serviceentry $se_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.resolution}')
  if [[ "$resolution" == "DNS" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [ "$resolution" == "DNS" ]
}

@test "15.6 HTTP protocol is configured" {
  echo '0.54' >> /var/work/tests/result/all
  se_name=$(kubectl get serviceentry -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  protocols=$(kubectl get serviceentry $se_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.ports[*].protocol}')
  if echo "$protocols" | grep -q "HTTP"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$protocols" | grep -q "HTTP"
}

@test "15.7 Can access echo.free.beeceptor.com via HTTP from bronze namespace" {
  echo '0.54' >> /var/work/tests/result/all
  # Test HTTP access (expect redirect or response)
  run kubectl exec sleep-bronze -n $NAMESPACE --context $CONTEXT -- curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://echo.free.beeceptor.com
  http_code="$output"

  # Accept 200, 301, 302, 307, 308 (success or redirect)
  if [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]] || [[ "$http_code" == "307" ]] || [[ "$http_code" == "308" ]]; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]] || [[ "$http_code" == "307" ]] || [[ "$http_code" == "308" ]]
}

# Total: 6 points for Task
