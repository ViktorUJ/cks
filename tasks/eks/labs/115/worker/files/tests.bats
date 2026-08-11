#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-115"
LOG_GROUP="/aws/eks/$(kubectl config current-context 2>/dev/null | sed 's|.*/||')/application"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-115 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Symptom: flaky-before logs lost after pod recreation" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy flaky-before -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/2/before_symptom.txt
  old_pod=$(grep -o 'OLD_POD_NAME=.*' "$f" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
  if [[ "$ready" -ge 1 ]] && [[ -s "$f" ]] && grep -q 'OLD_POD_NAME=' "$f" \
     && grep -q 'BEFORE_MARKER_LAB115' "$f" && grep -qi 'NotFound' "$f" \
     && [[ -n "$old_pod" ]] \
     && ! kubectl get pod "$old_pod" -n "$NS" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "flaky-before ready=$ready; file $f must hold OLD_POD_NAME, BEFORE_MARKER_LAB115, NotFound; old pod ($old_pod) must be gone"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Fluent Bit DaemonSet is running with the IRSA role attached" {
  echo '1' >> /var/work/tests/result/all
  desired=$(kubectl get ds aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  ready=$(kubectl get ds aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.status.numberReady}' 2>/dev/null)
  role_arn=$(kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  cm_body=$(kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.data.fluent-bit\.conf}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]] && [[ "$ready" == "$desired" ]] \
     && [[ "$role_arn" == *fluentbit-irsa-role* ]] \
     && echo "$cm_body" | grep -qi 'Mem_Buf_Limit' \
     && echo "$cm_body" | grep -qi 'storage.type'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ds ready=$ready desired=$desired; sa role-arn=$role_arn; cm has Mem_Buf_Limit/storage.type?"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Fix proven: flaky-after log line found in CloudWatch after pod deletion" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy flaky-after -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/after_fixed.txt
  old_pod=$(grep -o 'OLD_POD_NAME=.*' "$f" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')
  found=$(aws logs filter-log-events --log-group-name "$LOG_GROUP" \
    --filter-pattern "AFTER_MARKER_LAB115" --query 'events[*].message' --output text 2>/dev/null)
  if [[ "$ready" -ge 1 ]] && [[ -s "$f" ]] && grep -q 'OLD_POD_NAME=' "$f" \
     && grep -qi 'NotFound' "$f" && grep -q 'AFTER_MARKER_LAB115' "$f" \
     && [[ -n "$old_pod" ]] \
     && ! kubectl get pod "$old_pod" -n "$NS" >/dev/null 2>&1 \
     && [[ -n "$found" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "flaky-after ready=$ready; file $f content check failed or old pod ($old_pod) still exists; cw filter found=$found"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Filter drops /healthz noise, normal lines still reach CloudWatch" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/filter_check.txt
  cm_body=$(kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.data.fluent-bit\.conf}' 2>/dev/null)
  noise=$(aws logs filter-log-events --log-group-name "$LOG_GROUP" \
    --filter-pattern "healthz" --query 'events' --output text 2>/dev/null)
  normal=$(aws logs filter-log-events --log-group-name "$LOG_GROUP" \
    --filter-pattern "NORMAL_MARKER_LAB115" --query 'events' --output text 2>/dev/null)
  if [[ -s "$f" ]] && grep -qi 'grep' "$f" && grep -qi 'healthz' "$f" \
     && echo "$cm_body" | grep -qi 'Exclude' \
     && [[ -z "$noise" ]] && [[ -n "$normal" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file check failed, or grep filter missing in cm, or noise present ($noise), or normal missing ($normal)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Retention policy set to 7 days on the log group" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/retention.txt
  retention=$(aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
    --query "logGroups[?logGroupName=='$LOG_GROUP'].retentionInDays" --output text 2>/dev/null)
  if [[ -s "$f" ]] && grep -q '7' "$f" && [[ "$retention" == "7" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention 7; retentionInDays=$retention"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Multiline parser merges a 4-line traceback into one CloudWatch event" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/multiline.txt
  cm_body=$(kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch \
    -o jsonpath='{.data.fluent-bit\.conf}' 2>/dev/null)
  events=$(aws logs filter-log-events --log-group-name "$LOG_GROUP" \
    --filter-pattern "CRASH_TRACE_LAB115" --query 'events[*].message' --output text 2>/dev/null)
  merged=$(echo "$events" | grep -c 'CRASH_TRACE_LAB115')
  has_traceback_same_msg=$(echo "$events" | grep 'CRASH_TRACE_LAB115' | grep -c 'Traceback')
  if [[ -s "$f" ]] && grep -q 'CRASH_TRACE_LAB115' "$f" \
     && grep -qiE 'multiline|Traceback' "$f" \
     && echo "$cm_body" | grep -qi 'multiline.parser' \
     && [[ "$merged" -ge 1 ]] && [[ "$has_traceback_same_msg" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file check failed, or multiline.parser missing in cm, or events not merged (merged=$merged, same_msg=$has_traceback_same_msg)"
    result=1
  fi
  [ "$result" == "0" ]
}
