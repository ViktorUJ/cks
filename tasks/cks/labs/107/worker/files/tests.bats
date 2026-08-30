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
    echo "audit=$audit audit_version=$audit_version warn=$warn warn_version=$warn_version enforce=$enforce"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. baseline-audit-sample is admitted for audit and warn observation" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod baseline-audit-sample -n "$OBSERVE_NS" --context "$CTX" -o json 2>/dev/null)
  host_network=$(jq -r '.spec.hostNetwork == true' <<<"$pod" 2>/dev/null)
  phase=$(jq -r '.status.phase // ""' <<<"$pod" 2>/dev/null)
  if [[ "$host_network" == "true" && ( "$phase" == "Running" || "$phase" == "Pending" ) ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "hostNetwork=$host_network phase=$phase"
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
  if [[ "$readonly" == "true" && "$writable_tmp" == "true" && "$host_paths" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "read_only_rootfs=$readonly writable_tmp=$writable_tmp host_paths=$host_paths"
    result=1
  fi
  [ "$result" -eq 0 ]
}
