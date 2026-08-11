#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-114"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-114 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Artifact records the symptom: Metrics API not available" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/kubectl_top_before.txt
  if [[ -s "$f" ]] && grep -qi 'Metrics API not available' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention Metrics API not available"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. metrics-server addon installed and kubectl top works" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/3/kubectl_top_after.txt
  result=1
  for i in $(seq 1 24); do
    status=$(aws eks describe-addon --cluster-name "$cluster" --addon-name metrics-server \
      --query 'addon.addonStatus' --output text 2>/dev/null)
    top=$(kubectl top nodes 2>/dev/null)
    if [[ "$status" == "ACTIVE" ]] && [[ -n "$top" ]] && [[ "$top" != *"not available"* ]] && \
       [[ -s "$f" ]] && [[ "$(cat "$f")" != *"not available"* ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "metrics-server addon status=$status kubectl top nodes=$top file=$f (waited up to 4 min)"
  fi
  [ "$result" == "0" ]
}

@test "4. amazon-cloudwatch-observability addon installed, CloudWatch agent pods Running" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/4/cloudwatch_agent_pods.txt
  result=1
  for i in $(seq 1 30); do
    status=$(aws eks describe-addon --cluster-name "$cluster" \
      --addon-name amazon-cloudwatch-observability --query 'addon.addonStatus' \
      --output text 2>/dev/null)
    running=$(kubectl get pods -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent \
      -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ "$status" == "ACTIVE" ]] && [[ "$running" == *Running* ]] && [[ -s "$f" ]] && \
       grep -qi 'cloudwatch-agent' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "addon status=$status cloudwatch-agent phase=$running file=$f"
  fi
  [ "$result" == "0" ]
}

@test "5. kube-prometheus-stack scrapes ping-app via ServiceMonitor" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/prom_query.txt
  result=1
  for i in $(seq 1 24); do
    prom_ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
    fail_count=$(echo "$prom_ready" | grep -o 'false' | wc -l)
    image=$(kubectl get deploy ping-app -n "$NS" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    ready=$(kubectl get deploy ping-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    sm=$(kubectl get servicemonitor ping-app -n "$NS" \
      -o jsonpath='{.spec.endpoints[0].port}' 2>/dev/null)
    if [[ -n "$prom_ready" ]] && [[ "$fail_count" -eq 0 ]] && [[ "$image" == *ping_pong* ]] && \
       [[ "$ready" == "1" ]] && [[ "$sm" == "metrics" ]] && [[ -s "$f" ]] && \
       grep -q 'requests_total' "$f" && grep -q '"metric"' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "prom_ready=$prom_ready image=$image ready=$ready sm_port=$sm file=$f"
  fi
  [ "$result" == "0" ]
}

@test "6. AMP workspace exists and its endpoint is recorded" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/amp_endpoint.txt
  wid=$(aws amp list-workspaces --alias eks-task114-amp \
    --query 'workspaces[0].workspaceId' --output text 2>/dev/null)
  result=1
  if [[ -n "$wid" ]] && [[ "$wid" != "None" ]] && [[ -s "$f" ]] && \
     grep -q 'aps-workspaces' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "amp workspace id=$wid file=$f"
  fi
  [ "$result" == "0" ]
}
