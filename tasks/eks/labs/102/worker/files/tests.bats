#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER="eks-task102"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Cluster runs authenticationMode API and artifact confirms it" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/1/accessconfig.json
  mode=$(grep -o '"authenticationMode"[^,}]*' "$f" 2>/dev/null | grep -o 'API' | head -n1)
  if [[ -n "$cluster" ]] && [[ -s "$f" ]] && [[ "$mode" == "API" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cluster=$cluster file=$f mode=$mode"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Test IAM role for the second principal exists" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/test_role_arn.txt
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

@test "3. Access entry STANDARD with kubernetesGroups viewers exists for the test role" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  role_arn=$(cat /var/work/tests/artifacts/2/test_role_arn.txt 2>/dev/null | tr -d '[:space:]')
  entry=$(aws eks describe-access-entry --cluster-name "$cluster" --principal-arn "$role_arn" \
    --query 'accessEntry.[type,kubernetesGroups[0]]' --output text 2>/dev/null)
  atype=$(echo "$entry" | awk '{print $1}')
  agroup=$(echo "$entry" | awk '{print $2}')
  if [[ "$atype" == "STANDARD" ]] && [[ "$agroup" == "viewers" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "role_arn=$role_arn entry=$entry"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. ClusterRole and ClusterRoleBinding grant only get/list on pods to group viewers" {
  echo '1' >> /var/work/tests/result/all
  verbs=$(kubectl get clusterrole viewers-pod-reader -o jsonpath='{.rules[0].verbs}' 2>/dev/null)
  resources=$(kubectl get clusterrole viewers-pod-reader -o jsonpath='{.rules[0].resources}' 2>/dev/null)
  bound_group=$(kubectl get clusterrolebinding viewers-pod-reader -o jsonpath='{.subjects[0].name}' 2>/dev/null)
  bound_kind=$(kubectl get clusterrolebinding viewers-pod-reader -o jsonpath='{.subjects[0].kind}' 2>/dev/null)
  if [[ "$verbs" == *get* ]] && [[ "$verbs" == *list* ]] && [[ "$verbs" != *create* ]] \
     && [[ "$verbs" != *delete* ]] && [[ "$resources" == *pods* ]] \
     && [[ "$bound_group" == "viewers" ]] && [[ "$bound_kind" == "Group" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "verbs=$verbs resources=$resources bound_group=$bound_group bound_kind=$bound_kind"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact records manual read-only check and the Forbidden namespace attempt" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/rbac_check.txt
  if [[ -s "$f" ]] && grep -qi 'get pods' "$f" && grep -qi 'Forbidden' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention both a pod read check and Forbidden"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. AmazonEKSViewPolicy is associated with the test role at cluster scope" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  role_arn=$(cat /var/work/tests/artifacts/2/test_role_arn.txt 2>/dev/null | tr -d '[:space:]')
  scope=$(aws eks list-associated-access-policies --cluster-name "$cluster" --principal-arn "$role_arn" \
    --query "associatedAccessPolicies[?policyArn=='arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy'].accessScope.type" \
    --output text 2>/dev/null)
  if [[ "$scope" == "cluster" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "role_arn=$role_arn scope=$scope"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact explains Unauthorized versus Forbidden with real commands" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
  if [[ -s "$f" ]] && grep -qi 'Unauthorized' "$f" && grep -qi 'Forbidden' "$f" \
     && grep -qi 'list-access-entries' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f must mention Unauthorized, Forbidden and list-access-entries"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Access entry was deleted, seen as gone, then recreated (round trip)" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  role_arn=$(cat /var/work/tests/artifacts/2/test_role_arn.txt 2>/dev/null | tr -d '[:space:]')
  f=/var/work/tests/artifacts/8/delete_recreate.txt
  entry=$(aws eks describe-access-entry --cluster-name "$cluster" --principal-arn "$role_arn" \
    --query 'accessEntry.type' --output text 2>/dev/null)
  if [[ "$entry" == "STANDARD" ]] && [[ -s "$f" ]] && grep -qi 'Unauthorized' "$f" \
     && grep -qi 'delete-access-entry' "$f" && grep -qi 'create-access-entry' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "access entry type after round trip=$entry ; file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}
