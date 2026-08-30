#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="security-106"
NODE_LABEL="security.cks.io/localhost-profiles-106"
AA_PROFILE="k8s-106-deny-write"
SECCOMP_PROFILE="profiles/cks-106-deny-unshare.json"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. AppArmor Localhost profile is loaded in enforce mode on the labelled workload node" {
  echo '1' >> /var/work/tests/result/all
  node=$(kubectl get nodes --context "$CTX" -l "${NODE_LABEL}=true" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  status=$(ssh -o BatchMode=yes control-plane "sudo aa-status 2>/dev/null" 2>/dev/null || true)
  profile_file=$(ssh -o BatchMode=yes control-plane "sudo test -r /etc/apparmor.d/${AA_PROFILE} && echo present" 2>/dev/null || true)
  if [[ -n "$node" && "$profile_file" == "present" && "$status" == *"${AA_PROFILE} (enforce)"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "labelled_node=${node:-missing} profile_file=${profile_file:-missing} apparmor_status=$(tr '\n' ' ' <<<"$status")"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. apparmor-writer uses the Localhost profile and a write to /work is denied" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod apparmor-writer -n "$NS" --context "$CTX" -o json 2>/dev/null)
  profile=$(jq -r '.spec.securityContext.appArmorProfile.type + ":" + (.spec.securityContext.appArmorProfile.localhostProfile // "")' <<<"$pod" 2>/dev/null)
  node_selector=$(jq -r ".spec.nodeSelector[\"${NODE_LABEL}\"] // \"\"" <<<"$pod" 2>/dev/null)
  automount=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase' <<<"$pod" 2>/dev/null)
  set +e
  output=$(kubectl exec -n "$NS" apparmor-writer --context "$CTX" -- sh -c 'printf blocked >/work/cks-106-denied.txt' 2>&1)
  write_status=$?
  set -e
  if [[ "$profile" == "Localhost:${AA_PROFILE}" && "$node_selector" == "true" && "$automount" == "false" && "$phase" == "Running" && "$write_status" -ne 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "profile=$profile node_selector=$node_selector automount=$automount phase=$phase write_status=$write_status output=$output"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. runtime-default explicitly uses RuntimeDefault seccomp and has filter mode enabled" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod runtime-default -n "$NS" --context "$CTX" -o json 2>/dev/null)
  seccomp=$(jq -r '.spec.securityContext.seccompProfile.type' <<<"$pod" 2>/dev/null)
  node_selector=$(jq -r ".spec.nodeSelector[\"${NODE_LABEL}\"] // \"\"" <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase' <<<"$pod" 2>/dev/null)
  effective=$(kubectl exec -n "$NS" runtime-default --context "$CTX" -- grep '^Seccomp:[[:space:]]*2$' /proc/1/status 2>/dev/null || true)
  if [[ "$seccomp" == "RuntimeDefault" && "$node_selector" == "true" && "$phase" == "Running" && "$effective" == "Seccomp:"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "seccomp_profile=$seccomp node_selector=$node_selector phase=$phase effective=${effective:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. localhost-seccomp uses the delivered custom Localhost seccomp profile" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod localhost-seccomp -n "$NS" --context "$CTX" -o json 2>/dev/null)
  profile=$(jq -r '.spec.securityContext.seccompProfile.type + ":" + (.spec.securityContext.seccompProfile.localhostProfile // "")' <<<"$pod" 2>/dev/null)
  node_selector=$(jq -r ".spec.nodeSelector[\"${NODE_LABEL}\"] // \"\"" <<<"$pod" 2>/dev/null)
  capabilities=$(jq -c '(.spec.containers[0].securityContext.capabilities.add // []) | sort' <<<"$pod" 2>/dev/null)
  allow_escalation=$(jq -r '.spec.containers[0].securityContext.allowPrivilegeEscalation' <<<"$pod" 2>/dev/null)
  node_profile=$(ssh -o BatchMode=yes control-plane "sudo jq -e '.defaultAction == \"SCMP_ACT_ALLOW\" and ([.syscalls[] | select((.names | index(\"unshare\")) and .action == \"SCMP_ACT_ERRNO\" and .errnoRet == 1)] | length == 1)' /var/lib/kubelet/seccomp/${SECCOMP_PROFILE}" 2>/dev/null || true)
  if [[ "$profile" == "Localhost:${SECCOMP_PROFILE}" && "$node_selector" == "true" && "$capabilities" == '["SYS_ADMIN"]' && "$allow_escalation" == "false" && "$node_profile" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "profile=$profile node_selector=$node_selector capabilities=$capabilities allow_privilege_escalation=$allow_escalation node_profile=${node_profile:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. Custom seccomp blocks unshare despite SYS_ADMIN and records the expected denial" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get pod localhost-seccomp -n "$NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  artifact=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- cat /tmp/unshare-result 2>/dev/null || true)
  effective=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- grep '^Seccomp:[[:space:]]*2$' /proc/1/status 2>/dev/null || true)
  set +e
  output=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- unshare -m true 2>&1)
  syscall_status=$?
  set -e
  if [[ "$phase" == "Running" && "$artifact" == "unshare denied by seccomp" && "$effective" == "Seccomp:"* && "$syscall_status" -ne 0 && "$output" =~ [Pp]ermission[[:space:]][Dd]enied|[Oo]peration[[:space:]][Nn]ot[[:space:]][Pp]ermitted ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "phase=$phase artifact=${artifact:-missing} effective=${effective:-missing} syscall_status=$syscall_status output=$output"
    result=1
  fi
  [ "$result" -eq 0 ]
}
