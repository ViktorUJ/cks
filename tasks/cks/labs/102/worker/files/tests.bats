#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-102"

record_result() {
  local passed="$1"
  echo '1' >> /var/work/tests/result/all
  if [[ "$passed" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  return "$passed"
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Namespace cks-102, frontend/backend/client Pods and backend Service exist" {
  ns=$(kubectl --context "$CTX" get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  frontend=$(kubectl --context "$CTX" get pod frontend -n "$NS" -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  backend=$(kubectl --context "$CTX" get pod backend -n "$NS" -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
  client=$(kubectl --context "$CTX" get pod client -n "$NS" -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  service_port=$(kubectl --context "$CTX" get svc backend -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  if [[ "$ns" == "$NS" && "$frontend" == "frontend" && "$backend" == "backend" && "$client" == "untrusted" && "$service_port" == "80" ]]; then
    record_result 0
  else
    if [[ "$frontend" != "frontend" ]]; then
      echo "HINT: Pod 'frontend' must carry label 'role: frontend'."
    elif [[ "$backend" != "backend" ]]; then
      echo "HINT: Pod 'backend' must carry label 'app: backend'."
    elif [[ "$client" != "untrusted" ]]; then
      echo "HINT: Pod 'client' must carry label 'role: untrusted' - this distinguishes it from the trusted frontend identity for the CiliumNetworkPolicy in the next task."
    elif [[ "$service_port" != "80" ]]; then
      echo "HINT: Service 'backend' must expose port 80."
    fi
    echo "ns=$ns frontend.role=$frontend backend.app=$backend client.role=$client backend.port=$service_port"
    record_result 1
  fi
}

@test "2. Cilium L3/L4 policy permits frontend to backend:80 and blocks client" {
  mkdir -p /var/work/tests/artifacts/2
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
  policy_ok=$(printf '%s' "$policy" | jq -r '[.spec.endpointSelector.matchLabels.app == "backend", ([.spec.ingress[]?.fromEndpoints[]?.matchLabels.role] | index("frontend") != null), ([.spec.ingress[]?.toPorts[]?.ports[]? | select(.port == "80" and .protocol == "TCP")] | length > 0)] | all' 2>/dev/null)

  allowed=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/ 2>&1)
  allowed_rc=$?
  blocked=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/ 2>&1)
  blocked_rc=$?
  printf 'frontend: rc=%s output=%s\nclient: rc=%s output=%s\n' "$allowed_rc" "$allowed" "$blocked_rc" "$blocked" > /var/work/tests/artifacts/2/l3-l4.txt

  if [[ "$policy_ok" == "true" && "$allowed_rc" -eq 0 && "$allowed" == "200" ]] && [[ "$blocked_rc" -ne 0 || "$blocked" != "200" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: CiliumNetworkPolicy 'backend-policy' must select endpoint label 'app: backend', allow ingress fromEndpoints matching label 'role: frontend', and permit toPorts port 80/TCP. Check each of these three conditions separately."
    elif [[ "$allowed_rc" -ne 0 || "$allowed" != "200" ]]; then
      echo "HINT: 'frontend' could not reach backend on port 80 (rc=$allowed_rc status=$allowed) even though it should be allowed. Check the fromEndpoints selector actually matches the frontend Pod's real labels."
    elif [[ "$blocked_rc" -eq 0 && "$blocked" == "200" ]]; then
      echo "HINT: 'client' (role: untrusted) was able to reach backend on port 80 - the policy is too permissive. Check that fromEndpoints is scoped to role=frontend only, not matching all Pods in the namespace."
    fi
    cat /var/work/tests/artifacts/2/l3-l4.txt
    record_result 1
  fi
}

@test "3. Cilium L7 policy permits GET / and denies POST / with 403" {
  mkdir -p /var/work/tests/artifacts/3
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
  l7_ok=$(printf '%s' "$policy" | jq -r '[.spec.ingress[]?.toPorts[]?.rules.http[]? | select(.method == "GET" and .path == "/")] | length > 0' 2>/dev/null)
  get_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/ 2>&1)
  get_rc=$?
  post_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/ 2>&1)
  post_rc=$?
  printf 'GET /: rc=%s status=%s\nPOST /: rc=%s status=%s\n' "$get_rc" "$get_code" "$post_rc" "$post_code" > /var/work/tests/artifacts/3/l7-http.txt

  if [[ "$l7_ok" == "true" && "$get_rc" -eq 0 && "$get_code" == "200" && "$post_rc" -eq 0 && "$post_code" == "403" ]]; then
    record_result 0
  else
    if [[ "$l7_ok" != "true" ]]; then
      echo "HINT: The policy's L7 HTTP rule must specify method 'GET' and path '/' exactly - a missing or wrong toPorts.rules.http entry means Cilium is not enforcing L7 at all."
    elif [[ "$get_rc" -ne 0 || "$get_code" != "200" ]]; then
      echo "HINT: GET / from frontend did not return 200 (rc=$get_rc status=$get_code). Check the L7 rule's method/path match the actual request exactly - Cilium L7 policy is stricter than L3/L4 and denies anything not explicitly allowed."
    elif [[ "$post_rc" -ne 0 || "$post_code" != "403" ]]; then
      echo "HINT: POST / did not return 403 (rc=$post_rc status=$post_code) - it should be denied by the L7 policy since only GET was allowed. A denied L7 request from an already-allowed L3/L4 endpoint results in HTTP 403, not a connection failure."
    fi
    cat /var/work/tests/artifacts/3/l7-http.txt
    record_result 1
  fi
}

@test "4. DNS-aware Cilium policy resolves example.com and permits only HTTPS" {
  mkdir -p /var/work/tests/artifacts/4
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy frontend-fqdn -n "$NS" -o json 2>/dev/null)
  policy_ok=$(printf '%s' "$policy" | jq -r '
    def dns_port53:
      ([.toPorts[]?
        | select((.rules.dns // []) | any(.matchPattern == "*"))
        | .ports[]?
        | select(.port == "53")
        | .protocol] as $p
       | (($p | index("ANY")) != null)
         or ((($p | index("UDP")) != null) and (($p | index("TCP")) != null)));

    def dns_rule:
      ((.toEndpoints // []) | length == 1)
      and (.toEndpoints[0].matchLabels["k8s:io.kubernetes.pod.namespace"] == "kube-system")
      and (.toEndpoints[0].matchLabels["k8s:k8s-app"] == "kube-dns")
      and dns_port53
      and ((.toFQDNs // []) | length == 0)
      and ((.toCIDR // []) | length == 0)
      and ((.toCIDRSet // []) | length == 0)
      and ((.toEntities // []) | length == 0)
      and ((.toServices // []) | length == 0)
      and ((.toGroups // []) | length == 0)
      and ((.toNodes // []) | length == 0);

    def fqdn_rule:
      ((.toFQDNs // []) | length == 1)
      and (.toFQDNs[0].matchName == "example.com")
      and ((.toFQDNs[0].matchPattern // "") == "")
      and ((.toPorts // []) | length == 1)
      and ((.toPorts[0].ports // []) | length == 1)
      and (.toPorts[0].ports[0].port == "443")
      and (.toPorts[0].ports[0].protocol == "TCP")
      and ((.toEndpoints // []) | length == 0)
      and ((.toCIDR // []) | length == 0)
      and ((.toCIDRSet // []) | length == 0)
      and ((.toEntities // []) | length == 0)
      and ((.toServices // []) | length == 0)
      and ((.toGroups // []) | length == 0)
      and ((.toNodes // []) | length == 0);

    (.spec.endpointSelector.matchLabels.role == "frontend")
    and ((.spec.egress // []) as $e
         | (any($e[]?; dns_rule))
           and (any($e[]?; fqdn_rule))
           and (all($e[]?; dns_rule or fqdn_rule)))
  ' 2>/dev/null)

  # Сетевая проверка через example.com/www.google.com - НЕ часть grading criteria.
  # IANA прямо указывает, что HTTP-сервис example-доменов предоставляется best-effort
  # и не предназначен как testing endpoint для software; доступность внешнего сайта
  # зависит от Internet egress тестовой среды, а не от корректности policy студента.
  # Результат сохраняется только как diagnostic evidence, не как условие PASS/FAIL.
  allowed=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/ 2>&1)
  allowed_rc=$?
  same_fqdn_http=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://example.com:80/ 2>&1)
  same_fqdn_http_rc=$?
  blocked=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/ 2>&1)
  blocked_rc=$?
  printf 'example.com HTTPS: rc=%s status=%s\nexample.com HTTP: rc=%s status=%s\nwww.google.com HTTPS: rc=%s status=%s\n' "$allowed_rc" "$allowed" "$same_fqdn_http_rc" "$same_fqdn_http" "$blocked_rc" "$blocked" > /var/work/tests/artifacts/4/fqdn.txt
  if [[ "$allowed_rc" -ne 0 || ! "$allowed" =~ ^[23][0-9][0-9]$ ]]; then
    echo "WARNING (non-blocking): HTTPS to example.com did not succeed (rc=$allowed_rc status=$allowed). This does not fail the task by itself - example.com availability is best-effort and outside student control; see /var/work/tests/artifacts/4/fqdn.txt."
  fi

  if [[ "$policy_ok" == "true" ]]; then
    record_result 0
  else
    echo "HINT: frontend-fqdn must select role=frontend and contain only the DNS rule to kube-system/kube-dns:53 with rules.dns plus the exact example.com:443/TCP FQDN rule; broad extra egress (toEntities, toCIDR, extra toFQDNs/toPorts, etc.) is not allowed."
    cat /var/work/tests/artifacts/4/fqdn.txt
    echo "policy_ok=$policy_ok"
    record_result 1
  fi
}

@test "5. Hubble evidence correlates exact frontend-to-backend GET and POST test cases" {
  artifact=/var/work/tests/artifacts/5/hubble-observe.json
  window=/var/work/tests/artifacts/5/test-window.txt
  allowed=$(jq -s '[.[] | (.flow // .) as $f | select(
    $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
    $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
    $f.l7.http.method == "GET" and ($f.l7.http.url | endswith("/")) and
    ($f.l7.http.url | contains("backend")) and $f.verdict == "FORWARDED"
  )] | length' "$artifact" 2>/dev/null || echo 0)
  denied=$(jq -s '[.[] | (.flow // .) as $f | select(
    $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
    $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
    $f.l7.http.method == "POST" and ($f.l7.http.url | endswith("/")) and
    ($f.l7.http.url | contains("backend")) and $f.verdict == "DROPPED"
  )] | length' "$artifact" 2>/dev/null || echo 0)
  if [[ -s "$artifact" && -s "$window" && "$allowed" -ge 1 && "$denied" -ge 1 ]] \
    && grep -q 'source=cks-102/frontend destination=cks-102/backend' "$window" \
    && grep -q 'allowed=GET / denied=POST /' "$window"; then
    record_result 0
  else
    if ! [[ -s "$artifact" ]]; then
      echo "HINT: hubble-observe.json is missing or empty. Run 'hubble observe -o jsonpath'/'--output json' filtered on this namespace WHILE task 2/3 requests are happening, not after they finish."
    elif [[ "$allowed" -lt 1 ]]; then
      echo "HINT: No FORWARDED flow found matching frontend->backend GET /. Capture Hubble output during (not before) the actual GET request from task 3."
    elif [[ "$denied" -lt 1 ]]; then
      echo "HINT: No DROPPED flow found matching frontend->backend POST /. Capture Hubble output during the actual POST request that gets the L7 403."
    elif ! [[ -s "$window" ]] || ! grep -q 'source=cks-102/frontend destination=cks-102/backend' "$window"; then
      echo "HINT: test-window.txt must contain a line starting with 'source=cks-102/frontend destination=cks-102/backend' - use this exact format to summarize the correlated flow."
    else
      echo "HINT: test-window.txt must also contain a line 'allowed=GET / denied=POST /' summarizing both outcomes in this exact format."
    fi
    echo "exact Hubble correlation missing: allowed=$allowed denied=$denied artifact=$artifact window=$window"
    record_result 1
  fi
}
