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
  sa_exists=$(kubectl get serviceaccount auditor -n "$NS" --context "$CTX" -o name 2>/dev/null || true)
  role=$(kubectl get role pod-observer -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  binding=$(kubectl get rolebinding auditor-pod-observer -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  minimal=$(jq -r '(.rules | length == 1) and (.rules[0].apiGroups == [""]) and (.rules[0].resources == ["pods"]) and ((.rules[0].verbs | sort) == ["get", "list", "watch"])' <<<"$role" 2>/dev/null)
  bound=$(jq -r '.roleRef.apiGroup == "rbac.authorization.k8s.io" and .roleRef.kind == "Role" and .roleRef.name == "pod-observer" and (.subjects | length == 1) and (.subjects[0].kind == "ServiceAccount" and .subjects[0].name == "auditor" and .subjects[0].namespace == "security-104")' <<<"$binding" 2>/dev/null)
  can_get=$(kubectl auth can-i get pods -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  can_list=$(kubectl auth can-i list pods -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  can_watch=$(kubectl auth can-i watch pods -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  cannot_create_pods=$(kubectl auth can-i create pods -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  cannot_delete_pods=$(kubectl auth can-i delete pods -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  cannot_get_secrets=$(kubectl auth can-i get secrets -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  cannot_list_secrets=$(kubectl auth can-i list secrets -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  cannot_delete=$(kubectl auth can-i delete secrets -n "$NS" --as="system:serviceaccount:$NS:auditor" --context "$CTX" 2>/dev/null || true)
  extra_rolebindings=$(kubectl get rolebinding -n "$NS" --context "$CTX" -o json 2>/dev/null \
    | jq -r '[.items[] | select(.metadata.name != "auditor-pod-observer") | select([.subjects[]? | select(.kind == "ServiceAccount" and .name == "auditor" and .namespace == "security-104")] | length > 0)] | length' 2>/dev/null)
  extra_clusterrolebindings=$(kubectl get clusterrolebinding --context "$CTX" -o json 2>/dev/null \
    | jq -r '[.items[] | select([.subjects[]? | select(.kind == "ServiceAccount" and .name == "auditor" and .namespace == "security-104")] | length > 0)] | length' 2>/dev/null)
  if [[ -n "$sa_exists" && "$minimal" == "true" && "$bound" == "true" \
        && "$can_get" == "yes" && "$can_list" == "yes" && "$can_watch" == "yes" \
        && "$cannot_create_pods" == "no" && "$cannot_delete_pods" == "no" \
        && "$cannot_get_secrets" == "no" && "$cannot_list_secrets" == "no" && "$cannot_delete" == "no" \
        && "$extra_rolebindings" == "0" && "$extra_clusterrolebindings" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    # Diagnostic hint: point at the first likely cause instead of a generic fail.
    if [[ -z "$sa_exists" ]]; then
      echo "HINT: ServiceAccount 'auditor' does not exist in namespace '$NS'. Create it before the Role/RoleBinding."
    elif [[ "$minimal" != "true" ]]; then
      echo "HINT: Role 'pod-observer' must have exactly ONE rule: apiGroups [\"\"], resources [\"pods\"], verbs [\"get\",\"list\",\"watch\"]. Check for extra rules, extra verbs, or a wrong apiGroup."
    elif [[ "$bound" != "true" ]]; then
      echo "HINT: RoleBinding 'auditor-pod-observer' must bind Role 'pod-observer' to EXACTLY one subject: ServiceAccount 'auditor' in namespace '$NS'. Check roleRef.kind/name/apiGroup and that subjects has no extra entries."
    elif [[ "$can_get" != "yes" || "$can_list" != "yes" || "$can_watch" != "yes" ]]; then
      echo "HINT: ServiceAccount 'auditor' cannot get/list/watch pods (get=$can_get list=$can_list watch=$can_watch), even though the Role/RoleBinding look correct on paper. Check the RoleBinding and Role are in the SAME namespace as the subject."
    elif [[ "$cannot_create_pods" != "no" || "$cannot_delete_pods" != "no" ]]; then
      echo "HINT: ServiceAccount 'auditor' can create or delete pods - it has more access than get/list/watch. Check for extra verbs on the Role."
    elif [[ "$cannot_get_secrets" != "no" || "$cannot_list_secrets" != "no" || "$cannot_delete" != "no" ]]; then
      echo "HINT: ServiceAccount 'auditor' can access secrets - it has more access than the Role grants. Check for an extra ClusterRoleBinding or a second Role/RoleBinding."
    elif [[ "$extra_rolebindings" != "0" || "$extra_clusterrolebindings" != "0" ]]; then
      echo "HINT: Found ANOTHER RoleBinding/ClusterRoleBinding (besides 'auditor-pod-observer') that also binds ServiceAccount 'auditor'. Remove it - 'auditor' must only have the minimal access from Role 'pod-observer'."
    fi
    echo "sa_exists=$sa_exists minimal=$minimal binding=$bound can_get=$can_get can_list=$can_list can_watch=$can_watch cannot_create_pods=$cannot_create_pods cannot_delete_pods=$cannot_delete_pods cannot_get_secrets=$cannot_get_secrets cannot_list_secrets=$cannot_list_secrets auditor_can_delete_secrets=$cannot_delete extra_rolebindings=$extra_rolebindings extra_clusterrolebindings=$extra_clusterrolebindings"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. token-client uses a bounded API-default projected token that authenticates and has no secret deletion right" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod token-client -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  sa=$(kubectl get serviceaccount api-client -n "$NS" --context "$CTX" -o name 2>/dev/null || true)
  token_spec=$(jq -r '[.spec.volumes[]?.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and (.audience == null) and (.expirationSeconds | tonumber) >= 600 and (.expirationSeconds | tonumber) <= 3600)] | length' <<<"$pod" 2>/dev/null)
  # Total count of ALL serviceAccountToken projected sources on the Pod, regardless of
  # whether they match the expected path/audience/expiration - this prevents a Pod from
  # having one correct 'api-token' source PLUS an extra, unchecked token source (e.g. a
  # different path or a longer-lived/different-audience token) that would otherwise slip
  # through undetected since only the single matching source was ever inspected.
  total_token_sources=$(jq -r '[.spec.volumes[]?.projected.sources[]?.serviceAccountToken] | length' <<<"$pod" 2>/dev/null)
  mounted=$(jq -r '. as $pod | [$pod.spec.volumes[]? | select(.projected != null) | . as $volume | ([.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and (.audience == null) and (.expirationSeconds | tonumber) >= 600 and (.expirationSeconds | tonumber) <= 3600)] | length) as $tokens | select($tokens > 0) | $pod.spec.containers[]?.volumeMounts[]? | select(.name == $volume.name and .mountPath == "/var/run/secrets/tokens" and .readOnly == true)] | length' <<<"$pod" 2>/dev/null)
  auto=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  client_sa=$(jq -r '.spec.serviceAccountName' <<<"$pod" 2>/dev/null)
  # Collect every Secret referenced by the Pod, through any mechanism, and check whether
  # any of them is a legacy long-lived ServiceAccount token Secret - a student could pass
  # this test's projected-token checks AND still additionally mount a legacy token.
  referenced_secrets=$(jq -r '
    [.spec.volumes[]?.secret.secretName?,
     .spec.volumes[]?.projected.sources[]?.secret.name?,
     .spec.containers[]?.envFrom[]?.secretRef.name?,
     .spec.containers[]?.env[]?.valueFrom.secretKeyRef.name?] | .[] | select(. != null)
  ' <<<"$pod" 2>/dev/null)
  legacy_token_secret_found=false
  for secret_name in $referenced_secrets; do
    secret_type=$(kubectl get secret "$secret_name" -n "$NS" --context "$CTX" -o jsonpath='{.type}' 2>/dev/null || true)
    if [[ "$secret_type" == "kubernetes.io/service-account-token" ]]; then
      legacy_token_secret_found=true
      break
    fi
  done
  projected_token=$(kubectl exec -n "$NS" token-client --context "$CTX" -- cat /var/run/secrets/tokens/api-token 2>/dev/null || true)
  review=$(jq -n --arg token "$projected_token" '{apiVersion:"authentication.k8s.io/v1",kind:"TokenReview",spec:{token:$token}}' | kubectl create --context "$CTX" -f - -o json 2>/dev/null || true)
  authenticated=$(jq -r '.status.authenticated // false' <<<"$review" 2>/dev/null)
  username=$(jq -r '.status.user.username // ""' <<<"$review" 2>/dev/null)
  cannot_delete=$(kubectl auth can-i delete secrets -n "$NS" --as="system:serviceaccount:$NS:api-client" --context "$CTX" 2>/dev/null || true)
  if [[ "$sa" == "serviceaccount/api-client" && "$client_sa" == "api-client" && "$auto" == "false" \
        && "$token_spec" -ge 1 && "$total_token_sources" -eq 1 && "$mounted" -ge 1 && "$legacy_token_secret_found" == "false" \
        && "$authenticated" == "true" && "$username" == "system:serviceaccount:$NS:api-client" && "$cannot_delete" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$sa" != "serviceaccount/api-client" || "$client_sa" != "api-client" ]]; then
      echo "HINT: Pod 'token-client' must use serviceAccountName 'api-client' in namespace '$NS'. Check spec.serviceAccountName."
    elif [[ "$auto" != "false" ]]; then
      echo "HINT: Pod 'token-client' must set automountServiceAccountToken: false - the projected token volume replaces the default mechanism, it does not add to it."
    elif [[ "$token_spec" -lt 1 ]]; then
      echo "HINT: The projected serviceAccountToken source must have path 'api-token', NO audience field set, and expirationSeconds between 600 and 3600 (inclusive). Check for a hardcoded audience, or an expirationSeconds outside that range - Kubernetes rejects values below 600 as invalid regardless of what the manifest says."
    elif [[ "$total_token_sources" -ne 1 ]]; then
      echo "HINT: Pod 'token-client' has $total_token_sources serviceAccountToken projected source(s), but exactly ONE is required. An extra serviceAccountToken source (a different path, audience, or expirationSeconds) would give this Pod an additional, unaudited credential even though the primary 'api-token' source looks correct - remove any additional serviceAccountToken entries from the projected volume."
    elif [[ "$mounted" -lt 1 ]]; then
      echo "HINT: The projected volume must be mounted at exactly '/var/run/secrets/tokens' with readOnly: true. Check volumeMounts.mountPath spelling and the readOnly flag."
    elif [[ "$legacy_token_secret_found" == "true" ]]; then
      echo "HINT: Pod 'token-client' references a Secret of type kubernetes.io/service-account-token (a legacy long-lived token) IN ADDITION to the correct projected token. The task requires using ONLY the short-lived projected token - remove any manually mounted legacy token Secret."
    elif [[ "$authenticated" != "true" ]]; then
      echo "HINT: TokenReview did not authenticate the token read from the Pod. The token file may be empty, stale, or the volume may not actually be mounted yet."
    elif [[ "$username" != "system:serviceaccount:$NS:api-client" ]]; then
      echo "HINT: TokenReview authenticated a DIFFERENT identity than expected. Check that the projected token belongs to ServiceAccount 'api-client', not another SA."
    elif [[ "$cannot_delete" != "no" ]]; then
      echo "HINT: ServiceAccount 'api-client' can delete secrets - it has more access than intended. Check for an unexpected RoleBinding/ClusterRoleBinding."
    fi
    echo "sa=$sa pod_sa=$client_sa automount=$auto projected_tokens=$token_spec total_token_sources=$total_token_sources mounted_projected_tokens=$mounted legacy_token_secret_found=$legacy_token_secret_found tokenreview_authenticated=$authenticated tokenreview_username=$username api_client_can_delete_secrets=$cannot_delete"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. no-token pod and ServiceAccount disable token automounting" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod no-token -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  sa=$(kubectl get serviceaccount no-token-sa -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  pod_auto=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  sa_auto=$(jq -r '.automountServiceAccountToken' <<<"$sa" 2>/dev/null)
  pod_sa=$(jq -r '.spec.serviceAccountName' <<<"$pod" 2>/dev/null)
  token_volumes=$(jq -r '[.spec.volumes[]? | select(.projected.sources[]?.serviceAccountToken)] | length' <<<"$pod" 2>/dev/null)
  referenced_secrets=$(jq -r '
    [.spec.volumes[]?.secret.secretName?,
     .spec.volumes[]?.projected.sources[]?.secret.name?,
     .spec.containers[]?.envFrom[]?.secretRef.name?,
     .spec.containers[]?.env[]?.valueFrom.secretKeyRef.name?] | .[] | select(. != null)
  ' <<<"$pod" 2>/dev/null)
  legacy_token_secret_found=false
  for secret_name in $referenced_secrets; do
    secret_type=$(kubectl get secret "$secret_name" -n "$NS" --context "$CTX" -o jsonpath='{.type}' 2>/dev/null || true)
    if [[ "$secret_type" == "kubernetes.io/service-account-token" ]]; then
      legacy_token_secret_found=true
      break
    fi
  done
  set +e
  kubectl wait -n "$NS" --for=condition=Ready pod/no-token --timeout=60s --context "$CTX" >/dev/null 2>&1
  exec_result=$(kubectl exec -n "$NS" no-token --context "$CTX" -- test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token 2>&1)
  exec_status=$?
  set -e
  if [[ "$pod_auto" == "false" && "$sa_auto" == "false" && "$pod_sa" == "no-token-sa" \
        && "$token_volumes" == "0" && "$legacy_token_secret_found" == "false" && "$exec_status" -eq 0 ]]; then
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
    elif [[ "$legacy_token_secret_found" == "true" ]]; then
      echo "HINT: Pod 'no-token' references a Secret of type kubernetes.io/service-account-token (a legacy long-lived token). The task requires the Pod to have NO Kubernetes API token at all, projected or legacy - remove any manually mounted token Secret."
    elif [[ "$exec_status" -ne 0 ]]; then
      echo "HINT: 'kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token' did not succeed cleanly (exit=$exec_status). Either the exec itself failed (check the Pod is actually Running/Ready) or the token file unexpectedly exists. Output: $exec_result"
    fi
    echo "pod_automount=$pod_auto sa_automount=$sa_auto pod_sa=$pod_sa token_volumes=$token_volumes legacy_token_secret_found=$legacy_token_secret_found exec_status=$exec_status"
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
  can_read=$(kubectl auth can-i get secrets -n "$NS" --as="system:serviceaccount:$NS:legacy-operator" --context "$CTX" 2>/dev/null || true)
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

@test "5. API server disables anonymous auth for all but health endpoints via AuthenticationConfiguration" {
  echo '1' >> /var/work/tests/result/all
  pod_json=$(kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null)
  auth_config_flag=$(jq -r '.items[0].spec.containers[0].command[]? | select(startswith("--authentication-config="))' <<<"$pod_json" 2>/dev/null)
  anonymous_auth_flag=$(jq -r '.items[0].spec.containers[0].command[]? | select(startswith("--anonymous-auth="))' <<<"$pod_json" 2>/dev/null)
  ready=$(jq -r '.items[0].status.conditions[]? | select(.type == "Ready") | .status' <<<"$pod_json" 2>/dev/null)
  restart_count=$(jq -r '.items[0].status.containerStatuses[0].restartCount // 0' <<<"$pod_json" 2>/dev/null)
  server=$(kubectl config view --minify --context "$CTX" -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
  version_code=$(curl --connect-timeout 5 --max-time 10 -ks -o /dev/null -w '%{http_code}' "$server/version" 2>/dev/null || true)
  livez_code=$(curl --connect-timeout 5 --max-time 10 -ks -o /dev/null -w '%{http_code}' "$server/livez" 2>/dev/null || true)
  readyz_code=$(curl --connect-timeout 5 --max-time 10 -ks -o /dev/null -w '%{http_code}' "$server/readyz" 2>/dev/null || true)
  auth_readyz_ok=$(kubectl get --raw=/readyz --context "$CTX" 2>/dev/null || true)
  # Extended check: effective authorization-mode must still be Node,RBAC and must NOT
  # include AlwaysAllow - a working AuthenticationConfiguration is worthless if anything
  # that DOES authenticate is then authorized unconditionally.
  authz_mode_flag=$(jq -r '.items[0].spec.containers[0].command[]? | select(startswith("--authorization-mode="))' <<<"$pod_json" 2>/dev/null)
  authz_mode_ok=false
  if [[ "$authz_mode_flag" == *"Node"* && "$authz_mode_flag" == *"RBAC"* && "$authz_mode_flag" != *"AlwaysAllow"* ]]; then
    authz_mode_ok=true
  fi
  # Audit for lab-owned unintended anonymous/unauthenticated RBAC bindings: the fixture
  # ClusterRole+ClusterRoleBinding must be gone, but the STOCK kubeadm binding
  # 'system:public-info-viewer' (also targets system:unauthenticated, but only for the
  # /healthz and /version non-resource URLs) must be left alone - a checker or student
  # that treats every anonymous-adjacent binding as a violation would break bootstrap.
  set +e
  kubectl get clusterrole lab104-anonymous-debug-access --context "$CTX" >/dev/null 2>&1
  lab_anon_role_status=$?
  kubectl get clusterrolebinding lab104-unintended-anonymous-access --context "$CTX" >/dev/null 2>&1
  lab_anon_binding_status=$?
  kubectl get clusterrolebinding system:public-info-viewer --context "$CTX" >/dev/null 2>&1
  stock_binding_status=$?
  set -e
  # Live negative control: an actually-unauthenticated identity (system:anonymous in
  # group system:unauthenticated) must not be able to read the resources the removed
  # lab-owned binding used to grant, cluster-wide.
  anon_cannot_pods=$(kubectl auth can-i get pods -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated --context "$CTX" 2>/dev/null || true)
  anon_cannot_secrets=$(kubectl auth can-i get secrets -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated --context "$CTX" 2>/dev/null || true)
  anon_cannot_configmaps=$(kubectl auth can-i get configmaps -A --as=system:anonymous --as-group=system:unauthenticated --as-group=system:authenticated --context "$CTX" 2>/dev/null || true)
  config_path=""
  config_content=""
  if [[ -n "$auth_config_flag" ]]; then
    config_path=$(sed 's/^--authentication-config=//' <<<"$auth_config_flag")
    config_content=$(ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 control-plane "sudo cat '$config_path' 2>/dev/null" 2>/dev/null || true)
  fi
  anon_conditions_ok=$(python3 -c "
import sys, yaml
try:
    doc = yaml.safe_load(sys.stdin.read())
    anon = (doc or {}).get('anonymous', {})
    paths = sorted(c.get('path') for c in anon.get('conditions', []) if isinstance(c, dict))
    print('true' if anon.get('enabled') is True and paths == ['/healthz', '/livez', '/readyz'] else 'false')
except Exception:
    print('false')
" <<<"$config_content" 2>/dev/null || echo false)
  config_apiversion_ok=$(python3 -c "
import sys, yaml
try:
    doc = yaml.safe_load(sys.stdin.read())
    doc = doc or {}
    print('true' if doc.get('apiVersion') == 'apiserver.config.k8s.io/v1' and doc.get('kind') == 'AuthenticationConfiguration' else 'false')
except Exception:
    print('false')
" <<<"$config_content" 2>/dev/null || echo false)
  if [[ -n "$auth_config_flag" && -z "$anonymous_auth_flag" && "$anon_conditions_ok" == "true" \
        && "$config_apiversion_ok" == "true" \
        && "$ready" == "True" && "$restart_count" -lt 3 \
        && "$version_code" == "401" && "$livez_code" == "200" && "$readyz_code" == "200" \
        && "$auth_readyz_ok" == "ok" \
        && "$authz_mode_ok" == "true" \
        && "$lab_anon_role_status" -ne 0 && "$lab_anon_binding_status" -ne 0 && "$stock_binding_status" -eq 0 \
        && "$anon_cannot_pods" == "no" && "$anon_cannot_secrets" == "no" && "$anon_cannot_configmaps" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$auth_config_flag" ]]; then
      echo "HINT: kube-apiserver static Pod does not have --authentication-config=... in its command. Create an AuthenticationConfiguration file, mount it via hostPath, and reference it from the manifest - do not just flip --anonymous-auth to false."
    elif [[ -n "$anonymous_auth_flag" ]]; then
      echo "HINT: kube-apiserver still has --anonymous-auth set alongside --authentication-config. These two are mutually exclusive - remove --anonymous-auth entirely."
    elif [[ "$config_apiversion_ok" != "true" ]]; then
      echo "HINT: The AuthenticationConfiguration file must use apiVersion: apiserver.config.k8s.io/v1 (the stable API in this Kubernetes version) and kind: AuthenticationConfiguration - apiserver.config.k8s.io/v1beta1 is not a valid version and kube-apiserver will fail to load it."
    elif [[ "$anon_conditions_ok" != "true" ]]; then
      echo "HINT: The AuthenticationConfiguration file must set anonymous.enabled: true with conditions covering exactly /livez, /readyz and /healthz - no more, no fewer paths. Check the file was actually mounted into the container at the path referenced by --authentication-config."
    elif [[ "$ready" != "True" || "$restart_count" -ge 3 ]]; then
      echo "HINT: kube-apiserver Pod is not Ready or is restarting repeatedly (restartCount=$restart_count). If --anonymous-auth=false (or a misconfigured AuthenticationConfiguration) blocks kubelet's own HTTPS liveness/readiness probes on /livez and /readyz, kubelet will keep killing and restarting the container."
    elif [[ "$version_code" != "401" ]]; then
      echo "HINT: An unauthenticated GET /version did not return 401 (got '$version_code'). Anonymous access must be denied for endpoints other than /livez, /readyz, /healthz."
    elif [[ "$livez_code" != "200" || "$readyz_code" != "200" ]]; then
      echo "HINT: Unauthenticated GET /livez or /readyz did not return 200 (livez=$livez_code, readyz=$readyz_code). These must remain anonymously accessible or kubelet's own health probes will fail."
    elif [[ "$auth_readyz_ok" != "ok" ]]; then
      echo "HINT: An AUTHENTICATED request to /readyz (via kubectl, using real client credentials) did not succeed. Restricting anonymous access must not break access for authenticated clients."
    elif [[ "$authz_mode_ok" != "true" ]]; then
      echo "HINT: The effective --authorization-mode ('$authz_mode_flag') must contain Node,RBAC and must NOT contain AlwaysAllow. A correct AuthenticationConfiguration is useless if anything that authenticates is then authorized unconditionally."
    elif [[ "$lab_anon_role_status" -eq 0 || "$lab_anon_binding_status" -eq 0 ]]; then
      echo "HINT: The lab-owned ClusterRole 'lab104-anonymous-debug-access' and/or ClusterRoleBinding 'lab104-unintended-anonymous-access' still exist. Delete BOTH - this binding grants system:unauthenticated (i.e. any anonymous request) real RBAC read access to pods/secrets/configmaps, which is a separate, intentional finding from the AuthenticationConfiguration work above."
    elif [[ "$stock_binding_status" -ne 0 ]]; then
      echo "HINT: The STOCK kubeadm ClusterRoleBinding 'system:public-info-viewer' is missing. Do not delete it - it also targets group system:unauthenticated, but only grants access to the /healthz and /version non-resource URLs, which is standard, required kubeadm bootstrap behaviour, not the lab-owned finding you are meant to remove."
    elif [[ "$anon_cannot_pods" != "no" || "$anon_cannot_secrets" != "no" || "$anon_cannot_configmaps" != "no" ]]; then
      echo "HINT: An unauthenticated identity (system:anonymous / group system:unauthenticated) can still read pods, secrets, or configmaps somewhere in the cluster (pods=$anon_cannot_pods secrets=$anon_cannot_secrets configmaps=$anon_cannot_configmaps). Check for ANOTHER ClusterRoleBinding/RoleBinding granting access to system:unauthenticated or system:anonymous besides the one you already removed."
    fi
    echo "authentication_config_flag=$auth_config_flag anonymous_auth_flag=$anonymous_auth_flag config_apiversion_ok=$config_apiversion_ok anon_conditions_ok=$anon_conditions_ok ready=$ready restart_count=$restart_count version_http=$version_code livez_http=$livez_code readyz_http=$readyz_code authenticated_readyz=$auth_readyz_ok authz_mode_flag=$authz_mode_flag authz_mode_ok=$authz_mode_ok lab_anon_role_status=$lab_anon_role_status lab_anon_binding_status=$lab_anon_binding_status stock_binding_status=$stock_binding_status anon_cannot_pods=$anon_cannot_pods anon_cannot_secrets=$anon_cannot_secrets anon_cannot_configmaps=$anon_cannot_configmaps"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. app-vulnerable no longer exposes db-creds through env; volume mount uses defaultMode 0400" {
  echo '1' >> /var/work/tests/result/all
  before="/var/work/tests/artifacts/6/env-leak-before.txt"
  mode_file="/var/work/tests/artifacts/6/secret-file-mode.txt"
  pod=$(kubectl get pod app-vulnerable -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  expected_password=$(kubectl get secret db-creds -n "$NS" --context "$CTX" -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || true)
  no_env_secret=$(jq -r '
    ([.spec.containers[]?.envFrom[]? | select(.secretRef.name == "db-creds")] | length == 0) and
    ([.spec.containers[]?.env[]? | select(.valueFrom.secretKeyRef.name == "db-creds")] | length == 0)
  ' <<<"$pod" 2>/dev/null)
  # No SECOND exposure path for db-creds either: no projected Secret source, and no
  # second volume besides the single intended db-creds-vol.
  no_second_exposure=$(jq -r '
    ([.spec.volumes[]?.projected.sources[]?.secret | select(.name == "db-creds")] | length == 0) and
    ([.spec.volumes[]? | select(.secret.secretName == "db-creds")] | length == 1)
  ' <<<"$pod" 2>/dev/null)
  volume_ok=$(jq -r '
    ([.spec.volumes[]? | select(.name == "db-creds-vol" and .secret.secretName == "db-creds" and .secret.defaultMode == 256)] | length == 1) and
    ([.spec.containers[]?.volumeMounts[]? | select(.name == "db-creds-vol" and .mountPath == "/etc/secrets" and .readOnly == true)] | length == 1)
  ' <<<"$pod" 2>/dev/null)
  set +e
  kubectl wait -n "$NS" --for=condition=Ready pod/app-vulnerable --timeout=60s --context "$CTX" >/dev/null 2>&1
  environ=$(kubectl exec -n "$NS" app-vulnerable --context "$CTX" -- cat /proc/1/environ 2>/dev/null | tr '\0' '\n')
  environ_exec_status=$?
  # secret volumes mount through an "..data" symlink farm; busybox's stat without -L
  # reports the mode of the innermost symlink itself (always 777 on Linux, meaningless
  # here), not the real backing file - always dereference fully with -L.
  actual_mode=$(kubectl exec -n "$NS" app-vulnerable --context "$CTX" -- stat -L -c '%a' /etc/secrets/DB_PASSWORD 2>/dev/null)
  mode_exec_status=$?
  actual_value=$(kubectl exec -n "$NS" app-vulnerable --context "$CTX" -- cat /etc/secrets/DB_PASSWORD 2>/dev/null)
  value_exec_status=$?
  set -e
  # An exec failure (Pending Pod, container error, etc.) must NOT be silently treated
  # as proof that the leak is gone - only a SUCCESSFUL exec that shows no DB_PASSWORD
  # counts as evidence.
  no_leak=$([[ "$environ_exec_status" -eq 0 && "$environ" != *"DB_PASSWORD"* ]] && echo true || echo false)
  mode_exact_ok=$([[ "$mode_exec_status" -eq 0 && "$actual_mode" =~ ^400$ ]] && echo true || echo false)
  # Positive control: the app's own runtime process must actually be able to read the
  # secret value it depends on - hardening the mount must not silently break the app.
  can_read_secret=$([[ "$value_exec_status" -eq 0 && -n "$expected_password" && "$actual_value" == "$expected_password" ]] && echo true || echo false)
  before_ok=false
  if [[ -s "$before" && -n "$expected_password" ]] && grep -qF "DB_PASSWORD=$expected_password" "$before"; then
    before_ok=true
  fi
  # secret-file-mode.txt remains required student evidence, but the checker verifies the
  # actual mode itself above (mode_exact_ok) rather than trusting this file's content.
  mode_artifact_exists=$([[ -s "$mode_file" ]] && echo true || echo false)
  if [[ "$before_ok" == "true" && "$mode_artifact_exists" == "true" \
    && "$no_env_secret" == "true" && "$no_second_exposure" == "true" && "$volume_ok" == "true" \
    && "$no_leak" == "true" && "$mode_exact_ok" == "true" && "$can_read_secret" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$before_ok" != "true" ]]; then
      echo "HINT: The 'before' evidence file is missing, or does not contain the ACTUAL secret value ('DB_PASSWORD=<real value from Secret db-creds>'), not just the literal word DB_PASSWORD. You must capture the real leak BEFORE fixing it - run 'kubectl exec ... -- cat /proc/1/environ' against the ORIGINAL vulnerable Pod first."
    elif [[ "$mode_artifact_exists" != "true" ]]; then
      echo "HINT: secret-file-mode.txt is missing or empty. Run 'stat -c %a' on the mounted secret file inside the container and save the output there, even though the checker independently re-verifies the actual mode."
    elif [[ "$no_env_secret" != "true" ]]; then
      echo "HINT: The final Pod still references db-creds through env/envFrom. Remove envFrom.secretRef and env[].valueFrom.secretKeyRef entirely - the Secret must ONLY be exposed via the volume mount."
    elif [[ "$no_second_exposure" != "true" ]]; then
      echo "HINT: db-creds is exposed through a SECOND path in addition to (or instead of) the intended volume - e.g. a projected Secret source, or more than one Secret volume. There must be exactly one db-creds-vol Secret volume and no projected Secret source for db-creds."
    elif [[ "$volume_ok" != "true" ]]; then
      echo "HINT: volume 'db-creds-vol' must mount Secret 'db-creds' at '/etc/secrets', readOnly: true, with defaultMode 0400 (octal) which is 256 in decimal. YAML defaultMode is parsed as decimal unless written with a leading 0 - writing 'defaultMode: 400' means decimal 400, NOT octal 0400/256. Use 'defaultMode: 0400' or the numeric value 256 directly."
    elif [[ "$no_leak" != "true" ]]; then
      echo "HINT: Either 'kubectl exec ... cat /proc/1/environ' failed to run (exit=$environ_exec_status), or DB_PASSWORD is still present in the output. A failed exec is NOT proof the leak is gone - fix the Pod so the exec succeeds AND shows no DB_PASSWORD."
    elif [[ "$mode_exact_ok" != "true" ]]; then
      echo "HINT: 'stat -c %a /etc/secrets/DB_PASSWORD' run directly by the checker did not return exactly '400' (got '$actual_mode', exec exit=$mode_exec_status). The student artifact file is not trusted as the sole source of truth here - the checker verifies the real file mode itself."
    elif [[ "$can_read_secret" != "true" ]]; then
      echo "HINT: The checker could not read the correct secret value from inside the container ('kubectl exec ... cat /etc/secrets/DB_PASSWORD' exit=$value_exec_status). Hardening the mount must not break the application's actual ability to read its own secret - this is a positive control, not just an absence-of-leak check."
    fi
    echo "before_ok=$before_ok no_env_secret=$no_env_secret no_second_exposure=$no_second_exposure volume_ok=$volume_ok no_leak=$no_leak mode_exact_ok=$mode_exact_ok actual_mode=$actual_mode can_read_secret=$can_read_secret"
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
  kubectl get clusterrole build-agent-hidden-privesc --context "$CTX" >/dev/null 2>&1
  role_status=$?
  set -e
  cannot_impersonate=$(kubectl auth can-i impersonate users --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null || true)
  cannot_bind=$(kubectl auth can-i bind clusterroles --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null || true)
  cannot_escalate=$(kubectl auth can-i escalate clusterroles --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null || true)
  cannot_approve_csr=$(kubectl auth can-i update certificatesigningrequests/approval --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null || true)
  cannot_approve_signer=$(kubectl auth can-i approve signers/kubernetes.io/kube-apiserver-client --as="system:serviceaccount:$NS:build-agent" --context "$CTX" 2>/dev/null || true)
  # The artifact must record the dangerous ClusterRoleBinding NAME (what was actually
  # deleted and what the auth can-i checks below are being verified against), not merely
  # the name of the ClusterRole it referenced - those two names are not guaranteed to be
  # equal, even though in this lab's fixture they happen to coincide.
  binding_before_ok=false
  if [[ -s "$before" ]] && grep -q 'build-agent-hidden-privesc' "$before"; then
    binding_before_ok=true
  fi
  if [[ "$binding_before_ok" == "true" ]] \
    && [[ "$binding_status" -ne 0 && "$role_status" -ne 0 ]] \
    && [[ "$cannot_impersonate" == "no" && "$cannot_bind" == "no" && "$cannot_escalate" == "no" \
          && "$cannot_approve_csr" == "no" && "$cannot_approve_signer" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$binding_before_ok" != "true" ]]; then
      echo "HINT: dangerous-bindings-before.txt is missing or does not list 'build-agent-hidden-privesc' as a ClusterRoleBinding name. Find dangerous ClusterRole first (verbs impersonate/bind/escalate, or the CSR approval rule), THEN find the ClusterRoleBinding(s) that reference them - write down the BINDING name, not the ClusterRole name."
    elif [[ "$binding_status" -eq 0 ]]; then
      echo "HINT: ClusterRoleBinding 'build-agent-hidden-privesc' still exists. Delete it - do not leave the dangerous binding in place."
    elif [[ "$role_status" -eq 0 ]]; then
      echo "HINT: ClusterRole 'build-agent-hidden-privesc' still exists. Delete it too, not just the binding - a leftover dangerous ClusterRole is a template ready to be reused by a new binding."
    elif [[ "$cannot_impersonate" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still impersonate users. Check for another ClusterRoleBinding granting the 'impersonate' verb, not just the one already removed."
    elif [[ "$cannot_bind" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still 'bind' clusterroles. This verb was not being checked before and is easy to miss - check it was actually revoked, not just 'escalate'."
    elif [[ "$cannot_escalate" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still 'escalate' clusterroles. This is a distinct verb from 'bind' - check both were revoked, not only one of them."
    elif [[ "$cannot_approve_csr" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still update certificatesigningrequests/approval. This right lives on a separate rule - check it was not granted through a different binding."
    elif [[ "$cannot_approve_signer" != "no" ]]; then
      echo "HINT: ServiceAccount 'build-agent' can still 'approve' on signer 'kubernetes.io/kube-apiserver-client'. This is a SEPARATE right from certificatesigningrequests/approval - both the update verb AND the signer-scoped approve verb must be revoked."
    fi
    echo "binding_before_ok=$binding_before_ok binding_status=$binding_status role_status=$role_status cannot_impersonate=$cannot_impersonate cannot_bind=$cannot_bind cannot_escalate=$cannot_escalate cannot_approve_csr=$cannot_approve_csr cannot_approve_signer=$cannot_approve_signer"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "8. Namespace baseline disables automount on the default ServiceAccount" {
  echo '1' >> /var/work/tests/result/all
  BASE_NS="security-104-baseline"
  sa=$(kubectl get serviceaccount default -n "$BASE_NS" --context "$CTX" -o json 2>/dev/null || true)
  sa_automount=$(jq -r '.automountServiceAccountToken' <<<"$sa" 2>/dev/null)
  pod=$(kubectl get pod implicit-default-sa -n "$BASE_NS" --context "$CTX" -o json 2>/dev/null || true)
  pod_sa=$(jq -r '.spec.serviceAccountName // "default"' <<<"$pod" 2>/dev/null)
  # automountServiceAccountToken must be ABSENT from the Pod spec (inheriting the SA
  # baseline), not explicitly set to false on the Pod itself - explicit false would prove
  # the STUDENT disabled it on the Pod, not that the namespace/SA baseline actually works.
  # Do NOT use jq's `//` fallback here: `false // "unset"` evaluates to "unset" because
  # `//` treats false as a missing value, which would make an explicit `false` indistinguishable
  # from a genuinely absent field.
  pod_automount_absent=$(jq -r '(.spec | has("automountServiceAccountToken") | not)' <<<"$pod" 2>/dev/null)
  pod_automount_field=$(jq -r 'if (.spec | has("automountServiceAccountToken")) then .spec.automountServiceAccountToken else "absent" end' <<<"$pod" 2>/dev/null)
  token_volumes=$(jq -r '[.spec.volumes[]? | select(.projected.sources[]?.serviceAccountToken or (.secret.secretName? | tostring | test("token")))] | length' <<<"$pod" 2>/dev/null)
  referenced_secrets=$(jq -r '
    [.spec.volumes[]?.secret.secretName?,
     .spec.volumes[]?.projected.sources[]?.secret.name?,
     .spec.containers[]?.envFrom[]?.secretRef.name?,
     .spec.containers[]?.env[]?.valueFrom.secretKeyRef.name?] | .[] | select(. != null)
  ' <<<"$pod" 2>/dev/null)
  legacy_token_secret_found=false
  for secret_name in $referenced_secrets; do
    secret_type=$(kubectl get secret "$secret_name" -n "$BASE_NS" --context "$CTX" -o jsonpath='{.type}' 2>/dev/null || true)
    if [[ "$secret_type" == "kubernetes.io/service-account-token" ]]; then
      legacy_token_secret_found=true
      break
    fi
  done
  set +e
  kubectl wait -n "$BASE_NS" --for=condition=Ready pod/implicit-default-sa --timeout=60s --context "$CTX" >/dev/null 2>&1
  kubectl exec -n "$BASE_NS" implicit-default-sa --context "$CTX" -- test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token
  token_read_status=$?
  set -e
  if [[ "$sa_automount" == "false" && "$pod_sa" == "default" && "$pod_automount_absent" == "true" \
        && "$token_volumes" == "0" && "$legacy_token_secret_found" == "false" && "$token_read_status" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$sa_automount" != "false" ]]; then
      echo "HINT: ServiceAccount 'default' in namespace '$BASE_NS' must have automountServiceAccountToken: false. Patch the SA BEFORE creating any Pod in this namespace - patching it after a Pod already exists will not retroactively remove that Pod's token."
    elif [[ "$pod_sa" != "default" ]]; then
      echo "HINT: Pod 'implicit-default-sa' should implicitly use the 'default' ServiceAccount (do not set serviceAccountName explicitly) - that is the whole point of testing the namespace baseline."
    elif [[ "$pod_automount_absent" != "true" ]]; then
      echo "HINT: Pod 'implicit-default-sa' has automountServiceAccountToken explicitly set (value: $pod_automount_field). This task must prove NAMESPACE-LEVEL baseline inheritance - do not set this field on the Pod itself, even to false; leave it unset and let it inherit from the SA."
    elif [[ "$token_volumes" != "0" ]]; then
      echo "HINT: Pod 'implicit-default-sa' still has a token volume. If the namespace baseline is correctly disabled, Kubernetes should not inject one automatically - check the Pod was created AFTER the SA patch, not before."
    elif [[ "$legacy_token_secret_found" == "true" ]]; then
      echo "HINT: Pod 'implicit-default-sa' references a Secret of type kubernetes.io/service-account-token (a legacy long-lived token) manually. The task requires the Pod to have NO Kubernetes API token at all, inherited or manual."
    elif [[ "$token_read_status" -ne 0 ]]; then
      echo "HINT: 'kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token' did not succeed cleanly (exit=$token_read_status). Either the exec itself failed (check the Pod is actually Running/Ready first) or the token file unexpectedly exists - the baseline patch may not have taken effect for this Pod."
    fi
    echo "sa_automount=$sa_automount pod_sa=$pod_sa pod_automount_absent=$pod_automount_absent pod_automount_field=$pod_automount_field token_volumes=$token_volumes legacy_token_secret_found=$legacy_token_secret_found token_read_status=$token_read_status"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "9. Dangerous RBAC grant is captured in the real audit log and contained" {
  echo '1' >> /var/work/tests/result/all
  event_file="/var/work/tests/artifacts/9/audit-escalation-event.json"
  containment_file="/var/work/tests/artifacts/9/containment-result.txt"
  pod_json=$(kubectl get pods -n kube-system -l component=kube-apiserver --context "$CTX" -o json 2>/dev/null)
  command=$(jq -r '.items[0].spec.containers[0].command[]? | select(. == "--audit-policy-file=/etc/kubernetes/audit/policy.yaml")' <<<"$pod_json" 2>/dev/null)
  log_flag=$(jq -r '.items[0].spec.containers[0].command[]? | select(. == "--audit-log-path=/var/log/kubernetes/audit/audit.log")' <<<"$pod_json" 2>/dev/null)
  readyz_ok=$(kubectl get --raw=/readyz --context "$CTX" 2>/dev/null || true)

  # Read the REAL audit log on the control-plane ourselves - do not trust the student
  # artifact file as the sole source of truth for whether the event actually happened.
  real_log_event=$(ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 control-plane \
    "sudo cat /var/log/kubernetes/audit/audit.log" 2>/dev/null \
    | jq -c 'select(
        .verb == "create" and
        .stage == "ResponseComplete" and
        .objectRef.resource == "clusterrolebindings" and
        .objectRef.name == "incident-simulated-escalation" and
        .responseStatus.code == 201 and
        .requestObject.roleRef.kind == "ClusterRole" and
        .requestObject.roleRef.name == "cluster-admin" and
        ([.requestObject.subjects[]? | select(.kind == "ServiceAccount" and .name == "build-agent" and .namespace == "security-104")] | length == 1)
      )' 2>/dev/null | tail -n1 || true)
  real_log_level=$(jq -r '.level // ""' <<<"${real_log_event:-\{\}}" 2>/dev/null || true)
  real_log_ok=$([[ -n "$real_log_event" && "$real_log_level" == "RequestResponse" ]] && echo true || echo false)
  real_log_user=$(jq -r '.user.username // ""' <<<"${real_log_event:-\{\}}" 2>/dev/null || true)
  real_log_auditid=$(jq -r '.auditID // ""' <<<"${real_log_event:-\{\}}" 2>/dev/null || true)

  # The student artifact must match the REAL event (by auditID), and pass the same
  # exact structural checks - not just an ad-hoc substring test.
  artifact_event_ok=$(jq -r '
    .verb == "create" and
    .objectRef.resource == "clusterrolebindings" and
    .objectRef.name == "incident-simulated-escalation" and
    .requestObject.roleRef.kind == "ClusterRole" and
    .requestObject.roleRef.name == "cluster-admin" and
    ([.requestObject.subjects[]? | select(.kind == "ServiceAccount" and .name == "build-agent" and .namespace == "security-104")] | length == 1) and
    (.user.username // "" | length > 0)
  ' "$event_file" 2>/dev/null || true)
  artifact_auditid=$(jq -r '.auditID // ""' "$event_file" 2>/dev/null || true)
  artifact_matches_real_log=$([[ -n "$artifact_auditid" && "$artifact_auditid" == "$real_log_auditid" ]] && echo true || echo false)

  set +e
  kubectl get clusterrolebinding incident-simulated-escalation --context "$CTX" >/dev/null 2>&1
  binding_status=$?
  set -e
  # Independently re-run the authorization check ourselves after containment - do not
  # trust containment-result.txt as the sole proof that access was actually revoked.
  independent_can_i=$(kubectl auth can-i '*' '*' --as=system:serviceaccount:security-104:build-agent --context "$CTX" 2>/dev/null || true)

  if [[ -n "$command" && -n "$log_flag" && "$readyz_ok" == "ok" ]] \
    && [[ "$real_log_ok" == "true" ]] \
    && [[ "$artifact_event_ok" == "true" && "$artifact_matches_real_log" == "true" ]] \
    && [[ "$binding_status" -ne 0 ]] \
    && [[ "$independent_can_i" == "no" ]] \
    && grep -q '^no$' "$containment_file"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ -z "$command" || -z "$log_flag" ]]; then
      echo "HINT: kube-apiserver static Pod is missing the exact --audit-policy-file=/etc/kubernetes/audit/policy.yaml or --audit-log-path=/var/log/kubernetes/audit/audit.log flags. Edit /etc/kubernetes/manifests/kube-apiserver.yaml directly and add the required hostPath volumes for the policy file and log directory."
    elif [[ "$readyz_ok" != "ok" ]]; then
      echo "HINT: kubectl get --raw=/readyz did not return 'ok'. The API server may not have restarted cleanly after the audit backend was added - check the static Pod's status and logs."
    elif [[ "$real_log_ok" != "true" ]]; then
      echo "HINT: The checker read /var/log/kubernetes/audit/audit.log DIRECTLY on the control-plane via SSH and could not find a matching RequestResponse-level event for the ClusterRoleBinding creation. Make sure your audit policy captures rbac.authorization.k8s.io resources at RequestResponse level BEFORE you create incident-simulated-escalation, that the rule is listed before the Metadata catch-all, and that the binding was actually created with roleRef=cluster-admin and subject ServiceAccount build-agent in security-104."
    elif [[ "$artifact_event_ok" != "true" ]]; then
      echo "HINT: audit-escalation-event.json does not structurally match the required event (exact roleRef and subjects fields, plus a non-empty user.username) - a hand-written JSON file with just a few matching strings is not accepted."
    elif [[ "$artifact_matches_real_log" != "true" ]]; then
      echo "HINT: audit-escalation-event.json's auditID ('$artifact_auditid') does not match any event actually found in the real audit log on the control-plane ('$real_log_auditid'). The artifact must be the REAL event copied from the log, not a fabricated JSON file."
    elif [[ "$binding_status" -eq 0 ]]; then
      echo "HINT: ClusterRoleBinding 'incident-simulated-escalation' still exists. Delete it as part of containment - detecting the dangerous grant is not enough, you must also remove it."
    elif [[ "$independent_can_i" != "no" ]]; then
      echo "HINT: The checker independently re-ran 'kubectl auth can-i * * --as=system:serviceaccount:security-104:build-agent' AFTER containment and it did not return 'no'. Access must be actually revoked, not just the binding object deleted from view - check for another lingering ClusterRoleBinding/RoleBinding."
    elif ! grep -q '^no$' "$containment_file"; then
      echo "HINT: containment-result.txt must contain exactly 'no', the output of 'kubectl auth can-i ... --as=system:serviceaccount:security-104:build-agent' AFTER deleting the binding."
    fi
    echo "audit_policy_flag=$command audit_log_flag=$log_flag readyz_ok=$readyz_ok real_log_ok=$real_log_ok real_log_user=$real_log_user real_log_auditid=$real_log_auditid artifact_event_ok=$artifact_event_ok artifact_auditid=$artifact_auditid artifact_matches_real_log=$artifact_matches_real_log binding_status=$binding_status independent_can_i=$independent_can_i containment=$(cat "$containment_file" 2>/dev/null)"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "10. Existing Secret is decoded, rehydrated into a new Secret and mounted read-only" {
  echo '1' >> /var/work/tests/result/all
  # Source of truth: decode the ORIGINAL fixture Secret ourselves, live - never trust a
  # student-written decode artifact as the authoritative value.
  source_user=$(kubectl get secret legacy-config -n "$NS" --context "$CTX" -o jsonpath='{.data.SERVICE_USER}' 2>/dev/null | base64 -d 2>/dev/null || true)
  source_token=$(kubectl get secret legacy-config -n "$NS" --context "$CTX" -o jsonpath='{.data.SERVICE_TOKEN}' 2>/dev/null | base64 -d 2>/dev/null || true)
  new_secret=$(kubectl get secret rehydrated-config -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  new_user=$(jq -r '.data.SERVICE_USER // ""' <<<"$new_secret" 2>/dev/null | base64 -d 2>/dev/null || true)
  new_token=$(jq -r '.data.SERVICE_TOKEN // ""' <<<"$new_secret" 2>/dev/null | base64 -d 2>/dev/null || true)
  values_match=false
  if [[ -n "$source_user" && -n "$source_token" && "$new_user" == "$source_user" && "$new_token" == "$source_token" ]]; then
    values_match=true
  fi
  pod=$(kubectl get pod secret-workflow -n "$NS" --context "$CTX" -o json 2>/dev/null || true)
  mount_ok=$(jq -r '
    ([.spec.volumes[]? | select(.secret.secretName == "rehydrated-config")] | length == 1) and
    ([.spec.containers[]?.volumeMounts[]? | select(.mountPath == "/etc/rehydrated" and .readOnly == true)] | length == 1)
  ' <<<"$pod" 2>/dev/null)
  set +e
  kubectl wait -n "$NS" --for=condition=Ready pod/secret-workflow --timeout=60s --context "$CTX" >/dev/null 2>&1
  file_user=$(kubectl exec -n "$NS" secret-workflow --context "$CTX" -- cat /etc/rehydrated/SERVICE_USER 2>/dev/null)
  file_user_status=$?
  file_token=$(kubectl exec -n "$NS" secret-workflow --context "$CTX" -- cat /etc/rehydrated/SERVICE_TOKEN 2>/dev/null)
  file_token_status=$?
  set -e
  files_ok=false
  if [[ "$file_user_status" -eq 0 && "$file_token_status" -eq 0 \
        && "$file_user" == "$source_user" && "$file_token" == "$source_token" ]]; then
    files_ok=true
  fi
  if [[ "$values_match" == "true" && "$mount_ok" == "true" && "$files_ok" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$values_match" != "true" ]]; then
      echo "HINT: Secret 'rehydrated-config' in namespace '$NS' does not exist, or its SERVICE_USER/SERVICE_TOKEN values do not match the base64-decoded values from the original Secret 'legacy-config'. Read the original Secret via the API, base64 -d both fields, and use those EXACT values as literals when creating the new Secret."
    elif [[ "$mount_ok" != "true" ]]; then
      echo "HINT: Pod 'secret-workflow' must mount Secret 'rehydrated-config' via a Secret volume, read-only, at exactly '/etc/rehydrated'. Check volumeMounts.mountPath and readOnly: true."
    elif [[ "$files_ok" != "true" ]]; then
      echo "HINT: Reading /etc/rehydrated/SERVICE_USER and /etc/rehydrated/SERVICE_TOKEN inside the container did not return the expected decoded values (exec exit codes: user=$file_user_status token=$file_token_status). Check the Pod is Running/Ready and that the mounted Secret is really 'rehydrated-config'."
    fi
    echo "source_user_present=$([[ -n "$source_user" ]] && echo yes || echo no) values_match=$values_match mount_ok=$mount_ok files_ok=$files_ok file_user_status=$file_user_status file_token_status=$file_token_status"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "11. Repaired Role in rbac-a and a cross-namespace RoleBinding grant exactly the intended access" {
  echo '1' >> /var/work/tests/result/all
  role=$(kubectl get role pod-role -n rbac-a --context "$CTX" -o json 2>/dev/null || true)
  role_verbs_ok=$(jq -r '
    ([.rules[]? | select(.apiGroups == [""] and .resources == ["pods"])] | length == 1) and
    ((.rules[] | select(.apiGroups == [""] and .resources == ["pods"]) | .verbs | sort) == ["get","list","watch"])
  ' <<<"$role" 2>/dev/null)
  can_get=$(kubectl auth can-i get pods -n rbac-a --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  can_list=$(kubectl auth can-i list pods -n rbac-a --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  can_watch=$(kubectl auth can-i watch pods -n rbac-a --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  cannot_delete=$(kubectl auth can-i delete pods -n rbac-a --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  can_get_cm=$(kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  can_list_cm=$(kubectl auth can-i list configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  cannot_delete_cm=$(kubectl auth can-i delete configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  cannot_secrets_cm=$(kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev --context "$CTX" 2>/dev/null || true)
  pod=$(kubectl get pod -n rbac-a --context "$CTX" -o json 2>/dev/null || true)
  pod_uses_dev=$(jq -r '[.items[]? | select(.spec.serviceAccountName == "dev")] | length > 0' <<<"$pod" 2>/dev/null)
  if [[ "$role_verbs_ok" == "true" \
    && "$can_get" == "yes" && "$can_list" == "yes" && "$can_watch" == "yes" && "$cannot_delete" == "no" \
    && "$can_get_cm" == "yes" && "$can_list_cm" == "yes" && "$cannot_delete_cm" == "no" && "$cannot_secrets_cm" == "no" \
    && "$pod_uses_dev" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$role_verbs_ok" != "true" ]]; then
      echo "HINT: Role 'pod-role' in namespace 'rbac-a' must have EXACTLY the verbs get, list, watch on pods - the original fixture also had 'delete' (must be removed) and was missing 'watch' (must be added). Fix the EXISTING Role in-place, do not create a second one."
    elif [[ "$can_get" != "yes" || "$can_list" != "yes" || "$can_watch" != "yes" || "$cannot_delete" != "no" ]]; then
      echo "HINT: ServiceAccount 'dev' in 'rbac-a' does not have exactly get/list/watch on pods in its own namespace (get=$can_get list=$can_list watch=$can_watch delete=$cannot_delete, delete should be 'no'). Check the RoleBinding 'pod-role-binding' is still correctly bound after you edited the Role."
    elif [[ "$can_get_cm" != "yes" || "$can_list_cm" != "yes" ]]; then
      echo "HINT: ServiceAccount 'dev' (from rbac-a) cannot get/list ConfigMaps in namespace 'rbac-b' (get=$can_get_cm list=$can_list_cm). Create a NEW Role+RoleBinding IN rbac-b, with the RoleBinding's subject set to ServiceAccount 'dev' in namespace 'rbac-a' - a RoleBinding can reference a subject from a different namespace than itself, but the rights it grants are still scoped to the RoleBinding's own namespace."
    elif [[ "$cannot_delete_cm" != "no" || "$cannot_secrets_cm" != "no" ]]; then
      echo "HINT: ServiceAccount 'dev' has MORE access in 'rbac-b' than intended (delete configmaps=$cannot_delete_cm, get secrets=$cannot_secrets_cm - both should be 'no'). Grant only get/list on configmaps, nothing else."
    elif [[ "$pod_uses_dev" != "true" ]]; then
      echo "HINT: No Pod in namespace 'rbac-a' uses serviceAccountName 'dev'. Create one so the cross-namespace access is actually exercised by a real workload, not just proven via 'kubectl auth can-i --as'."
    fi
    echo "role_verbs_ok=$role_verbs_ok can_get=$can_get can_list=$can_list can_watch=$can_watch cannot_delete=$cannot_delete can_get_cm=$can_get_cm can_list_cm=$can_list_cm cannot_delete_cm=$cannot_delete_cm cannot_secrets_cm=$cannot_secrets_cm pod_uses_dev=$pod_uses_dev"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "12. Client-certificate user 'john' is onboarded via CSR and scoped to namespaced RBAC" {
  echo '1' >> /var/work/tests/result/all
  csr=$(kubectl get csr john-csr --context "$CTX" -o json 2>/dev/null || true)
  signer_ok=$(jq -r '.spec.signerName == "kubernetes.io/kube-apiserver-client"' <<<"$csr" 2>/dev/null)
  approved=$(jq -r '[.status.conditions[]? | select(.type == "Approved" and .status == "True")] | length > 0' <<<"$csr" 2>/dev/null)
  cert_b64=$(jq -r '.status.certificate // ""' <<<"$csr" 2>/dev/null)
  cert_pem=""
  if [[ -n "$cert_b64" && "$cert_b64" != "null" ]]; then
    cert_pem=$(base64 -d <<<"$cert_b64" 2>/dev/null || true)
  fi
  cn_ok=false
  chain_ok=false
  if [[ -n "$cert_pem" ]]; then
    subject=$(openssl x509 -noout -subject -nameopt utf8 <<<"$cert_pem" 2>/dev/null || true)
    [[ "$subject" == *"CN=john"* || "$subject" == *"CN = john"* ]] && cn_ok=true
    # Verify the issued certificate actually chains to THIS cluster's CA, not just that
    # some certificate-shaped blob exists in status.certificate.
    ca_pem=$(ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=10 control-plane "sudo cat /etc/kubernetes/pki/ca.crt" 2>/dev/null || true)
    if [[ -n "$ca_pem" ]]; then
      verify_out=$(openssl verify -CAfile <(echo "$ca_pem") <(echo "$cert_pem") 2>&1 || true)
      [[ "$verify_out" == *": OK"* ]] && chain_ok=true
    fi
  fi
  can_create=$(kubectl auth can-i create pods -n development --as=john --context "$CTX" 2>/dev/null || true)
  can_list=$(kubectl auth can-i list pods -n development --as=john --context "$CTX" 2>/dev/null || true)
  can_get=$(kubectl auth can-i get pods -n development --as=john --context "$CTX" 2>/dev/null || true)
  cannot_delete=$(kubectl auth can-i delete pods -n development --as=john --context "$CTX" 2>/dev/null || true)
  cannot_other_ns=$(kubectl auth can-i create pods -n "$NS" --as=john --context "$CTX" 2>/dev/null || true)
  # Live proof of REAL client-cert authentication, not just RBAC impersonation via
  # --as=john (which any admin can do regardless of whether a valid cert was ever
  # issued): present the student-saved cert/key directly to the API server over TLS.
  real_auth_ok=false
  crt_file="/var/work/tests/artifacts/12/john.crt"
  key_file="/var/work/tests/artifacts/12/john.key"
  if [[ -s "$crt_file" && -s "$key_file" && -n "$ca_pem" ]]; then
    server=$(kubectl config view --minify --context "$CTX" -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    allowed_code=$(curl --connect-timeout 5 --max-time 10 -s -o /dev/null -w '%{http_code}' \
      --cacert <(echo "$ca_pem") --cert "$crt_file" --key "$key_file" \
      "$server/api/v1/namespaces/development/pods" 2>/dev/null || true)
    denied_code=$(curl --connect-timeout 5 --max-time 10 -s -o /dev/null -w '%{http_code}' \
      --cacert <(echo "$ca_pem") --cert "$crt_file" --key "$key_file" \
      "$server/api/v1/namespaces/$NS/pods" 2>/dev/null || true)
    [[ "$allowed_code" == "200" && "$denied_code" == "403" ]] && real_auth_ok=true
  fi
  if [[ "$signer_ok" == "true" && "$approved" == "true" && "$cn_ok" == "true" && "$chain_ok" == "true" \
    && "$can_create" == "yes" && "$can_list" == "yes" && "$can_get" == "yes" && "$cannot_delete" == "no" \
    && "$cannot_other_ns" == "no" && "$real_auth_ok" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$signer_ok" != "true" ]]; then
      echo "HINT: CertificateSigningRequest 'john-csr' does not exist or does not use signerName 'kubernetes.io/kube-apiserver-client' - this is the signer required to authenticate a real client identity against the API server."
    elif [[ "$approved" != "true" ]]; then
      echo "HINT: CSR 'john-csr' has not been Approved. Use 'kubectl certificate approve john-csr'."
    elif [[ "$cn_ok" != "true" ]]; then
      echo "HINT: The issued certificate's subject CN is not 'john'. Check the CSR (openssl req) was generated with -subj '/CN=john' before it was submitted."
    elif [[ "$chain_ok" != "true" ]]; then
      echo "HINT: The issued certificate does not verify against this cluster's own CA (/etc/kubernetes/pki/ca.crt on control-plane). Something is wrong with how the CSR was created or approved."
    elif [[ "$can_create" != "yes" || "$can_list" != "yes" || "$can_get" != "yes" ]]; then
      echo "HINT: User 'john' cannot create/list/get pods in namespace 'development' (create=$can_create list=$can_list get=$can_get). Create a Role in 'development' with these verbs on pods and a RoleBinding with subject {kind: User, name: john}."
    elif [[ "$cannot_delete" != "no" ]]; then
      echo "HINT: User 'john' can delete pods in 'development' - the task only grants create/list/get. Remove the extra verb."
    elif [[ "$cannot_other_ns" != "no" ]]; then
      echo "HINT: User 'john' has pod-create access in namespace '$NS' too - the RoleBinding must be scoped to 'development' only, not a ClusterRoleBinding."
    elif [[ "$real_auth_ok" != "true" ]]; then
      echo "HINT: Presenting the saved certificate/key directly to the API server over TLS (not via 'kubectl auth can-i --as') did not behave as expected - a request to /api/v1/namespaces/development/pods should return 200 and the same request against namespace '$NS' should return 403. Save the issued certificate as $crt_file and its private key as $key_file (PEM format)."
    fi
    echo "signer_ok=$signer_ok approved=$approved cn_ok=$cn_ok chain_ok=$chain_ok can_create=$can_create can_list=$can_list can_get=$can_get cannot_delete=$cannot_delete cannot_other_ns=$cannot_other_ns real_auth_ok=$real_auth_ok"
    result=1
  fi
  [ "$result" -eq 0 ]
}
