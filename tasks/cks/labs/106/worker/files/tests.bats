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
    if [[ -z "$node" ]]; then
      echo "HINT: No node carries label '${NODE_LABEL}=true'. Label the target node before scheduling workload Pods onto it."
    elif [[ "$profile_file" != "present" ]]; then
      echo "HINT: Profile file /etc/apparmor.d/${AA_PROFILE} is missing on control-plane. Copy your profile there first."
    else
      echo "HINT: aa-status does not show '${AA_PROFILE} (enforce)'. Load the profile with 'apparmor_parser -r /etc/apparmor.d/${AA_PROFILE}' - the file being present is not enough, it must actually be parsed and loaded into the kernel in enforce mode."
    fi
    echo "labelled_node=${node:-missing} profile_file=${profile_file:-missing} apparmor_status=$(tr '\n' ' ' <<<"$status")"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. apparmor-writer has the effective Localhost profile and receives an AppArmor write denial" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod apparmor-writer -n "$NS" --context "$CTX" -o json 2>/dev/null)
  profile=$(jq -r '.spec.securityContext.appArmorProfile.type + ":" + (.spec.securityContext.appArmorProfile.localhostProfile // "")' <<<"$pod" 2>/dev/null)
  node_selector=$(jq -r ".spec.nodeSelector[\"${NODE_LABEL}\"] // \"\"" <<<"$pod" 2>/dev/null)
  automount=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase' <<<"$pod" 2>/dev/null)
  effective_profile=$(kubectl exec -n "$NS" apparmor-writer --context "$CTX" -- cat /proc/1/attr/current 2>/dev/null || true)
  set +e
  output=$(kubectl exec -n "$NS" apparmor-writer --context "$CTX" -- sh -c 'printf blocked >/work/cks-106-denied.txt' 2>&1)
  write_status=$?
  set -e
  if [[ "$profile" == "Localhost:${AA_PROFILE}" && "$node_selector" == "true" && "$automount" == "false" && "$phase" == "Running" && "$effective_profile" == "${AA_PROFILE}"* && "$effective_profile" == *"(enforce)"* && "$write_status" -ne 0 ]] && grep -Eqi 'permission denied|operation not permitted' <<<"$output"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$profile" != "Localhost:${AA_PROFILE}" ]]; then
      echo "HINT: Pod 'apparmor-writer' securityContext.appArmorProfile must be {type: Localhost, localhostProfile: ${AA_PROFILE}} exactly - a plain 'RuntimeDefault' type will not enforce your custom profile."
    elif [[ "$node_selector" != "true" ]]; then
      echo "HINT: Pod must have nodeSelector['${NODE_LABEL}'] = 'true' to guarantee scheduling onto the node where the profile is actually loaded - AppArmor profiles are node-local."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: Pod is not Running (phase=$phase). If the profile name in the Pod spec does not match a profile actually loaded on the node, kubelet will report CreateContainerError."
    elif [[ "$effective_profile" != "${AA_PROFILE}"* ]]; then
      echo "HINT: /proc/1/attr/current inside the container does not show your profile applied - check the profile name matches exactly (case-sensitive) between the Pod spec and /etc/apparmor.d/."
    elif [[ "$write_status" -eq 0 ]]; then
      echo "HINT: The write to /work/cks-106-denied.txt succeeded when it should have been denied by AppArmor. Check your profile actually restricts write access to that path in enforce mode."
    fi
    echo "profile=$profile node_selector=$node_selector automount=$automount phase=$phase effective_profile=${effective_profile:-missing} write_status=$write_status output=$output"
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
    if [[ "$seccomp" != "RuntimeDefault" ]]; then
      echo "HINT: Pod 'runtime-default' must set securityContext.seccompProfile.type explicitly to 'RuntimeDefault' - relying on a cluster-wide default is not the same as declaring intent in the manifest."
    elif [[ "$effective" != "Seccomp:"* ]]; then
      echo "HINT: /proc/1/status inside the container does not show 'Seccomp: 2' (filter mode enabled). Check the Pod actually restarted after you added the seccompProfile field."
    fi
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
  node_profile=$(ssh -o BatchMode=yes control-plane "sudo jq -e '.defaultAction == \"SCMP_ACT_ALLOW\" and ([.syscalls[] | select((.names | index(\"unshare\")) and .action == \"SCMP_ACT_ERRNO\" and .errnoRet == 1)] | length == 1)' /var/lib/kubelet/seccomp/${SECCOMP_PROFILE}" 2>/dev/null || true)
  if [[ "$profile" == "Localhost:${SECCOMP_PROFILE}" && "$node_selector" == "true" && "$capabilities" == '["SYS_ADMIN"]' && "$node_profile" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$profile" != "Localhost:${SECCOMP_PROFILE}" ]]; then
      echo "HINT: Pod 'localhost-seccomp' seccompProfile must be {type: Localhost, localhostProfile: ${SECCOMP_PROFILE}} - remember localhostProfile is relative to the kubelet seccomp root, not an absolute path."
    elif [[ "$capabilities" != '["SYS_ADMIN"]' ]]; then
      echo "HINT: Container must add exactly capability SYS_ADMIN (needed to attempt unshare) - check spec.containers[0].securityContext.capabilities.add."
    elif [[ "$node_profile" != "true" ]]; then
      echo "HINT: The profile JSON at /var/lib/kubelet/seccomp/${SECCOMP_PROFILE} on the node must have defaultAction SCMP_ACT_ALLOW and a specific rule blocking syscall 'unshare' with SCMP_ACT_ERRNO/errnoRet 1 - check the exact JSON structure."
    fi
    echo "profile=$profile node_selector=$node_selector capabilities=$capabilities node_profile=${node_profile:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. Custom seccomp blocks unshare while an Unconfined SYS_ADMIN control can execute it" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get pod localhost-seccomp -n "$NS" --context "$CTX" -o jsonpath='{.status.phase}' 2>/dev/null)
  artifact=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- cat /tmp/unshare-result 2>/dev/null || true)
  effective=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- grep '^Seccomp:[[:space:]]*2$' /proc/1/status 2>/dev/null || true)
  set +e
  output=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- unshare -m true 2>&1)
  syscall_status=$?
  control_output=$(kubectl run sysadmin-control -n "$NS" --context "$CTX" --rm -i --restart=Never \
    --image=busybox:1.36 --overrides="{\"spec\":{\"nodeSelector\":{\"${NODE_LABEL}\":\"true\"},\"securityContext\":{\"seccompProfile\":{\"type\":\"Unconfined\"}},\"containers\":[{\"name\":\"sysadmin-control\",\"image\":\"busybox:1.36\",\"securityContext\":{\"capabilities\":{\"add\":[\"SYS_ADMIN\"]}},\"command\":[\"unshare\",\"-m\",\"true\"]}]}}" 2>&1)
  control_status=$?
  set -e
  if [[ "$phase" == "Running" && "$artifact" == "unshare denied by seccomp" && "$effective" == "Seccomp:"* && "$syscall_status" -ne 0 && "$control_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$syscall_status" -eq 0 ]]; then
      echo "HINT: 'unshare -m true' succeeded in the custom-profile Pod - it should be blocked. Double-check the seccomp profile JSON syntax and that it was actually loaded (see test 4)."
    elif [[ "$control_status" -ne 0 ]]; then
      echo "HINT: The Unconfined+SYS_ADMIN control Pod should succeed at 'unshare -m true' - if it also fails, the failure may not be seccomp-specific (e.g. missing capability, wrong image). This positive control proves the syscall itself works without your custom filter."
    elif [[ "$artifact" != "unshare denied by seccomp" ]]; then
      echo "HINT: /tmp/unshare-result inside the Pod does not contain the exact text 'unshare denied by seccomp' - save this exact string after observing the denial."
    fi
    echo "phase=$phase artifact=${artifact:-missing} effective=${effective:-missing} blocked_status=$syscall_status blocked_output=$output control_status=$control_status control_output=$control_output"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. userns-probe runs with hostUsers: false and root is translated to an unprivileged host UID" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod userns-probe -n "$NS" --context "$CTX" -o json 2>/dev/null)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  host_users=$(jq -r '.spec.hostUsers' <<<"$pod" 2>/dev/null)
  node_selector=$(jq -r ".spec.nodeSelector[\"${NODE_LABEL}\"] // \"\"" <<<"$pod" 2>/dev/null)
  container_id=$(jq -r '.status.containerStatuses[]? | select(.name == "app") | .containerID' <<<"$pod" 2>/dev/null | sed 's#^containerd://##')
  artifact=/var/work/tests/artifacts/6/userns.txt
  inside_id=$(kubectl exec -n "$NS" userns-probe --context "$CTX" -- id 2>/dev/null || true)
  uid_map=$(ssh -o BatchMode=yes control-plane "host_pid=\$(sudo crictl inspect '$container_id' 2>/dev/null | jq -r '.info.pid // empty'); [[ -n \"\$host_pid\" ]] && sudo cat /proc/\$host_pid/uid_map" 2>/dev/null || true)
  host_uid=$(awk '{print $2}' <<<"$uid_map" | head -1)
  range_len=$(awk '{print $3}' <<<"$uid_map" | head -1)
  if [[ "$phase" == "Running" && "$host_users" == "false" && "$node_selector" == "true" \
    && "$inside_id" == *"uid=0(root)"* \
    && -n "$host_uid" && "$host_uid" != "0" && "$range_len" -ge 65536 ]] \
    && grep -Fq 'uid=0(root)' "$artifact" 2>/dev/null \
    && grep -Eq '^0[[:space:]]+[1-9][0-9]*[[:space:]]+[0-9]+$' "$artifact" 2>/dev/null; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$host_users" != "false" ]]; then
      echo "HINT: Pod 'userns-probe' must set hostUsers: false - this is what activates a separate Linux user namespace for the Pod."
    elif [[ "$inside_id" != *"uid=0(root)"* ]]; then
      echo "HINT: Inside the container 'id' should still report uid=0(root) - that is expected, the container's view of its own UID does not change, only the HOST-side mapping does."
    elif [[ -z "$host_uid" || "$host_uid" == "0" ]]; then
      echo "HINT: The uid_map for this process on the host shows UID 0 mapping to host UID $host_uid - it must map to a non-zero, unprivileged host UID. Check hostUsers: false actually took effect and crictl inspect found the right container."
    elif [[ "$range_len" -lt 65536 ]]; then
      echo "HINT: The UID range in uid_map is smaller than 65536 - check the user namespace was allocated the expected range."
    else
      echo "HINT: Runtime values look correct, but /var/work/tests/artifacts/6/userns.txt is missing the expected 'uid=0(root)' text or the uid_map line format '0 <host_uid> <range>'."
    fi
    echo "phase=$phase host_users=$host_users node_selector=$node_selector inside_id=$inside_id uid_map=$uid_map host_uid=${host_uid:-missing} range_len=${range_len:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. seccompDefault: true on kubelet applies RuntimeDefault when no profile is set" {
  echo '1' >> /var/work/tests/result/all
  kubelet_config=$(ssh -o BatchMode=yes control-plane "sudo cat /var/lib/kubelet/config.yaml" 2>/dev/null || true)
  kubelet_active=$(ssh -o BatchMode=yes control-plane 'sudo systemctl is-active kubelet' 2>/dev/null || true)
  node=$(kubectl get nodes --context "$CTX" -l "${NODE_LABEL}=true" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  node_ready=$(kubectl get node "$node" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  pod=$(kubectl get pod no-seccomp-field -n "$NS" --context "$CTX" -o json 2>/dev/null)
  pod_seccomp=$(jq -r '.spec.securityContext.seccompProfile // .spec.containers[0].securityContext.seccompProfile // "unset"' <<<"$pod" 2>/dev/null)
  effective=$(kubectl exec -n "$NS" no-seccomp-field --context "$CTX" -- grep '^Seccomp:' /proc/1/status 2>/dev/null || true)
  if [[ "$kubelet_config" == *'seccompDefault: true'* && "$kubelet_active" == "active" && "$node_ready" == "True" \
    && "$pod_seccomp" == "unset" && "$effective" == *"2"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$kubelet_config" != *'seccompDefault: true'* ]]; then
      echo "HINT: kubelet config.yaml on this node is missing 'seccompDefault: true'. Add it and restart kubelet."
    elif [[ "$kubelet_active" != "active" || "$node_ready" != "True" ]]; then
      echo "HINT: kubelet is not active or node is NotReady after the config change (kubelet=$kubelet_active node_ready=$node_ready). Check for a YAML syntax error in config.yaml."
    elif [[ "$pod_seccomp" != "unset" ]]; then
      echo "HINT: Pod 'no-seccomp-field' must NOT set any seccompProfile field at all - the whole point of this task is to prove kubelet's own default takes effect when the Pod is silent about it."
    elif [[ "$effective" != *"2"* ]]; then
      echo "HINT: /proc/1/status inside the Pod does not show 'Seccomp: 2' (filter mode) even though the Pod spec has no seccompProfile - kubelet's seccompDefault is not actually applying RuntimeDefault. Check kubelet actually restarted with the new config."
    fi
    echo "seccompDefault_set=$([[ "$kubelet_config" == *'seccompDefault: true'* ]] && echo yes || echo no) kubelet_active=$kubelet_active node_ready=$node_ready pod_seccomp=$pod_seccomp effective=${effective:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Broken AppArmor profile syntax is fixed and loaded via apparmor_parser -r -v" {
  echo '1' >> /var/work/tests/result/all
  artifact=/var/work/tests/artifacts/8/apparmor-debug.txt
  parse_check=$(ssh -o BatchMode=yes control-plane 'sudo apparmor_parser -p /etc/apparmor.d/k8s-106-broken-profile 2>&1; echo "exit=$?"' 2>/dev/null || true)
  status_output=$(ssh -o BatchMode=yes control-plane 'sudo aa-status 2>/dev/null' 2>/dev/null || true)
  if [[ -s "$artifact" ]] && grep -qi 'syntax error' "$artifact" \
    && [[ "$parse_check" == *"exit=0"* ]] \
    && [[ "$status_output" == *"k8s-106-broken-profile"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if ! [[ -s "$artifact" ]] || ! grep -qi 'syntax error' "$artifact"; then
      echo "HINT: apparmor-debug.txt must capture the ORIGINAL syntax error output from 'apparmor_parser -p' or 'apparmor_parser -r -v' BEFORE you fix the profile - save that evidence first."
    elif [[ "$parse_check" != *"exit=0"* ]]; then
      echo "HINT: The profile still fails to parse after your fix (apparmor_parser exit != 0). Check the reported syntax error line carefully - unmatched braces and typos in rule keywords are the most common cause."
    elif [[ "$status_output" != *"k8s-106-broken-profile"* ]]; then
      echo "HINT: The fixed profile parses cleanly but is not loaded into the kernel - run 'apparmor_parser -r' (reload) explicitly, parsing successfully with '-p' (dry-run) alone does not load it."
    fi
    echo "artifact_has_error=$(grep -qi 'syntax error' "$artifact" 2>/dev/null && echo yes || echo no) parse_check=$parse_check status_has_profile=$([[ "$status_output" == *"k8s-106-broken-profile"* ]] && echo yes || echo no)"
    result=1
  fi
  [ "$result" -eq 0 ]
}
