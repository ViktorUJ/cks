#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="security-104"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Minimal RBAC: auditor can only read pods in security-104" {
  echo '1' >> /var/work/tests/result/all
  role=$(kubectl get role pod-observer -n "$NS" --context "$CTX" -o json 2>/dev/null)
  binding=$(kubectl get rolebinding auditor-pod-observer -n "$NS" --context "$CTX" -o json 2>/dev/null)
  minimal=$(jq -r '(.rules | length == 1) and (.rules[0].apiGroups == [""]) and (.rules[0].resources == ["pods"]) and ((.rules[0].verbs | sort) == ["get", "list", "watch"])' <<<"$role" 2>/dev/null)
  bound=$(jq -r '.roleRef.kind == "Role" and .roleRef.name == "pod-observer" and ([.subjects[]? | select(.kind == "ServiceAccount" and .name == "auditor" and .namespace == "security-104")] | length == 1)' <<<"$binding" 2>/dev/null)
  cannot_delete=$(kubectl auth can-i delete secrets -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null)
  if [[ "$minimal" == "true" && "$bound" == "true" && "$cannot_delete" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    # Diagnostic hint: point at the first likely cause instead of a generic fail.
    if [[ "$minimal" != "true" ]]; then
      echo "HINT: Role 'pod-observer' must have exactly ONE rule: apiGroups [\"\"], resources [\"pods\"], verbs [\"get\",\"list\",\"watch\"]. Check for extra rules, extra verbs, or a wrong apiGroup."
    elif [[ "$bound" != "true" ]]; then
      echo "HINT: RoleBinding 'auditor-pod-observer' must bind Role 'pod-observer' to ServiceAccount 'auditor' in namespace '$NS'. Check roleRef.kind/name and subjects[].namespace."
    elif [[ "$cannot_delete" != "no" ]]; then
      echo "HINT: ServiceAccount 'auditor' can delete secrets - it has more access than the Role grants. Check for an extra ClusterRoleBinding or a second Role/RoleBinding."
    fi
    echo "minimal=$minimal binding=$bound auditor_can_delete_secrets=$cannot_delete"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. token-client uses a bounded API-default projected token that authenticates and has no secret deletion right" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod token-client -n "$NS" --context "$CTX" -o json 2>/dev/null)
  sa=$(kubectl get serviceaccount api-client -n "$NS" --context "$CTX" -o name 2>/dev/null)
  token_spec=$(jq -r '[.spec.volumes[]?.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and (.audience == null) and (.expirationSeconds | tonumber) <= 3600)] | length' <<<"$pod" 2>/dev/null)
  mounted=$(jq -r '. as $pod | [$pod.spec.volumes[]? | select(.projected != null) | . as $volume | ([.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and (.audience == null) and (.expirationSeconds | tonumber) <= 3600)] | length) as $tokens | select($tokens > 0) | $pod.spec.containers[]?.volumeMounts[]? | select(.name == $volume.name and .mountPath == "/var/run/secrets/tokens" and .readOnly == true)] | length' <<<"$pod" 2>/dev/null)
  auto=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  client_sa=$(jq -r '.spec.serviceAccountName' <<<"$pod" 2>/dev/null)
  projected_token=$(kubectl exec -n "$NS" token-client --context "$CTX" -- cat /var/run/secrets/tokens/api-token 2>/dev/null || true)
  review=$(jq -n --arg token "$projected_token" '{apiVersion:"authentication.k8s.io/v1",kind:"TokenReview",spec:{token:$token}}' | kubectl create --context "$CTX" -f - -o json 2>/dev/null || true)
  authenticated=$(jq -r '.status.authenticated // false' <<<"$review" 2>/dev/null)
  username=$(jq -r '.status.user.username // ""' <<<"$review" 2>/dev/null)
  cannot_delete=$(kubectl auth can-i delete secrets -n "$NS" --as="system:serviceaccount:$NS:api-client" --context "$CTX" 2>/dev/null)
  if [[ "$sa" == "serviceaccount/$NS/api-client" && "$client_sa" == "api-client" && "$auto" == "false" && "$token_spec" -ge 1 && "$mounted" -ge 1 && "$authenticated" == "true" && "$username" == "system:serviceaccount:$NS:api-client" && "$cannot_delete" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$sa" != "serviceaccount/$NS/api-client" || "$client_sa" != "api-client" ]]; then
      echo "HINT: Pod 'token-client' must use serviceAccountName 'api-client' in namespace '$NS'. Check spec.serviceAccountName."
    elif [[ "$auto" != "false" ]]; then
      echo "HINT: Pod 'token-client' must set automountServiceAccountToken: false - the projected token volume replaces the default mechanism, it does not add to it."
    elif [[ "$token_spec" -lt 1 ]]; then
      echo "HINT: The projected serviceAccountToken source must have path 'api-token', NO audience field set, and expirationSeconds <= 3600. Check for a hardcoded audience - it is easy to set one that the API server does not accept."
    elif [[ "$mounted" -lt 1 ]]; then
      echo "HINT: The projected volume must be mounted at exactly '/var/run/secrets/tokens' with readOnly: true. Check volumeMounts.mountPath spelling and the readOnly flag."
    elif [[ "$authenticated" != "true" ]]; then
      echo "HINT: TokenReview did not authenticate the token read from the Pod. The token file may be empty, stale, or the volume may not actually be mounted yet."
    elif [[ "$username" != "system:serviceaccount:$NS:api-client" ]]; then
      echo "HINT: TokenReview authenticated a DIFFERENT identity than expected. Check that the projected token belongs to ServiceAccount 'api-client', not another SA."
    elif [[ "$cannot_delete" != "no" ]]; then
      echo "HINT: ServiceAccount 'api-client' can delete secrets - it has more access than intended. Check for an unexpected RoleBinding/ClusterRoleBinding."
    fi
    echo "sa=$sa pod_sa=$client_sa automount=$auto projected_tokens=$token_spec mounted_projected_tokens=$mounted tokenreview_authenticated=$authenticated tokenreview_username=$username api_client_can_delete_secrets=$cannot_delete"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. no-token pod and ServiceAccount disable token automounting" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod no-token -n "$NS" --context "$CTX" -o json 2>/dev/null)
  sa=$(kubectl get serviceaccount no-token-sa -n "$NS" --context "$CTX" -o json 2>/dev/null)
  pod_auto=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  sa_auto=$(jq -r '.automountServiceAccountToken' <<<"$sa" 2>/dev/null)
  pod_sa=$(jq -r '.spec.serviceAccountName' <<<"$pod" 2>/dev/null)
  token_volumes=$(jq -r '[.spec.volumes[]? | select(.projected.sources[]?.serviceAccountToken)] | length' <<<"$pod" 2>/dev/null)
  if [[ "$pod_auto" == "false" && "$sa_auto" == "false" && "$pod_sa" == "no-token-sa" && "$token_volumes" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$pod_sa" != "no-token-sa" ]]; then
      echo "HINT: Pod 'no-token' must use serviceAccountName 'no-token-sa'. Check spec.serviceAccountName."
    elif [[ "$sa_auto" != "false" ]]; then
      echo "HINT: ServiceAccount 'no-token-sa' must have automountServiceAccountToken: false set on the ServiceAccount object itself, not only on the Pod."
    elif [[ "$pod_auto" != "false" ]]; then
      echo "HINT: Pod 'no-token' must ALSO set automountServiceAccountToken: false explicitly, even though the ServiceAccount already disables it - the task requires both, defence in depth."
    elif [[ "$token_volumes" != "0" ]]; then
      echo "HINT: The Pod still has a projected serviceAccountToken volume. If automount is truly disabled, Kubernetes will not inject this volume - check that you did not manually add one."
    fi
    echo "pod_automount=$pod_auto sa_automount=$sa_auto pod_sa=$pod_sa token_volumes=$token_volumes"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. Legacy wildcard ClusterRole and binding have been removed" {
  echo '1' >> /var/work/tests/result/all
  set +e
  kubectl get clusterrole legacy-operator-admin --context "$CTX" >/dev/null 2>&1
  role_status=$?
  kubectl get clusterrolebinding legacy-operator-admin --context "$CTX" >/dev/null 2>&1
  binding_status=$?
  set -e
  can_read=$(kubectl auth can-i get secrets -n "$NS" --as="system:serviceaccount:$NS:legacy-operator" --context "$CTX" 2>/dev/null)
  if [[ "$role_status" -ne 0 && "$binding_status" -ne 0 && "$can_read" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$role_status" -eq 0 ]]; then
      echo "HINT: ClusterRole 'legacy-operator-admin' still exists. Delete it, not just the binding - a leftover wildcard ClusterRole is a template ready to be reused."
    elif [[ "$binding_status" -eq 0 ]]; then
      echo "HINT: ClusterRoleBinding 'legacy-operator-admin' still exists. Deleting only the ClusterRole is not enough - a dangling binding to a re-created role of the same name would silently regain access."
    elif [[ "$can_read" != "no" ]]; then
      echo "HINT: ServiceAccount 'legacy-operator' can still read secrets after your changes. Check for ANOTHER RoleBinding/ClusterRoleBinding granting this SA access, not only the one named 'legacy-operator-admin'."
    fi
    echo "clusterrole_status=$role_status binding_status=$binding_status legacy_can_read_secrets=$can_read"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. API server rejects anonymous requests" {
  echo '1' >> /var/work/tests/result/all
  command=$(kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null | jq -r '.items[0].spec.containers[0].command[]? | select(. == "--anonymous-auth=false")' 2>/dev/null)
  server=$(kubectl config view --minify --context "$CTX" -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
  code=$(curl --connect-timeout 5 --max-time 10 -ks -o /dev/null -w '%{http_code}' "$server/version" 2>/dev/null || true)
  if [[ "$command" == "--anonymous-auth=false" && "$code" == "401" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$command" != "--anonymous-auth=false" ]]; then
      echo "HINT: kube-apiserver static Pod does not have --anonymous-auth=false in its command. Edit /etc/kubernetes/manifests/kube-apiserver.yaml directly - do not edit the Pod object through the API, kubelet will just recreate it from the manifest."
    elif [[ "$code" != "401" ]]; then
      echo "HINT: The flag is set, but an unauthenticated request to /version did not return 401 (got '$code'). The static Pod may not have restarted yet after the manifest edit - wait for kubelet to pick up the change, or the request may be failing for a different reason (network/TLS) before reaching authn."
    fi
    echo "anonymous_auth_argument=$command anonymous_version_http=$code"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. app-vulnerable no longer exposes db-creds through env; volume mount uses defaultMode 0400" {
  echo '1' >> /var/work/tests/result/all
  before="/var/work/tests/artifacts/6/env-leak-before.txt"
  mode_file="/var/work/tests/artifacts/6/secret-file-mode.txt"
  pod=$(kubectl get pod app-vulnerable -n "$NS" --context "$CTX" -o json 2>/dev/null)
  no_env_secret=$(jq -r '
    ([.spec.containers[]?.envFrom[]? | select(.secretRef.name == "db-creds")] | length == 0) and
    ([.spec.containers[]?.env[]? | select(.valueFrom.secretKeyRef.name == "db-creds")] | length == 0)
  ' <<<"$pod" 2>/dev/null)
  volume_ok=$(jq -r '
    ([.spec.volumes[]? | select(.name == "db-creds-vol" and .secret.secretName == "db-creds" and .secret.defaultMode == 256)] | length == 1) and
    ([.spec.containers[]?.volumeMounts[]? | select(.name == "db-creds-vol" and .mountPath == "/etc/secrets" and .readOnly == true)] | length == 1)
  ' <<<"$pod" 2>/dev/null)
  environ=$(kubectl exec -n "$NS" app-vulnerable --context "$CTX" -- cat /proc/1/environ 2>/dev/null | tr '\0' '\n' || true)
  no_leak=$([[ "$environ" != *"DB_PASSWORD"* ]] && echo true || echo false)
  if [[ -s "$before" ]] && grep -q 'DB_PASSWORD' "$before" \
    && [[ "$no_env_secret" == "true" && "$volume_ok" == "true" && "$no_leak" == "true" ]] \
    && grep -Fq '400' "$mode_file"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if ! [[ -s "$before" ]] || ! grep -q 'DB_PASSWORD' "$before"; then
      echo "HINT: The 'before' evidence file is missing or does not contain DB_PASSWORD. You must capture the leak BEFORE fixing it - run 'kubectl exec ... -- cat /proc/1/environ' against the ORIGINAL vulnerable Pod first."
    elif [[ "$no_env_secret" != "true" ]]; then
      echo "HINT: The final Pod still references db-creds through env/envFrom. Remove envFrom.secretRef and env[].valueFrom.secretKeyRef entirely - the Secret must ONLY be exposed via the volume mount."
    elif [[ "$volume_ok" != "true" ]]; then
      echo "HINT: volume 'db-creds-vol' must mount Secret 'db-creds' at '/etc/secrets', readOnly: true, with defaultMode 0400 (octal) which is 256 in decimal. YAML defaultMode is parsed as decimal unless written with a leading 0 - writing 'defaultMode: 400' means decimal 400, NOT octal 0400/256. Use 'defaultMode: 0400' or the numeric value 256 directly."
    elif [[ "$no_leak" != "true" ]]; then
      echo "HINT: DB_PASSWORD is still present in /proc/1/environ of the fixed Pod. Check that you removed BOTH env and envFrom referencing db-creds, not just one of them."
    elif ! grep -Fq '400' "$mode_file"; then
      echo "HINT: secret-file-mode.txt does not show '400'. Run 'stat -c %a' on the mounted secret file inside the container and save that exact output - it should read 400, confirming defaultMode 0400/256 took effect."
    fi
    echo "before_has_leak=$(grep -c 'DB_PASSWORD' "$before" 2>/dev/null || echo 0) no_env_secret=$no_env_secret volume_ok=$volume_ok no_leak=$no_leak mode_file=$(cat "$mode_file" 2>/dev/null)"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. dangerous impersonate/bind/escalate/CSR-approval ClusterRoleBinding is found and revoked" {
  echo '1' >> /var/work/tests/result/all
  before="/var/work/tests/artifacts/7/dangerous-bindings-before.txt"
  set +e
  kubectl get clusterrolebinding build-agent-hidden-privesc --context "$CTX" >/dev/null 2>&1
  binding_status=$?
  set -e
  cannot_impersonate=$(kubectl auth can-i impersonate users --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null)
  cannot_approve_csr=$(kubectl auth can-i update certificatesigningrequests/approval --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null)
  cannot_escalate=$(kubectl auth can-i escalate clusterroles --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null)
  if [[ -s "$before" ]] && grep -q 'build-agent-hidden-privesc' "$before" \
    && [[ "$binding_status" -ne 0 ]] \
    && [[ "$cannot_impersonate" == "no" && "$cannot_approve_csr" == "no" && "$cannot_escalate" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if ! [[ -s "$before" ]] || ! grep -q 'build-agent-hidden-privesc' "$before"; then
      echo "HINT: dangerous-bindings-before.txt is missing or does not list 'build-agent-hidden-privesc'. Find it BEFORE deleting anything, using a query over verbs impersonate/bind/escalate AND the CSR approval subresource."
    elif [[ "$binding_status" -eq 0 ]]; then
      echo "HINT: ClusterRoleBinding 'build-agent-hidden-privesc' still exists. Delete it (and its ClusterRole) - do not leave the dangerous binding in place."
    elif [[ "$cannot_impersonate" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still impersonate users. Check for another ClusterRoleBinding granting the 'impersonate' verb, not just the one already removed."
    elif [[ "$cannot_approve_csr" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still approve certificatesigningrequests. This right lives on a separate rule (resource certificatesigningrequests/approval) - check it was not granted through a different binding."
    elif [[ "$cannot_escalate" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still 'escalate' clusterroles. This is a distinct verb from 'bind' - check both were revoked, not only one of them."
    fi
    echo "binding_status=$binding_status cannot_impersonate=$cannot_impersonate cannot_approve_csr=$cannot_approve_csr cannot_escalate=$cannot_escalate"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Namespace baseline disables automount on the default ServiceAccount" {
  echo '1' >> /var/work/tests/result/all
  BASE_NS="security-104-baseline"
  sa=$(kubectl get serviceaccount default -n "$BASE_NS" --context "$CTX" -o json 2>/dev/null)
  sa_automount=$(jq -r '.automountServiceAccountToken' <<<"$sa" 2>/dev/null)
  pod=$(kubectl get pod implicit-default-sa -n "$BASE_NS" --context "$CTX" -o json 2>/dev/null)
  pod_sa=$(jq -r '.spec.serviceAccountName // "default"' <<<"$pod" 2>/dev/null)
  pod_automount_field=$(jq -r '.spec.automountServiceAccountToken // "unset"' <<<"$pod" 2>/dev/null)
  token_volumes=$(jq -r '[.spec.volumes[]? | select(.projected.sources[]?.serviceAccountToken or .secret.secretName? | tostring | test("token"))] | length' <<<"$pod" 2>/dev/null)
  set +e
  token_read=$(kubectl exec -n "$BASE_NS" implicit-default-sa --context "$CTX" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>&1)
  token_read_status=$?
  set -e
  if [[ "$sa_automount" == "false" && "$pod_sa" == "default" && "$token_volumes" == "0" && "$token_read_status" -ne 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$sa_automount" != "false" ]]; then
      echo "HINT: ServiceAccount 'default' in namespace '$BASE_NS' must have automountServiceAccountToken: false. Patch the SA BEFORE creating any Pod in this namespace - patching it after a Pod already exists will not retroactively remove that Pod's token."
    elif [[ "$pod_sa" != "default" ]]; then
      echo "HINT: Pod 'implicit-default-sa' should implicitly use the 'default' ServiceAccount (do not set serviceAccountName explicitly) - that is the whole point of testing the namespace baseline."
    elif [[ "$token_volumes" != "0" ]]; then
      echo "HINT: Pod 'implicit-default-sa' still has a token volume. If the namespace baseline is correctly disabled, Kubernetes should not inject one automatically - check the Pod was created AFTER the SA patch, not before."
    elif [[ "$token_read_status" -eq 0 ]]; then
      echo "HINT: Reading /var/run/secrets/kubernetes.io/serviceaccount/token inside the container succeeded, meaning a token file is actually present - the baseline patch did not take effect for this Pod."
    fi
    echo "sa_automount=$sa_automount pod_sa=$pod_sa pod_automount_field=$pod_automount_field token_volumes=$token_volumes token_read_status=$token_read_status token_read=$token_read"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. RBAC escalation attempt is captured in audit log and contained" {
  echo '1' >> /var/work/tests/result/all
  event_file="/var/work/tests/artifacts/9/audit-escalation-event.json"
  containment_file="/var/work/tests/artifacts/9/containment-result.txt"
  command=$(kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null | jq -r '.items[0].spec.containers[0].command[]? | select(startswith("--audit-policy-file"))' 2>/dev/null)
  log_flag=$(kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null | jq -r '.items[0].spec.containers[0].command[]? | select(startswith("--audit-log-path"))' 2>/dev/null)
  event_ok=$(jq -r '
    .verb == "create" and
    .objectRef.resource == "clusterrolebindings" and
    .objectRef.name == "incident-simulated-escalation" and
    ((.requestObject | tostring) | test("build-agent"))
  ' "$event_file" 2>/dev/null)
  set +e
  kubectl get clusterrolebinding incident-simulated-escalation --context "$CTX" >/dev/null 2>&1
  binding_status=$?
  set -e
  if [[ -n "$command" && -n "$log_flag" ]] \
    && [[ "$event_ok" == "true" ]] \
    && [[ "$binding_status" -ne 0 ]] \
    && grep -q '^no$' "$containment_file"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$command" || -z "$log_flag" ]]; then
      echo "HINT: kube-apiserver static Pod is missing --audit-policy-file or --audit-log-path. Edit /etc/kubernetes/manifests/kube-apiserver.yaml directly and add the required hostPath volumes for the policy file and log directory."
    elif [[ "$event_ok" != "true" ]]; then
      echo "HINT: audit-escalation-event.json is missing or does not match a 'create' event for ClusterRoleBinding 'incident-simulated-escalation' mentioning 'build-agent'. Make sure your audit policy captures RBAC resources at RequestResponse level BEFORE you create the simulated binding, then grep the audit log for this exact event."
    elif [[ "$binding_status" -eq 0 ]]; then
      echo "HINT: ClusterRoleBinding 'incident-simulated-escalation' still exists. Delete it as part of containment - detecting the escalation is not enough, you must also remove it."
    elif ! grep -q '^no$' "$containment_file"; then
      echo "HINT: containment-result.txt must contain exactly 'no', the output of 'kubectl auth can-i ... --as=system:serviceaccount:security-104:build-agent' AFTER deleting the binding - confirming access was actually revoked, not just that the object is gone."
    fi
    echo "audit_policy_flag=$command audit_log_flag=$log_flag event_ok=$event_ok binding_status=$binding_status containment=$(cat "$containment_file" 2>/dev/null)"
    result=1
  fi
  [ "$result" -eq 0 ]
}
