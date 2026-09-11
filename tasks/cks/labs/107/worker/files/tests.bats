#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
RESTRICTED_NS="psa-restricted-107"
OBSERVE_NS="psa-observe-107"

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
  if [[ "$enforce" == "restricted" && "$version" == "v1.36" && "$rejection_status" -ne 0 && "$rejection" =~ violates[[:space:]]PodSecurity.*restricted ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$enforce" != "restricted" ]]; then
      echo "HINT: Namespace '$RESTRICTED_NS' must have label 'pod-security.kubernetes.io/enforce: restricted'."
    elif [[ "$version" != "v1.36" ]]; then
      echo "HINT: Namespace must also pin 'pod-security.kubernetes.io/enforce-version: v1.36' - without a fixed version, the enforced PSS baseline can silently change on a Kubernetes upgrade."
    else
      echo "HINT: A Pod with hostNetwork: true (an unsafe field) was not rejected by admission. Check the enforce label actually took effect - labels on an existing namespace apply immediately, no restart needed."
    fi
    echo "enforce=$enforce version=$version rejection_status=$rejection_status rejection=$rejection"
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
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  if [[ "$hardened" == "true" && "$phase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$hardened" != "true" ]]; then
      echo "HINT: Pod 'restricted-app' is missing one of the required restricted-level fields: Pod-level runAsNonRoot: true + runAsUser: 1000 + seccompProfile RuntimeDefault, AND per-container allowPrivilegeEscalation: false + privileged: false + capabilities.drop: [ALL] + seccompProfile RuntimeDefault. Check each field individually - a single missing one fails admission under 'restricted'."
    else
      echo "HINT: Pod spec satisfies the restricted profile but is not Running (phase=$phase). Check 'kubectl describe pod' for a scheduling or image-pull issue unrelated to PSA."
    fi
    echo "hardened=$hardened phase=$phase"
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
  if [[ "$host_network" == "true" && ( "$phase" == "Running" || "$phase" == "Pending" ) && "$warning" =~ Warning:.*[Vv]iolat.*PodSecurity.*baseline ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$host_network" != "true" ]]; then
      echo "HINT: Pod 'baseline-audit-sample' must set hostNetwork: true - this deliberately violates baseline so warn/audit have something to report, while still being ADMITTED because this namespace has no enforce label."
    else
      echo "HINT: A hostNetwork Pod applied to '$OBSERVE_NS' did not produce a PodSecurity 'Warning:' mentioning 'baseline' - check that the warn label from test 3 is actually set and that the violating field (hostNetwork) is one baseline actually restricts."
    fi
    echo "hostNetwork=$host_network phase=$phase psa_warning=$warning"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. restricted-app uses read-only root filesystem and writable emptyDir /tmp" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod restricted-app -n "$RESTRICTED_NS" --context "$CTX" -o json 2>/dev/null)
  readonly=$(jq -r '[.spec.containers[]? | .securityContext.readOnlyRootFilesystem == true] | length > 0 and all' <<<"$pod" 2>/dev/null)
  writable_tmp=$(jq -r '
    ([.spec.volumes[]? | select(.name == "writable-tmp" and .emptyDir != null)] | length == 1) and
    ([.spec.containers[]?.volumeMounts[]? | select(.name == "writable-tmp" and .mountPath == "/tmp" and (.readOnly // false) == false)] | length > 0)
  ' <<<"$pod" 2>/dev/null)
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
      echo "HINT: Volume 'writable-tmp' (emptyDir) must be mounted at exactly '/tmp' with readOnly not set to true - the app needs SOME writable path even with a read-only rootfs."
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
  policy_name=$(jq -r '.spec.policyName // ""' <<<"$binding" 2>/dev/null)
  actions=$(jq -r '(.spec.validationActions // []) | index("Deny") != null' <<<"$binding" 2>/dev/null)
  ns_scoped=$(jq -r '(.spec.matchResources.namespaceSelector.matchLabels["kubernetes.io/metadata.name"] // "") == "'"$RESTRICTED_NS"'" or ((.spec.matchResources.namespaceSelector.matchExpressions // [])[] | select(.key == "kubernetes.io/metadata.name" and .operator == "In") | .values | index("'"$RESTRICTED_NS"'") != null)' <<<"$binding" 2>/dev/null)
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
  set -e
  if [[ -n "$policy" && "$policy_name" == "require-no-automount-token" && "$actions" == "true" && "$ns_scoped" == "true" \
    && "$deny_status" -ne 0 && "$deny_output" == *"require-no-automount-token"* && "$deny_output" != *"violates PodSecurity"* \
    && "$allow_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$policy" ]]; then
      echo "HINT: ValidatingAdmissionPolicy 'require-no-automount-token' does not exist. Create it with a CEL expression checking automountServiceAccountToken == false."
    elif [[ "$policy_name" != "require-no-automount-token" || "$actions" != "true" ]]; then
      echo "HINT: ValidatingAdmissionPolicyBinding must reference policyName 'require-no-automount-token' and set validationActions: [Deny]."
    elif [[ "$ns_scoped" != "true" ]]; then
      echo "HINT: The binding's matchResources.namespaceSelector must scope to namespace '$RESTRICTED_NS' specifically - an unscoped binding would affect the whole cluster unexpectedly."
    elif [[ "$deny_status" -eq 0 || "$deny_output" != *"require-no-automount-token"* ]]; then
      echo "HINT: A fully PSA-compliant Pod that omits automountServiceAccountToken: false was NOT denied by your VAP. Check the CEL expression actually evaluates automountServiceAccountToken, not some other field."
    elif [[ "$deny_output" == *"violates PodSecurity"* ]]; then
      echo "HINT: The denial message mentions 'violates PodSecurity' - that means PSA (not your VAP) is doing the rejecting, likely for an unrelated reason. This test needs the VAP-specific denial isolated - make sure the test Pod is otherwise fully PSA-restricted-compliant."
    elif [[ "$allow_status" -ne 0 ]]; then
      echo "HINT: A Pod that DOES set automountServiceAccountToken: false was rejected - it should be allowed. Check your CEL condition logic is not inverted."
    fi
    echo "policy_name=$policy_name actions=$actions ns_scoped=$ns_scoped deny_status=$deny_status deny_output=$deny_output allow_status=$allow_status allow_output=$allow_output"
    result=1
  fi
  [ "$result" -eq 0 ]
}
