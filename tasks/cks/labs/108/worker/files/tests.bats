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
  kubectl get validatingpolicy "$1" --context "$CTX" -o json 2>/dev/null | \
    jq -e '.apiVersion == "policies.kyverno.io/v1" and (.spec.validationActions | index("Deny") != null)' >/dev/null
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Kyverno is installed and its admission controller is available" {
  crd=$(kubectl get crd validatingpolicies.policies.kyverno.io --context "$CTX" -o name 2>/dev/null)
  version=$(kubectl get deployment -n kyverno --context "$CTX" -l app.kubernetes.io/part-of=kyverno -o json 2>/dev/null | jq -r '[.items[].spec.template.spec.containers[].image | select(test("kyverno"))][0] // ""')
  available=$(kubectl get deployment -n kyverno --context "$CTX" -o json 2>/dev/null | \
    jq '[.items[] | select((.status.availableReplicas // 0) > 0)] | length' 2>/dev/null)
  if [[ "$crd" == "customresourcedefinition.apiextensions.k8s.io/validatingpolicies.policies.kyverno.io" && "$version" == *v1.19.* && "$available" -ge 1 ]]; then
    result=0
  else
    echo "validatingpolicy_crd=$crd kyverno_image=$version available_kyverno_deployments=$available"
    result=1
  fi
  record_result "$result"
}

@test "2. deny-latest-tag rejects latest in containers, initContainers, and ephemeralContainers" {
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
  main_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: latest-init-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause:latest
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  init_status=$?

  kubectl delete pod ephemeral-policy-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl run ephemeral-policy-base -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  kubectl wait pod/ephemeral-policy-base -n "$NS" --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  base_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:latest --profile=general -- true >/dev/null 2>&1
  ephemeral_latest_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true >/dev/null 2>&1
  ephemeral_trusted_status=$?
  kubectl delete pod ephemeral-policy-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  set -e
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$init_status" -ne 0 && "$base_status" -eq 0 && "$ephemeral_latest_status" -ne 0 && "$ephemeral_trusted_status" -eq 0 ]]; then result=0; else
    echo "policy_enforced=$policy_status main=$main_status init=$init_status base=$base_status ephemeral_latest=$ephemeral_latest_status ephemeral_trusted=$ephemeral_trusted_status"; result=1
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

@test "4. allow-approved-registries blocks bypasses and admits trusted images in all container lists" {
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
  main_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: unapproved-init-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  init_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: approved-main-and-init
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/e2e-test-images/busybox:1.36-1
  containers:
  - name: app
    image: ghcr.io/cks-lab/app:1.0.0
EOF
  trusted_lists_status=$?

  # Reuse a real running trusted Pod to exercise the ephemeralcontainers subresource.
  kubectl delete pod registry-ephemeral-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl run registry-ephemeral-base -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  kubectl wait pod/registry-ephemeral-base -n "$NS" --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  base_status=$?
  kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --image=docker.io/library/busybox:1.36 --profile=general -- true >/dev/null 2>&1
  ephemeral_untrusted_status=$?
  kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true >/dev/null 2>&1
  ephemeral_trusted_status=$?
  kubectl delete pod registry-ephemeral-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  set -e
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$init_status" -ne 0 && "$trusted_lists_status" -eq 0 && "$base_status" -eq 0 && "$ephemeral_untrusted_status" -ne 0 && "$ephemeral_trusted_status" -eq 0 ]]; then result=0; else
    echo "policy_enforced=$policy_status main=$main_status init=$init_status trusted_lists=$trusted_lists_status base=$base_status ephemeral_untrusted=$ephemeral_untrusted_status ephemeral_trusted=$ephemeral_trusted_status"; result=1
  fi
  record_result "$result"
}

@test "5. OPTIONAL: add-kyverno-managed-label mutates matching Pods" {
  echo '1' >> /var/work/tests/result/all
  policy=$(kubectl get mutatingpolicy add-kyverno-managed-label --context "$CTX" -o json 2>/dev/null)
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
  has_mutate=$(jq -r '(.spec.mutations // []) | length' <<<"$policy" 2>/dev/null)
  if [[ "$admission_status" -eq 0 && "$label" == "kyverno" && "$has_mutate" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
  else
    echo "OPTIONAL: mutation not ready (admission_status=$admission_status label=$label mutate_rules=$has_mutate)"
  fi
  # Последний этап опционален: check_result его проверяет, но не делает лабу неуспешной.
  true
}
