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
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$untagged_status" -ne 0 && "$init_status" -ne 0 && "$base_status" -eq 0 && "$ephemeral_latest_status" -ne 0 && "$ephemeral_trusted_status" -eq 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'deny-latest-tag' does not exist, is not apiVersion policies.kyverno.io/v1, or does not have validationActions: [Deny]."
    elif [[ "$main_status" -eq 0 ]]; then
      echo "HINT: A Pod with image tag ':latest' was admitted - it should be denied. Check your CEL expression actually parses the tag, not just checks for the string 'latest' loosely."
    elif [[ "$untagged_status" -eq 0 ]]; then
      echo "HINT: A Pod with NO tag at all (implicit latest) was admitted - an image reference without ':tag' defaults to 'latest' and must be denied the same way as an explicit ':latest'."
    elif [[ "$init_status" -eq 0 ]]; then
      echo "HINT: A Pod with a ':latest' initContainer (but a pinned main container) was admitted - your policy must check spec.initContainers, not only spec.containers."
    elif [[ "$ephemeral_latest_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an ephemeral container with ':latest' was admitted - your policy must also cover spec.ephemeralContainers, which uses the pods/ephemeralcontainers subresource."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A correctly pinned image was unexpectedly rejected - check your policy is not too broad (e.g. accidentally matching any image string containing digits, or blocking all debug/ephemeral operations)."
    fi
    echo "policy_enforced=$policy_status main=$main_status untagged=$untagged_status init=$init_status base=$base_status ephemeral_latest=$ephemeral_latest_status ephemeral_trusted=$ephemeral_trusted_status"; result=1
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
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'require-run-as-non-root' does not exist or is not enforced (Deny)."
    else
      echo "HINT: A Pod with securityContext.runAsNonRoot: false was admitted - it should be denied. Check your CEL expression is actually evaluating spec.securityContext.runAsNonRoot, and that a false value (not just a missing value) is caught."
    fi
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
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'allow-approved-registries' does not exist or is not enforced (Deny)."
    elif [[ "$main_status" -eq 0 ]]; then
      echo "HINT: An image from docker.io (not in the approved registry allowlist) was admitted - check your registry match logic actually restricts to the approved prefix(es)."
    elif [[ "$init_status" -eq 0 ]]; then
      echo "HINT: An unapproved initContainer image was admitted even though the main container was trusted - your policy must check spec.initContainers too, not just spec.containers."
    elif [[ "$trusted_lists_status" -ne 0 ]]; then
      echo "HINT: A Pod with BOTH main and init containers from approved registries was rejected - it should be allowed. Check your allowlist actually covers both 'registry.k8s.io' and 'ghcr.io/cks-lab' if both are meant to be trusted."
    elif [[ "$ephemeral_untrusted_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an ephemeral container from an unapproved registry was admitted - check your policy also covers spec.ephemeralContainers."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A Pod/ephemeral container from an approved registry was unexpectedly rejected - your allowlist match may be too narrow (e.g. exact string match instead of prefix match)."
    fi
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
    if [[ "$has_mutate" -lt 1 ]]; then
      echo "OPTIONAL HINT: MutatingPolicy 'add-kyverno-managed-label' has no mutations defined - add a mutation adding label 'security.cks.io/managed-by: kyverno'."
    elif [[ "$label" != "kyverno" ]]; then
      echo "OPTIONAL HINT: The dry-run admission response Pod is missing label 'security.cks.io/managed-by: kyverno' - check the mutation's applyConfiguration/patch actually sets this exact key/value."
    fi
    echo "OPTIONAL: mutation not ready (admission_status=$admission_status label=$label mutate_rules=$has_mutate)"
  fi
  # Последний этап опционален: check_result его проверяет, но не делает лабу неуспешной.
  true
}

@test "6. ImagePolicyWebhook denies :latest via external backend and admits a pinned tag" {
  echo '1' >> /var/work/tests/result/all
  manifest=$(node_ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true)
  backend_available=$(kubectl get deployment image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | \
    jq -r '.status.availableReplicas // 0' 2>/dev/null)
  set +e
  kubectl delete pod webhook-latest-must-fail webhook-pinned-ok --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl run webhook-latest-must-fail --image=nginx:latest --context "$CTX" 2>/tmp/webhook-latest-err.txt >/dev/null
  latest_status=$?
  kubectl run webhook-pinned-ok --image=nginx:1.27.3 --context "$CTX" >/dev/null 2>&1
  kubectl wait pod/webhook-pinned-ok --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  pinned_status=$?
  deny_message=$(cat /tmp/webhook-latest-err.txt 2>/dev/null || true)
  set -e
  if [[ "$manifest" == *'ImagePolicyWebhook'* \
    && "$manifest" == *'--admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml'* \
    && "$manifest" == *'imagepolicy.k8s.io/v1alpha1=true'* \
    && "$backend_available" -ge 1 \
    && "$latest_status" -ne 0 && "$deny_message" == *'image policy webhook backend denied'* \
    && "$pinned_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$backend_available" -lt 1 ]]; then
      echo "HINT: Deployment 'image-policy-backend' in namespace 'image-policy' has no available replicas - check the Deployment mounts the ConfigMap correctly and the Pod is actually Running."
    elif [[ "$manifest" != *'ImagePolicyWebhook'* ]]; then
      echo "HINT: kube-apiserver.yaml --enable-admission-plugins does not include ImagePolicyWebhook - add it to the EXISTING list (comma-separated), do not replace the whole flag value."
    elif [[ "$manifest" != *'imagepolicy.k8s.io/v1alpha1=true'* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --runtime-config=imagepolicy.k8s.io/v1alpha1=true - without it the ImageReview API is not served and the backend is never called."
    elif [[ "$manifest" != *'--admission-control-config-file='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --admission-control-config-file pointing at your AdmissionConfiguration file."
    elif [[ "$latest_status" -eq 0 ]]; then
      echo "HINT: Pod webhook-latest-must-fail (nginx:latest) was created - it should have been denied by the ImagePolicyWebhook backend. Check the backend is reachable from kube-apiserver (Service/kubeconfig server URL) and defaultAllow is false."
    elif [[ "$deny_message" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: The Pod was denied, but not with the expected ImagePolicyWebhook message - check the denial actually came from the backend (your server.py 'reason' field), not from an unrelated admission controller."
    else
      echo "HINT: Pod webhook-pinned-ok (nginx:1.27.3) was not created/Ready - a correctly pinned tag should be allowed by the backend logic in server.py."
    fi
    echo "backend_available=$backend_available latest_status=$latest_status pinned_status=$pinned_status deny_message=$deny_message"
    result=1
  fi
  kubectl delete pod webhook-latest-must-fail webhook-pinned-ok --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  rm -f /tmp/webhook-latest-err.txt
  record_result "$result"
}
