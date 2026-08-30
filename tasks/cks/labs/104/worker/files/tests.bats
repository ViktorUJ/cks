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
    echo "minimal=$minimal binding=$bound auditor_can_delete_secrets=$cannot_delete"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. token-client uses a bounded projected ServiceAccount token" {
  echo '1' >> /var/work/tests/result/all
  pod=$(kubectl get pod token-client -n "$NS" --context "$CTX" -o json 2>/dev/null)
  sa=$(kubectl get serviceaccount api-client -n "$NS" --context "$CTX" -o name 2>/dev/null)
  token=$(jq -r '[.spec.volumes[]?.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and .audience == "kubernetes.default.svc" and (.expirationSeconds | tonumber) <= 3600)] | length' <<<"$pod" 2>/dev/null)
  mounted=$(jq -r '. as $pod | [$pod.spec.volumes[]? | select(.projected != null) | . as $volume | ([.projected.sources[]?.serviceAccountToken | select(.path == "api-token" and .audience == "kubernetes.default.svc" and (.expirationSeconds | tonumber) <= 3600)] | length) as $tokens | select($tokens > 0) | $pod.spec.containers[]?.volumeMounts[]? | select(.name == $volume.name and .mountPath == "/var/run/secrets/tokens" and .readOnly == true)] | length' <<<"$pod" 2>/dev/null)
  auto=$(jq -r '.spec.automountServiceAccountToken' <<<"$pod" 2>/dev/null)
  client_sa=$(jq -r '.spec.serviceAccountName' <<<"$pod" 2>/dev/null)
  if [[ "$sa" == "serviceaccount/$NS/api-client" && "$client_sa" == "api-client" && "$auto" == "false" && "$token" -ge 1 && "$mounted" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa=$sa pod_sa=$client_sa automount=$auto projected_tokens=$token mounted_projected_tokens=$mounted"
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
    echo "anonymous_auth_argument=$command anonymous_version_http=$code"
    result=1
  fi
  [ "$result" -eq 0 ]
}
