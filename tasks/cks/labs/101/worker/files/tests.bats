#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-101"
CHECKER_ARTIFACTS="/var/work/tests/checker-artifacts"

client_run() {
  local name=$1
  local label=$2
  local command=$3
  kubectl --context "$CTX" run "$name" -n "$NS" --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels="app=$label" --command -- sh -c "$command"
}

@test "0 Init" {
  rm -rf "$CHECKER_ARTIFACTS"
  mkdir -p "$CHECKER_ARTIFACTS"
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Namespace cks-101, frontend/backend Deployments and backend Service exist" {
  echo '1' >> /var/work/tests/result/all

  namespace=$(kubectl --context "$CTX" get namespace "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  frontend_image=$(kubectl --context "$CTX" get deployment frontend -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  backend_image=$(kubectl --context "$CTX" get deployment backend -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  frontend_label=$(kubectl --context "$CTX" get deployment frontend -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  backend_label=$(kubectl --context "$CTX" get deployment backend -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  endpoints=$(kubectl --context "$CTX" get endpoints backend -n "$NS" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)

  # A mutable tag (including :latest) is not an accepted security-lab reference.
  # The repository and a full SHA-256 digest form the exact allowed reference format.
  if [[ "$namespace" == "$NS" ]] && [[ "$frontend_image" =~ ^viktoruj/ping_pong@sha256:[a-f0-9]{64}$ ]] && \
     [[ "$backend_image" =~ ^viktoruj/ping_pong@sha256:[a-f0-9]{64}$ ]] && [[ "$frontend_label" == "frontend" ]] && \
     [[ "$backend_label" == "backend" ]] && [[ "$endpoints" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$namespace" != "$NS" ]]; then
      echo "HINT: Namespace '$NS' does not exist yet. Create it before the Deployments."
    elif ! [[ "$frontend_image" =~ ^viktoruj/ping_pong@sha256:[a-f0-9]{64}$ ]] || ! [[ "$backend_image" =~ ^viktoruj/ping_pong@sha256:[a-f0-9]{64}$ ]]; then
      echo "HINT: Both Deployments must use image 'viktoruj/ping_pong@sha256:<64-hex-digest>' - a mutable tag like ':latest' is not accepted. Pin the exact digest."
    elif [[ "$frontend_label" != "frontend" || "$backend_label" != "backend" ]]; then
      echo "HINT: Pod template labels must be exactly 'app: frontend' / 'app: backend' - the Service and NetworkPolicy selectors in later tasks depend on this exact label value."
    elif [[ "$endpoints" -lt 1 ]]; then
      echo "HINT: Service 'backend' has no endpoints. Check that the backend Deployment's Pods are Running/Ready and that the Service selector matches the Pod label."
    fi
    echo "namespace=$namespace frontend=$frontend_image/$frontend_label backend=$backend_image/$backend_label endpoints=$endpoints"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "2. Default-deny NetworkPolicy covers ingress and egress in cks-101" {
  echo '1' >> /var/work/tests/result/all
  policy=$(kubectl --context "$CTX" get networkpolicy -n "$NS" -o json 2>/dev/null | jq -r '
    .items[] | select(.spec.podSelector == {})
    | select((.spec.policyTypes | sort) == ["Egress", "Ingress"])
    | select((.spec.ingress // []) | length == 0)
    | select((.spec.egress // []) | length == 0) | .metadata.name' | head -n1)
  if [[ -n "$policy" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "HINT: Create podSelector: {}, policyTypes [Ingress, Egress], and no allow rules. ingress/egress may be omitted or empty; they must not allow traffic."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. frontend identity reaches backend:8080; foreign identity is blocked" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p "$CHECKER_ARTIFACTS/3"
  student_connectivity_artifact=$(find /var/work/tests/artifacts/3 -maxdepth 1 -type f -size +0c -print -quit 2>/dev/null || true)
  backend_ip=$(kubectl --context "$CTX" get service backend -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ -z "$backend_ip" || "$backend_ip" == "None" ]]; then
    echo "backend ClusterIP unavailable" > $CHECKER_ARTIFACTS/3/connectivity.txt
    [ 1 -eq 0 ]
  fi

  # The foreign source receives only backend egress. A failed request now proves
  # backend ingress selection, not the namespace default-deny egress policy.
  kubectl --context "$CTX" delete networkpolicy checker-allow-foreign-egress -n "$NS" --ignore-not-found >/dev/null 2>&1
  cat <<'EOF' | kubectl --context "$CTX" apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: checker-allow-foreign-egress, namespace: cks-101}
spec:
  podSelector: {matchLabels: {app: foreign}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {app: backend}}}]
      ports: [{protocol: TCP, port: 8080}]
EOF
  checker_policy_status=$?
  run client_run policy-frontend frontend "curl -fsS --max-time 5 http://$backend_ip:8080/"
  frontend_status=$status; frontend_output=$output
  run client_run policy-foreign foreign "curl -fsS --max-time 5 http://$backend_ip:8080/"
  foreign_status=$status; foreign_output=$output
  kubectl --context "$CTX" delete networkpolicy checker-allow-foreign-egress -n "$NS" --ignore-not-found >/dev/null 2>&1
  {
    echo "frontend exit=$frontend_status"; echo "$frontend_output"
    echo "foreign egress-policy exit=$checker_policy_status"; echo "foreign exit=$foreign_status"; echo "$foreign_output"
  } > $CHECKER_ARTIFACTS/3/connectivity.txt
  if [[ -n "$student_connectivity_artifact" && "$checker_policy_status" -eq 0 && "$frontend_status" -eq 0 && "$foreign_status" -ne 0 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "HINT: Save non-empty allowed/denied connectivity evidence in /var/work/tests/artifacts/3, and ensure frontend egress plus backend ingress permit only TCP/8080."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. frontend identity can resolve DNS through kube-dns on port 53" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p "$CHECKER_ARTIFACTS/4"
  student_dns_artifact=/var/work/tests/artifacts/4/dns.txt
  student_dns_valid=false
  if [[ -s "$student_dns_artifact" ]] && grep -q "Name:" "$student_dns_artifact"; then student_dns_valid=true; fi
  run kubectl --context "$CTX" run policy-dns -n "$NS" --rm -i --restart=Never \
    --image=busybox:1.36.1 --labels=app=frontend --command -- nslookup kubernetes.default.svc.cluster.local
  dns_status=$status
  printf '%s\n' "$output" > $CHECKER_ARTIFACTS/4/dns.txt

  # Require the narrow DNS peer and both transports, and reject broad egress in
  # policies which select frontend (including a podSelector of {}).
  dns_policy_valid=$(kubectl --context "$CTX" get networkpolicy -n "$NS" -o json 2>/dev/null | jq -r '
    def frontend_selected: .spec.podSelector == {} or .spec.podSelector.matchLabels.app == "frontend";
    def backend_rule: ((.to // []) | length == 1) and .to[0].podSelector.matchLabels.app == "backend" and ((.to[0] | has("namespaceSelector")) | not) and (([.ports[]? | select(.port == 8080) | .protocol] | unique) == ["TCP"]);
    def dns_rule: ((.to // []) | length == 1) and .to[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "kube-system" and .to[0].podSelector.matchLabels["k8s-app"] == "kube-dns" and (([.ports[]? | select(.port == 53) | .protocol] | sort | unique) == ["TCP", "UDP"]);
    [.items[] | select((.spec.policyTypes // []) | index("Egress")) | select(frontend_selected) | .spec.egress[]?] as $rules
    | (($rules | any(dns_rule)) and ($rules | all(backend_rule or dns_rule)))')
  if [[ "$student_dns_valid" == "true" && "$dns_status" -eq 0 && "$dns_policy_valid" == "true" ]] && grep -q "Name:" "$CHECKER_ARTIFACTS/4/dns.txt"; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "HINT: Save the successful lookup in /var/work/tests/artifacts/4/dns.txt, and allow only backend TCP/8080 plus kube-system/kube-dns on UDP/TCP 53."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. frontend identity cannot reach metadata 169.254.169.254" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p "$CHECKER_ARTIFACTS/5"
  student_metadata_artifact=/var/work/tests/artifacts/5/metadata.output

  # Do not use curl -f here: it maps a reachable HTTP 401/403 to a non-zero exit code.
  # Preserve curl's own exit code and http_code so the failure layer stays visible.
  run client_run policy-metadata frontend "set +e; body=\$(curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=\$?; printf 'CURL_EXIT:%s\\n%s\\n' \"\$rc\" \"\$body\"; exit 0"
  metadata_output=$output
  metadata_rc=$(printf '%s\n' "$metadata_output" | sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' | tail -n1)
  http_code=$(printf '%s\n' "$metadata_output" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -n1)

  case "$metadata_rc" in
    6) outcome="level=dns outcome=name-resolution-failure" ;;
    7) outcome="level=network outcome=tcp-connect-failure" ;;
    28) outcome="level=network outcome=timeout" ;;
    0) outcome="level=http outcome=response status=${http_code:-unknown}" ;;
    *) outcome="level=other outcome=curl-exit-${metadata_rc:-missing}" ;;
  esac
  {
    printf '%s\n' "$metadata_output"
    printf 'http_code=%s\n' "${http_code:-missing}"
    printf '%s\n' "$outcome"
  } > $CHECKER_ARTIFACTS/5/metadata.output
  printf '%s\n' "${metadata_rc:-missing}" > $CHECKER_ARTIFACTS/5/metadata.exit-code

  student_metadata_output=$(cat "$student_metadata_artifact" 2>/dev/null || true)
  student_metadata_rc=$(printf '%s\n' "$student_metadata_output" | sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' | tail -n1)
  student_metadata_code=$(printf '%s\n' "$student_metadata_output" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -n1)
  student_metadata_valid=false
  if [[ -s "$student_metadata_artifact" && "$student_metadata_code" == "000" && ( "$student_metadata_rc" == "7" || "$student_metadata_rc" == "28" ) ]] && grep -q '^level=network' "$student_metadata_artifact"; then student_metadata_valid=true; fi

  # Negative control: a real 401/403 must be distinguished from a network deny.
  # Bats 0.4 can lose interactive `kubectl run --rm -i` stdout, so collect a
  # completed Pod's logs instead of relying on the attach stream.
  kubectl --context "$CTX" delete pod policy-http-control -n default --ignore-not-found >/dev/null 2>&1
  kubectl --context "$CTX" run policy-http-control -n default --restart=Never \
    --image=curlimages/curl:8.11.1 --command -- sh -c \
    "curl -ksS -o /dev/null -w 'HTTPCODE:%{http_code}\\n' --max-time 10 https://kubernetes.default.svc/" >/dev/null
  control_create_status=$?
  kubectl --context "$CTX" wait -n default --for=jsonpath='{.status.phase}'=Succeeded pod/policy-http-control --timeout=30s >/dev/null 2>&1
  control_wait_status=$?
  control_output=$(kubectl --context "$CTX" logs -n default policy-http-control 2>&1)
  control_code=$(printf '%s\n' "$control_output" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -n1)
  kubectl --context "$CTX" delete pod policy-http-control -n default --ignore-not-found >/dev/null 2>&1
  printf 'create_exit=%s wait_exit=%s level=http outcome=response status=%s\n' \
    "$control_create_status" "$control_wait_status" "${control_code:-missing}" \
    > $CHECKER_ARTIFACTS/5/http-false-positive-control.txt

  if [[ "$student_metadata_valid" == "true" && "$http_code" == "000" && ( "$metadata_rc" == "7" || "$metadata_rc" == "28" ) ]] \
    && [[ "$control_code" == "401" || "$control_code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$control_code" != "401" && "$control_code" != "403" ]]; then
      echo "HINT: Save a network-deny result (CURL_EXIT 7/28, HTTPCODE:000, level=network) in /var/work/tests/artifacts/5/metadata.output; the HTTP control must return 401/403."
    elif [[ "$http_code" != "000" ]]; then
      echo "HINT: Request to 169.254.169.254 got an actual HTTP response (code=$http_code) instead of being network-blocked. Your egress policy is not blocking metadata access - check that the deny is not accidentally bypassed by an overly broad allow rule (e.g. 0.0.0.0/0 without ipBlock.except)."
    else
      echo "HINT: curl exit code was '$metadata_rc', not the expected connection-refused/timeout (7 or 28). Check $CHECKER_ARTIFACTS/5/metadata.output for the raw curl behavior."
    fi
    echo "metadata: curl_exit=${metadata_rc:-missing} http_code=${http_code:-missing} ($outcome); HTTP negative-control=${control_code:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. AND-trap ingress policy and ipBlock except are correctly scoped" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p $CHECKER_ARTIFACTS/6
  policy=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-legacy -n "$NS" -o json 2>/dev/null)
  and_scoped=$(jq -r '([.spec.ingress[]?.from[]?] | length > 0) and all(.spec.ingress[]?.from[]?; .namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "cks-101-legacy" and .podSelector.matchLabels.app == "legacy-client")' <<<"$policy" 2>/dev/null)
  egress_policy=$(kubectl --context "$CTX" get networkpolicy allow-legacy-egress -n cks-101-legacy -o json 2>/dev/null)
  except_scoped=$(jq -r '([.spec.egress[]?.to[]? | select(.ipBlock.cidr == "0.0.0.0/0") | select((.ipBlock.except // []) == ["169.254.169.254/32"])] | length == 1)' <<<"$egress_policy" 2>/dev/null)
  backend_ip=$(kubectl --context "$CTX" get service backend -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

  # These policies give the two negative identities backend egress, so each
  # probe detects one branch of a split-OR ingress policy.
  kubectl --context "$CTX" delete networkpolicy checker-legacy-wrong-egress -n cks-101-legacy --ignore-not-found >/dev/null 2>&1
  kubectl --context "$CTX" delete networkpolicy checker-legacy-local-egress -n "$NS" --ignore-not-found >/dev/null 2>&1
  cat <<'EOF' | kubectl --context "$CTX" apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: checker-legacy-wrong-egress, namespace: cks-101-legacy}
spec:
  podSelector: {matchLabels: {app: legacy-wrong-label}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {app: backend}}}]
      ports: [{protocol: TCP, port: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: checker-legacy-local-egress, namespace: cks-101}
spec:
  podSelector: {matchLabels: {app: legacy-client}}
  policyTypes: [Egress]
  egress:
    - to: [{podSelector: {matchLabels: {app: backend}}}]
      ports: [{protocol: TCP, port: 8080}]
EOF
  checker_policy_status=$?
  run kubectl --context "$CTX" run policy-legacy-allowed -n cks-101-legacy --rm -i --restart=Never --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c "curl -fsS --max-time 5 http://$backend_ip:8080/"
  allowed_status=$status
  run kubectl --context "$CTX" run policy-legacy-wrong-label -n cks-101-legacy --rm -i --restart=Never --image=curlimages/curl:8.11.1 --labels=app=legacy-wrong-label --command -- sh -c "curl -fsS --max-time 5 http://$backend_ip:8080/"
  wrong_label_status=$status
  run kubectl --context "$CTX" run policy-legacy-local -n "$NS" --rm -i --restart=Never --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c "curl -fsS --max-time 5 http://$backend_ip:8080/"
  local_status=$status
  run kubectl --context "$CTX" run policy-legacy-external -n cks-101-legacy --rm -i --restart=Never --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c "set +e; out=\$(curl -ksS -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 https://1.1.1.1/ 2>&1); rc=\$?; printf 'CURL_EXIT:%s\\n%s\\n' \"\$rc\" \"\$out\"; exit 0"
  external_output=$output
  run kubectl --context "$CTX" run policy-legacy-metadata -n cks-101-legacy --rm -i --restart=Never --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c "set +e; out=\$(curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=\$?; printf 'CURL_EXIT:%s\\n%s\\n' \"\$rc\" \"\$out\"; exit 0"
  metadata_output=$output
  kubectl --context "$CTX" delete networkpolicy checker-legacy-wrong-egress -n cks-101-legacy --ignore-not-found >/dev/null 2>&1
  kubectl --context "$CTX" delete networkpolicy checker-legacy-local-egress -n "$NS" --ignore-not-found >/dev/null 2>&1
  external_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' <<<"$external_output" | tail -n1)
  metadata_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' <<<"$metadata_output" | tail -n1)
  metadata_rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' <<<"$metadata_output" | tail -n1)
  {
    echo "checker_policy_apply_exit=$checker_policy_status"; echo "allowed=$allowed_status wrong_label=$wrong_label_status local=$local_status"; echo "external=$external_output"; echo "metadata=$metadata_output"
  } > $CHECKER_ARTIFACTS/6/and-trap.txt
  if [[ "$and_scoped" == true && "$except_scoped" == true && "$checker_policy_status" -eq 0 && "$allowed_status" -eq 0 && "$wrong_label_status" -ne 0 && "$local_status" -ne 0 && "$external_code" != 000 && "$metadata_code" == 000 && ( "$metadata_rc" == 7 || "$metadata_rc" == 28 ) ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "HINT: Allow only legacy-client in cks-101-legacy (both selectors in each peer), without extra peers; exclude metadata from broad legacy egress."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. hostNetwork Pod networking is observed as implementation-dependent for this Calico lab" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p "$CHECKER_ARTIFACTS/7"
  student_hostnetwork_artifact=/var/work/tests/artifacts/7/hostnetwork-metadata.output
  student_comparison_artifact=/var/work/tests/artifacts/7/comparison.txt
  student_hostnetwork_valid=false
  if [[ -s "$student_hostnetwork_artifact" && -s "$student_comparison_artifact" ]] \
    && grep -Eq 'HTTPCODE:[1-9][0-9][0-9]' "$student_hostnetwork_artifact" \
    && grep -qi 'environment-specific' "$student_comparison_artifact" \
    && grep -q 'task5_result=' "$student_comparison_artifact" \
    && grep -q 'task7_result=' "$student_comparison_artifact"; then student_hostnetwork_valid=true; fi
  pod=$(kubectl --context "$CTX" get pod hostnetwork-probe -n "$NS" -o json 2>/dev/null)
  host_network=$(jq -r '.spec.hostNetwork == true' <<<"$pod" 2>/dev/null)
  app_label=$(jq -r '.metadata.labels.app // ""' <<<"$pod" 2>/dev/null)
  run kubectl --context "$CTX" exec -n "$NS" hostnetwork-probe -- sh -c "set +e; out=\$(curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1); rc=\$?; printf 'CURL_EXIT:%s\\n%s\\n' \"\$rc\" \"\$out\"; exit 0"
  probe_output=$output
  probe_http_code=$(sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' <<<"$probe_output" | tail -n1)
  probe_rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' <<<"$probe_output" | tail -n1)
  task5_output=$(cat /var/work/tests/artifacts/5/metadata.output 2>/dev/null || true)
  task5_http_code=$(sed -n 's/^http_code=\([0-9][0-9][0-9]\).*/\1/p' <<<"$task5_output" | tail -n1)
  task5_rc=$(sed -n 's/.*CURL_EXIT:\([0-9][0-9]*\).*/\1/p' <<<"$task5_output" | tail -n1)
  {
    printf '%s\n' "$probe_output"
    echo "task5_result=curl_exit=${task5_rc:-missing} http_code=${task5_http_code:-missing}"
    echo "task7_result=curl_exit=${probe_rc:-missing} http_code=${probe_http_code:-missing}; observed for this Calico lab only, not a universal NetworkPolicy guarantee"
  } > $CHECKER_ARTIFACTS/7/comparison.txt
  printf '%s\n' "$probe_output" > $CHECKER_ARTIFACTS/7/hostnetwork-metadata.output
  if [[ "$student_hostnetwork_valid" == "true" && "$host_network" == true && "$app_label" == frontend && "$task5_http_code" == 000 && ( "$task5_rc" == 7 || "$task5_rc" == 28 ) && -n "$probe_http_code" && "$probe_http_code" != 000 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "HINT: Save hostNetwork metadata output and an environment-specific task5/task7 comparison in /var/work/tests/artifacts/7; record actual curl exit and HTTP codes."
    result=1
  fi
  [ "$result" -eq 0 ]
}
