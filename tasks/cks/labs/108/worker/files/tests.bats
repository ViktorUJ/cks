#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="policy-108"

record_result() {
  local result="$1"
  echo '1' >> /var/work/tests/result/all
  if [[ "$result" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  return "$result"
}

policy_enforced() {
  kubectl get clusterpolicy "$1" --context "$CTX" -o json 2>/dev/null | \
    jq -e '.spec.validationFailureAction == "Enforce"' >/dev/null
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Kyverno is installed and its admission controller is available" {
  crd=$(kubectl get crd clusterpolicies.kyverno.io --context "$CTX" -o name 2>/dev/null)
  available=$(kubectl get deployment -n kyverno --context "$CTX" -o json 2>/dev/null | \
    jq '[.items[] | select((.status.availableReplicas // 0) > 0)] | length' 2>/dev/null)
  if [[ "$crd" == "customresourcedefinition.apiextensions.k8s.io/clusterpolicies.kyverno.io" && "$available" -ge 1 ]]; then
    result=0
  else
    echo "clusterpolicy_crd=$crd available_kyverno_deployments=$available"
    result=1
  fi
  record_result "$result"
}

@test "2. deny-latest-tag rejects images tagged latest" {
  set +e
  policy_enforced deny-latest-tag
  policy_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: latest-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
  admission_status=$?
  set -e
  if [[ "$policy_status" -eq 0 && "$admission_status" -ne 0 ]]; then result=0; else
    echo "policy_enforced=$policy_status latest_admission_status=$admission_status"; result=1
  fi
  record_result "$result"
}

@test "3. require-run-as-non-root rejects a root-capable Pod" {
  set +e
  policy_enforced require-run-as-non-root
  policy_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: root-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  admission_status=$?
  set -e
  if [[ "$policy_status" -eq 0 && "$admission_status" -ne 0 ]]; then result=0; else
    echo "policy_enforced=$policy_status root_admission_status=$admission_status"; result=1
  fi
  record_result "$result"
}

@test "4. allow-approved-registries admits only approved image registries" {
  set +e
  policy_enforced allow-approved-registries
  policy_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: unapproved-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
  admission_status=$?
  set -e
  if [[ "$policy_status" -eq 0 && "$admission_status" -ne 0 ]]; then result=0; else
    echo "policy_enforced=$policy_status registry_admission_status=$admission_status"; result=1
  fi
  record_result "$result"
}

@test "5. OPTIONAL: add-kyverno-managed-label mutates matching Pods" {
  echo '1' >> /var/work/tests/result/all
  policy=$(kubectl get clusterpolicy add-kyverno-managed-label --context "$CTX" -o json 2>/dev/null)
  set +e
  mutated=$(cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -o json -f - 2>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  admission_status=$?
  set -e
  label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated" 2>/dev/null)
  has_mutate=$(jq -r '[.spec.rules[]? | select(.mutate != null)] | length' <<<"$policy" 2>/dev/null)
  if [[ "$admission_status" -eq 0 && "$label" == "kyverno" && "$has_mutate" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
  else
    echo "OPTIONAL: mutation not ready (admission_status=$admission_status label=$label mutate_rules=$has_mutate)"
  fi
  # Последний этап опционален: check_result его проверяет, но не делает лабу неуспешной.
  true
}
