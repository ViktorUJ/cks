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

policy_contract_ok() {
  kubectl get validatingpolicy "$1" --context "$CTX" -o json 2>/dev/null | \
    jq -e --arg ns "$NS" '
      def empty_selector($s):
        (($s.matchLabels // {}) | length) == 0 and
        (($s.matchExpressions // []) | length) == 0;
      def exact_ns_expression($e; $ns):
        ($e | gsub("[[:space:]]"; "")) as $x |
        $x == ("request.namespace==\u0027" + $ns + "\u0027") or
        $x == ("request.namespace==\"" + $ns + "\"") or
        $x == ("\u0027" + $ns + "\u0027==request.namespace") or
        $x == ("\"" + $ns + "\"==request.namespace");
      def exact_ns_selector($s; $ns):
        ((($s.matchLabels // {}) == {"kubernetes.io/metadata.name": $ns}) and
          (($s.matchExpressions // []) | length) == 0) or
        ((($s.matchLabels // {}) | length) == 0 and
          (($s.matchExpressions // []) == [{"key":"kubernetes.io/metadata.name","operator":"In","values":[$ns]}]));
      def covers($rules; $resource; $operation):
        any($rules[]; ((.resources // []) | index($resource) != null) and
          ((.operations // []) | index($operation) != null));
      .apiVersion == "policies.kyverno.io/v1" and
      .kind == "ValidatingPolicy" and
      ((.spec.validationActions // []) | index("Deny") != null) and
      ((.spec.matchConstraints.resourceRules // []) as $rules |
        ($rules | length) > 0 and all($rules[];
          ((.apiGroups // []) == [""]) and ((.apiVersions // []) == ["v1"]) and
          (((.resourceNames // []) | length) == 0) and
          ((.operations // []) | length) > 0 and
          all(.operations[]; . == "CREATE" or . == "UPDATE") and
          (.resources // [] | length) > 0 and
          all(.resources[]; . == "pods" or . == "pods/ephemeralcontainers")) and
        covers($rules; "pods"; "CREATE") and
        covers($rules; "pods"; "UPDATE") and
        covers($rules; "pods/ephemeralcontainers"; "UPDATE") and
        (((.spec.matchConstraints.excludeResourceRules // []) | length) == 0)) and
      empty_selector(.spec.matchConstraints.objectSelector // {}) and
      (((.spec.matchConditions // []) as $conditions |
        (($conditions | length) == 1 and
          exact_ns_expression($conditions[0].expression // ""; $ns) and
          empty_selector(.spec.matchConstraints.namespaceSelector // {})) or
        (($conditions | length) == 0 and
          exact_ns_selector(.spec.matchConstraints.namespaceSelector // {}; $ns))))
    ' >/dev/null
}

mutating_policy_contract_ok() {
  jq -e --arg ns "$NS" '
    def empty_selector($s):
      (($s.matchLabels // {}) | length) == 0 and
      (($s.matchExpressions // []) | length) == 0;
    def exact_ns_expression($e; $ns):
      ($e | gsub("[[:space:]]"; "")) as $x |
      $x == ("request.namespace==\u0027" + $ns + "\u0027") or
      $x == ("request.namespace==\"" + $ns + "\"") or
      $x == ("\u0027" + $ns + "\u0027==request.namespace") or
      $x == ("\"" + $ns + "\"==request.namespace");
    def exact_ns_selector($selector; $ns):
      ((($selector.matchLabels // {}) == {"kubernetes.io/metadata.name": $ns}) and
        (($selector.matchExpressions // []) | length) == 0) or
      ((($selector.matchLabels // {}) | length) == 0 and
        (($selector.matchExpressions // []) == [{"key":"kubernetes.io/metadata.name","operator":"In","values":[$ns]}]));
    .apiVersion == "policies.kyverno.io/v1" and
    .kind == "MutatingPolicy" and
    .metadata.name == "add-kyverno-managed-label" and
    ((.spec.matchConstraints.resourceRules // []) as $rules |
      ($rules | length) > 0 and
      all($rules[];
        (.apiGroups == [""]) and (.apiVersions == ["v1"]) and
        (.resources == ["pods"]) and
        ((.operations // []) | index("CREATE") != null) and
        all(.operations[]; . == "CREATE" or . == "UPDATE") and
        ((.resourceNames // []) | length) == 0) and
      ((.spec.matchConstraints.excludeResourceRules // []) | length) == 0) and
    empty_selector(.spec.matchConstraints.objectSelector // {}) and
    ((.spec.matchConditions // []) as $conditions |
      (($conditions | length) == 1 and
        exact_ns_expression($conditions[0].expression // ""; $ns) and
        empty_selector(.spec.matchConstraints.namespaceSelector // {})) or
      (($conditions | length) == 0 and
        exact_ns_selector(.spec.matchConstraints.namespaceSelector // {}; $ns)))
  ' >/dev/null 2>&1
}

kyverno_denied_by() {
  local expected_policy="$1" status="$2" output="$3"
  [[ "$status" -ne 0 && "$output" == *"Policy ${expected_policy} failed:"* ]]
}

# Isolate Task 2 registry-port negatives from the Task 4 allowlist. A port-only
# image is denied by BOTH policies: accepting either denial masks a broken Task 2.
# Temporarily switch Task 4 to Audit, wait for the updated effective admission
# behavior, prove ALL THREE Task 2 port denials, and restore the exact actions.
# The restore is live-verified.
task2_port_denials_isolated() (
  # Run the mutation in a child shell: EXIT/INT/TERM cleanup remains scoped to
  # this probe and cannot replace Bats' own parent-process handlers.
  local base_pod="$1" old_actions="" restore_needed=0 ready=0 ok=0
  local output status init_output init_status eph_output eph_status
  local restore_output restore_status
  restore_task4_policy() {
    [[ "$restore_needed" -eq 1 ]] || return 0
    local payload current verify_output verify_status requires_deny=0
    payload=$(jq -nc --argjson actions "$old_actions" '{spec:{validationActions:$actions}}') || return 1
    jq -en --argjson actions "$old_actions" '$actions | index("Deny") != null' >/dev/null 2>&1 && requires_deny=1
    for _ in $(seq 1 30); do
      current=$(kubectl get validatingpolicy allow-approved-registries --context "$CTX" -o json 2>/dev/null | jq -c '.spec.validationActions // []' 2>/dev/null)
      # A concurrent actor owns any state differing from our exact Audit value.
      # Never clobber their change with an unconditional restore.
      if [[ "$current" != '["Audit"]' && "$current" != "$old_actions" ]]; then
        echo "FATAL: Concurrent validationActions update; preserve current policy and resolve manually." >&2
        return 1
      fi
      if [[ "$current" == "$old_actions" ]] || kubectl patch validatingpolicy allow-approved-registries \
        --context "$CTX" --type=json \
        -p "$(jq -nc --argjson original "$old_actions" '[{"op":"test","path":"/spec/validationActions","value":["Audit"]},{"op":"replace","path":"/spec/validationActions","value":$original}]')" >/dev/null 2>&1; then
        current=$(kubectl get validatingpolicy allow-approved-registries --context "$CTX" -o json 2>/dev/null | jq -c '.spec.validationActions // []' 2>/dev/null)
        if [[ "$current" == "$old_actions" ]]; then
          if [[ "$requires_deny" -eq 0 ]]; then
            restore_needed=0
            return 0
          fi
          verify_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_PORT_RESTORED'
apiVersion: v1
kind: Pod
metadata:
  name: task2-port-allowlist-restored
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF_PORT_RESTORED
          )
          verify_status=$?
          if kyverno_denied_by allow-approved-registries "$verify_status" "$verify_output"; then
            restore_needed=0
            return 0
          fi
        fi
      fi
      sleep 2
    done
    echo 'FATAL: checker could not restore allow-approved-registries to its original effective validationActions. Restore it manually before continuing.' >&2
    return 1
  }
  # EXIT cleanup covers ordinary errors, CTRL-C and TERM. Do not promise SIGKILL
  # recovery: OS-level kill -9 does not permit cleanup in any shell.
  trap 'restore_task4_policy || true' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  old_actions=$(kubectl get validatingpolicy allow-approved-registries --context "$CTX" -o json 2>/dev/null | jq -c '.spec.validationActions // []' 2>/dev/null)
  if [[ -n "$old_actions" ]]; then
    # Arm EXIT recovery BEFORE the state-changing API request, not after it.
    restore_needed=1
    kubectl patch validatingpolicy allow-approved-registries --context "$CTX" --type=json \
      -p "$(jq -nc --argjson old "$old_actions" '[{"op":"test","path":"/spec/validationActions","value":$old},{"op":"replace","path":"/spec/validationActions","value":["Audit"]}]')" >/dev/null 2>&1 || return 1
    for _ in $(seq 1 30); do
      if kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1 <<'EOF_PORT_READY'
apiVersion: v1
kind: Pod
metadata:
  name: task2-port-allowlist-audit-preflight
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF_PORT_READY
      then ready=1; break; fi
      sleep 1
    done
  else
    ready=1  # Task 4 is not installed yet; aggregate Task 4 grading still requires it.
  fi
  if [[ "$ready" -eq 1 ]]; then
    output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_PORT_MAIN'
apiVersion: v1
kind: Pod
metadata:
  name: task2-port-main-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.example:5000/app
EOF_PORT_MAIN
    )
    status=$?
    init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_PORT_INIT'
apiVersion: v1
kind: Pod
metadata:
  name: task2-port-init-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.example:5000/app
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF_PORT_INIT
    )
    init_status=$?
    eph_output=$(kubectl debug "pod/${base_pod}" -n "$NS" --context "$CTX" --target="$base_pod" \
      --image=registry.example:5000/app --profile=general -- true 2>&1)
    eph_status=$?
    if kyverno_denied_by deny-latest-tag "$status" "$output" \
      && kyverno_denied_by deny-latest-tag "$init_status" "$init_output" \
      && kyverno_denied_by deny-latest-tag "$eph_status" "$eph_output"; then ok=1; fi
  fi
  if [[ "$restore_needed" -eq 1 ]]; then
    # Normal-path recovery uses the same retrying, live-verified cleanup as EXIT.
    restore_task4_policy || ok=0
  fi
  [[ "$ok" -eq 1 ]]
)

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
  policy_contract_ok deny-latest-tag
  policy_status=$?
  main_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  main_status=$?
  main_attributed=false
  kyverno_denied_by deny-latest-tag "$main_status" "$main_output" && main_attributed=true
  untagged_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  untagged_status=$?
  untagged_attributed=false
  kyverno_denied_by deny-latest-tag "$untagged_status" "$untagged_output" && untagged_attributed=true
  port_untagged_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: registry-port-implicit-latest-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.example:5000/app
EOF
)
  port_untagged_status=$?
  port_untagged_attributed=false
  kyverno_denied_by deny-latest-tag "$port_untagged_status" "$port_untagged_output" && port_untagged_attributed=true
  init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  init_status=$?
  init_attributed=false
  kyverno_denied_by deny-latest-tag "$init_status" "$init_output" && init_attributed=true
  untagged_init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  untagged_init_status=$?
  untagged_init_attributed=false
  kyverno_denied_by deny-latest-tag "$untagged_init_status" "$untagged_init_output" && untagged_init_attributed=true
  port_init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: registry-port-implicit-init-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.example:5000/app
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  port_init_status=$?
  port_init_attributed=false
  kyverno_denied_by deny-latest-tag "$port_init_status" "$port_init_output" && port_init_attributed=true

  kubectl delete pod ephemeral-policy-base -n "$NS" --context "$CTX" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1
  kubectl run ephemeral-policy-base -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  kubectl wait pod/ephemeral-policy-base -n "$NS" --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  base_status=$?
  ephemeral_latest_output=$(kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:latest --profile=general -- true 2>&1)
  ephemeral_latest_status=$?
  ephemeral_latest_attributed=false
  kyverno_denied_by deny-latest-tag "$ephemeral_latest_status" "$ephemeral_latest_output" && ephemeral_latest_attributed=true
  ephemeral_untagged_output=$(kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox --profile=general -- true 2>&1)
  ephemeral_untagged_status=$?
  ephemeral_untagged_attributed=false
  kyverno_denied_by deny-latest-tag "$ephemeral_untagged_status" "$ephemeral_untagged_output" && ephemeral_untagged_attributed=true
  ephemeral_port_output=$(kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.example:5000/app --profile=general -- true 2>&1)
  ephemeral_port_status=$?
  ephemeral_port_attributed=false
  kyverno_denied_by deny-latest-tag "$ephemeral_port_status" "$ephemeral_port_output" && ephemeral_port_attributed=true
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true >/dev/null 2>&1
  ephemeral_trusted_status=$?
  kubectl debug pod/ephemeral-policy-base -n "$NS" --context "$CTX" --target=ephemeral-policy-base \
    --attach=false --image=registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56 \
    --profile=general -- true >/dev/null 2>&1
  digest_ephemeral_status=$?
  task2_port_denials_isolated ephemeral-policy-base
  strict_port_status=$?
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
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-init-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  digest_init_status=$?

  # UPDATE of an existing Pod is a real image-change path, not a CREATE request.
  update_latest_pod="latest-update-$(date +%s%N)-$$"
  kubectl run "$update_latest_pod" -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  update_latest_create_status=$?
  update_latest_output=""
  update_latest_status=1
  update_latest_positive_status=1
  if [[ "$update_latest_create_status" -eq 0 ]]; then
    update_latest_output=$(kubectl patch pod "$update_latest_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/containers/0/image","value":"registry.k8s.io/pause:latest"}]' 2>&1)
    update_latest_status=$?
    kubectl patch pod "$update_latest_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/containers/0/image","value":"registry.k8s.io/pause:3.11"}]' >/dev/null 2>&1
    update_latest_positive_status=$?
  fi
  update_latest_attributed=false
  kyverno_denied_by deny-latest-tag "$update_latest_status" "$update_latest_output" && update_latest_attributed=true
  kubectl delete pod "$update_latest_pod" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  update_init_pod="latest-init-update-$(date +%s%N)-$$"
  kubectl run "$update_init_pod" -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true},"initContainers":[{"name":"init","image":"registry.k8s.io/pause:3.10"}]}}' >/dev/null 2>&1
  update_init_create_status=$?
  update_init_output=""; update_init_status=1; update_init_positive_status=1
  if [[ "$update_init_create_status" -eq 0 ]]; then
    update_init_output=$(kubectl patch pod "$update_init_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/initContainers/0/image","value":"registry.k8s.io/pause:latest"}]' 2>&1)
    update_init_status=$?
    kubectl patch pod "$update_init_pod" -n "$NS" --context "$CTX" --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/initContainers/0/image","value":"registry.k8s.io/pause:3.11"}]' >/dev/null 2>&1
    update_init_positive_status=$?
  fi
  update_init_attributed=false
  kyverno_denied_by deny-latest-tag "$update_init_status" "$update_init_output" && update_init_attributed=true
  kubectl delete pod "$update_init_pod" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  set -e
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$untagged_status" -ne 0 \
    && "$main_attributed" == "true" && "$untagged_attributed" == "true" \
    && "$init_attributed" == "true" && "$untagged_init_attributed" == "true" \
    && "$base_status" -eq 0 && "$ephemeral_latest_attributed" == "true" && "$ephemeral_untagged_attributed" == "true" \
    && "$ephemeral_trusted_status" -eq 0 && "$digest_status" -eq 0 \
    && "$digest_init_status" -eq 0 && "$digest_ephemeral_status" -eq 0 \
    && "$strict_port_status" -eq 0 \
    && "$update_latest_create_status" -eq 0 && "$update_latest_attributed" == "true" \
    && "$update_latest_positive_status" -eq 0 \
    && "$update_init_create_status" -eq 0 && "$update_init_attributed" == "true" \
    && "$update_init_positive_status" -eq 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'deny-latest-tag' does not exist, is not apiVersion policies.kyverno.io/v1, does not have validationActions: [Deny], is not limited to namespace policy-108, or its resourceRules do not cover pods CREATE, pods UPDATE and pods/ephemeralcontainers UPDATE."
    elif [[ "$main_status" -eq 0 ]]; then
      echo "HINT: A Pod with image tag ':latest' was admitted - it should be denied. Check your CEL expression actually parses the tag, not just checks for the string 'latest' loosely."
    elif [[ "$untagged_status" -eq 0 ]]; then
      echo "HINT: A Pod with NO tag at all (implicit latest) was admitted - an image reference without ':tag' defaults to 'latest' and must be denied the same way as an explicit ':latest'."
    elif [[ "$port_untagged_attributed" != "true" ]]; then
      echo "HINT: 'registry.example:5000/app' has a registry port but no image tag. The colon before the last '/' is not a tag separator; deny-latest-tag must reject it as implicit latest."
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
    elif [[ "$digest_init_status" -ne 0 || "$digest_ephemeral_status" -ne 0 ]]; then
      echo "HINT: Digest-pinned images must be accepted in regular, init and ephemeral container lists."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A correctly pinned image was unexpectedly rejected - check your policy is not too broad (e.g. accidentally matching any image string containing digits, or blocking all debug/ephemeral operations)."
    fi
    echo "policy_contract=$policy_status main=$main_status untagged=$untagged_status port_untagged=$port_untagged_status port_attributed=$port_untagged_attributed init=$init_status untagged_init=$untagged_init_status port_init_attributed=$port_init_attributed base=$base_status ephemeral_latest=$ephemeral_latest_status ephemeral_untagged=$ephemeral_untagged_status ephemeral_port_attributed=$ephemeral_port_attributed ephemeral_trusted=$ephemeral_trusted_status digest=$digest_status digest_init=$digest_init_status digest_ephemeral=$digest_ephemeral_status update_create=$update_latest_create_status update_attributed=$update_latest_attributed update_positive=$update_latest_positive_status"; result=1
  fi
  record_result "$result"
}

@test "3. require-run-as-non-root blocks Pod-level and container-level root overrides" {
  set +e
  policy_contract_ok require-run-as-non-root
  policy_status=$?
  root_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  root_status=$?
  root_attributed=false
  kyverno_denied_by require-run-as-non-root "$root_status" "$root_output" && root_attributed=true
  unset_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  unset_status=$?
  unset_attributed=false
  kyverno_denied_by require-run-as-non-root "$unset_status" "$unset_output" && unset_attributed=true
  main_override_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: container-root-override-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
EOF
)
  main_override_status=$?
  main_override_attributed=false
  kyverno_denied_by require-run-as-non-root "$main_override_status" "$main_override_output" && main_override_attributed=true
  init_override_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: init-root-override-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  init_override_status=$?
  init_override_attributed=false
  kyverno_denied_by require-run-as-non-root "$init_override_status" "$init_override_output" && init_override_attributed=true
  main_runasnonroot_only_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_MAIN_RUNASNONROOT_ONLY'
apiVersion: v1
kind: Pod
metadata:
  name: main-runasnonroot-only-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsNonRoot: false
EOF_MAIN_RUNASNONROOT_ONLY
  )
  main_runasnonroot_only_status=$?
  main_runasnonroot_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${main_runasnonroot_only_status}" "${main_runasnonroot_only_output}" && main_runasnonroot_only_attributed=true
  main_runasuser_only_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_MAIN_RUNASUSER_ONLY'
apiVersion: v1
kind: Pod
metadata:
  name: main-runasuser-only-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsUser: 0
EOF_MAIN_RUNASUSER_ONLY
  )
  main_runasuser_only_status=$?
  main_runasuser_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${main_runasuser_only_status}" "${main_runasuser_only_output}" && main_runasuser_only_attributed=true
  init_runasnonroot_only_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_INIT_RUNASNONROOT_ONLY'
apiVersion: v1
kind: Pod
metadata:
  name: init-runasnonroot-only-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF_INIT_RUNASNONROOT_ONLY
  )
  init_runasnonroot_only_status=$?
  init_runasnonroot_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${init_runasnonroot_only_status}" "${init_runasnonroot_only_output}" && init_runasnonroot_only_attributed=true
  init_runasuser_only_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_INIT_RUNASUSER_ONLY'
apiVersion: v1
kind: Pod
metadata:
  name: init-runasuser-only-negative
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsUser: 0
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF_INIT_RUNASUSER_ONLY
  )
  init_runasuser_only_status=$?
  init_runasuser_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${init_runasuser_only_status}" "${init_runasuser_only_output}" && init_runasuser_only_attributed=true
  pod_uid_zero_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-uid-zero-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 0
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  pod_uid_zero_status=$?
  pod_uid_zero_attributed=false
  kyverno_denied_by require-run-as-non-root "$pod_uid_zero_status" "$pod_uid_zero_output" && pod_uid_zero_attributed=true
  override_positive_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: positive-nonroot-override
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
EOF
)
  override_positive_status=$?

  ephemeral_root_pod="ephemeral-root-$(date +%s%N)-$$"
  kubectl run "$ephemeral_root_pod" -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  ephemeral_create_status=$?
  ephemeral_root_output=""
  ephemeral_root_status=1
  if [[ "$ephemeral_create_status" -eq 0 ]]; then
    ephemeral_root_output=$(kubectl patch pod "$ephemeral_root_pod" -n "$NS" --context "$CTX" \
      --subresource=ephemeralcontainers --type=json --dry-run=server \
      -p='[{"op":"add","path":"/spec/ephemeralContainers","value":[{"name":"debug-root","image":"registry.k8s.io/pause:3.10","securityContext":{"runAsNonRoot":false,"runAsUser":0}}]}]' 2>&1)
    ephemeral_root_status=$?
  fi
  ephemeral_root_attributed=false
  kyverno_denied_by require-run-as-non-root "$ephemeral_root_status" "$ephemeral_root_output" && ephemeral_root_attributed=true
  eph_runasnonroot_only_output=$(kubectl patch pod "$ephemeral_root_pod" -n "$NS" --context "$CTX" \
    --subresource=ephemeralcontainers --type=json --dry-run=server \
    -p='[{"op":"add","path":"/spec/ephemeralContainers","value":[{"name":"debug-runasnonroot","image":"registry.k8s.io/pause:3.10","securityContext":{"runAsNonRoot":false}}]}]' 2>&1)
  eph_runasnonroot_only_status=$?
  eph_runasnonroot_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${eph_runasnonroot_only_status}" "${eph_runasnonroot_only_output}" && eph_runasnonroot_only_attributed=true
  eph_runasuser_only_output=$(kubectl patch pod "$ephemeral_root_pod" -n "$NS" --context "$CTX" \
    --subresource=ephemeralcontainers --type=json --dry-run=server \
    -p='[{"op":"add","path":"/spec/ephemeralContainers","value":[{"name":"debug-runasuser","image":"registry.k8s.io/pause:3.10","securityContext":{"runAsUser":0}}]}]' 2>&1)
  eph_runasuser_only_status=$?
  eph_runasuser_only_attributed=false
  kyverno_denied_by require-run-as-non-root "${eph_runasuser_only_status}" "${eph_runasuser_only_output}" && eph_runasuser_only_attributed=true
  kubectl delete pod "$ephemeral_root_pod" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  set -e
  if [[ "$policy_status" -eq 0 && "$root_attributed" == "true" && "$unset_attributed" == "true" \
    && "$main_override_attributed" == "true" && "$init_override_attributed" == "true" \
    && "$pod_uid_zero_attributed" == "true" && "$override_positive_status" -eq 0 \
    && "$main_runasnonroot_only_attributed" == "true" && "$main_runasuser_only_attributed" == "true" \
    && "$init_runasnonroot_only_attributed" == "true" && "$init_runasuser_only_attributed" == "true" \
    && "$ephemeral_create_status" -eq 0 && "$ephemeral_root_attributed" == "true" \
    && "$eph_runasnonroot_only_attributed" == "true" && "$eph_runasuser_only_attributed" == "true" ]]; then
    result=0
  else
    echo "HINT: require-run-as-non-root must DENY unset/false Pod-level values, Pod UID 0, and root overrides in containers, initContainers and ephemeralContainers. All denials must be attributed to this policy; a safe container-level override must be admitted."
    echo "policy=$policy_status root=$root_attributed unset=$unset_attributed main_override=$main_override_attributed init_override=$init_override_attributed pod_uid_zero=$pod_uid_zero_attributed positive=$override_positive_status ephemeral_create=$ephemeral_create_status ephemeral_override=$ephemeral_root_attributed ephemeral_message=$ephemeral_root_output"
    result=1
  fi
  record_result "$result"
}

@test "4. allow-approved-registries blocks bypasses and admits trusted images in all container lists" {
  set +e
  policy_contract_ok allow-approved-registries
  policy_status=$?
  main_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  main_status=$?
  main_attributed=false
  kyverno_denied_by allow-approved-registries "$main_status" "$main_output" && main_attributed=true
  unqualified_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  unqualified_status=$?
  unqualified_attributed=false
  kyverno_denied_by allow-approved-registries "$unqualified_status" "$unqualified_output" && unqualified_attributed=true
  # A pinned (non-latest) tag is used here deliberately: task 2's policy must already
  # deny ":latest" regardless of registry, so an unpinned tag on quay.io would be denied
  # for an ambiguous reason and would NOT isolate/prove the registry allowlist control
  # specifically (this probe's only purpose is to confirm quay.io itself is rejected).
  quay_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  quay_status=$?
  quay_attributed=false
  kyverno_denied_by allow-approved-registries "$quay_status" "$quay_output" && quay_attributed=true
  lookalike_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  lookalike_status=$?
  lookalike_attributed=false
  kyverno_denied_by allow-approved-registries "$lookalike_status" "$lookalike_output" && lookalike_attributed=true
  lookalike_path_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  lookalike_path_status=$?
  lookalike_path_attributed=false
  kyverno_denied_by allow-approved-registries "$lookalike_path_status" "$lookalike_path_output" && lookalike_path_attributed=true
  init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
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
)
  init_status=$?
  init_attributed=false
  kyverno_denied_by allow-approved-registries "$init_status" "$init_output" && init_attributed=true
  quay_init_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: unapproved-quay-init-must-fail
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: quay.io/prometheus/busybox:v0.24.0
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  quay_init_status=$?
  quay_init_attributed=false
  kyverno_denied_by allow-approved-registries "$quay_init_status" "$quay_init_output" && quay_init_attributed=true
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
  cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: approved-ghcr-init
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: ghcr.io/cks-lab/init:1.0.0
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
  trusted_ghcr_init_status=$?

  # Reuse a real running trusted Pod to exercise the ephemeralcontainers subresource.
  kubectl delete pod registry-ephemeral-base -n "$NS" --context "$CTX" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1
  kubectl run registry-ephemeral-base -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  kubectl wait pod/registry-ephemeral-base -n "$NS" --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  base_status=$?
  ephemeral_untrusted_output=$(kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --image=docker.io/library/busybox:1.36 --profile=general -- true 2>&1)
  ephemeral_untrusted_status=$?
  ephemeral_untrusted_attributed=false
  kyverno_denied_by allow-approved-registries "$ephemeral_untrusted_status" "$ephemeral_untrusted_output" && ephemeral_untrusted_attributed=true
  ephemeral_lookalike_output=$(kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --image=ghcr.io/cks-lab.evil/debug:1.0.0 --profile=general -- true 2>&1)
  ephemeral_lookalike_status=$?
  ephemeral_lookalike_attributed=false
  kyverno_denied_by allow-approved-registries "$ephemeral_lookalike_status" "$ephemeral_lookalike_output" && ephemeral_lookalike_attributed=true
  kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true >/dev/null 2>&1
  ephemeral_trusted_status=$?
  kubectl debug pod/registry-ephemeral-base -n "$NS" --context "$CTX" --target=registry-ephemeral-base \
    --attach=false --image=ghcr.io/cks-lab/debug:1.0.0 --profile=general -- true >/dev/null 2>&1
  ephemeral_ghcr_trusted_status=$?
  kubectl delete pod registry-ephemeral-base -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1

  update_registry_pod="registry-update-$(date +%s%N)-$$"
  kubectl run "$update_registry_pod" -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true}}}' >/dev/null 2>&1
  update_registry_create_status=$?
  update_registry_output=""
  update_registry_status=1
  update_registry_positive_status=1
  if [[ "$update_registry_create_status" -eq 0 ]]; then
    update_registry_output=$(kubectl patch pod "$update_registry_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/containers/0/image","value":"docker.io/library/busybox:1.36"}]' 2>&1)
    update_registry_status=$?
    kubectl patch pod "$update_registry_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/containers/0/image","value":"ghcr.io/cks-lab/app:1.0.0"}]' >/dev/null 2>&1
    update_registry_positive_status=$?
  fi
  update_registry_attributed=false
  kyverno_denied_by allow-approved-registries "$update_registry_status" "$update_registry_output" && update_registry_attributed=true
  kubectl delete pod "$update_registry_pod" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  update_registry_init_pod="registry-init-update-$(date +%s%N)-$$"
  kubectl run "$update_registry_init_pod" -n "$NS" --context "$CTX" --restart=Never \
    --image=registry.k8s.io/pause:3.10 \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true},"initContainers":[{"name":"init","image":"registry.k8s.io/pause:3.10"}]}}' >/dev/null 2>&1
  update_registry_init_create_status=$?
  update_registry_init_output=""; update_registry_init_status=1; update_registry_init_positive_status=1
  if [[ "$update_registry_init_create_status" -eq 0 ]]; then
    update_registry_init_output=$(kubectl patch pod "$update_registry_init_pod" -n "$NS" --context "$CTX" \
      --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/initContainers/0/image","value":"quay.io/prometheus/busybox:v0.24.0"}]' 2>&1)
    update_registry_init_status=$?
    kubectl patch pod "$update_registry_init_pod" -n "$NS" --context "$CTX" --type=json --dry-run=server \
      -p='[{"op":"replace","path":"/spec/initContainers/0/image","value":"ghcr.io/cks-lab/init:1.0.0"}]' >/dev/null 2>&1
    update_registry_init_positive_status=$?
  fi
  update_registry_init_attributed=false
  kyverno_denied_by allow-approved-registries "$update_registry_init_status" "$update_registry_init_output" && update_registry_init_attributed=true
  kubectl delete pod "$update_registry_init_pod" -n "$NS" --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  set -e
  if [[ "$policy_status" -eq 0 && "$main_status" -ne 0 && "$unqualified_status" -ne 0 \
    && "$main_attributed" == "true" && "$unqualified_attributed" == "true" \
    && "$quay_attributed" == "true" && "$lookalike_attributed" == "true" && "$lookalike_path_attributed" == "true" \
    && "$init_attributed" == "true" && "$trusted_lists_status" -eq 0 && "$trusted_ghcr_init_status" -eq 0 && "$base_status" -eq 0 \
    && "$ephemeral_untrusted_attributed" == "true" && "$ephemeral_trusted_status" -eq 0 \
    && "$ephemeral_ghcr_trusted_status" -eq 0 \
    && "$quay_init_attributed" == "true" && "$ephemeral_lookalike_attributed" == "true" \
    && "$update_registry_create_status" -eq 0 && "$update_registry_attributed" == "true" \
    && "$update_registry_positive_status" -eq 0 \
    && "$update_registry_init_create_status" -eq 0 && "$update_registry_init_attributed" == "true" \
    && "$update_registry_init_positive_status" -eq 0 ]]; then result=0; else
    if [[ "$policy_status" -ne 0 ]]; then
      echo "HINT: ValidatingPolicy 'allow-approved-registries' does not exist, is not enforced (Deny), is not limited to namespace policy-108, or its resourceRules do not cover pods CREATE, pods UPDATE and pods/ephemeralcontainers UPDATE."
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
    elif [[ "$main_attributed" != "true" || "$unqualified_attributed" != "true" || "$quay_attributed" != "true" || "$lookalike_attributed" != "true" || "$lookalike_path_attributed" != "true" || "$init_attributed" != "true" || "$ephemeral_untrusted_attributed" != "true" ]]; then
      echo "HINT: One or more negative probes were denied, but not by ValidatingPolicy allow-approved-registries. A denial from another policy does not prove this task."
    elif [[ "$trusted_lists_status" -ne 0 ]]; then
      echo "HINT: A Pod with BOTH main and init containers from approved registries was rejected - it should be allowed. Check your allowlist actually covers both 'registry.k8s.io' and 'ghcr.io/cks-lab' if both are meant to be trusted."
    elif [[ "$trusted_ghcr_init_status" -ne 0 || "$ephemeral_ghcr_trusted_status" -ne 0 ]]; then
      echo "HINT: Both approved prefixes must be accepted in every container list, including ghcr.io/cks-lab/* in initContainers and ephemeralContainers."
    elif [[ "$ephemeral_untrusted_status" -eq 0 ]]; then
      echo "HINT: 'kubectl debug' adding an ephemeral container from an unapproved registry was admitted - check your policy also covers spec.ephemeralContainers."
    elif [[ "$base_status" -ne 0 || "$ephemeral_trusted_status" -ne 0 ]]; then
      echo "HINT: A Pod/ephemeral container from an approved registry was unexpectedly rejected - your allowlist match may be too narrow (e.g. exact string match instead of prefix match)."
    fi
    echo "policy_contract=$policy_status main=$main_status main_attributed=$main_attributed unqualified=$unqualified_status unqualified_attributed=$unqualified_attributed quay=$quay_status quay_attributed=$quay_attributed lookalike=$lookalike_status lookalike_attributed=$lookalike_attributed lookalike_path=$lookalike_path_status lookalike_path_attributed=$lookalike_path_attributed init=$init_status init_attributed=$init_attributed quay_init_attributed=$quay_init_attributed trusted_lists=$trusted_lists_status ghcr_init=$trusted_ghcr_init_status base=$base_status ephemeral_untrusted=$ephemeral_untrusted_status ephemeral_untrusted_attributed=$ephemeral_untrusted_attributed ephemeral_lookalike_attributed=$ephemeral_lookalike_attributed ephemeral_trusted=$ephemeral_trusted_status ephemeral_ghcr=$ephemeral_ghcr_trusted_status update_create=$update_registry_create_status update_attributed=$update_registry_attributed update_positive=$update_registry_positive_status"; result=1
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
  mutated_outside=$(cat <<'EOF' | kubectl apply --dry-run=server --context "$CTX" -o json -f - 2>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: mutation-scope-check
  namespace: default
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
)
  outside_status=$?
  set -e
  label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated" 2>/dev/null)
  existing_label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated_existing" 2>/dev/null)
  outside_label=$(jq -r '.metadata.labels["security.cks.io/managed-by"] // empty' <<<"$mutated_outside" 2>/dev/null)
  has_mutate=$(jq -r '(.spec.mutations // []) | length' <<<"$policy" 2>/dev/null)
  mutation_contract_status=0
  mutating_policy_contract_ok <<<"$policy" || mutation_contract_status=1
  if [[ "$mutation_contract_status" -eq 0 && "$admission_status" -eq 0 && "$label" == "kyverno" && "$has_mutate" -ge 1 \
    && "$existing_status" -eq 0 && "$existing_label" == "external" \
    && "$outside_status" -eq 0 && -z "$outside_label" ]]; then
    echo '1' >> /var/work/tests/result/ok
  else
    if [[ "$mutation_contract_status" -ne 0 ]]; then
      echo "OPTIONAL HINT: MutatingPolicy must have an exact policy-108 namespace boundary, only Pod CREATE/UPDATE rules (must cover CREATE), and no object/namespace exclusions or broader match conditions. Testing default alone is insufficient to prove scope."
    elif [[ "$has_mutate" -lt 1 ]]; then
      echo "OPTIONAL HINT: MutatingPolicy 'add-kyverno-managed-label' has no mutations defined - add a mutation adding label 'security.cks.io/managed-by: kyverno'."
    elif [[ "$label" != "kyverno" ]]; then
      echo "OPTIONAL HINT: The dry-run admission response Pod is missing label 'security.cks.io/managed-by: kyverno' - check the mutation's applyConfiguration/patch actually sets this exact key/value."
    elif [[ "$existing_label" != "external" ]]; then
      echo "OPTIONAL HINT: A Pod that already had label 'security.cks.io/managed-by: external' had its value overwritten to '$existing_label' - the mutation must only ADD the label if it is absent, not unconditionally overwrite an existing value."
    elif [[ "$outside_status" -ne 0 || -n "$outside_label" ]]; then
      echo "OPTIONAL HINT: MutatingPolicy must be scoped to namespace policy-108. A dry-run Pod in namespace default must remain unmodified."
    fi
    echo "OPTIONAL: mutation not ready (contract=$mutation_contract_status admission_status=$admission_status label=$label existing_status=$existing_status existing_label=$existing_label outside_status=$outside_status outside_label=$outside_label mutate_rules=$has_mutate)"
  fi
  # Последний этап опционален: check_result его проверяет, но не делает лабу неуспешной -
  # если MutatingPolicy отсутствует вовсе, шаг выше уже вернул до этой точки без записи в
  # result/all. Если policy существует, но не проходит проверку - это засчитывается как
  # обычный провалившийся (но не пропущенный) тест.
  true
}

@test "6. ImagePolicyWebhook denies :latest via external backend and admits a pinned tag" {
  # Scope signal/EXIT handlers to this test only; other Bats cases keep their own traps.
  (
  manifest=$(node_ssh "sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true)
  baseline_plugins=$(node_ssh "sudo cat /var/lib/cks-lab108-checker/baseline-admission-plugins.txt" 2>/dev/null || true)
  backend_kubeconfig=$(node_ssh "sudo cat /etc/kubernetes/image-policy/kubeconfig" 2>/dev/null || true)
  admission_config=$(node_ssh "sudo cat /etc/kubernetes/image-policy/admission-config.yaml" 2>/dev/null || true)
  backend_server=$(grep -E '^[[:space:]]*server:[[:space:]]*' <<<"$backend_kubeconfig" | head -n1 | sed -E "s/^[[:space:]]*server:[[:space:]]*//; s/^[\"']//; s/[\"'][[:space:]]*$//")
  backend_https_ok=false
  [[ "$backend_server" =~ ^https://[^/]+:8443/imagepolicy$ ]] && backend_https_ok=true
  default_allow_false=false
  grep -Eq '^[[:space:]]*defaultAllow:[[:space:]]*false[[:space:]]*$' <<<"$admission_config" && default_allow_false=true
  service_port=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | jq -r '[.spec.ports[]? | select(.port == 8443)] | length') || service_port=0
  service_ip=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
  backend_service_target_ok=false
  [[ -n "$service_ip" && "$backend_server" == "https://${service_ip}:8443/imagepolicy" ]] && backend_service_target_ok=true
  current_plugins=$(sed -nE 's/^[[:space:]]*-[[:space:]]*--enable-admission-plugins=([^"[:space:]]*).*$/\1/p' <<<"$manifest" | head -n1)
  plugin_flag_count=$(grep -Ec '^[[:space:]]*-[[:space:]]*--enable-admission-plugins=' <<<"$manifest" || true)
  image_policy_plugin_enabled=false
  if [[ "$plugin_flag_count" -eq 1 ]] && grep -qE '(^|,)ImagePolicyWebhook(,|$)' <<<"$current_plugins"; then
    image_policy_plugin_enabled=true
  fi
  backend_available=$(kubectl get deployment image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | \
    jq -r '.status.availableReplicas // 0' 2>/dev/null)
  # Verify every plugin that was already enabled before the student's change (per the
  # bootstrap-captured baseline) is still present after adding ImagePolicyWebhook - a
  # config that ADDS the new plugin by REPLACING the whole flag value would silently
  # drop e.g. NodeRestriction and must not pass just because 'ImagePolicyWebhook' is
  # present somewhere in the manifest.
  # kubeadm explicitly enables NodeRestriction (not a default-on plugin). The
  # control-plane bootstrap snapshot lives on a node where students have sudo,
  # so an empty/replaced snapshot is NOT sufficient evidence of preservation.
  # Require the expected kubeadm safety plugin independently of that snapshot.
  required_node_restriction_ok=false
  if [[ "$plugin_flag_count" -eq 1 ]] \
    && [[ ",$current_plugins," == *,NodeRestriction,* ]]; then
    required_node_restriction_ok=true
  fi
  baseline_snapshot_ok=false
  if [[ -n "$baseline_plugins" && ",$baseline_plugins," == *,NodeRestriction,* ]]; then
    baseline_snapshot_ok=true
  fi
  preserved_baseline_plugins="yes"
  if [[ "$baseline_snapshot_ok" != "true" ]]; then
    preserved_baseline_plugins="no"
  else
    IFS=',' read -ra _baseline_arr <<<"$baseline_plugins"
    for p in "${_baseline_arr[@]}"; do
      [[ -z "$p" ]] && continue
      if [[ ",$current_plugins," != *",${p},"* ]]; then
        preserved_baseline_plugins="no"
        break
      fi
    done
  fi
  set +e
  kubectl delete pod -n default webhook-latest-must-fail webhook-pinned-ok webhook-failclosed-must-fail --context "$CTX" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1
  kubectl run -n default webhook-latest-must-fail --image=nginx:latest --context "$CTX" 2>/tmp/webhook-latest-err.txt >/dev/null
  latest_status=$?
  implicit_output=$(kubectl run -n default webhook-implicit-must-fail --image=nginx --dry-run=server --context "$CTX" 2>&1)
  implicit_status=$?
  port_implicit_output=$(kubectl run -n default webhook-port-implicit-must-fail --image=registry.example:5000/app --dry-run=server --context "$CTX" 2>&1)
  port_implicit_status=$?
  kubectl run -n default webhook-pinned-ok --image=nginx:1.27.3 --context "$CTX" >/dev/null 2>&1
  kubectl wait -n default pod/webhook-pinned-ok --context "$CTX" --for=condition=Ready --timeout=90s >/dev/null 2>&1
  pinned_status=$?
  deny_message=$(cat /tmp/webhook-latest-err.txt 2>/dev/null || true)

  # Explicitly test user-supplied ImageReview annotations: they MUST NOT bypass the
  # backend. Also verify initContainer and ephemeralContainer paths, not only main.
  annotation_bypass_output=$(kubectl run -n default webhook-user-annotation-must-fail \
    --annotations='alpha.image-policy.k8s.io/break-glass=true' \
    --image=nginx:latest --dry-run=server --context "$CTX" 2>&1)
  annotation_bypass_status=$?
  init_latest_output=$(kubectl apply --dry-run=server -n default --context "$CTX" -f - 2>&1 <<'EOF_IPW_INIT'
apiVersion: v1
kind: Pod
metadata:
  name: webhook-init-latest-must-fail
  namespace: default
spec:
  initContainers:
  - name: init
    image: nginx:latest
  containers:
  - name: app
    image: nginx:1.27.3
EOF_IPW_INIT
  )
  init_latest_status=$?
  init_pinned_output=$(kubectl apply --dry-run=server -n default --context "$CTX" -f - 2>&1 <<'EOF_IPW_INIT_OK'
apiVersion: v1
kind: Pod
metadata:
  name: webhook-init-pinned-positive
  namespace: default
spec:
  initContainers:
  - name: init
    image: nginx:1.27.3
  containers:
  - name: app
    image: nginx:1.27.3
EOF_IPW_INIT_OK
  )
  init_pinned_status=$?
  ephemeral_latest_output=$(kubectl debug -n default pod/webhook-pinned-ok --context "$CTX" \
    --target=webhook-pinned-ok --image=nginx:latest --profile=general -- true 2>&1)
  ephemeral_latest_status=$?
  ephemeral_positive_output=$(kubectl debug -n default pod/webhook-pinned-ok --context "$CTX" \
    --target=webhook-pinned-ok --attach=false \
    --image=registry.k8s.io/e2e-test-images/busybox:1.36-1 --profile=general -- true 2>&1)
  ephemeral_positive_status=$?

  # Enumerate actual namespaces (including kube-system, kube-public, Kyverno and
  # Gatekeeper namespaces). A backend hard-coded for default/gatekeeper-108/image-policy
  # must not pass while admitting latest or untagged images elsewhere.
  other_ns_probe_ok=true
  other_ns_probe_details=""
  namespace_list=$(kubectl get namespaces --context "$CTX" -o json 2>&1)
  namespace_list_status=$?
  probe_namespaces=()
  if [[ "$namespace_list_status" -ne 0 ]]; then
    other_ns_probe_ok=false
    other_ns_probe_details="Unable to enumerate namespaces: ${namespace_list}"
  else
    mapfile -t probe_namespaces < <(jq -r '.items[]? | select(.metadata.deletionTimestamp == null) | .metadata.name | select(. != "policy-108")' <<<"$namespace_list" 2>/dev/null)
    if [[ "${#probe_namespaces[@]}" -eq 0 || " ${probe_namespaces[*]} " != *" default "* \
      || " ${probe_namespaces[*]} " != *" kube-system "* ]]; then
      other_ns_probe_ok=false
      other_ns_probe_details="Namespace enumeration is incomplete or malformed."
    fi
  fi
  for probe_ns in "${probe_namespaces[@]}"; do
    nonce="$(date +%s%N)-$$"
    other_latest_output=$(kubectl run -n "$probe_ns" "ipw-latest-${nonce}" \
      --image=nginx:latest --dry-run=server --context "$CTX" 2>&1)
    other_latest_status=$?
    other_implicit_output=$(kubectl run -n "$probe_ns" "ipw-implicit-${nonce}" \
      --image=nginx --dry-run=server --context "$CTX" 2>&1)
    other_implicit_status=$?
    other_init_output=$(kubectl apply -n "$probe_ns" --dry-run=server --context "$CTX" -f - 2>&1 <<EOF_IPW_NS_INIT
apiVersion: v1
kind: Pod
metadata:
  name: ipw-init-${nonce}
  namespace: ${probe_ns}
spec:
  initContainers:
  - name: init
    image: nginx:latest
  containers:
  - name: app
    image: nginx:1.27.3
EOF_IPW_NS_INIT
    )
    other_init_status=$?
    other_pinned_output=$(kubectl run -n "$probe_ns" "ipw-pinned-${nonce}" \
      --image=nginx:1.27.3 --dry-run=server --context "$CTX" 2>&1)
    other_pinned_status=$?
    if [[ "$other_latest_status" -eq 0 || "$other_latest_output" != *'image policy webhook backend denied'* \
      || "$other_implicit_status" -eq 0 || "$other_implicit_output" != *'image policy webhook backend denied'* \
      || "$other_init_status" -eq 0 || "$other_init_output" != *'image policy webhook backend denied'* \
      || "$other_pinned_status" -ne 0 ]]; then
      other_ns_probe_ok=false
      other_ns_probe_details="${other_ns_probe_details} ns=${probe_ns} latest=${other_latest_status} latest_message=${other_latest_output} implicit=${other_implicit_status} implicit_message=${other_implicit_output} init=${other_init_status} init_message=${other_init_output} allow=${other_pinned_status} allow_message=${other_pinned_output};"
    fi
  done

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
  original_selector=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | jq -c '.spec.selector // {}' 2>/dev/null || true)
  selector_restore_pending=0
  restore_webhook_selector() {
    [[ "$selector_restore_pending" -eq 1 ]] || return 0
    local restore_json observed
    restore_json=$(jq -nc --argjson original "$original_selector" \
      '[{"op":"test","path":"/spec/selector","value":{"app":"image-policy-backend-detached-for-probe"}},{"op":"replace","path":"/spec/selector","value":$original}]') || return 1
    for _ in $(seq 1 30); do
      observed=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | jq -c '.spec.selector // {}' 2>/dev/null)
      if [[ "$observed" != '{"app":"image-policy-backend-detached-for-probe"}' && "$observed" != "$original_selector" ]]; then
        echo "FATAL: Concurrent Service selector change; checker will not overwrite it." >&2
        return 1
      fi
      if [[ "$observed" == "$original_selector" ]] || kubectl patch service image-policy-backend -n image-policy --context "$CTX" \
        --type=json -p "$restore_json" >/dev/null 2>&1; then
        observed=$(kubectl get service image-policy-backend -n image-policy --context "$CTX" -o json 2>/dev/null | jq -c '.spec.selector // {}' 2>/dev/null)
        if [[ "$observed" == "$original_selector" ]]; then
          selector_restore_pending=0
          return 0
        fi
      fi
      sleep 2
    done
    echo 'FATAL: Service image-policy/image-policy-backend selector could not be restored; new Pod admission may remain unavailable. Restore the selector from the saved original_selector before continuing.' >&2
    return 1
  }
  detach_patch_ok=1
  if [[ -n "$original_selector" && "$original_selector" != '{}' ]]; then
    # Arm cleanup before ANY write to Service; a partial/aborted patch still has
    # a chance to be repaired. Parent Bats runner handlers remain untouched.
    selector_restore_pending=1
    trap 'restore_webhook_selector || true' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    kubectl patch service image-policy-backend -n image-policy --context "$CTX" --type=json \
      -p "$(jq -nc --argjson original "$original_selector" '[{"op":"test","path":"/spec/selector","value":$original},{"op":"replace","path":"/spec/selector","value":{"app":"image-policy-backend-detached-for-probe"}}]')" >/dev/null 2>&1
    detach_patch_ok=$?
  fi
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
  # Endpoints can be empty while kube-proxy has not yet removed the old ClusterIP rules,
  # so a probe sent at that instant may still reach the old backend Pod. Wait (server-side
  # dry-run, nothing is created) until a never-seen image is actually refused; a fail-open
  # configuration is admitted on every attempt and still fails below.
  for _ in $(seq 1 20); do
    kubectl run -n default webhook-failclosed-wait --image="nginx:fcwait-$(date +%s%N)-$$" \
      --dry-run=server --context "$CTX" >/dev/null 2>&1 || break
    sleep 1
  done
  unique_tag="failclosed-$(date +%s%N)-$$"
  kubectl run -n default webhook-failclosed-must-fail --image="nginx:${unique_tag}" --context "$CTX" 2>/tmp/webhook-failclosed-err.txt >/dev/null
  failclosed_status=$?
  failclosed_message=$(cat /tmp/webhook-failclosed-err.txt 2>/dev/null || true)
  failclosed_is_backend_error=false
  # With endpoint detached, admission should fail on a request to the exact backend
  # URL, not because an unrelated policy denied the distinctive test image.
  [[ -n "$service_ip" && "$failclosed_message" == *"https://${service_ip}:8443/imagepolicy"* ]] && failclosed_is_backend_error=true
  # Restore the Service selector (routing back to the SAME, still-Running backend Pod -
  # no Pod creation involved, so nothing here can be blocked by ImagePolicyWebhook).
  # original_selector is captured above as compact JSON (via `-o json | jq -c`, NOT
  # `-o jsonpath`, since kubectl's jsonpath map printer emits Go-style `map[k:v]`
  # syntax which is not valid JSON and would make this patch a no-op silently
  # swallowed by the >/dev/null 2>&1 redirect below).
  restore_patch_status=1
  selector_exact_restored=false
  if [[ "$selector_restore_pending" -eq 1 ]]; then
    restore_webhook_selector
    restore_patch_status=$?
    if [[ "$restore_patch_status" -eq 0 ]]; then
      selector_exact_restored=true
      # Safe to disarm after live read-back: no Service mutation pending.
      trap - EXIT INT TERM
    fi
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
  recovery_status=1
  for _ in $(seq 1 30); do
    if kubectl run -n default "webhook-recovery-probe" --image="nginx:recovery-$(date +%s%N)" --dry-run=server -o name \
      --context "$CTX" >/dev/null 2>&1; then
      recovery_status=0
      break
    fi
    sleep 1
  done
  set -e
  if [[ "$manifest" == *'ImagePolicyWebhook'* \
    && "$manifest" == *'--admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml'* \
    && "$manifest" == *'imagepolicy.k8s.io/v1alpha1=true'* \
    && "$backend_https_ok" == "true" && "$backend_service_target_ok" == "true" \
    && "$default_allow_false" == "true" && "$service_port" -ge 1 \
    && "$preserved_baseline_plugins" == "yes" && "$image_policy_plugin_enabled" == "true" \
    && "$required_node_restriction_ok" == "true" && "$baseline_snapshot_ok" == "true" \
    && "$backend_available" -ge 1 \
    && "$latest_status" -ne 0 && "$deny_message" == *'image policy webhook backend denied'* \
    && "$implicit_status" -ne 0 && "$implicit_output" == *'image policy webhook backend denied'* \
    && "$port_implicit_status" -ne 0 && "$port_implicit_output" == *'image policy webhook backend denied'* \
    && "$annotation_bypass_status" -ne 0 && "$annotation_bypass_output" == *'image policy webhook backend denied'* \
    && "$init_latest_status" -ne 0 && "$init_latest_output" == *'image policy webhook backend denied'* \
    && "$init_pinned_status" -eq 0 \
    && "$ephemeral_latest_status" -ne 0 && "$ephemeral_latest_output" == *'image policy webhook backend denied'* \
    && "$ephemeral_positive_status" -eq 0 && "$pinned_status" -eq 0 \
    && "$other_ns_probe_ok" == "true" \
    && "$backend_detached_status" -eq 0 && "$failclosed_status" -ne 0 \
    && "$failclosed_is_backend_error" == "true" && "$detach_patch_ok" -eq 0 \
    && "$selector_exact_restored" == "true" && "$restore_patch_status" -eq 0 \
    && "$backend_restored_status" -eq 0 && "$recovery_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$backend_available" -lt 1 ]]; then
      echo "HINT: Deployment 'image-policy-backend' in namespace 'image-policy' has no available replicas - check the Deployment mounts the ConfigMap correctly and the Pod is actually Running."
    elif [[ "$manifest" != *'ImagePolicyWebhook'* ]]; then
      echo "HINT: kube-apiserver.yaml --enable-admission-plugins does not include ImagePolicyWebhook - add it to the EXISTING list (comma-separated), do not replace the whole flag value."
    elif [[ "$image_policy_plugin_enabled" != "true" ]]; then
      echo "HINT: Exactly one active --enable-admission-plugins flag must contain ImagePolicyWebhook as an exact plugin token. Comments and duplicate flags are not proof."
    elif [[ "$preserved_baseline_plugins" != "yes" ]]; then
      echo "HINT: kubeadm enables NodeRestriction. The baseline snapshot must contain it, and the CURRENT --enable-admission-plugins flag must still contain NodeRestriction alongside ImagePolicyWebhook. Baseline data on the student-administered node alone is not trusted proof."
    elif [[ "$manifest" != *'imagepolicy.k8s.io/v1alpha1=true'* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --runtime-config=imagepolicy.k8s.io/v1alpha1=true - without it the ImageReview API is not served and the backend is never called."
    elif [[ "$manifest" != *'--admission-control-config-file='* ]]; then
      echo "HINT: kube-apiserver.yaml is missing --admission-control-config-file pointing at your AdmissionConfiguration file."
    elif [[ "$backend_https_ok" != "true" ]]; then
      echo "HINT: /etc/kubernetes/image-policy/kubeconfig must target the backend with HTTPS on :8443/imagepolicy."
    elif [[ "$backend_service_target_ok" != "true" ]]; then
      echo "HINT: The HTTPS endpoint in kubeconfig must target image-policy-backend Service ClusterIP on :8443/imagepolicy, not an unrelated listener."
    elif [[ "$service_port" -lt 1 ]]; then
      echo "HINT: Service image-policy/image-policy-backend must expose port 8443."
    elif [[ "$default_allow_false" != "true" ]]; then
      echo "HINT: AdmissionConfiguration must explicitly set ImagePolicyWebhook imagePolicy.defaultAllow: false."
    elif [[ "$latest_status" -eq 0 ]]; then
      echo "HINT: Pod webhook-latest-must-fail (nginx:latest) was created - it should have been denied by the ImagePolicyWebhook backend. Check the backend is reachable from kube-apiserver (Service/kubeconfig server URL) and defaultAllow is false."
    elif [[ "$deny_message" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: The Pod was denied, but not with the expected ImagePolicyWebhook message - check the denial actually came from the backend (your server.py 'reason' field), not from an unrelated admission controller."
    elif [[ "$implicit_status" -eq 0 || "$port_implicit_status" -eq 0 || "$implicit_output" != *'image policy webhook backend denied'* || "$port_implicit_output" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: ImagePolicyWebhook backend must deny implicit latest, including registry-port images without a tag, with exact backend attribution."
    elif [[ "$annotation_bypass_status" -eq 0 || "$annotation_bypass_output" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: A Pod carrying the user-supplied annotation alpha.image-policy.k8s.io/break-glass=true was not denied by the backend - Pod annotations are attacker-controlled and must never bypass ImagePolicyWebhook."
    elif [[ "$init_latest_status" -eq 0 || "$init_latest_output" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: A Pod with a ':latest' initContainer in namespace default was not denied by the backend - ImagePolicyWebhook reviews initContainers too, do not limit the check to spec.containers."
    elif [[ "$ephemeral_latest_status" -eq 0 || "$ephemeral_latest_output" != *'image policy webhook backend denied'* ]]; then
      echo "HINT: 'kubectl debug' with a ':latest' ephemeral container in namespace default was not denied by the backend."
    elif [[ "$init_pinned_status" -ne 0 || "$ephemeral_positive_status" -ne 0 ]]; then
      echo "HINT: A correctly pinned initContainer or ephemeral container in namespace default was rejected - the backend must only deny latest/untagged images."
    elif [[ "$pinned_status" -ne 0 ]]; then
      echo "HINT: Pod webhook-pinned-ok (nginx:1.27.3) was not created/Ready - a correctly pinned tag should be allowed by the backend logic in server.py."
    elif [[ "$other_ns_probe_ok" != "true" ]]; then
      echo "HINT: ImagePolicyWebhook must deny explicit/implicit latest and latest initContainers in EVERY existing namespace except policy-108, while allowing pinned tags. ${other_ns_probe_details}"
    elif [[ "$backend_detached_status" -ne 0 ]]; then
      echo "HINT: Backend Endpoints did not become empty. Fail-closed was not actually tested."
    elif [[ "$failclosed_status" -eq 0 || "$failclosed_is_backend_error" != "true" ]]; then
      echo "HINT: A Pod was ADMITTED while the image-policy-backend Service was detached (unreachable) - defaultAllow must be false, so admission should be DENIED (fail-closed) when the backend cannot be reached, not silently allowed (fail-open)."
    elif [[ "$restore_patch_status" -ne 0 ]]; then
      echo "HINT: Failed to restore image-policy-backend Service's original selector."
    elif [[ "$backend_restored_status" -eq 0 && "$recovery_status" -ne 0 ]]; then
      echo "HINT: Service Endpoints returned, but admission through ImagePolicyWebhook did not recover within 30 seconds."
    else
      echo "HINT: image-policy-backend's Service did not recover its Endpoints after being restored - check nothing about the fail-closed probe left the Service/Deployment selector mismatched."
    fi
    echo "backend_available=$backend_available backend_server=$backend_server backend_https_ok=$backend_https_ok backend_service_target_ok=$backend_service_target_ok service_port_8443_count=$service_port default_allow_false=$default_allow_false preserved_baseline_plugins=$preserved_baseline_plugins baseline_plugins=$baseline_plugins current_plugins=$current_plugins latest_status=$latest_status implicit_status=$implicit_status implicit_message=$implicit_output port_implicit_status=$port_implicit_status port_implicit_message=$port_implicit_output pinned_status=$pinned_status backend_detached_status=$backend_detached_status failclosed_status=$failclosed_status failclosed_is_backend_error=$failclosed_is_backend_error restore_patch_status=$restore_patch_status backend_restored_status=$backend_restored_status recovery_status=$recovery_status deny_message=$deny_message failclosed_message=$failclosed_message"
    result=1
  fi
  kubectl delete pod -n default webhook-latest-must-fail webhook-pinned-ok webhook-failclosed-must-fail --context "$CTX" --ignore-not-found --wait=false >/dev/null 2>&1
  rm -f /tmp/webhook-latest-err.txt /tmp/webhook-failclosed-err.txt
  record_result "$result"
  )
}

@test "7. Gatekeeper ConstraintTemplate Rego blocks very-bad-registry.test without losing the old rule" {
  set +e
  template=$(kubectl get constrainttemplate k8sblockedregistries --context "$CTX" -o json 2>/dev/null)
  template_status=$?
  rego=$(jq -r '.spec.targets[] | select(.target == "admission.k8s.gatekeeper.sh") | .rego' <<<"$template" 2>/dev/null)
  constraint=$(kubectl get k8sblockedregistries deny-bad-registries --context "$CTX" -o json 2>/dev/null)
  constraint_status=$?
  constraint_contract_ok=false
  if [[ "$constraint_status" -eq 0 ]] && jq -e '
    .apiVersion == "constraints.gatekeeper.sh/v1beta1" and
    .kind == "K8sBlockedRegistries" and
    .metadata.name == "deny-bad-registries" and
    ((.spec.parameters // {}) | length) == 0 and
    ((.spec.match.namespaces // []) == ["gatekeeper-108"]) and
    (((.spec.match.excludedNamespaces // []) | length) == 0) and
    (((.spec.match.labelSelector // {}) | length) == 0) and
    (((.spec.match.namespaceSelector // {}) | length) == 0) and
    ((.spec.match.kinds // []) == [{"apiGroups":[""],"kinds":["Pod"]}])
  ' <<<"$constraint" >/dev/null 2>&1; then
    constraint_contract_ok=true
  fi
  constraints_for_template=$(kubectl get k8sblockedregistries --context "$CTX" -o json 2>/dev/null | jq -c '[.items[].metadata.name] | sort') || constraints_for_template='[]'
  constraint_set_exact=false
  [[ "$constraints_for_template" == '["deny-bad-registries"]' ]] && constraint_set_exact=true
  # The fix must be additive Rego, not a parameters edit: Constraint.spec.parameters is
  # not used by this ConstraintTemplate's Rego at all (it reads hardcoded
  # blocked_registry(...) facts), so a student who only patches
  # Constraint.spec.parameters.blocked would leave the Rego - and therefore the actual
  # admission behavior - completely unchanged.
  rego_has_old_untrusted=false
  grep -Eq '^[[:space:]]*blocked_registry\("untrusted-registry\.example"\)[[:space:]]*$' <<<"$rego" && rego_has_old_untrusted=true
  rego_has_old_docker_fake=false
  grep -Eq '^[[:space:]]*blocked_registry\("docker-fake\.test"\)[[:space:]]*$' <<<"$rego" && rego_has_old_docker_fake=true
  rego_has_new=false
  grep -Eq '^[[:space:]]*blocked_registry\("very-bad-registry\.test"\)[[:space:]]*$' <<<"$rego" && rego_has_new=true

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
  old_docker_fake_output=$(kubectl apply --dry-run=server --context "$CTX" -f - 2>&1 <<'EOF_POD'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-docker-fake
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: docker-fake.test/app:1
EOF_POD
)
  old_docker_fake_status=$?
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
  if [[ "$template_status" -eq 0 && "$constraint_contract_ok" == "true" && "$constraint_set_exact" == "true" \
    && "$rego_has_old_untrusted" == "true" && "$rego_has_old_docker_fake" == "true" && "$rego_has_new" == "true" \
    && "$new_bad_status" -ne 0 && "$new_bad_output" == *'[deny-bad-registries]'* && "$new_bad_output" == *'validation.gatekeeper.sh'* \
    && "$old_bad_status" -ne 0 && "$old_bad_output" == *'[deny-bad-registries]'* && "$old_bad_output" == *'validation.gatekeeper.sh'* \
    && "$old_docker_fake_status" -ne 0 && "$old_docker_fake_output" == *'[deny-bad-registries]'* && "$old_docker_fake_output" == *'validation.gatekeeper.sh'* \
    && "$trusted_status" -eq 0 ]]; then
    result=0
  else
    if [[ "$template_status" -ne 0 ]]; then
      echo "HINT: ConstraintTemplate 'k8sblockedregistries' not found - check it was not accidentally deleted, and that you edited the existing object rather than replacing it under a different name."
    elif [[ "$constraint_contract_ok" != "true" ]]; then
      echo "HINT: Constraint K8sBlockedRegistries/deny-bad-registries must remain Pod-only in gatekeeper-108 with no parameters, selectors or exclusions."
    elif [[ "$constraint_set_exact" != "true" ]]; then
      echo "HINT: This lab expects exactly one K8sBlockedRegistries Constraint: deny-bad-registries."
    elif [[ "$rego_has_old_untrusted" != "true" || "$rego_has_old_docker_fake" != "true" ]]; then
      echo "HINT: Keep BOTH original active Rego facts: untrusted-registry.example and docker-fake.test."
    elif [[ "$rego_has_new" != "true" ]]; then
      echo "HINT: spec.targets[].rego does not contain 'blocked_registry(\"very-bad-registry.test\")' yet - edit the ConstraintTemplate's Rego (not the Constraint's parameters, which this template does not even use) and add this fact."
    elif [[ "$new_bad_status" -eq 0 ]]; then
      echo "HINT: A Pod with image from 'very-bad-registry.test' in namespace gatekeeper-108 was admitted - it should be denied by the Gatekeeper constraint after your Rego fix."
    elif [[ "$new_bad_output" != *"k8sblockedregistries"* || "$new_bad_output" == *"kyverno"* ]]; then
      echo "HINT: The probe Pod was denied, but not clearly by the Gatekeeper 'k8sblockedregistries' constraint (or the denial actually came from an unrelated Kyverno policy) - check you fixed the ConstraintTemplate's Rego, not a Kyverno policy, and that the probe ran in namespace gatekeeper-108."
    elif [[ "$old_bad_status" -eq 0 ]]; then
      echo "HINT: A Pod with image from the ALREADY-blocked 'untrusted-registry.example' was admitted after your edit - your change must be additive (a new blocked_registry(...) fact alongside the existing one), not a replacement of the original rule."
    elif [[ "$old_docker_fake_status" -eq 0 ]]; then
      echo "HINT: docker-fake.test was blocked before the task and must remain denied after the edit."
    elif [[ "$trusted_status" -ne 0 ]]; then
      echo "HINT: A Pod from the already-trusted registry (registry.k8s.io) was denied after your fix - check your Rego edit did not accidentally introduce a syntax error or an overly broad rule."
    fi
    echo "template_status=$template_status constraint_status=$constraint_status constraint_contract_ok=$constraint_contract_ok constraint_set_exact=$constraint_set_exact constraints=$constraints_for_template rego_old_untrusted=$rego_has_old_untrusted rego_old_docker_fake=$rego_has_old_docker_fake rego_new=$rego_has_new new_bad_status=$new_bad_status new_bad_output=$new_bad_output old_bad_status=$old_bad_status old_bad_output=$old_bad_output old_docker_fake_status=$old_docker_fake_status old_docker_fake_output=$old_docker_fake_output trusted_status=$trusted_status trusted_output=$trusted_output"
    result=1
  fi
  record_result "$result"
}
