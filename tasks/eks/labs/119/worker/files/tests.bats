#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-119"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-119 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Artifact 2/nodegroup_health.txt shows a healthy managed node group" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  ng=$(aws eks list-nodegroups --cluster-name "$cluster" --query 'nodegroups[0]' --output text 2>/dev/null)
  issues=$(aws eks describe-nodegroup --cluster-name "$cluster" --nodegroup-name "$ng" \
    --query 'nodegroup.health.issues' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/2/nodegroup_health.txt
  if [[ -s "$f" ]] && [[ -z "$issues" ]] && grep -qi 'Ready' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, or nodegroup health.issues not empty ($issues), or no Ready node listed"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Test IAM role for the self-managed instance exists" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/test_role_arn.txt
  role_arn=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  if [[ -s "$f" ]] && [[ "$role_arn" == arn:aws:iam::*:role/*test* ]] \
     && aws iam get-role --role-name "$(echo "$role_arn" | sed 's|.*/||')" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file=$f role_arn=$role_arn does not resolve to an existing IAM role"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Artifact 4/instance_id.txt records the self-managed EC2 instance ID" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/instance_id.txt
  iid=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  if [[ -s "$f" ]] && [[ "$iid" =~ ^i-[0-9a-f]+$ ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not hold a valid instance id, got: $iid"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5/no_join_symptom.txt confirms running instance absent from nodes" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/no_join_symptom.txt
  iid=$(cat /var/work/tests/artifacts/4/instance_id.txt 2>/dev/null | tr -d '[:space:]')
  if [[ -s "$f" ]] && grep -qi 'running' "$f" && grep -qi 'get nodes' "$f" \
     && [[ -n "$iid" ]] && grep -q "$iid" "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f must mention the instance id, running, and get nodes"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact 6/why_no_access_entry.txt explains the missing access entry" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/why_no_access_entry.txt
  role_arn=$(cat /var/work/tests/artifacts/3/test_role_arn.txt 2>/dev/null | tr -d '[:space:]')
  if [[ -s "$f" ]] && grep -qi 'access entry' "$f" && grep -q 'EC2_LINUX' "$f" \
     && [[ -n "$role_arn" ]] && grep -qF "$role_arn" "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f must mention access entry, EC2_LINUX and the role arn"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Access entry EC2_LINUX exists and the node reached Ready" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  role_arn=$(cat /var/work/tests/artifacts/3/test_role_arn.txt 2>/dev/null | tr -d '[:space:]')
  atype=$(aws eks describe-access-entry --cluster-name "$cluster" --principal-arn "$role_arn" \
    --query 'accessEntry.type' --output text 2>/dev/null || true)
  f=/var/work/tests/artifacts/7/node_ready.txt
  node_name=$(grep '^node_name=' "$f" 2>/dev/null | cut -d= -f2)
  node_status=$(grep '^node_status=' "$f" 2>/dev/null | cut -d= -f2)
  # The node object disappears together with the instance terminated in task 9, so the
  # live status is checked while it is still there and the recorded one afterwards.
  live_status=$(kubectl get node "$node_name" --no-headers 2>/dev/null | awk '{print $2}' || true)
  node_ok=0
  if [[ "$live_status" == "Ready" ]]; then
    node_ok=1
  elif [[ "$node_status" == "Ready" ]] && [[ "$node_name" == ip-*.compute.internal ]]; then
    node_ok=1
  fi
  if [[ "$atype" == "EC2_LINUX" ]] && [[ -s "$f" ]] && [[ "$node_ok" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "access entry type=$atype node_name=$node_name recorded=$node_status live=$live_status"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Pod probe in eks-119 runs on the fixed self-managed node" {
  echo '1' >> /var/work/tests/result/all
  node_name=$(grep '^node_name=' /var/work/tests/artifacts/7/node_ready.txt 2>/dev/null | cut -d= -f2)
  f=/var/work/tests/artifacts/8/probe.txt
  rec_phase=$(grep '^pod_phase=' "$f" 2>/dev/null | cut -d= -f2)
  rec_node=$(grep '^pod_node=' "$f" 2>/dev/null | cut -d= -f2)
  # Terminating the instance in task 9 kills the node and the pod with it, so the live
  # state counts while the pod is there and the recorded evidence counts afterwards.
  live_phase=$(kubectl get po probe -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  live_node=$(kubectl get po probe -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
  ok=0
  if [[ -n "$node_name" ]]; then
    if [[ "$live_phase" == "Running" ]] && [[ "$live_node" == "$node_name" ]]; then
      ok=1
    elif [[ -s "$f" ]] && [[ "$rec_phase" == "Running" ]] && [[ "$rec_node" == "$node_name" ]]; then
      ok=1
    fi
  fi
  if [[ "$ok" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "expected_node=$node_name live_phase=$live_phase live_node=$live_node recorded_phase=$rec_phase recorded_node=$rec_node"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "9. Self-managed instance was terminated after the lab" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/9/terminated.txt
  iid=$(cat /var/work/tests/artifacts/4/instance_id.txt 2>/dev/null | tr -d '[:space:]')
  state=$(aws ec2 describe-instances --instance-ids "$iid" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || true)
  # AWS stops listing a terminated instance after a while, and a running instance is
  # always listed, so "not found any more" is proof of termination as well.
  gone=0
  [[ -z "$state" || "$state" == "None" ]] && gone=1
  if [[ -s "$f" ]] \
     && [[ "$state" == "terminated" || "$state" == "shutting-down" || "$gone" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or instance state=$state (expected terminated/shutting-down/gone)"
    result=1
  fi
  [ "$result" == "0" ]
}
