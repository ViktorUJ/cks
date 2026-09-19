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
  # aa-status groups profiles under section headers ('N profiles are in enforce mode.')
  # and lists bare profile names/paths underneath - it does NOT print a per-profile
  # '(enforce)'/'(complain)' suffix in that listing (that suffix format belongs to
  # /proc/<pid>/attr/current and to the kernel's own profiles file, not to aa-status's
  # profile list). A grep for the literal string 'PROFILE (enforce)' against aa-status
  # output therefore never matches even a correctly loaded enforce profile. Read the
  # authoritative kernel state directly instead: /sys/kernel/security/apparmor/profiles
  # is a stable, machine-readable 'name (mode)\n' per-profile listing straight from the
  # kernel, unambiguous and not dependent on any userspace tool's cosmetic formatting.
  status=$(ssh -o BatchMode=yes control-plane "sudo cat /sys/kernel/security/apparmor/profiles 2>/dev/null" 2>/dev/null || true)
  profile_file=$(ssh -o BatchMode=yes control-plane "sudo test -r /etc/apparmor.d/${AA_PROFILE} && echo present" 2>/dev/null || true)
  # Checker-owned bootstrap baseline (captured by master.sh BEFORE the lab was handed to
  # the student, while the profile was still in complain mode): proves a write matching
  # this profile's '/work/**' pattern actually succeeded under complain mode. Without
  # this, observing "write denied" after the student's change alone cannot rule out the
  # denial having a different, unrelated cause from the very start - only a baseline
  # captured BEFORE the student's change can attribute the later denial specifically to
  # the complain->enforce transition. Read via 'sudo cat' over SSH, matching this
  # checker's own convention (unlike some other labs' worker-local, non-sudo checkers).
  baseline_dir_owner_mode=$(ssh -o BatchMode=yes control-plane "sudo stat -c '%U:%G %a' /var/lib/cks-lab106-checker" 2>/dev/null || true)
  baseline_file_owner_mode=$(ssh -o BatchMode=yes control-plane "sudo stat -c '%U:%G %a' /var/lib/cks-lab106-checker/bootstrap-baseline-1.txt" 2>/dev/null || true)
  baseline_trust_boundary_ok="no"
  if [[ "$baseline_dir_owner_mode" =~ ^root:root\ 0?700$ && "$baseline_file_owner_mode" =~ ^root:root\ 0?400$ ]]; then
    baseline_trust_boundary_ok="yes"
  fi
  bootstrap_baseline=$(ssh -o BatchMode=yes control-plane "sudo cat /var/lib/cks-lab106-checker/bootstrap-baseline-1.txt" 2>/dev/null || true)
  bootstrap_baseline_ok="no"
  # Validate the baseline's recorded fields, not just a bare 'RC=0': the probe must have
  # targeted a path actually under '/work/' (the same host path the student's Pod later
  # mounts an emptyDir onto and that this profile's '/work/** r,' rule governs) - a
  # baseline that succeeded against some OTHER, unrelated path would prove nothing about
  # whether the '/work/**' flow this lab's tasks exercise behaved correctly in complain
  # mode before the student's enforce transition.
  if [[ "$baseline_trust_boundary_ok" == "yes" ]] \
    && grep -qE 'profile=k8s-106-deny-write' <<<"$bootstrap_baseline" \
    && grep -qE 'mode=complain' <<<"$bootstrap_baseline" \
    && grep -qE 'path=/work/' <<<"$bootstrap_baseline" \
    && grep -qE 'RC=0$' <<<"$bootstrap_baseline"; then
    bootstrap_baseline_ok="yes"
  fi
  if [[ -n "$node" && "$profile_file" == "present" && "$bootstrap_baseline_ok" == "yes" ]] && grep -qE "^${AA_PROFILE} \(enforce\)$" <<<"$status"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$node" ]]; then
      echo "HINT: No node carries label '${NODE_LABEL}=true'. Label the target node before scheduling workload Pods onto it."
    elif [[ "$profile_file" != "present" ]]; then
      echo "HINT: Profile file /etc/apparmor.d/${AA_PROFILE} is missing on control-plane. Copy your profile there first."
    elif [[ "$baseline_trust_boundary_ok" != "yes" ]]; then
      echo "HINT: /var/lib/cks-lab106-checker (dir='$baseline_dir_owner_mode') or its bootstrap-baseline-1.txt (file='$baseline_file_owner_mode') is not locked down to root:root 0700/0400 as expected - this is an infrastructure precondition failure, not something you can fix from inside the lab. Contact the lab operator."
    elif [[ "$bootstrap_baseline_ok" != "yes" ]]; then
      echo "HINT: the checker's own bootstrap-time baseline shows the write probe under the complain-mode profile did NOT succeed as expected before the lab started - this is an infrastructure precondition failure, not something you can fix from inside the lab. Contact the lab operator."
    else
      echo "HINT: /sys/kernel/security/apparmor/profiles does not contain a line '${AA_PROFILE} (enforce)'. Load the profile with 'apparmor_parser -r /etc/apparmor.d/${AA_PROFILE}' then 'aa-enforce /etc/apparmor.d/${AA_PROFILE}' (or edit the flags and reload) - the file being present is not enough, it must actually be parsed and loaded into the kernel in enforce mode. Note: 'aa-status' output does NOT show a per-profile '(enforce)' suffix in its profile list, so do not rely on grepping that command's output for this string."
    fi
    echo "labelled_node=${node:-missing} profile_file=${profile_file:-missing} bootstrap_baseline_ok=$bootstrap_baseline_ok baseline_trust_boundary_ok=$baseline_trust_boundary_ok apparmor_profiles=$(tr '\n' ' ' <<<"$status")"
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
  # Checker-run positive control BEFORE the write probe: the profile grants '/** rix' -
  # a plain read of the mounted emptyDir must succeed. Without this, a write failure
  # alone does not distinguish 'AppArmor denies writes as designed' from 'this whole
  # mount/path is broken for an unrelated reason' (e.g. wrong mountPath, missing volume).
  set +e
  read_output=$(kubectl exec -n "$NS" apparmor-writer --context "$CTX" -- sh -c 'ls /work' 2>&1)
  read_status=$?
  # Use a run-unique filename for the denied write, and search for its EXACT match in
  # the kernel log. A fixed filename would let a stale denial event from a PREVIOUS
  # checker run (or a previous failed student attempt) satisfy the grep below even if
  # THIS run's write actually failed for an unrelated reason (e.g. a read-only mount) -
  # a fixed name cannot distinguish 'this probe's denial' from 'some old denial that
  # happens to still be in the last 500 journal lines'. A nonce closes that gap.
  nonce="$(date +%s%N)-$$"
  denied_file="cks-106-denied-${nonce}.txt"
  output=$(kubectl exec -n "$NS" apparmor-writer --context "$CTX" -- sh -c "printf blocked >/work/${denied_file}" 2>&1)
  write_status=$?
  set -e
  # Exit code + stderr text ('permission denied') is not sufficient evidence on its own:
  # a plain filesystem/DAC permission error, a read-only mount, or any other unrelated
  # EPERM/EACCES would produce the exact same shell-visible symptom and still pass this
  # check if AppArmor is not actually the mechanism responsible. Independently confirm
  # the kernel actually logged an AppArmor denial for THIS profile and THIS run's unique
  # path - AppArmor audit events go through the kernel audit subsystem and are visible
  # via 'journalctl -k' (or dmesg) as 'apparmor="DENIED" ... profile="<name>" ... name="<path>"'.
  kernel_denial=$(ssh -o BatchMode=yes control-plane "sudo journalctl -k --no-pager -n 500 2>/dev/null | grep -F 'apparmor=\"DENIED\"' | grep -F 'profile=\"${AA_PROFILE}\"' | grep -F '${denied_file}' | tail -1" 2>/dev/null || true)
  if [[ "$profile" == "Localhost:${AA_PROFILE}" && "$node_selector" == "true" && "$automount" == "false" && "$phase" == "Running" \
        && "$effective_profile" == "${AA_PROFILE}"* && "$effective_profile" == *"(enforce)"* \
        && "$read_status" -eq 0 && "$write_status" -ne 0 && -n "$kernel_denial" ]] \
        && grep -Eqi 'permission denied|operation not permitted' <<<"$output"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$profile" != "Localhost:${AA_PROFILE}" ]]; then
      echo "HINT: Pod 'apparmor-writer' securityContext.appArmorProfile must be {type: Localhost, localhostProfile: ${AA_PROFILE}} exactly - a plain 'RuntimeDefault' type will not enforce your custom profile."
    elif [[ "$node_selector" != "true" ]]; then
      echo "HINT: Pod must have nodeSelector['${NODE_LABEL}'] = 'true' to guarantee scheduling onto the node where the profile is actually loaded - AppArmor profiles are node-local."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: Pod is not Running (phase=$phase). If the profile name in the Pod spec does not match a profile actually loaded on the node, kubelet will report CreateContainerError."
    elif [[ "$effective_profile" != "${AA_PROFILE}"* || "$effective_profile" != *"(enforce)"* ]]; then
      echo "HINT: /proc/1/attr/current inside the container does not show '${AA_PROFILE} (enforce)' applied - check the profile name matches exactly (case-sensitive) between the Pod spec and /etc/apparmor.d/, and that the profile is actually in enforce mode on the node."
    elif [[ "$read_status" -ne 0 ]]; then
      echo "HINT: A plain read ('ls /work') failed inside the container. The profile's '/** rix' rule should allow this - if even reads are blocked, something else (wrong mountPath, missing emptyDir volume, a stricter profile than intended) is broken, and a write failure alone would not prove AppArmor is doing what this task expects."
    elif [[ "$write_status" -eq 0 ]]; then
      echo "HINT: The write to /work/${denied_file} succeeded when it should have been denied by AppArmor. Check your profile actually restricts write access to that path in enforce mode."
    elif [[ -z "$kernel_denial" ]]; then
      echo "HINT: The write failed, but no matching 'apparmor=\"DENIED\" ... profile=\"${AA_PROFILE}\" ... name=\".../${denied_file}\"' kernel audit event was found via 'journalctl -k' on control-plane. A non-zero exit code and a 'permission denied' string alone can come from an unrelated DAC/filesystem error, not necessarily from THIS AppArmor profile - the kernel log is the only evidence that AppArmor itself produced this specific denial."
    fi
    echo "profile=$profile node_selector=$node_selector automount=$automount phase=$phase effective_profile=${effective_profile:-missing} read_status=$read_status write_status=$write_status output=$output kernel_denial=${kernel_denial:-missing}"
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
  # Use 'unshare -n' (CLONE_NEWNET), NOT 'unshare -m' (CLONE_NEWNS). Both require the
  # same CAP_SYS_ADMIN, but BusyBox's 'unshare -m' issues a SECOND, independent mount(2)
  # syscall right after unshare(2) succeeds (an unconditional 'mount("none","/",...)' for
  # forced private propagation - see util-linux/unshare.c's mount_or_die() call gated
  # only on OPT_mount, active unless --propagation unchanged is passed, and even then
  # mount() is still called, just with flags=0). This Pod has no explicit
  # securityContext.appArmorProfile, so it inherits containerd's RuntimeDefault AppArmor
  # profile, which carries an unconditional 'deny mount,' rule independent of
  # capabilities or seccomp. That means 'unshare -m true' can fail with EPERM from
  # AppArmor alone, even when this seccomp profile does not block anything at all -
  # confounding the very control this test is trying to isolate. 'unshare -n' only ever
  # calls unshare(2) itself, with no secondary mount(2), so a failure here is
  # attributable to seccomp alone.
  output=$(kubectl exec -n "$NS" localhost-seccomp --context "$CTX" -- unshare -n true 2>&1)
  syscall_status=$?
  control_output=$(kubectl run sysadmin-control -n "$NS" --context "$CTX" --rm -i --restart=Never \
    --image=busybox:1.36 --overrides="{\"spec\":{\"nodeSelector\":{\"${NODE_LABEL}\":\"true\"},\"securityContext\":{\"seccompProfile\":{\"type\":\"Unconfined\"}},\"containers\":[{\"name\":\"sysadmin-control\",\"image\":\"busybox:1.36\",\"securityContext\":{\"capabilities\":{\"add\":[\"SYS_ADMIN\"]}},\"command\":[\"unshare\",\"-n\",\"true\"]}]}}" 2>&1)
  control_status=$?
  set -e
  if [[ "$phase" == "Running" && "$artifact" == "unshare denied by seccomp" && "$effective" == "Seccomp:"* && "$syscall_status" -ne 0 && "$control_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$syscall_status" -eq 0 ]]; then
      echo "HINT: 'unshare -n true' succeeded in the custom-profile Pod - it should be blocked. Double-check the seccomp profile JSON syntax and that it was actually loaded (see test 4)."
    elif [[ "$control_status" -ne 0 ]]; then
      echo "HINT: The Unconfined+SYS_ADMIN control Pod should succeed at 'unshare -n true' - if it also fails, the failure may not be seccomp-specific (e.g. missing capability, wrong image, or an AppArmor profile denying it - make sure neither Pod uses 'unshare -m', which triggers an extra mount(2) call that containerd's default AppArmor profile denies unconditionally). This positive control proves the syscall itself works without your custom filter."
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
  # A grep on the raw config.yaml text alone is not sufficient evidence: the on-disk
  # file can be overridden by a kubelet command-line flag, a drop-in, or simply not be
  # the file kubelet was actually started with - none of that shows up in a textual
  # grep. Read the EFFECTIVE, applied kubelet configuration via its own '/configz'
  # endpoint (proxied through the API server, like any other node debug endpoint) and
  # require the boolean field itself, not a substring match on raw YAML text.
  node=$(kubectl get nodes --context "$CTX" -l "${NODE_LABEL}=true" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  configz=$(kubectl get --raw "/api/v1/nodes/${node}/proxy/configz" --context "$CTX" 2>/dev/null || true)
  effective_seccomp_default=$(jq -r '.kubeletconfig.seccompDefault' <<<"$configz" 2>/dev/null || true)
  kubelet_active=$(ssh -o BatchMode=yes control-plane 'sudo systemctl is-active kubelet' 2>/dev/null || true)
  node_ready=$(kubectl get node "$node" --context "$CTX" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  pod=$(kubectl get pod no-seccomp-field -n "$NS" --context "$CTX" -o json 2>/dev/null)
  pod_seccomp=$(jq -r '.spec.securityContext.seccompProfile // .spec.containers[0].securityContext.seccompProfile // "unset"' <<<"$pod" 2>/dev/null)
  effective=$(kubectl exec -n "$NS" no-seccomp-field --context "$CTX" -- grep '^Seccomp:' /proc/1/status 2>/dev/null || true)
  if [[ "$effective_seccomp_default" == "true" && "$kubelet_active" == "active" && "$node_ready" == "True" \
    && "$pod_seccomp" == "unset" && "$effective" == *"2"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$effective_seccomp_default" != "true" ]]; then
      echo "HINT: kubelet's EFFECTIVE, applied configuration (from /api/v1/nodes/${node:-<node>}/proxy/configz, .kubeletconfig.seccompDefault) is not 'true' - a grep on config.yaml's text alone is not enough, because a command-line flag or drop-in could still override the on-disk file. Make sure kubelet actually reloaded this specific field after your change (restart kubelet), and that you edited the file kubelet is really reading."
    elif [[ "$kubelet_active" != "active" || "$node_ready" != "True" ]]; then
      echo "HINT: kubelet is not active or node is NotReady after the config change (kubelet=$kubelet_active node_ready=$node_ready). Check for a YAML syntax error in config.yaml."
    elif [[ "$pod_seccomp" != "unset" ]]; then
      echo "HINT: Pod 'no-seccomp-field' must NOT set any seccompProfile field at all - the whole point of this task is to prove kubelet's own default takes effect when the Pod is silent about it."
    elif [[ "$effective" != *"2"* ]]; then
      echo "HINT: /proc/1/status inside the Pod does not show 'Seccomp: 2' (filter mode) even though the Pod spec has no seccompProfile - kubelet's seccompDefault is not actually applying RuntimeDefault. Check kubelet actually restarted with the new config."
    fi
    echo "effective_seccompDefault=${effective_seccomp_default:-missing} kubelet_active=$kubelet_active node_ready=$node_ready pod_seccomp=$pod_seccomp effective=${effective:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Broken AppArmor profile syntax is fixed and loaded via apparmor_parser -r -v" {
  echo '1' >> /var/work/tests/result/all
  artifact=/var/work/tests/artifacts/8/apparmor-debug.txt
  # -Q (--skip-kernel-load) fully compiles/validates the profile without loading it into
  # the kernel - unlike -p (--preprocess), which is just include-flattening, not a
  # dedicated syntax-check mode (see README/solution for the full explanation).
  parse_check=$(ssh -o BatchMode=yes control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile 2>&1; echo "exit=$?"' 2>/dev/null || true)
  status_output=$(ssh -o BatchMode=yes control-plane 'sudo aa-status 2>/dev/null' 2>/dev/null || true)
  # The student's own apparmor-debug.txt lives inside /var/work/tests, which the shared
  # work_pc_v2 bootstrap template makes world-writable - a student COULD fabricate a
  # 'syntax error' string into that file AFTER already fixing the profile, and a checker
  # that only reads that one file could not tell the difference. Cross-check against the
  # checker-owned bootstrap-baseline-2.txt (captured by master.sh at provision time,
  # BEFORE the student ever saw this profile, by independently running the same parser
  # probe on the still-broken seed file) to confirm the ORIGINAL failure genuinely
  # existed and genuinely was a syntax error, independent of anything the student wrote.
  baseline_dir_owner_mode=$(ssh -o BatchMode=yes control-plane "sudo stat -c '%U:%G %a' /var/lib/cks-lab106-checker" 2>/dev/null || true)
  baseline2_owner_mode=$(ssh -o BatchMode=yes control-plane "sudo stat -c '%U:%G %a' /var/lib/cks-lab106-checker/bootstrap-baseline-2.txt" 2>/dev/null || true)
  baseline2_trust_ok="no"
  if [[ "$baseline_dir_owner_mode" =~ ^root:root\ 0?700$ && "$baseline2_owner_mode" =~ ^root:root\ 0?400$ ]]; then
    baseline2_trust_ok="yes"
  fi
  bootstrap_baseline2=$(ssh -o BatchMode=yes control-plane "sudo cat /var/lib/cks-lab106-checker/bootstrap-baseline-2.txt" 2>/dev/null || true)
  bootstrap_baseline2_ok="no"
  if [[ "$baseline2_trust_ok" == "yes" ]] && grep -qi 'syntax error' <<<"$bootstrap_baseline2"; then
    bootstrap_baseline2_ok="yes"
  fi
  if [[ -s "$artifact" ]] && grep -qi 'syntax error' "$artifact" \
    && [[ "$bootstrap_baseline2_ok" == "yes" ]] \
    && [[ "$parse_check" == *"exit=0"* ]] \
    && [[ "$status_output" == *"k8s-106-broken-profile"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$baseline2_trust_ok" != "yes" ]]; then
      echo "HINT: /var/lib/cks-lab106-checker (dir='$baseline_dir_owner_mode') or its bootstrap-baseline-2.txt (file='$baseline2_owner_mode') is not locked down to root:root 0700/0400 as expected - this is an infrastructure precondition failure, not something you can fix from inside the lab. Contact the lab operator."
    elif [[ "$bootstrap_baseline2_ok" != "yes" ]]; then
      echo "HINT: the checker's own bootstrap-time baseline does not show the expected original syntax error for k8s-106-broken-profile - this is an infrastructure precondition failure, not something you can fix from inside the lab. Contact the lab operator."
    elif ! [[ -s "$artifact" ]] || ! grep -qi 'syntax error' "$artifact"; then
      echo "HINT: apparmor-debug.txt must capture the ORIGINAL syntax error output from 'apparmor_parser -Q' or 'apparmor_parser -r -v' BEFORE you fix the profile - save that evidence first."
    elif [[ "$parse_check" != *"exit=0"* ]]; then
      echo "HINT: The profile still fails to parse after your fix (apparmor_parser exit != 0). Check the reported syntax error line carefully - unmatched braces and typos in rule keywords are the most common cause."
    elif [[ "$status_output" != *"k8s-106-broken-profile"* ]]; then
      echo "HINT: The fixed profile parses cleanly but is not loaded into the kernel - run 'apparmor_parser -r' (reload) explicitly, parsing successfully with '-Q' (skip-kernel-load) alone does not load it."
    fi
    echo "artifact_has_error=$(grep -qi 'syntax error' "$artifact" 2>/dev/null && echo yes || echo no) bootstrap_baseline2_ok=$bootstrap_baseline2_ok baseline2_trust_ok=$baseline2_trust_ok parse_check=$parse_check status_has_profile=$([[ "$status_output" == *"k8s-106-broken-profile"* ]] && echo yes || echo no)"
    result=1
  fi
  [ "$result" -eq 0 ]
}
