#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
RESTRICTED_NS="psa-restricted-107"
OBSERVE_NS="psa-observe-107"
CONTROLLER_NS="psa-controller-107"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. restricted enforce v1.36 is labeled and rejects an unsafe Pod" {
  echo '1' >> /var/work/tests/result/all
  labels=$(kubectl get namespace "$RESTRICTED_NS" --context "$CTX" -o json 2>/dev/null)
  enforce=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce"] // ""' <<<"$labels")
  version=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce-version"] // ""' <<<"$labels")
  system_psa_labels=$(kubectl get namespace kube-system kube-public kube-node-lease \
    --context "$CTX" -o json 2>/dev/null \
    | jq -c '
        [
          .items[] as $ns
          | (($ns.metadata.labels // {}) | to_entries[])
          | select(.key | startswith("pod-security.kubernetes.io/"))
          | {namespace: $ns.metadata.name, key: .key, value: .value}
        ]
      ') || system_psa_labels='[{"error":"unable-to-read-system-namespaces"}]'
  system_psa_clean=$(jq -r 'length == 0' <<<"$system_psa_labels" 2>/dev/null) || system_psa_clean=false
  set +e
  rejection=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: restricted-rejection-check
  namespace: $RESTRICTED_NS
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF_POD
)
  rejection_status=$?
  set -e
  if [[ "$enforce" == "restricted" && "$version" == "v1.36" && "$rejection_status" -ne 0 && "$rejection" =~ violates[[:space:]]PodSecurity.*restricted && "$system_psa_clean" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$enforce" != "restricted" ]]; then
      echo "HINT: Namespace '$RESTRICTED_NS' must have label 'pod-security.kubernetes.io/enforce: restricted'."
    elif [[ "$version" != "v1.36" ]]; then
      echo "HINT: Namespace must also pin 'pod-security.kubernetes.io/enforce-version: v1.36' - without a fixed version, the enforced PSS baseline can silently change on a Kubernetes upgrade."
    elif [[ "$system_psa_clean" != "true" ]]; then
      echo "HINT: Do not apply Pod Security labels to system namespaces in this lab. Remove lab-added pod-security.kubernetes.io/* labels from kube-system, kube-public and kube-node-lease."
    else
      echo "HINT: A Pod with hostNetwork: true (an unsafe field) was not rejected by admission. Check the enforce label actually took effect - labels on an existing namespace apply immediately, no restart needed."
    fi
    echo "enforce=$enforce version=$version system_psa_clean=$system_psa_clean system_psa_labels=$system_psa_labels rejection_status=$rejection_status rejection=$rejection"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. restricted-app is a hardened Pod accepted by restricted" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod restricted-app -n "$RESTRICTED_NS" --context "$CTX" -o json 2>/dev/null)
  hardened=$(jq -r '
    .spec.securityContext.runAsNonRoot == true and
    (.spec.securityContext.runAsUser | tonumber) == 1000 and
    .spec.securityContext.seccompProfile.type == "RuntimeDefault" and
    ([.spec.containers[]? |
      .securityContext.allowPrivilegeEscalation == false and
      .securityContext.privileged == false and
      (.securityContext.capabilities.drop | index("ALL") != null) and
      .securityContext.seccompProfile.type == "RuntimeDefault"
    ] | length > 0 and all)
  ' <<<"$pod" 2>/dev/null)
  effective_uid_1000=$(jq -r '
    (.spec.securityContext.runAsUser == 1000)
    and
    (
      [
        .spec.containers[]?,
        .spec.initContainers[]?,
        .spec.ephemeralContainers[]?
      ]
      | length > 0
      and all(.[]; ((.securityContext.runAsUser // 1000) | tonumber) == 1000)
    )
  ' <<<"$pod" 2>/dev/null) || effective_uid_1000=false
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)

  # Existing Pods are not retroactively rejected when an enforce label is added.
  # Force PodSecurity to re-evaluate every existing Pod in this dedicated namespace
  # by dry-running a change of enforce-version from v1.36 to "latest". On this lab's
  # Kubernetes 1.36 API server, latest resolves to the same v1.36 PSS rules; the dry-run
  # changes nothing, but PodSecurity still reports existing violations as warnings.
  set +e
  psa_recheck=$(kubectl label namespace "$RESTRICTED_NS" \
    --context "$CTX" \
    --dry-run=server \
    --overwrite \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    2>&1)
  psa_recheck_status=$?
  set -e

  psa_recheck_clean=true
  if [[ "$psa_recheck_status" -ne 0 ]] \
    || grep -Fq "existing pods in namespace \"$RESTRICTED_NS\" violate the new PodSecurity enforce level" <<<"$psa_recheck"; then
    psa_recheck_clean=false
  fi

  if [[ "$hardened" == "true" \
    && "$effective_uid_1000" == "true" \
    && "$phase" == "Running" \
    && "$psa_recheck_clean" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$hardened" != "true" ]]; then
      echo "HINT: Pod 'restricted-app' does not match this lab's explicit hardening contract: pod-level runAsNonRoot: true + runAsUser: 1000 + seccompProfile RuntimeDefault, and per-container allowPrivilegeEscalation: false + privileged: false + capabilities.drop: [ALL] + seccompProfile RuntimeDefault. Some requirements are intentionally stricter/more explicit than the minimum PSS 'restricted' contract (including explicit privileged: false, container-level seccomp when pod-level seccomp applies, and exact UID 1000). Fix the lab-required fields, then confirm the Pod is admitted and Running."
    elif [[ "$effective_uid_1000" != "true" ]]; then
      echo "HINT: Pod-level runAsUser: 1000 is overridden by at least one container/init/ephemeral container. Container securityContext overrides Pod securityContext; this lab requires effective UID 1000."
    elif [[ "$phase" != "Running" ]]; then
      echo "HINT: Pod spec satisfies the restricted profile but is not Running (phase=$phase). Check 'kubectl describe pod' for a scheduling or image-pull issue unrelated to PSA."
    else
      echo "HINT: Existing Pods are not retroactively rejected when PSA enforce labels are added. A live server-side dry-run re-evaluation found an existing Pod in '$RESTRICTED_NS' that violates restricted. Fix/recreate 'restricted-app' so its CURRENT spec is actually valid under restricted:v1.36."
    fi
    echo "effective_uid_1000=$effective_uid_1000"
    echo "hardened=$hardened phase=$phase psa_recheck_status=$psa_recheck_status psa_recheck_clean=$psa_recheck_clean psa_recheck=$psa_recheck"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. observe namespace has audit and warn baseline v1.36 without enforce" {
  echo '1' >> /var/work/tests/result/all
  labels=$(kubectl get namespace "$OBSERVE_NS" --context "$CTX" -o json 2>/dev/null)
  audit=$(jq -r '.metadata.labels["pod-security.kubernetes.io/audit"] // ""' <<<"$labels")
  audit_version=$(jq -r '.metadata.labels["pod-security.kubernetes.io/audit-version"] // ""' <<<"$labels")
  warn=$(jq -r '.metadata.labels["pod-security.kubernetes.io/warn"] // ""' <<<"$labels")
  warn_version=$(jq -r '.metadata.labels["pod-security.kubernetes.io/warn-version"] // ""' <<<"$labels")
  enforce=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce"] // ""' <<<"$labels")
  if [[ "$audit" == "baseline" && "$audit_version" == "v1.36" && "$warn" == "baseline" && "$warn_version" == "v1.36" && -z "$enforce" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -n "$enforce" ]]; then
      echo "HINT: Namespace '$OBSERVE_NS' must NOT have an enforce label - this namespace is meant to only observe/report via audit and warn, not actually block anything."
    elif [[ "$audit" != "baseline" || "$warn" != "baseline" ]]; then
      echo "HINT: Both 'pod-security.kubernetes.io/audit' and 'pod-security.kubernetes.io/warn' labels must be set to 'baseline' exactly."
    else
      echo "HINT: Both '-version' labels must be pinned to 'v1.36' exactly, matching the enforce-version convention used elsewhere in this lab."
    fi
    echo "audit=$audit audit_version=$audit_version warn=$warn warn_version=$warn_version enforce=$enforce"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. baseline-audit-sample is admitted and warn reports the baseline violation" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod baseline-audit-sample -n "$OBSERVE_NS" --context "$CTX" -o json 2>/dev/null)
  host_network=$(jq -r '.spec.hostNetwork == true' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  labels=$(kubectl get namespace "$OBSERVE_NS" --context "$CTX" -o json 2>/dev/null)
  enforce=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce"] // ""' <<<"$labels" 2>/dev/null)

  # Positive control: warn/audit must REPORT the baseline violation but must not
  # reject the request. Capture both output and exit status.
  set +e
  warning=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: baseline-warning-check
  namespace: $OBSERVE_NS
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF_POD
)
  warning_status=$?
  set -e

  if [[ "$host_network" == "true" \
    && ( "$phase" == "Running" || "$phase" == "Pending" ) \
    && -z "$enforce" \
    && "$warning_status" -eq 0 \
    && "$warning" =~ Warning:.*[Vv]iolat.*PodSecurity.*baseline ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$host_network" != "true" ]]; then
      echo "HINT: Pod 'baseline-audit-sample' must set hostNetwork: true - this deliberately violates baseline so warn/audit have something to report."
    elif [[ "$phase" != "Running" && "$phase" != "Pending" ]]; then
      echo "HINT: Pod 'baseline-audit-sample' must have been admitted by the API and exist as Running/Pending (phase=$phase)."
    elif [[ -n "$enforce" ]]; then
      echo "HINT: Namespace '$OBSERVE_NS' must not have an enforce label. Task 4 is proving that warn/audit report a violation without blocking it."
    elif [[ "$warning_status" -ne 0 ]]; then
      echo "HINT: The current server-side dry-run was rejected (exit=$warning_status). warn/audit must not block this baseline-violating Pod; remove the admission control that is denying it before treating this task as complete."
    else
      echo "HINT: A hostNetwork Pod applied to '$OBSERVE_NS' did not produce a PodSecurity 'Warning:' mentioning 'baseline' - check that the warn label from test 3 is actually set and that the violating field (hostNetwork) is one baseline actually restricts."
    fi
    echo "hostNetwork=$host_network phase=$phase enforce=$enforce warning_status=$warning_status psa_warning=$warning"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. restricted-app uses read-only root filesystem and writable emptyDir /tmp" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod restricted-app -n "$RESTRICTED_NS" --context "$CTX" -o json 2>/dev/null)
  readonly=$(jq -r '[.spec.containers[]? | .securityContext.readOnlyRootFilesystem == true] | length > 0 and all' <<<"$pod" 2>/dev/null)
  writable_tmp=$(jq -r '
    ([.spec.volumes[]?
      | select(.name == "writable-tmp" and .emptyDir != null)]
     | length == 1)
    and
    ([.spec.containers[]?] | length > 0)
    and
    all(
      .spec.containers[]?;
      ([.volumeMounts[]?
        | select(
            .name == "writable-tmp"
            and .mountPath == "/tmp"
            and (.readOnly // false) == false
          )]
       | length == 1)
      and
      ([.volumeMounts[]?
        | select(
            (.readOnly // false) == false
            and (.name != "writable-tmp" or .mountPath != "/tmp")
          )]
       | length == 0)
    )
  ' <<<"$pod" 2>/dev/null) || writable_tmp=false
  host_paths=$(jq -r '[.spec.volumes[]? | select(.hostPath != null)] | length' <<<"$pod" 2>/dev/null)
  set +e
  root_write=$(kubectl exec -n "$RESTRICTED_NS" restricted-app --context "$CTX" -- sh -c 'touch /root-write-test.txt' 2>&1)
  root_write_status=$?
  tmp_write=$(kubectl exec -n "$RESTRICTED_NS" restricted-app --context "$CTX" -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt' 2>&1)
  tmp_write_status=$?
  set -e
  if [[ "$readonly" == "true" && "$writable_tmp" == "true" && "$host_paths" == "0" \
    && "$root_write_status" -ne 0 && "$root_write" == *"Read-only file system"* \
    && "$tmp_write_status" -eq 0 && "$tmp_write" == *"probe"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$readonly" != "true" ]]; then
      echo "HINT: All containers must set securityContext.readOnlyRootFilesystem: true."
    elif [[ "$writable_tmp" != "true" ]]; then
      echo "HINT: Each regular container must have exactly one writable mount: volume 'writable-tmp' at '/tmp'. All other volumeMounts must set readOnly: true."
    elif [[ "$host_paths" != "0" ]]; then
      echo "HINT: Do not use hostPath for the writable directory - it must be an emptyDir, hostPath would leak data to the node's filesystem."
    elif [[ "$root_write_status" -eq 0 ]]; then
      echo "HINT: Writing to the root filesystem (/root-write-test.txt) succeeded - it should fail with 'Read-only file system' if readOnlyRootFilesystem is truly in effect."
    elif [[ "$tmp_write_status" -ne 0 ]]; then
      echo "HINT: Writing to /tmp failed - the writable-tmp emptyDir mount is not actually working at that path. Check volumeMounts.mountPath spelling."
    fi
    echo "read_only_rootfs=$readonly writable_tmp=$writable_tmp host_paths=$host_paths root_write_status=$root_write_status root_write=$root_write tmp_write_status=$tmp_write_status tmp_write=$tmp_write"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. native ValidatingAdmissionPolicy denies missing automount opt-out and allows the safe equivalent" {
  echo '1' >> /var/work/tests/result/all
  policy=$(kubectl get validatingadmissionpolicy require-no-automount-token --context "$CTX" -o json 2>/dev/null)
  binding=$(kubectl get validatingadmissionpolicybinding require-no-automount-token-binding --context "$CTX" -o json 2>/dev/null)
  bindings_for_policy=$(kubectl get validatingadmissionpolicybindings \
    --context "$CTX" -o json 2>/dev/null \
    | jq -c '[.items[] | select(.spec.policyName == "require-no-automount-token") | .metadata.name] | sort') || bindings_for_policy='[]'
  binding_set_exact=$(jq -r 'length == 1 and .[0] == "require-no-automount-token-binding"' \
    <<<"$bindings_for_policy" 2>/dev/null) || binding_set_exact=false
  policy_name=$(jq -r '.spec.policyName // ""' <<<"$binding" 2>/dev/null)
  actions=$(jq -r '(.spec.validationActions // []) | index("Deny") != null' <<<"$binding" 2>/dev/null)
  # Structural scope proof: the selector must pin the immutable namespace-name label to
  # exactly RESTRICTED_NS (matchLabels, or an 'In' with a single value). A single negative
  # probe in OBSERVE_NS cannot tell "only RESTRICTED_NS" from "everything except OBSERVE_NS".
  selector_exact=$(jq -r --arg ns "$RESTRICTED_NS" '
      (.spec.matchResources.namespaceSelector // {}) as $s
      | ($s.matchLabels // {}) as $ml
      | ($s.matchExpressions // []) as $me
      | (
          ([($ml | keys[]) | . == "kubernetes.io/metadata.name"] | all)
          and ([$me[]? | .key == "kubernetes.io/metadata.name"] | all)
          and (
          (($ml["kubernetes.io/metadata.name"] // "") == $ns)
          or
          any($me[]?;
              .key == "kubernetes.io/metadata.name"
              and .operator == "In"
              and ((.values // []) | length) == 1
              and .values[0] == $ns)
          )
        )
    ' <<<"$binding" 2>/dev/null) || selector_exact=false
  # No extra per-object/per-request scope filters: a label-based objectSelector or a false
  # matchCondition silently exempts part of the Pods inside the namespace from the policy.
  policy_match_conditions_empty=$(jq -r '((.spec.matchConditions // []) | length) == 0' <<<"$policy" 2>/dev/null) || policy_match_conditions_empty=false
  # CEL must depend ONLY on object.spec.automountServiceAccountToken as its admission-data
  # source. This is a dependency check, not a syntax allowlist: any correct CEL form
  # (has(), optional selection '.?field.orValue(..)', ternaries, ...) is fine because the live
  # missing/false/true probes validate the semantics. Other data roots are not allowed.
  validation_dependency_ok="true"
  validation_count=$(jq -r '(.spec.validations // []) | length' <<<"$policy" 2>/dev/null) || validation_count=0
  [[ "$validation_count" -ge 1 ]] 2>/dev/null || validation_dependency_ok="false"
  while IFS= read -r expr; do
    [[ -n "$expr" ]] || continue
    # Normalise CEL optional selection (object.spec.?field) for dependency analysis only.
    normalized=$(tr -d '[:space:]' <<<"$expr" | tr -d '?')
    if [[ "$normalized" != *"object.spec.automountServiceAccountToken"* ]]; then
      validation_dependency_ok="false"
      break
    fi
    rest="${normalized//object.spec.automountServiceAccountToken/}"
    if grep -Eq '(^|[^[:alnum:]_])(object|oldObject|request|params|namespaceObject|variables|authorizer)([^[:alnum:]_]|$)' <<<"$rest"; then
      validation_dependency_ok="false"
      break
    fi
  done < <(jq -r '.spec.validations[]?.expression // empty' <<<"$policy" 2>/dev/null)
  policy_variables_empty=$(jq -r '((.spec.variables // []) | length) == 0' <<<"$policy" 2>/dev/null) || policy_variables_empty=false
  policy_param_kind_empty=$(jq -r '(.spec.paramKind == null)' <<<"$policy" 2>/dev/null) || policy_param_kind_empty=false
  policy_audit_annotations_empty=$(jq -r '((.spec.auditAnnotations // []) | length) == 0' \
    <<<"$policy" 2>/dev/null) || policy_audit_annotations_empty=false
  # Resource/operation scope: exactly core/v1 pods for CREATE and UPDATE, no excludes; the
  # Binding intersects with the policy, so it must not add its own resourceRules/excludes.
  policy_rules_exact=$(jq -r '
      (.spec.matchConstraints.resourceRules // []) as $rules
      | (
          ($rules | length) > 0
          and all($rules[];
                ((.apiGroups // []) == [""])
                and ((.apiVersions // []) == ["v1"])
                and ((.resources // []) == ["pods"])
                and (((.resourceNames // []) | length) == 0)
                and (.scope == null or .scope == "" or .scope == "*" or .scope == "Namespaced")
                and (((.operations // []) | length) > 0)
                and all(.operations[]; . == "CREATE" or . == "UPDATE"))
          and (([$rules[].operations[]] | index("CREATE")) != null)
          and (([$rules[].operations[]] | index("UPDATE")) != null)
          and (((.spec.matchConstraints.excludeResourceRules // []) | length) == 0)
        )
    ' <<<"$policy" 2>/dev/null) || policy_rules_exact=false
  binding_resource_rules_empty=$(jq -r '
      ((.spec.matchResources.resourceRules // []) | length) == 0
      and ((.spec.matchResources.excludeResourceRules // []) | length) == 0
    ' <<<"$binding" 2>/dev/null) || binding_resource_rules_empty=false
  # Namespace scoping belongs only in the Binding; a policy-side namespaceSelector is a
  # second (possibly mutable-label) scope that is intersected with the Binding's.
  policy_namespace_selector_empty=$(jq -r '
      (.spec.matchConstraints.namespaceSelector // {}) as $s
      | ((($s.matchLabels // {}) | length) == 0 and (($s.matchExpressions // []) | length) == 0)
    ' <<<"$policy" 2>/dev/null) || policy_namespace_selector_empty=false
  policy_object_selector_empty=$(jq -r '
      (.spec.matchConstraints.objectSelector // {}) as $s
      | ((($s.matchLabels // {}) | length) == 0 and (($s.matchExpressions // []) | length) == 0)
    ' <<<"$policy" 2>/dev/null) || policy_object_selector_empty=false
  binding_object_selector_empty=$(jq -r '
      (.spec.matchResources.objectSelector // {}) as $s
      | ((($s.matchLabels // {}) | length) == 0 and (($s.matchExpressions // []) | length) == 0)
    ' <<<"$binding" 2>/dev/null) || binding_object_selector_empty=false
  set +e
  # This Pod is fully PSA restricted-compliant (non-root, seccomp, drop ALL, no escalation)
  # but omits automountServiceAccountToken: false. PSA alone must accept it; only the new
  # VAP is expected to deny it, so a PSA-level "violates PodSecurity" message here would
  # indicate the test is not isolating the VAP-specific control.
  deny_output=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
  namespace: $RESTRICTED_NS
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF_POD
)
  deny_status=$?
  allow_output=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
  namespace: $RESTRICTED_NS
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF_POD
)
  allow_status=$?
  # Abuse control for the boolean: an explicit 'true' is PSA-compliant too, so the policy
  # (not PSA) must deny it. A policy that only checks has(...automountServiceAccountToken)
  # would pass the missing/false probes above while allowing the dangerous value.
  true_output=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: vap-explicit-true-check
  namespace: $RESTRICTED_NS
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF_POD
)
  true_status=$?
  expected_vap_reason="ValidatingAdmissionPolicy 'require-no-automount-token' with binding 'require-no-automount-token-binding' denied request:"
  # The denial prefix depends on the VAP's reason ("... is invalid: : ..." for the default
  # Invalid reason, "... is forbidden: ..." for Forbidden), so match the full attribution
  # phrase generated by the API server instead of assuming one prefix.
  # A validation message is arbitrary user-controlled text and can itself contain a string
  # that looks like another VAP attribution, so do NOT search for it anywhere: take the
  # FIRST attribution, which the API server emits before the policy's own message.
  extract_first_vap_attribution() {
    grep -oE "ValidatingAdmissionPolicy '[^']+' with binding '[^']+' denied request:" <<<"$1" | head -n1
  }
  deny_vap_reason=$(extract_first_vap_attribution "$deny_output")
  true_vap_reason=$(extract_first_vap_attribution "$true_output")
  deny_attributed=false
  true_attributed=false
  [[ "$deny_vap_reason" == "$expected_vap_reason" ]] && deny_attributed=true
  [[ "$true_vap_reason" == "$expected_vap_reason" ]] && true_attributed=true
  # Functional scope proof: the SAME probe Pod (PSA-compliant, missing the automount
  # opt-out) applied to a DIFFERENT namespace must NOT be denied by this VAP - a Binding
  # whose namespaceSelector merely CONTAINS RESTRICTED_NS among several matched
  # namespaces (e.g. matchExpressions.values: [RESTRICTED_NS, OBSERVE_NS]) would still
  # satisfy a structural 'does the selector mention RESTRICTED_NS' check, yet would
  # incorrectly ALSO deny this same Pod shape in OBSERVE_NS - a cluster-wide scope
  # regression that a purely structural selector check cannot catch. OBSERVE_NS has
  # warn/audit baseline (from task 3) but no enforce, so PSA itself will not deny this
  # Pod there either - a denial in OBSERVE_NS can only mean the VAP's Binding scope is
  # broader than intended.
  other_ns_output=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: vap-scope-check
  namespace: $OBSERVE_NS
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF_POD
)
  other_ns_status=$?
  set -e
  if [[ -n "$policy" && "$policy_name" == "require-no-automount-token" && "$actions" == "true" \
    && "$binding_set_exact" == "true" \
    && "$deny_status" -ne 0 && "$deny_attributed" == "true" && "$deny_output" != *"violates PodSecurity"* \
    && "$allow_status" -eq 0 && "$other_ns_status" -eq 0 \
    && "$true_status" -ne 0 && "$true_attributed" == "true" && "$true_output" != *"violates PodSecurity"* \
    && "$selector_exact" == "true" \
    && "$policy_match_conditions_empty" == "true" && "$policy_object_selector_empty" == "true" \
    && "$policy_namespace_selector_empty" == "true" \
    && "$binding_object_selector_empty" == "true" && "$validation_dependency_ok" == "true" \
    && "$policy_variables_empty" == "true" && "$policy_param_kind_empty" == "true" \
    && "$policy_audit_annotations_empty" == "true" \
    && "$policy_rules_exact" == "true" && "$binding_resource_rules_empty" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$policy" ]]; then
      echo "HINT: ValidatingAdmissionPolicy 'require-no-automount-token' does not exist. Create it with a CEL expression checking automountServiceAccountToken == false."
    elif [[ "$binding_set_exact" != "true" ]]; then
      echo "HINT: This lab expects exactly one binding for policy 'require-no-automount-token': 'require-no-automount-token-binding'. Remove extra bindings that extend the policy to other namespaces."
    elif [[ "$policy_name" != "require-no-automount-token" || "$actions" != "true" ]]; then
      echo "HINT: ValidatingAdmissionPolicyBinding must reference policyName 'require-no-automount-token' and set validationActions: [Deny]."
    elif [[ "$policy_match_conditions_empty" != "true" || "$policy_object_selector_empty" != "true" || "$policy_namespace_selector_empty" != "true" || "$binding_object_selector_empty" != "true" ]]; then
      echo "HINT: Task 6 must cover every Pod in '$RESTRICTED_NS'. Do not narrow the policy with spec.matchConditions, matchConstraints.objectSelector, or matchConstraints.namespaceSelector, and do not use a Binding objectSelector. Namespace scoping for this lab belongs only in the Binding exact namespaceSelector for '$RESTRICTED_NS'."
    elif [[ "$validation_dependency_ok" != "true" || "$policy_variables_empty" != "true" || "$policy_param_kind_empty" != "true" || "$policy_audit_annotations_empty" != "true" ]]; then
      echo "HINT: Task 6 admission behavior must depend only on object.spec.automountServiceAccountToken. Do not use oldObject/request/params/namespaceObject/variables/authorizer, other object fields, or auditAnnotations in this lab; auditAnnotations contain independent CEL expressions whose runtime errors can change admission behavior through failurePolicy."
    elif [[ "$policy_rules_exact" != "true" || "$binding_resource_rules_empty" != "true" ]]; then
      echo "HINT: Task 6 VAP must match all core/v1 Pods (no resourceNames restriction) for CREATE and UPDATE, with Namespaced/unspecified scope and no excludeResourceRules. The Binding must not add resourceRules/excludeResourceRules."
    elif [[ "$deny_attributed" != "true" || "$true_attributed" != "true" ]]; then
      echo "HINT: The denial must come from ValidatingAdmissionPolicy 'require-no-automount-token' through binding 'require-no-automount-token-binding'. A denial from another admission policy is not proof that the required policy works."
    elif [[ "$deny_status" -eq 0 || "$deny_output" != *"require-no-automount-token"* ]]; then
      echo "HINT: A fully PSA-compliant Pod that omits automountServiceAccountToken: false was NOT denied by your VAP. Check the CEL expression actually evaluates automountServiceAccountToken, not some other field."
    elif [[ "$deny_output" == *"violates PodSecurity"* ]]; then
      echo "HINT: The denial message mentions 'violates PodSecurity' - that means PSA (not your VAP) is doing the rejecting, likely for an unrelated reason. This test needs the VAP-specific denial isolated - make sure the test Pod is otherwise fully PSA-restricted-compliant."
    elif [[ "$allow_status" -ne 0 ]]; then
      echo "HINT: A Pod that DOES set automountServiceAccountToken: false was rejected - it should be allowed. Check your CEL condition logic is not inverted."
    elif [[ "$true_status" -eq 0 || "$true_output" != *"require-no-automount-token"* ]]; then
      echo "HINT: A PSA-compliant Pod with automountServiceAccountToken: true was not denied by 'require-no-automount-token'. The policy must require the value to be explicitly false, not merely require the field to exist."
    elif [[ "$other_ns_status" -ne 0 ]]; then
      echo "HINT: The SAME PSA-compliant Pod shape (missing automountServiceAccountToken: false) was DENIED in namespace '$OBSERVE_NS' too - your Binding's matchResources.namespaceSelector matches more than just '$RESTRICTED_NS'. Scope it to exactly that one namespace, e.g. matchLabels: {kubernetes.io/metadata.name: $RESTRICTED_NS}, not a broader matchExpressions list that happens to include it alongside other namespaces."
    fi
    if [[ "$selector_exact" != "true" && "$other_ns_status" -eq 0 ]]; then
      echo "HINT: Binding namespaceSelector must contain an exact namespace-name constraint for '$RESTRICTED_NS' using kubernetes.io/metadata.name=<namespace> (matchLabels or In with exactly one value). Merely excluding '$OBSERVE_NS' or using a broader selector is not enough."
    fi
    echo "bindings_for_policy=$bindings_for_policy binding_set_exact=$binding_set_exact deny_attributed=$deny_attributed true_attributed=$true_attributed deny_vap_reason=$deny_vap_reason true_vap_reason=$true_vap_reason policy_namespace_selector_empty=$policy_namespace_selector_empty policy_rules_exact=$policy_rules_exact binding_resource_rules_empty=$binding_resource_rules_empty policy_variables_empty=$policy_variables_empty policy_param_kind_empty=$policy_param_kind_empty policy_audit_annotations_empty=$policy_audit_annotations_empty validation_count=$validation_count validation_dependency_ok=$validation_dependency_ok policy_match_conditions_empty=$policy_match_conditions_empty policy_object_selector_empty=$policy_object_selector_empty binding_object_selector_empty=$binding_object_selector_empty selector_exact=$selector_exact true_status=$true_status true_output=$true_output policy_name=$policy_name actions=$actions deny_status=$deny_status deny_output=$deny_output allow_status=$allow_status allow_output=$allow_output other_ns_status=$other_ns_status other_ns_output=$other_ns_output"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. controller-app survives controller-driven Pod recreation under enforce=restricted" {
  echo '1' >> /var/work/tests/result/all
  labels=$(kubectl get namespace "$CONTROLLER_NS" --context "$CTX" -o json 2>/dev/null)
  enforce=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce"] // ""' <<<"$labels")
  version=$(jq -r '.metadata.labels["pod-security.kubernetes.io/enforce-version"] // ""' <<<"$labels")

  dep=$(kubectl -n "$CONTROLLER_NS" get deploy controller-app --context "$CTX" -o json 2>/dev/null)
  dep_uid=$(jq -r '.metadata.uid // ""' <<<"$dep" 2>/dev/null)
  hardened=$(jq -r '
    (.spec.template.spec.securityContext.runAsNonRoot == true) and
    (.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation == false) and
    ((.spec.template.spec.containers[0].securityContext.capabilities.drop // []) | index("ALL") != null) and
    ((.spec.template.spec.securityContext.seccompProfile.type == "RuntimeDefault") or
     (.spec.template.spec.containers[0].securityContext.seccompProfile.type == "RuntimeDefault"))
  ' <<<"$dep" 2>/dev/null)

  replicas=$(jq -r '.spec.replicas // 0' <<<"$dep" 2>/dev/null)
  template_app_label=$(jq -r '.spec.template.metadata.labels.app // ""' <<<"$dep" 2>/dev/null)
  # A Ready Pod from an OLD ReplicaSet is not proof that the CURRENT Deployment
  # template was fixed. Require the Deployment controller to have observed the
  # current generation and completed the rollout before deleting any Pod.
  rollout_current=$(jq -r '
      (.metadata.generation // 0) as $generation
      | (.status.observedGeneration // 0) as $observed
      | (
          $generation > 0
          and $observed == $generation
          and (.status.updatedReplicas // 0) == 1
          and (.status.readyReplicas // 0) == 1
          and (.status.availableReplicas // 0) == 1
          and (.status.unavailableReplicas // 0) == 0
        )
    ' <<<"$dep" 2>/dev/null) || rollout_current=false

  deployment_rs_uids=$(kubectl -n "$CONTROLLER_NS" get replicasets \
    --context "$CTX" -o json 2>/dev/null \
    | jq -c --arg dep_uid "$dep_uid" '
        [
          .items[]
          | select(
              any(
                .metadata.ownerReferences[]?;
                .controller == true
                and .kind == "Deployment"
                and .uid == $dep_uid
              )
            )
          | .metadata.uid
        ]
      ') || deployment_rs_uids='[]'
  deployment_rs_count=$(jq -r 'length' <<<"$deployment_rs_uids" 2>/dev/null) || deployment_rs_count=0

  old_pods=$(kubectl -n "$CONTROLLER_NS" get pods -l app=controller-app --context "$CTX" -o json 2>/dev/null)
  owned_old_pods=$(jq -c --argjson rs_uids "$deployment_rs_uids" '
      [
        .items[]
        | select(.metadata.deletionTimestamp == null)
        | select(
            any(
              .metadata.ownerReferences[]?;
              .controller == true
              and .kind == "ReplicaSet"
              and (
                .uid as $owner_uid
                | any($rs_uids[]; . == $owner_uid)
              )
            )
          )
      ]
    ' <<<"$old_pods" 2>/dev/null) || owned_old_pods='[]'
  old_count=$(jq -r 'length' <<<"$owned_old_pods" 2>/dev/null) || old_count=0
  old_name=""
  old_uid=""
  old_ready="false"
  if [[ "$old_count" == "1" ]]; then
    old_name=$(jq -r '.[0].metadata.name // ""' <<<"$owned_old_pods")
    old_uid=$(jq -r '.[0].metadata.uid // ""' <<<"$owned_old_pods")
    old_ready=$(jq -r 'any(.[0].status.conditions[]?; .type == "Ready" and .status == "True")' <<<"$owned_old_pods" 2>/dev/null)
  fi
  recreated=false
  new_uid=""
  delete_status=1
  delete_output=""
  if [[ -n "$dep_uid" \
    && "$deployment_rs_count" -ge 1 \
    && "$replicas" == "1" \
    && "$template_app_label" == "controller-app" \
    && "$rollout_current" == "true" \
    && "$old_count" == "1" \
    && -n "$old_name" \
    && -n "$old_uid" \
    && "$old_ready" == "true" ]]; then
    set +e
    delete_output=$(kubectl -n "$CONTROLLER_NS" delete pod "$old_name" \
      --context "$CTX" --wait=true 2>&1)
    delete_status=$?
    set -e

    if [[ "$delete_status" -eq 0 ]]; then
      for i in $(seq 1 24); do
        current_rs_uids=$(kubectl -n "$CONTROLLER_NS" get replicasets \
          --context "$CTX" -o json 2>/dev/null \
          | jq -c --arg dep_uid "$dep_uid" '
              [
                .items[]
                | select(
                    any(
                      .metadata.ownerReferences[]?;
                      .controller == true
                      and .kind == "Deployment"
                      and .uid == $dep_uid
                    )
                  )
                | .metadata.uid
              ]
            ') || current_rs_uids='[]'
        replacement=$(kubectl -n "$CONTROLLER_NS" get pods \
          -l app=controller-app --context "$CTX" -o json 2>/dev/null)
        new_uid=$(jq -r \
          --arg old "$old_uid" \
          --argjson rs_uids "$current_rs_uids" '
            [
              .items[]
              | select(.metadata.uid != $old)
              | select(.metadata.deletionTimestamp == null)
              | select(
                  any(
                    .metadata.ownerReferences[]?;
                    .controller == true
                    and .kind == "ReplicaSet"
                    and (
                      .uid as $owner_uid
                      | any($rs_uids[]; . == $owner_uid)
                    )
                  )
                )
              | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))
            ]
            | if length == 1 then .[0].metadata.uid else "" end
          ' <<<"$replacement" 2>/dev/null)
        if [[ -n "$new_uid" ]]; then
          recreated=true
          break
        fi
        sleep 5
      done
    fi
  fi

  # Negative control: an unrelated unsafe Pod must still be denied in this
  # namespace - proves the recreation above succeeded because the template is
  # actually compliant, not because enforce stopped being active.
  set +e
  unsafe=$(kubectl apply --context "$CTX" --dry-run=server -f - 2>&1 <<EOF_POD
apiVersion: v1
kind: Pod
metadata:
  name: controller-unsafe-check
  namespace: $CONTROLLER_NS
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF_POD
)
  unsafe_status=$?
  set -e

  if [[ "$enforce" == "restricted" \
    && "$version" == "v1.36" \
    && "$hardened" == "true" \
    && -n "$dep_uid" \
    && "$deployment_rs_count" -ge 1 \
    && "$replicas" == "1" \
    && "$template_app_label" == "controller-app" \
    && "$rollout_current" == "true" \
    && "$old_count" == "1" \
    && "$old_ready" == "true" \
    && "$delete_status" -eq 0 \
    && "$recreated" == "true" \
    && -n "$new_uid" \
    && "$new_uid" != "$old_uid" \
    && "$unsafe_status" -ne 0 \
    && "$unsafe" =~ violates[[:space:]]PodSecurity ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$dep_uid" ]]; then
      echo "HINT: Deployment 'controller-app' was not found or has no UID."
    elif [[ "$deployment_rs_count" -lt 1 ]]; then
      echo "HINT: No ReplicaSet owned by Deployment 'controller-app' was found. A same-label ReplicaSet owned by another controller does not satisfy this task."
    elif [[ "$replicas" != "1" ]]; then
      echo "HINT: Deployment controller-app must have replicas: 1 for this scenario."
    elif [[ "$template_app_label" != "controller-app" ]]; then
      echo "HINT: Deployment Pod template must have label app=controller-app; otherwise the lab's delete/recreate probe cannot target the controller-owned Pod."
    elif [[ "$old_count" != "1" || "$old_ready" != "true" ]]; then
      echo "HINT: Before deletion there must be exactly one Ready Pod whose controller ownerReference points to a ReplicaSet owned by Deployment 'controller-app'. A Pod that only shares label app=controller-app is not enough."
    elif [[ "$rollout_current" != "true" ]]; then
      echo "HINT: Deployment 'controller-app' is not fully rolled out to its CURRENT template. Require observedGeneration==generation and exactly one updated/ready/available replica before testing recreation; a Ready Pod from an older ReplicaSet is not proof that the current template works."
    elif [[ "$delete_status" -ne 0 ]]; then
      echo "HINT: The checker could not delete the original Deployment-owned Pod: $delete_output"
    elif [[ "$recreated" != "true" ]]; then
      echo "HINT: After deleting the original Deployment-owned Pod, no NEW Ready Pod owned by a ReplicaSet of the same Deployment UID appeared. Check 'kubectl -n $CONTROLLER_NS describe rs' and namespace events for the current PodSecurity admission failure."
    elif [[ "$unsafe_status" -eq 0 || ! "$unsafe" =~ violates[[:space:]]PodSecurity ]]; then
      echo "HINT: The namespace no longer proves restricted enforcement: the independent unsafe Pod was not rejected by PodSecurity."
    else
      echo "HINT: $CONTROLLER_NS must enforce restricted:v1.36 and controller-app's CURRENT Pod template must be PSS-restricted-compliant so its own ReplicaSet can recreate a Ready Pod after deletion."
    fi
    echo "dep_uid=$dep_uid deployment_rs_uids=$deployment_rs_uids deployment_rs_count=$deployment_rs_count rollout_current=$rollout_current replicas=$replicas template_app_label=$template_app_label old_count=$old_count old_name=$old_name old_uid=$old_uid old_ready=$old_ready delete_status=$delete_status delete_output=$delete_output recreated=$recreated new_uid=$new_uid enforce=$enforce version=$version hardened=$hardened unsafe_status=$unsafe_status unsafe=$unsafe"
    result=1
  fi
  [ "$result" -eq 0 ]
}
