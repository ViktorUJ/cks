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

control_plane() {
  kubectl get nodes --context "$CTX" -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

node_ssh() {
  ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 "$(control_plane)" "$@"
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
    if [[ "$crd" != "customresourcedefinition.apiextensions.k8s.io/validatingpolicies.policies.kyverno.io" ]]; then
      echo "HINT: Kyverno CRDs are missing - run 'install-kyverno' and wait for the Helm release to finish before running any test."
    elif [[ "$version" != *v1.19.* ]]; then
      echo "HINT: Installed Kyverno image is not the expected v1.19.x - check the Helm chart version pin was not changed."
    else
      echo "HINT: No Kyverno Deployment has availableReplicas > 0 yet. Wait longer for the admission controller Pods to become Ready, or check 'kubectl get pods -n kyverno' for a crash/pending state."
    fi
    echo "validatingpolicy_crd=$crd kyverno_image=$version available_kyverno_deployments=$available"
    result=1
  fi
  record_result "$result"
}

@test "2. deny-latest-tag rejects explicit and implicit latest in all container lists" {
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
  name: implicit-latest-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause
EOF
  untagged_status=$?
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
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: implicit-latest-init-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  untagged_init_status=$?

  kubectl delete pod ephemeral-policy-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl run ephemeral-policy-base -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  kubectl wait pod/ephemeral-policy-base -n "$NS" --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  base_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:latest --profile=general -- true >/dev/null 2>&1
  ephemeral_latest_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox --profile=general -- true >/dev/null 2>&1
  ephemeral_untagged_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true >/dev/null 2>&1
  ephemeral_trusted_status=$?
  kubectl delete pod ephemeral-policy-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1

  # Positive control for the OTHER explicitly-allowed image reference form: task 2
  # requires accepting either a non-latest tag OR a digest reference - a policy that
  # denies ALL digest-pinned images (e.g. by requiring a literal ':tag' substring and
  # rejecting anything with '@sha256:') would still pass every probe above, since none
  # of them exercise the digest form at all.
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
EOF
  digest_status=$?
  set -e
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$untagged_status" -ne 0 \
    && "$init_status" -ne 0 && "$untagged_init_status" -ne 0 \
    && "$base_status" -eq 0 && "$ephemeral_latest_status" -ne 0 && "$ephemeral_untagged_status" -ne 0 \
    && "$ephemeral_trusted_status" -eq 0 && "$digest_status" -eq 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'deny-latest-tag' does not exist, is not apiVersion policies.kyverno.io/v1, or does not have validationActions: [Deny]."
    elif [[ "$main_status" -eq 0 ]]; then
      echo "HINT: A Pod with image tag ':latest' was admitted - it should be denied. Check your CEL expression actually parses the tag, not just checks for the string 'latest' loosely."
    elif [[ "$untagged_status" -eq 0 ]]; then
      echo "HINT: A Pod with NO tag at all (implicit latest) was admitted - an image reference without ':tag' defaults to 'latest' and must be denied the same way as an explicit ':latest'."
    elif [[ "$init_status" -eq 0 ]]; then
      echo "HINT: A Pod with a ':latest' initContainer (but a pinned main container) was admitted - your policy must check spec.initContainers, not only spec.containers."
    elif [[ "$untagged_init_status" -eq 0 ]]; then
      echo "HINT: A Pod with an UNTAGGED (implicit latest) initContainer was admitted - implicit latest must be denied in spec.initContainers too, not only as an explicit ':latest' string."
    elif [[ "$ephemeral_latest_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an ephemeral container with ':latest' was admitted - your policy must also cover spec.ephemeralContainers, which uses the pods/ephemeralcontainers subresource."
    elif [[ "$ephemeral_untagged_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an UNTAGGED (implicit latest) ephemeral container was admitted - implicit latest must be denied in spec.ephemeralContainers too, not only as an explicit ':latest' string."
    elif [[ "$digest_status" -ne 0 ]]; then
      echo "HINT: A digest-pinned image (image@sha256:...) was rejected - task 2 requires accepting EITHER a non-latest tag OR a digest reference. Check your CEL treats a digest reference as a valid, always-allowed form, not just an absence of ':latest'."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A correctly pinned image was unexpectedly rejected - check your policy is not too broad (e.g. accidentally matching any image string containing digits, or blocking all debug/ephemeral operations)."
    fi
    echo "policy_enforced=$policy_status main=$main_status untagged=$untagged_status init=$init_status untagged_init=$untagged_init_status base=$base_status ephemeral_latest=$ephemeral_latest_status ephemeral_untagged=$ephemeral_untagged_status ephemeral_trusted=$ephemeral_trusted_status digest=$digest_status"; result=1
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
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: unset-run-as-non-root-must-fail
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  unset_status=$?
  set -e
  if [[ "$policy_status" -eq 0 && "$admission_status" -ne 0 && "$unset_status" -ne 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'require-run-as-non-root' does not exist or is not enforced (Deny)."
    elif [[ "$admission_status" -eq 0 ]]; then
      echo "HINT: A Pod with securityContext.runAsNonRoot: false was admitted - it should be denied. Check your CEL expression is actually evaluating spec.securityContext.runAsNonRoot, and that a false value (not just a missing value) is caught."
    else
      echo "HINT: A Pod with NO Pod-level securityContext.runAsNonRoot at all was admitted - the task requires the field to be explicitly true, so a MISSING field must be denied the same way as an explicit false. Check your CEL uses something like 'has(...) && ... == true' rather than only catching the literal false value."
    fi
    echo "policy_enforced=$policy_status root_admission_status=$admission_status unset_status=$unset_status"; result=1
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
  name: unqualified-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
EOF
  unqualified_status=$?
  # A pinned (non-latest) tag is used here deliberately: task 2's policy must already
  # deny ":latest" regardless of registry, so an unpinned tag on quay.io would be denied
  # for an ambiguous reason and would NOT isolate/prove the registry allowlist control
  # specifically (this probe's only purpose is to confirm quay.io itself is rejected).
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: quay-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: quay.io/prometheus/busybox:v0.24.0
EOF
  quay_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: lookalike-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io.evil.example/pause:3.10
EOF
  lookalike_status=$?
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: lookalike-path-registry-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: ghcr.io/cks-lab.evil/busybox:1.36
EOF
  lookalike_path_status=$?
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
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$unqualified_status" -ne 0 \
    && "$quay_status" -ne 0 && "$lookalike_status" -ne 0 && "$lookalike_path_status" -ne 0 \
    && "$init_status" -ne 0 && "$trusted_lists_status" -eq 0 && "$base_status" -eq 0 \
    && "$ephemeral_untrusted_status" -ne 0 && "$ephemeral_trusted_status" -eq 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'allow-approved-registries' does not exist or is not enforced (Deny)."
    elif [[ "$main_status" -eq 0 ]]; then
      echo "HINT: An image from docker.io (not in the approved registry allowlist) was admitted - check your registry match logic actually restricts to the approved prefix(es)."
    elif [[ "$unqualified_status" -eq 0 ]]; then
      echo "HINT: An UNQUALIFIED image reference (e.g. 'busybox:1.36', implicit Docker Hub) was admitted - your policy must be a true ALLOWLIST (only registry.k8s.io/* or ghcr.io/cks-lab/* pass), not just a denylist of 'docker.io' as a literal string prefix."
    elif [[ "$quay_status" -eq 0 ]]; then
      echo "HINT: An image from quay.io (not in the approved registry allowlist) was admitted - your policy must reject ANY registry other than the two approved ones, not just docker.io specifically."
    elif [[ "$lookalike_status" -eq 0 ]]; then
      echo "HINT: A look-alike registry host ('registry.k8s.io.evil.example/...') was admitted - check your prefix match is anchored correctly (e.g. startsWith on the full 'registry.k8s.io/' including the trailing slash), not a loose substring match that a similarly-named host could satisfy."
    elif [[ "$lookalike_path_status" -eq 0 ]]; then
      echo "HINT: A look-alike path under ghcr.io ('ghcr.io/cks-lab.evil/...') was admitted - check your match is anchored on the exact 'ghcr.io/cks-lab/' prefix (including the trailing slash), not a loose substring match that a sibling path like 'cks-lab.evil' could satisfy."
    elif [[ "$init_status" -eq 0 ]]; then
      echo "HINT: An unapproved initContainer image was admitted even though the main container was trusted - your policy must check spec.initContainers too, not just spec.containers."
    elif [[ "$trusted_lists_status" -ne 0 ]]; then
      echo "HINT: A Pod with BOTH main and init containers from approved registries was rejected - it should be allowed. Check your allowlist actually covers both 'registry.k8s.io' and 'ghcr.io/cks-lab' if both are meant to be trusted."
    elif [[ "$ephemeral_untrusted_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an ephemeral container from an unapproved registry was admitted - check your policy also covers spec.ephemeralContainers."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A Pod/ephemeral container from an approved registry was unexpectedly rejected - your allowlist match may be too narrow (e.g. exact string match instead of prefix match)."
    fi
    echo "policy_enforced=$policy_status main=$main_status unqualified=$unqualified_status quay=$quay_status lookalike=$lookalike_status lookalike_path=$lookalike_path_status init=$init_status trusted_lists=$trusted_lists_status base=$base_status ephemeral_untrusted=$ephemeral_untrusted_status ephemeral_trusted=$ephemeral_trusted_status"; result=1
  fi
  record_result "$result"
}

@test "5. OPTIONAL: add-kyverno-managed-label mutates matching Pods" {
  policy=$(kubectl get mutatingpolicy add-kyverno-managed-label --context "$CTX" -o json 2>/dev/null)
  policy_exists=$(jq -r 'if . == null then "no" else "yes" end' <<<"${policy:-null}" 2>/dev/null)
  if [[ "$policy_exists" != "yes" ]]; then
    # Optional task was skipped entirely: do NOT count it in result/all at all, so
    # check_result's sum_ok/sum_all percentage is unaffected by skipping it - matching
    # the README's explicit claim that skipping task 5 is allowed without any score
    # penalty. Only once the student has actually created the MutatingPolicy do we hold
    # them to the full pass/fail bar below (counted in both all and ok/not-ok).
    echo "OPTIONAL: MutatingPolicy 'add-kyverno-managed-label' not found - task 5 skipped, not counted toward the result."
    return 0
  fi
  echo '1' >> /var/work/tests/result/all
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
  mutated_existing=$(cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -o json -f - 2>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check-existing-label
  namespace: policy-108
  labels:
    security.cks.io/managed-by: external
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  existing_status=$?
  set -e
  label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated" 2>/dev/null)
  existing_label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated_existing" 2>/dev/null)
  has_mutate=$(jq -r '(.spec.mutations // []) | length' <<<"$policy" 2>/dev/null)
  if [[ "$admission_status" -eq 0 && "$label" == "kyverno" && "$has_mutate" -ge 1 \
    && "$existing_status" -eq 0 && "$existing_label" == "external" ]]; then
    echo '1' >> /var/work/tests/result/ok
  else
    if [[ "$has_mutate" -lt 1 ]]; then
      echo "OPTIONAL HINT: MutatingPolicy 'add-kyverno-managed-label' has no mutations defined - add a mutation adding label 'security.cks.io/managed-by: kyverno'."
    elif [[ "$label" != "kyverno" ]]; then
      echo "OPTIONAL HINT: The dry-run admission response Pod is missing label 'security.cks.io/managed-by: kyverno' - check the mutation's applyConfiguration/patch actually sets this exact key/value."
    elif [[ "$existing_label" != "external" ]]; then
      echo "OPTIONAL HINT: A Pod that already had label 'security.cks.io/managed-by: external' had its value overwritten to '$existing_label' - the mutation must only ADD the label if it is absent, not unconditionally overwrite an existing value."
    fi
    echo "OPTIONAL: mutation not ready (admission_status=$admission_status label=$label existing_status=$existing_status existing_label=$existing_label mutate_rules=$has_mutate)"
  fi
  # Последний этап опционален: check_result его проверяет, но не делает лабу неуспешной -
  # если MutatingPolicy отсутствует вовсе, шаг выше уже вернул до этой точки без записи в
  # result/all. Если policy существует, но не проходит проверку - это засчитывается как
  # обычный провалившийся (но не пропущенный) тест.
  true
}

@test "6. ImagePolicyWebhook denies :latest via external backend and admits a pinned tag" {
  manifest=$(node_ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true)
  baseline_plugins=$(node_ssh "sudo cat /var/lib/cks-lab108-checker/baseline-admission-plugins.txt" 2>/dev/null || true)
  current_plugins=$(grep -oE -- '--enable-admission-plugins=[^"[:space:]]*' <<<"$manifest" | sed 's/^--enable-admission-plugins=//' || true)
  backend_available=$(kubectl get deployment image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | \
    jq -r '.status.availableReplicas // 0' 2>/dev/null)
  # Verify every plugin that was already enabled before the student's change (per the
  # bootstrap-captured baseline) is still present after adding ImagePolicyWebhook - a
  # config that ADDS the new plugin by REPLACING the whole flag value would silently
  # drop e.g. NodeRestriction and must not pass just because 'ImagePolicyWebhook' is
  # present somewhere in the manifest.
  preserved_baseline_plugins="yes"
  if [[ -n "$baseline_plugins" ]]; then
    IFS=',' read -ra _baseline_arr <<<"$baseline_plugins"
    for p in "${_baseline_arr[@]}"; do
      [[ -z "$p" ]] && continue
      if ! grep -qE "(^|,)${p}(,|\$)" <<<"$current_plugins"; then
        preserved_baseline_plugins="no"
        break
      fi
    done
  fi
  set +e
  kubectl delete pod webhook-latest-must-fail webhook-pinned-ok webhook-failclosed-must-fail --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl run webhook-latest-must-fail --image=nginx:latest --context "$CTX" 2>/tmp/webhook-latest-err.txt >/dev/null
  latest_status=$?
  kubectl run webhook-pinned-ok --image=nginx:1.27.3 --context "$CTX" >/dev/null 2>&1
  kubectl wait pod/webhook-pinned-ok --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  pinned_status=$?
  deny_message=$(cat /tmp/webhook-latest-err.txt 2>/dev/null || true)

  # Fail-closed check: defaultAllow:false means that if the backend becomes unreachable,
  # a NEW pinned-tag image (not cached from an earlier allow/deny decision, so the TTL
  # cache cannot mask this) must still be DENIED, not silently admitted. Detach the
  # Service from the backend Pod by patching its selector to a non-matching value -
  # NOT by scaling the Deployment to 0 replicas. ImagePolicyWebhook is a cluster-wide
  # admission plugin with no namespace exclusion in this lab's AdmissionConfiguration,
  # so it also governs the backend's OWN Pod. Scaling to 0 would force a NEW backend Pod
  # to be created when scaling back to 1 - but that creation itself needs to pass
  # ImagePolicyWebhook, and the backend is (by definition, mid-probe) unreachable at
  # that exact moment, so a CORRECTLY fail-closed config would deny its own replacement
  # Pod and never recover, hanging 'kubectl rollout status' and producing a guaranteed
  # false FAIL for an otherwise-correct student solution. Patching the Service selector
  # only changes routing to the EXISTING (already-admitted, already-Running) Pod - no
  # new Pod is created, so there is nothing left for ImagePolicyWebhook to block.
  original_selector=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | jq -c '.spec.selector' 2>/dev/null || true)
  kubectl patch service image-policy-backend -n image-policy --context "$CTX" \
    -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}' >/dev/null 2>&1
  for _ in $(seq 1 24); do
    eps=$(kubectl get endpoints image-policy-backend -n image-policy --context "$CTX" -o jsonpath='{.subsets}' 2>/dev/null || true)
    [[ -z "$eps" ]] && break
    sleep 5
  done
  if [[ -z "$eps" ]]; then
    backend_detached_status=0
  else
    backend_detached_status=1
  fi
  unique_tag="failclosed-$(date +%s%N)-$$"
  kubectl run webhook-failclosed-must-fail --image="nginx:${unique_tag}" --context "$CTX" 2>/tmp/webhook-failclosed-err.txt >/dev/null
  failclosed_status=$?
  failclosed_message=$(cat /tmp/webhook-failclosed-err.txt 2>/dev/null || true)
  # Restore the Service selector (routing back to the SAME, still-Running backend Pod -
  # no Pod creation involved, so nothing here can be blocked by ImagePolicyWebhook).
  # original_selector is captured above as compact JSON (via `-o json | jq -c`, NOT
  # `-o jsonpath`, since kubectl's jsonpath map printer emits Go-style `map[k:v]`
  # syntax which is not valid JSON and would make this patch a no-op silently
  # swallowed by the >/dev/null 2>&1 redirect below).
  if [[ -n "$original_selector" && "$original_selector" != "null" ]]; then
    kubectl patch service image-policy-backend -n image-policy --context "$CTX" \
      --type=merge -p "{\"spec\":{\"selector\":${original_selector}}}" >/dev/null 2>&1
    restore_patch_status=$?
  else
    kubectl patch service image-policy-backend -n image-policy --context "$CTX" \
      --type=merge -p '{"spec":{"selector":{"app":"image-policy-backend"}}}' >/dev/null 2>&1
    restore_patch_status=$?
  fi
  for _ in $(seq 1 24); do
    eps=$(kubectl get endpoints image-policy-backend -n image-policy --context "$CTX" -o jsonpath='{.subsets}' 2>/dev/null || true)
    [[ -n "$eps" ]] && break
    sleep 5
  done
  if [[ -n "$eps" ]]; then
    backend_restored_status=0
  else
    backend_restored_status=1
  fi
  # Endpoints being restored does not mean the ClusterIP data path is programmed yet:
  # kube-proxy needs 1-2s more, and the next test (Gatekeeper) starts immediately after
  # this one - its probes would hit 'connection refused' from the fail-closed webhook and
  # be misattributed. Wait until admission actually works again before finishing.
  for _ in $(seq 1 30); do
    if kubectl run "webhook-recovery-probe" --image="nginx:recovery-$(date +%s%N)" --dry-run=server -o name \
      --context "$CTX" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  set -e
  if [[ "$manifest" == *'ImagePolicyWebhook'* \
    && "$manifest" == *'--admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml'* \
    && "$manifest" == *'imagepolicy.k8s.io/v1alpha1=true'* \
    && "$preserved_baseline_plugins" == "yes" \
    && "$backend_available" -ge 1 \
    && "$latest_status" -ne 0 && "$deny_message" == *'image policy webhook backend denied'* \
    && "$pinned_status" -eq 0 \
    && "$failclosed_status" -ne 0 \
    && "$backend_restored_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$backend_available" -lt 1 ]]; then
      echo "HINT: Deployment 'image-policy-backend' in namespace 'image-policy' has no available replicas - check the Deployment mounts the ConfigMap correctly and the Pod is actually Running."
    elif [[ "$manifest" != *'ImagePolicyWebhook'* ]]; then
      echo "HINT: kube-apiserver.yaml --enable-admission-plugins does not include ImagePolicyWebhook - add it to the EXISTING list (comma-separated), do not replace the whole flag value."
    elif [[ "$preserved_baseline_plugins" != "yes" ]]; then
      echo "HINT: One or more admission plugins that were enabled BEFORE your change (baseline: '$baseline_plugins') are missing from the current --enable-admission-plugins value ('$current_plugins') - you replaced the flag instead of appending to it, which silently disables plugins like NodeRestriction."
    elif [[ "$manifest" != *'imagepolicy.k8s.io/v1alpha1=true'* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --runtime-config=imagepolicy.k8s.io/v1alpha1=true - without it the ImageReview API is not served and the backend is never called."
    elif [[ "$manifest" != *'--admission-control-config-file='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --admission-control-config-file pointing at your AdmissionConfiguration file."
    elif [[ "$latest_status" -eq 0 ]]; then
      echo "HINT: Pod webhook-latest-must-fail (nginx:latest) was created - it should have been denied by the ImagePolicyWebhook backend. Check the backend is reachable from kube-apiserver (Service/kubeconfig server URL) and defaultAllow is false."
    elif [[ "$deny_message" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: The Pod was denied, but not with the expected ImagePolicyWebhook message - check the denial actually came from the backend (your server.py 'reason' field), not from an unrelated admission controller."
    elif [[ "$pinned_status" -ne 0 ]]; then
      echo "HINT: Pod webhook-pinned-ok (nginx:1.27.3) was not created/Ready - a correctly pinned tag should be allowed by the backend logic in server.py."
    elif [[ "$failclosed_status" -eq 0 ]]; then
      echo "HINT: A Pod was ADMITTED while the image-policy-backend Service was detached (unreachable) - defaultAllow must be false, so admission should be DENIED (fail-closed) when the backend cannot be reached, not silently allowed (fail-open)."
    else
      echo "HINT: image-policy-backend's Service did not recover its Endpoints after being restored - check nothing about the fail-closed probe left the Service/Deployment selector mismatched."
    fi
    echo "backend_available=$backend_available preserved_baseline_plugins=$preserved_baseline_plugins baseline_plugins=$baseline_plugins current_plugins=$current_plugins latest_status=$latest_status pinned_status=$pinned_status backend_detached_status=$backend_detached_status failclosed_status=$failclosed_status restore_patch_status=$restore_patch_status backend_restored_status=$backend_restored_status deny_message=$deny_message failclosed_message=$failclosed_message"
    result=1
  fi
  kubectl delete pod webhook-latest-must-fail webhook-pinned-ok webhook-failclosed-must-fail --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  rm -f /tmp/webhook-latest-err.txt /tmp/webhook-failclosed-err.txt
  record_result "$result"
}

@test "7. Gatekeeper ConstraintTemplate Rego blocks very-bad-registry.test without losing the old rule" {
  set +e
  template=$(kubectl get constrainttemplate k8sblockedregistries --context "$CTX" -o json 2>/dev/null)
  template_status=$?
  rego=$(jq -r '.spec.targets[] | select(.target == "admission.k8s.gatekeeper.sh") | .rego' <<<"$template" 2>/dev/null)
  # The fix must be additive Rego, not a parameters edit: Constraint.spec.parameters is
  # not used by this ConstraintTemplate's Rego at all (it reads hardcoded
  # blocked_registry(...) facts), so a student who only patches
  # Constraint.spec.parameters.blocked would leave the Rego - and therefore the actual
  # admission behavior - completely unchanged.
  rego_has_old=false
  grep -Fq 'blocked_registry("untrusted-registry.example")' <<<"$rego" && rego_has_old=true
  rego_has_new=false
  grep -Fq 'blocked_registry("very-bad-registry.test")' <<<"$rego" && rego_has_new=true

  new_bad_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_POD'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF_POD
)
  new_bad_status=$?
  # Regression control: the ORIGINAL blocked registry must still be denied after the
  # student's edit - catches a student who REPLACES the old blocked_registry(...) fact
  # with the new one instead of adding a new fact alongside it.
  old_bad_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_POD'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF_POD
)
  old_bad_status=$?
  trusted_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_POD'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-trusted-registry-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF_POD
)
  trusted_status=$?
  set -e
  # Isolate the control: the denial must come from THIS Gatekeeper constraint, not from
  # an unrelated Kyverno ValidatingPolicy - the probe Pods above live in gatekeeper-108,
  # a namespace none of the Kyverno policies from tasks 2-5 (scoped to policy-108) ever
  # match, so a 'kyverno' string in the denial message here would indicate cross-talk
  # between the two admission engines, not a real Gatekeeper-only proof.
  if [[ "$template_status" -eq 0 && "$rego_has_old" == "true" && "$rego_has_new" == "true" \
    && "$new_bad_status" -ne 0 && "$new_bad_output" == *"k8sblockedregistries"* && "$new_bad_output" != *"kyverno"* \
    && "$old_bad_status" -ne 0 && "$old_bad_output" == *"k8sblockedregistries"* \
    && "$trusted_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$template_status" -ne 0 ]]; then
      echo "HINT: ConstraintTemplate 'k8sblockedregistries' not found - check it was not accidentally deleted, and that you edited the existing object rather than replacing it under a different name."
    elif [[ "$rego_has_old" != "true" ]]; then
      echo "HINT: spec.targets[].rego in the ConstraintTemplate no longer contains 'blocked_registry(\"untrusted-registry.example\")' - you must ADD a new rule for very-bad-registry.test alongside the existing ones, not replace them."
    elif [[ "$rego_has_new" != "true" ]]; then
      echo "HINT: spec.targets[].rego does not contain 'blocked_registry(\"very-bad-registry.test\")' yet - edit the ConstraintTemplate's Rego (not the Constraint's parameters, which this template does not even use) and add this fact."
    elif [[ "$new_bad_status" -eq 0 ]]; then
      echo "HINT: A Pod with image from 'very-bad-registry.test' in namespace gatekeeper-108 was admitted - it should be denied by the Gatekeeper constraint after your Rego fix."
    elif [[ "$new_bad_output" != *"k8sblockedregistries"* || "$new_bad_output" == *"kyverno"* ]]; then
      echo "HINT: The probe Pod was denied, but not clearly by the Gatekeeper 'k8sblockedregistries' constraint (or the denial actually came from an unrelated Kyverno policy) - check you fixed the ConstraintTemplate's Rego, not a Kyverno policy, and that the probe ran in namespace gatekeeper-108."
    elif [[ "$old_bad_status" -eq 0 ]]; then
      echo "HINT: A Pod with image from the ALREADY-blocked 'untrusted-registry.example' was admitted after your edit - your change must be additive (a new blocked_registry(...) fact alongside the existing one), not a replacement of the original rule."
    elif [[ "$trusted_status" -ne 0 ]]; then
      echo "HINT: A Pod from the already-trusted registry (registry.k8s.io) was denied after your fix - check your Rego edit did not accidentally introduce a syntax error or an overly broad rule."
    fi
    echo "template_status=$template_status rego_has_old=$rego_has_old rego_has_new=$rego_has_new new_bad_status=$new_bad_status new_bad_output=$new_bad_output old_bad_status=$old_bad_status old_bad_output=$old_bad_output trusted_status=$trusted_status trusted_output=$trusted_output"
    result=1
  fi
  record_result "$result"
}
