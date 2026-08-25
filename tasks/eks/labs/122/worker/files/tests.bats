#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-122"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-122: web on a gp3 PVC and a marker ConfigMap" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/1/marker.txt
  sc_prov=$(kubectl get sc gp3 -o jsonpath='{.provisioner}' 2>/dev/null)
  image=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  pvc_class=$(kubectl get pvc data -n "$NS" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
  pvc_phase=$(kubectl get pvc data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  marker=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  cm_value=$(kubectl get cm marker -n "$NS" -o jsonpath='{.data.marker}' 2>/dev/null)
  if [[ "$sc_prov" == "ebs.csi.aws.com" ]] && [[ "$image" == *ping_pong* ]] \
     && [[ "$ready" -ge 1 ]] && [[ "$pvc_class" == "gp3" ]] && [[ "$pvc_phase" == "Bound" ]] \
     && [[ -n "$marker" ]] && [[ "$cm_value" == "$marker" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sc_prov=$sc_prov web image=$image ready=$ready pvc_class=$pvc_class"
    echo "pvc_phase=$pvc_phase marker=$marker cm_value=$cm_value"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Region opt-in for Amazon EKS in AWS Backup is enabled and recorded" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/optin.txt
  after=$(aws backup describe-region-settings \
    --query "ResourceTypeOptInPreference.EKS" --output text 2>/dev/null)
  if [[ "$after" == "True" ]] && [[ -s "$f" ]] && grep -q '^before=' "$f" \
     && grep -qE '^after=(true|True)$' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "region opt-in EKS=$after file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. On-demand backup job of the cluster reaches a terminal state" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/backup_status.txt
  job_id=$(grep '^backup_job_id=' "$f" 2>/dev/null | cut -d= -f2-)
  status=""
  for i in $(seq 1 60); do
    status=$(aws backup describe-backup-job --backup-job-id "$job_id" \
      --query 'State' --output text 2>/dev/null)
    if [[ "$status" == "COMPLETED" ]] || [[ "$status" == "FAILED" ]] \
       || [[ "$status" == "ABORTED" ]] || [[ "$status" == "PARTIAL" ]] \
       || [[ "$status" == "EXPIRED" ]]; then
      break
    fi
    sleep 10
  done
  rp_arn=$(grep '^recovery_point_arn=' "$f" 2>/dev/null | cut -d= -f2-)
  if [[ ( "$status" == "COMPLETED" || "$status" == "PARTIAL" ) ]] && [[ -s "$f" ]] \
     && [[ -n "$rp_arn" ]] && grep -q '^status=' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "backup_job_id=$job_id status=$status recovery_point_arn=$rp_arn (waited up to 10 min)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Composite recovery point diagnosis artifact explains parent versus child" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/composite.txt
  if [[ -s "$f" ]] && grep -qi 'composite' "$f" && grep -qi 'child' "$f" \
     && grep -qiE 'ParentRecoveryPointArn|nested' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention composite/child/ParentRecoveryPointArn"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Namespace restore job is non-destructive and completes" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/restore_status.txt
  job_id=$(grep '^restore_job_id=' "$f" 2>/dev/null | cut -d= -f2-)
  status=""
  for i in $(seq 1 60); do
    status=$(aws backup describe-restore-job --restore-job-id "$job_id" \
      --query 'Status' --output text 2>/dev/null)
    if [[ "$status" == "COMPLETED" ]] || [[ "$status" == "FAILED" ]] \
       || [[ "$status" == "ABORTED" ]]; then
      break
    fi
    sleep 10
  done
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  marker_before=$(cat /var/work/tests/artifacts/1/marker.txt 2>/dev/null | tr -d '[:space:]')
  marker_after=$(kubectl get cm marker -n "$NS" -o jsonpath='{.data.marker}' 2>/dev/null)
  if [[ "$status" == "COMPLETED" ]] && [[ -s "$f" ]] && grep -qi 'non-destructive\|неразруш' "$f" \
     && [[ "$ready" -ge 1 ]] && [[ "$marker_after" == "$marker_before" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "restore_job_id=$job_id status=$status ready=$ready"
    echo "marker_before=$marker_before marker_after=$marker_after (waited up to 10 min)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact explains why a cluster version rollback cannot undo a deleted namespace" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/whynonrollback.txt
  if [[ -s "$f" ]] && grep -qi 'etcd' "$f" && grep -qi 'откат\|rollback' "$f" \
     && grep -qi 'namespace' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention etcd/rollback/namespace"
    result=1
  fi
  [ "$result" == "0" ]
}
