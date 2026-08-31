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

  if [[ "$namespace" == "$NS" ]] && [[ "$frontend_image" == *viktoruj/ping_pong* ]] && \
     [[ "$backend_image" == *viktoruj/ping_pong* ]] && [[ "$frontend_label" == "frontend" ]] && \
     [[ "$backend_label" == "backend" ]] && [[ "$endpoints" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
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
    echo "metadata: curl_exit=${metadata_rc:-missing} http_code=${http_code:-missing} ($outcome); HTTP negative-control=${control_code:-missing}"
    result=1
  fi
  [ "$result" -eq 0 ]
}
