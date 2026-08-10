#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-126"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-126 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. AmazonEKSVPCResourceController is attached to the cluster IAM role" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  role_name=$(aws eks describe-cluster --name "$cluster" --query 'cluster.roleArn' --output text 2>/dev/null | sed 's|.*/||')
  attached=$(aws iam list-attached-role-policies --role-name "$role_name" \
    --query "AttachedPolicies[?PolicyName=='AmazonEKSVPCResourceController'].PolicyName" \
    --output text 2>/dev/null)
  f=/var/work/tests/artifacts/2/prereqs.txt
  if [[ "$attached" == "AmazonEKSVPCResourceController" ]] && [[ -s "$f" ]] \
     && grep -q 'AmazonEKSVPCResourceController' "$f" && grep -q 'ENABLE_POD_ENI' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "role=$role_name attached=$attached file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. SecurityGroupPolicy secured-sgp references an existing security group" {
  echo '1' >> /var/work/tests/result/all
  sgp_sg=$(kubectl get securitygrouppolicy secured-sgp -n "$NS" \
    -o jsonpath='{.spec.securityGroups.groupIds[0]}' 2>/dev/null)
  selector=$(kubectl get securitygrouppolicy secured-sgp -n "$NS" \
    -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
  f=/var/work/tests/artifacts/3/sg_id.txt
  file_sg=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  if [[ -n "$sgp_sg" ]] && [[ "$sgp_sg" == "$file_sg" ]] && [[ "$selector" == "secured" ]] \
     && aws ec2 describe-security-groups --group-ids "$sgp_sg" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sgp_sg=$sgp_sg file_sg=$file_sg selector=$selector"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Deployment secured-app exists with label app=secured and artifact records the probe symptom" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  label=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/pod_not_ready.txt
  if [[ "$image" == *ping_pong* ]] && [[ "$label" == "secured" ]] && [[ -s "$f" ]] \
     && grep -qiE 'Readiness probe failed|Unhealthy' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "image=$image label=$label file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Probe fixed: secured-app is 1/1 Ready after the node-SG inbound rule" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/pod_ready.txt
  if [[ "$ready" == "1" ]] && [[ -s "$f" ]] && grep -q '1/1' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ready=$ready file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. DNS fixed: artifact explains the missing return rule on port 53" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/dns_fix.txt
  if [[ -s "$f" ]] && grep -q '53' "$f" && grep -qiE 'обратн|return rule' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention 53 and the return rule"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Same-node trap: artifact compares secured-app and CoreDNS nodes" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/same_node_trap.txt
  app_node=$(kubectl get pod -n "$NS" -l app=secured -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)
  if [[ -s "$f" ]] && [[ -n "$app_node" ]] && grep -q "$app_node" "$f" \
     && grep -qiE 'одной ноде|same node' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, app_node=$app_node not found, or trap not explained"
    result=1
  fi
  [ "$result" == "0" ]
}
