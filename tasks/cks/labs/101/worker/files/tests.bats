#!/usr/bin/env bats

export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-101"

client_run() {
  local name=$1
  local label=$2
  local command=$3
  kubectl --context "$CTX" run "$name" -n "$NS" --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels="app=$label" --command -- sh -c "$command"
}

@test "0 Init" {
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
    .items[]
    | select(.spec.podSelector == {})
    | select((.spec.policyTypes | sort) == ["Egress", "Ingress"])
    | select((.spec.ingress // []) | length == 0)
    | select((.spec.egress // []) | length == 0)
    | .metadata.name' | head -n1)

  if [[ -n "$policy" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: No NetworkPolicy matches an empty podSelector ({}) with policyTypes [Ingress, Egress] and empty ingress/egress rules. Check that podSelector is exactly {} (not a specific app label), and that both ingress and egress arrays are present but empty."
    echo "No default-deny ingress+egress policy found in $NS"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "3. frontend identity reaches backend:8080; foreign identity is blocked" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p /var/work/tests/artifacts/3

  backend_ip=$(kubectl --context "$CTX" get service backend -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ -z "$backend_ip" || "$backend_ip" == "None" ]]; then
    echo "backend ClusterIP is unavailable" > /var/work/tests/artifacts/3/connectivity.txt
    [ 1 -eq 0 ]
  fi

  run client_run policy-frontend frontend "curl -fsS --max-time 5 http://$backend_ip:8080/"
  frontend_status=$status
  frontend_output=$output
  run client_run policy-foreign foreign "curl -fsS --max-time 5 http://$backend_ip:8080/"
  foreign_status=$status
  foreign_output=$output

  {
    echo "frontend exit=$frontend_status"
    echo "$frontend_output"
    echo "foreign exit=$foreign_status"
    echo "$foreign_output"
  } > /var/work/tests/artifacts/3/connectivity.txt

  if [[ "$frontend_status" -eq 0 && "$foreign_status" -ne 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$frontend_status" -ne 0 ]]; then
      echo "HINT: The 'frontend' identity could not reach backend:8080 (exit=$frontend_status). Check your allow-rule's podSelector/namespaceSelector actually matches label 'app: frontend', and that it permits port 8080."
    elif [[ "$foreign_status" -eq 0 ]]; then
      echo "HINT: A Pod with an unrelated identity ('foreign') COULD reach backend:8080 - your NetworkPolicy is too permissive. Check for an overly broad selector (e.g. missing podSelector, or a namespaceSelector matching more than intended)."
    fi
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "4. frontend identity can resolve DNS through kube-dns on port 53" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p /var/work/tests/artifacts/4

  run kubectl --context "$CTX" run policy-dns -n "$NS" --rm -i --restart=Never \
    --image=busybox:1.36.1 --labels=app=frontend --command -- \
    nslookup kubernetes.default.svc.cluster.local
  dns_status=$status
  printf '%s\n' "$output" > /var/work/tests/artifacts/4/dns.txt

  if [[ "$dns_status" -eq 0 ]] && grep -q "Name:" /var/work/tests/artifacts/4/dns.txt; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "HINT: DNS resolution failed for a Pod labeled 'app: frontend'. Your default-deny egress policy must still allow UDP/TCP port 53 to kube-dns - check for an explicit egress rule permitting DNS, usually via a namespaceSelector matching kube-system plus port 53."
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "5. frontend identity cannot reach metadata 169.254.169.254" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p /var/work/tests/artifacts/5

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
  } > /var/work/tests/artifacts/5/metadata.output
  printf '%s\n' "${metadata_rc:-missing}" > /var/work/tests/artifacts/5/metadata.exit-code

  # Negative control for the original false positive: the unauthenticated API request is
  # expected to return HTTP 401/403. Its response must never be classified as a
  # NetworkPolicy deny because a real HTTP response proves network reachability.
  run kubectl --context "$CTX" run policy-http-control -n default --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --command -- sh -c \
    "curl -ksS -o /dev/null -w 'HTTPCODE:%{http_code}\\n' --max-time 5 https://kubernetes.default.svc/"
  control_output=$output
  control_code=$(printf '%s\n' "$control_output" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -n1)
  printf 'level=http outcome=response status=%s\n' "${control_code:-missing}" \
    > /var/work/tests/artifacts/5/http-false-positive-control.txt

  if [[ "$http_code" == "000" && ( "$metadata_rc" == "7" || "$metadata_rc" == "28" ) ]] \
    && [[ "$control_code" == "401" || "$control_code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$control_code" != "401" && "$control_code" != "403" ]]; then
      echo "HINT: The negative HTTP control request itself did not return 401/403 (got '$control_code') - this test cannot trust its own network-deny classification until the control proves the cluster network path works at all. Check general cluster connectivity first."
    elif [[ "$http_code" != "000" ]]; then
      echo "HINT: Request to 169.254.169.254 got an actual HTTP response (code=$http_code) instead of being network-blocked. Your egress policy is not blocking metadata access - check that the deny is not accidentally bypassed by an overly broad allow rule (e.g. 0.0.0.0/0 without ipBlock.except)."
    else
      echo "HINT: curl exit code was '$metadata_rc', not the expected connection-refused/timeout (7 or 28). Check /var/work/tests/artifacts/5/metadata.output for the raw curl behavior."
    fi
    echo "metadata: curl_exit=${metadata_rc:-missing} http_code=${http_code:-missing} ($outcome); HTTP negative-control=${control_code:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "6. AND-trap ingress policy and ipBlock except are correctly scoped" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p /var/work/tests/artifacts/6

  policy=$(kubectl --context "$CTX" get networkpolicy allow-backend-ingress-from-legacy -n "$NS" -o json 2>/dev/null)
  and_scoped=$(jq -r '
    [.spec.ingress[]?.from[]? | select(has("namespaceSelector") and has("podSelector"))] | length > 0
  ' <<<"$policy" 2>/dev/null)

  egress_policy=$(kubectl --context "$CTX" get networkpolicy allow-legacy-egress -n cks-101-legacy -o json 2>/dev/null)
  except_scoped=$(jq -r '
    [.spec.egress[]?.to[]? | select(.ipBlock.cidr == "0.0.0.0/0") | select((.ipBlock.except // []) | index("169.254.169.254/32") != null)] | length > 0
  ' <<<"$egress_policy" 2>/dev/null)

  backend_ip=$(kubectl --context "$CTX" get service backend -n "$NS" -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

  run kubectl --context "$CTX" run policy-legacy-allowed -n cks-101-legacy --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c \
    "curl -fsS --max-time 5 http://$backend_ip:8080/"
  legacy_in_ns_status=$status

  run kubectl --context "$CTX" run policy-legacy-foreign -n default --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c \
    "curl -fsS --max-time 5 http://$backend_ip:8080/"
  legacy_foreign_status=$status

  run kubectl --context "$CTX" run policy-legacy-external -n cks-101-legacy --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c \
    "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --max-time 5 https://1.1.1.1/ || true"
  legacy_external_output=$output

  run kubectl --context "$CTX" run policy-legacy-metadata -n cks-101-legacy --rm -i --restart=Never \
    --image=curlimages/curl:8.11.1 --labels=app=legacy-client --command -- sh -c \
    "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1 || true"
  legacy_metadata_output=$output

  {
    echo "legacy_in_namespace_status=$legacy_in_ns_status"
    echo "legacy_foreign_namespace_status=$legacy_foreign_status"
    echo "legacy_external=$legacy_external_output"
    echo "legacy_metadata=$legacy_metadata_output"
  } > /var/work/tests/artifacts/6/and-trap.txt

  if [[ "$and_scoped" == "true" && "$except_scoped" == "true" \
    && "$legacy_in_ns_status" -eq 0 && "$legacy_foreign_status" -ne 0 \
    && "$legacy_external_output" != *"HTTPCODE:000"* \
    && "$legacy_metadata_output" == *"HTTPCODE:000"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$and_scoped" != "true" ]]; then
      echo "HINT: NetworkPolicy 'allow-backend-ingress-from-legacy' must combine namespaceSelector AND podSelector inside the SAME 'from' entry - two separate 'from' list items are combined with OR, not AND, which is a common trap."
    elif [[ "$except_scoped" != "true" ]]; then
      echo "HINT: NetworkPolicy 'allow-legacy-egress' in cks-101-legacy must allow ipBlock 0.0.0.0/0 with 'except: [\"169.254.169.254/32\"]' - the metadata address must be explicitly excluded from the broad CIDR allow."
    elif [[ "$legacy_in_ns_status" -ne 0 ]]; then
      echo "HINT: legacy-client Pod inside cks-101-legacy could not reach backend - check that the AND-scoped rule matches this namespace's actual labels/podSelector."
    elif [[ "$legacy_foreign_status" -eq 0 ]]; then
      echo "HINT: legacy-client identity from an unrelated namespace (default) could still reach backend - the AND-trap rule is too permissive and is matching on namespaceSelector OR podSelector instead of AND."
    elif [[ "$legacy_external_output" == *"HTTPCODE:000"* ]]; then
      echo "HINT: The legacy Pod cannot reach an external address (1.1.1.1) at all - check the 0.0.0.0/0 egress rule is actually present, not just the except clause."
    elif [[ "$legacy_metadata_output" != *"HTTPCODE:000"* ]]; then
      echo "HINT: The legacy Pod CAN still reach 169.254.169.254 despite the except clause - check the CIDR notation '169.254.169.254/32' is exact (no typo, correct prefix length)."
    fi
    echo "and_scoped=$and_scoped except_scoped=$except_scoped in_ns=$legacy_in_ns_status foreign=$legacy_foreign_status external=$legacy_external_output metadata=$legacy_metadata_output"
    result=1
  fi
  [ "$result" -eq 0 ]
}

@test "7. hostNetwork Pod networking is observed as implementation-dependent for this Calico lab" {
  echo '1' >> /var/work/tests/result/all
  mkdir -p /var/work/tests/artifacts/7

  pod=$(kubectl --context "$CTX" get pod hostnetwork-probe -n "$NS" -o json 2>/dev/null)
  host_network=$(jq -r '.spec.hostNetwork == true' <<<"$pod" 2>/dev/null)
  app_label=$(jq -r '.metadata.labels.app // ""' <<<"$pod" 2>/dev/null)

  run kubectl --context "$CTX" exec -n "$NS" hostnetwork-probe --context "$CTX" -- \
    sh -c "curl -sS -o /dev/null -w 'HTTPCODE:%{http_code}' --connect-timeout 2 --max-time 3 http://169.254.169.254/ 2>&1 || true"
  probe_output=$output
  probe_http_code=$(printf '%s\n' "$probe_output" | sed -n 's/.*HTTPCODE:\([0-9][0-9][0-9]\).*/\1/p' | tail -n1)

  {
    printf '%s\n' "$probe_output"
    echo "task5_result=network-deny (http_code=000)"
    echo "task7_result=observed HTTP response for hostNetwork Pod in this Calico lab (http_code=${probe_http_code:-unknown}); environment-specific, not a universal NetworkPolicy guarantee"
  } > /var/work/tests/artifacts/7/comparison.txt
  printf '%s\n' "$probe_output" > /var/work/tests/artifacts/7/hostnetwork-metadata.output

  if [[ "$host_network" == "true" && "$app_label" == "frontend" && -n "$probe_http_code" && "$probe_http_code" != "000" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    if [[ "$host_network" != "true" ]]; then
      echo "HINT: Pod 'hostnetwork-probe' must have spec.hostNetwork: true - this task specifically observes how NetworkPolicy interacts with host networking."
    elif [[ "$app_label" != "frontend" ]]; then
      echo "HINT: Pod 'hostnetwork-probe' must carry label 'app: frontend' so it is covered by the same NetworkPolicy selectors as the rest of this task."
    elif [[ -z "$probe_http_code" || "$probe_http_code" == "000" ]]; then
      echo "HINT: Expected an actual HTTP response code from the metadata probe (proving hostNetwork bypasses the CNI-enforced NetworkPolicy in this environment), but got no response. Check the Pod is actually Running with hostNetwork: true applied."
    fi
    echo "host_network=$host_network app_label=$app_label probe_http_code=${probe_http_code:-missing} output=$probe_output"
    result=1
  fi
  [ "$result" -eq 0 ]
}
