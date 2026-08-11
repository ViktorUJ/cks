#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-125"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Auto Mode is enabled with general-purpose node pool" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/1/automode.txt
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  enabled=$(aws eks describe-cluster --name "$cluster" \
    --query 'cluster.computeConfig.enabled' --output text 2>/dev/null)
  pools=$(kubectl get nodepools -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  result=1
  if [[ "$enabled" == "True" ]] && [[ "$pools" == *general-purpose* ]] && [[ -s "$f" ]] && \
     grep -q '"enabled": true' "$f" && grep -q 'general-purpose' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "enabled=$enabled pools=$pools file=$f"
  fi
  [ "$result" == "0" ]
}

@test "2. Built-in system NodePool stays disabled" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/twopools.txt
  pools=$(kubectl get nodepools -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  result=1
  if [[ "$pools" != *system* ]] && [[ -s "$f" ]] && grep -q 'system' "$f" && \
     grep -q 'CriticalAddonsOnly' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pools=$pools file=$f"
  fi
  [ "$result" == "0" ]
}

@test "3. Workload on general-purpose and read-only built-in NodePool" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/readonly.txt
  image=$(kubectl get deploy web -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  nodes=$(kubectl get pods -n "$NS" -l app=web -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  on_fargate=0
  for n in $nodes; do
    [[ "$n" == fargate-* ]] && on_fargate=1
  done
  result=1
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && [[ "$on_fargate" == "0" ]] && \
     [[ -s "$f" ]] && grep -qiE 'denied|forbidden|error' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "image=$image ready=$ready on_fargate=$on_fargate file=$f"
  fi
  [ "$result" == "0" ]
}

@test "4. No SSH/SSM access to an Auto Mode node" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/nossh.txt
  if [[ -s "$f" ]] && grep -qiE 'TargetNotConnected|error|not connected' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show a connection failure"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Custom NodePool with explicit limits" {
  echo '1' >> /var/work/tests/result/all
  cpu_limit=$(kubectl get nodepool custom-limited \
    -o jsonpath='{.spec.limits.cpu}' 2>/dev/null)
  nodeclass=$(kubectl get nodepool custom-limited \
    -o jsonpath='{.spec.template.spec.nodeClassRef.name}' 2>/dev/null)
  result=1
  if [[ "$cpu_limit" == "10" ]] && [[ "$nodeclass" == "default" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cpu_limit=$cpu_limit nodeclass=$nodeclass"
  fi
  [ "$result" == "0" ]
}
