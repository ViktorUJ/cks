#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
NS="cks-102"
CHECKER_DIR="/var/work/tests/checker-artifacts"

record_result() {
  local passed="$1"
  echo '1' >> /var/work/tests/result/all
  if [[ "$passed" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  return "$passed"
}

# Живой probe: делает curl из указанного Pod и печатает "<curl_exit> <http_code>".
# Bats с `set -E` + ERR-trap заваливает тест на ненулевом exit code внутри command
# substitution, даже когда сам curl-exit ожидаем (transport-level deny) - поэтому
# реальный exit code захватывается через if/else, а не через "$?" после отдельной команды.
live_probe() {
  local pod="$1"; shift
  local code rc
  if code=$(kubectl --context "$CTX" exec -n "$NS" "$pod" -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$@" 2>/dev/null); then
    rc=0
  else
    rc=$?
  fi
  printf '%s %s\n' "$rc" "$code"
}

reachable() { # reachable <rc> <code> - CURL_EXIT=0 и реальный HTTP status (1xx-5xx)
  [[ "$1" == "0" && "$2" =~ ^[1-5][0-9][0-9]$ ]]
}

exact_code() { # exact_code <rc> <code> <expected>
  [[ "$1" == "0" && "$2" == "$3" ]]
}

transport_denied() { # transport_denied <rc> <code> - HTTPCODE=000, exit 7/28
  [[ "$2" == "000" && "$1" =~ ^(7|28)$ ]]
}

# Additive policy state: вместо неполной эмуляции Kubernetes LabelSelector semantics
# (In/NotIn/Exists/DoesNotExist) над произвольным selector, для этой изолированной лабы
# проверяем точный допустимый policy set по имени и запрещаем любые другие policy
# resources в namespace, способные расширить effective allow-set - как дополнительные
# CiliumNetworkPolicy, так и другие policy types, которые Cilium применяет одновременно
# (standard NetworkPolicy, CiliumClusterwideNetworkPolicy).
no_unexpected_policies() {
  local namespace="$1"
  shift
  local expected actual_cnp actual_np ccnp_count
  expected=$(printf '%s\n' "$@" | sort)
  actual_cnp=$(kubectl --context "$CTX" -n "$namespace" get ciliumnetworkpolicy -o json 2>/dev/null | \
    jq -r '.items[].metadata.name' | sort)
  actual_np=$(kubectl --context "$CTX" -n "$namespace" get networkpolicy.networking.k8s.io -o json 2>/dev/null | \
    jq -r '.items[].metadata.name' 2>/dev/null)
  ccnp_count=$(kubectl --context "$CTX" get ciliumclusterwidenetworkpolicy -o json 2>/dev/null | \
    jq -r '.items | length' 2>/dev/null)
  [[ -z "$ccnp_count" ]] && ccnp_count=0
  [[ "$actual_cnp" == "$expected" && -z "$actual_np" && "$ccnp_count" -eq 0 ]]
}

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
  mkdir -p "$CHECKER_DIR"
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
  mkdir -p "$CHECKER_DIR/2"

  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
  if [[ -z "$policy" || "$policy" == "null" ]]; then
    echo "HINT: CiliumNetworkPolicy 'backend-policy' not found in $NS."
    record_result 1
    return
  fi

  # Точный итоговый allow-set: app=backend selector, role=frontend source, TCP/80 без
  # endPort и без лишних портов. К этому моменту backend-policy уже может (и должна)
  # содержать L7 http rule из задания 3 - этот тест проверяет только L3/L4 shape, не
  # запрещая L7 rule.
  policy_ok=$(printf '%s' "$policy" | jq -r '
    (.spec.endpointSelector.matchLabels == {"app":"backend"})
    and ((.spec.ingress // []) | length == 1)
    and ((.spec.ingress[0].fromEndpoints // []) | length == 1)
    and (.spec.ingress[0].fromEndpoints[0].matchLabels == {"role":"frontend"})
    and ((.spec.ingress[0].toPorts // []) | length == 1)
    and ((.spec.ingress[0].toPorts[0].ports // []) | length == 1)
    and (.spec.ingress[0].toPorts[0].ports[0].port == "80")
    and (.spec.ingress[0].toPorts[0].ports[0].protocol == "TCP")
    and ((.spec.ingress[0].toPorts[0].ports[0].endPort // null) == null)
  ' 2>/dev/null)

  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  # Чекер сам доказывает причинность (before/after), без student-artifact: временно
  # снимает уже применённый backend-policy, убеждается, что backend реально достижим
  # для ОБОИХ identity (иначе deny ничего не доказывает - сеть могла быть сломана и без
  # policy), затем накатывает policy обратно и проверяет итоговое поведение.
  printf '%s' "$policy" | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' \
    > "$CHECKER_DIR/2/backend-policy.json"
  kubectl --context "$CTX" delete ciliumnetworkpolicy backend-policy -n "$NS" --wait=true >/dev/null 2>&1
  sleep 3

  read -r base_f_rc base_f_code <<<"$(live_probe frontend http://backend/)"
  read -r base_c_rc base_c_code <<<"$(live_probe client http://backend/)"

  kubectl --context "$CTX" apply -f "$CHECKER_DIR/2/backend-policy.json" >/dev/null 2>&1
  sleep 3

  read -r after_f_rc after_f_code <<<"$(live_probe frontend http://backend/)"
  read -r after_c_rc after_c_code <<<"$(live_probe client http://backend/)"

  printf 'baseline frontend: rc=%s code=%s\nbaseline client: rc=%s code=%s\nafter frontend: rc=%s code=%s\nafter client: rc=%s code=%s\n' \
    "$base_f_rc" "$base_f_code" "$base_c_rc" "$base_c_code" "$after_f_rc" "$after_f_code" "$after_c_rc" "$after_c_code" \
    > "$CHECKER_DIR/2/l3-l4-runtime.txt"

  baseline_ok=true
  reachable "$base_f_rc" "$base_f_code" || baseline_ok=false
  reachable "$base_c_rc" "$base_c_code" || baseline_ok=false

  after_ok=true
  exact_code "$after_f_rc" "$after_f_code" "200" || after_ok=false
  transport_denied "$after_c_rc" "$after_c_code" || after_ok=false

  if [[ "$policy_ok" == "true" && "$policies_ok" == "true" && "$baseline_ok" == "true" && "$after_ok" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: CiliumNetworkPolicy 'backend-policy' must select exactly endpointSelector {app: backend}, exactly one ingress rule with fromEndpoints {role: frontend}, and exactly one toPorts entry for TCP/80 with no endPort - no extra ports, no extra peers."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: only 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS - no other CiliumNetworkPolicy, standard NetworkPolicy, or cluster-wide CiliumClusterwideNetworkPolicy. Cilium policies are additive, so an extra policy may widen the effective allow-set."
    elif [[ "$baseline_ok" != "true" ]]; then
      echo "HINT: with backend-policy temporarily removed, both 'frontend' and 'client' must reach backend with a real HTTP status - if they can't, that's a connectivity problem unrelated to your policy, and the deny in task 2 doesn't prove anything (rc=$base_f_rc/$base_f_code frontend, rc=$base_c_rc/$base_c_code client)."
    else
      echo "HINT: after re-applying backend-policy, 'frontend' must get exactly HTTP 200 (got rc=$after_f_rc code=$after_f_code) and 'client' must get a transport-level deny, HTTPCODE=000 with exit 7/28 (got rc=$after_c_rc code=$after_c_code) - a real HTTP response (403/404/...) means the network path still exists and L3/L4 deny is not proven."
    fi
    cat "$CHECKER_DIR/2/l3-l4-runtime.txt"
    record_result 1
  fi
}

@test "3. Cilium L7 policy permits GET / and denies POST / with 403" {
  mkdir -p "$CHECKER_DIR/3"

  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
  if [[ -z "$policy" || "$policy" == "null" ]]; then
    echo "HINT: CiliumNetworkPolicy 'backend-policy' not found in $NS."
    record_result 1
    return
  fi

  # Точный итоговый allow-set для TCP/80: тот же selector/peer/port из задания 2, плюс
  # ровно один L7 http rule (GET /), без дублирующего L4-only правила на том же порту и без
  # дополнительных methods/paths.
  policy_ok=$(printf '%s' "$policy" | jq -r '
    (.spec.endpointSelector.matchLabels == {"app":"backend"})
    and ((.spec.ingress // []) | length == 1)
    and ((.spec.ingress[0].fromEndpoints // []) | length == 1)
    and (.spec.ingress[0].fromEndpoints[0].matchLabels == {"role":"frontend"})
    and ((.spec.ingress[0].toPorts // []) | length == 1)
    and ((.spec.ingress[0].toPorts[0].ports // []) | length == 1)
    and (.spec.ingress[0].toPorts[0].ports[0].port == "80")
    and (.spec.ingress[0].toPorts[0].ports[0].protocol == "TCP")
    and ((.spec.ingress[0].toPorts[0].ports[0].endPort // null) == null)
    and ((.spec.ingress[0].toPorts[0].rules.http // []) | length == 1)
    and (.spec.ingress[0].toPorts[0].rules.http[0].method == "GET")
    and (.spec.ingress[0].toPorts[0].rules.http[0].path == "/")
  ' 2>/dev/null)

  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  # Чекер сам доказывает переход L4->L7 (before/after), без student-artifact: строит
  # L4-only вариант ИЗ уже применённого объекта (просто снимает rules.http), временно
  # накатывает его и убеждается, что L4-only policy не смотрит внутрь HTTP - GET и POST
  # оба реально доходят до backend. Затем возвращает финальный L7-вариант и проверяет
  # итоговое поведение.
  printf '%s' "$policy" | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' \
    > "$CHECKER_DIR/3/backend-policy-l7.json"
  jq 'del(.spec.ingress[0].toPorts[0].rules)' "$CHECKER_DIR/3/backend-policy-l7.json" \
    > "$CHECKER_DIR/3/backend-policy-l4-only.json"

  kubectl --context "$CTX" apply -f "$CHECKER_DIR/3/backend-policy-l4-only.json" >/dev/null 2>&1
  sleep 3

  read -r base_get_rc base_get_code <<<"$(live_probe frontend http://backend/)"
  read -r base_post_rc base_post_code <<<"$(live_probe frontend -X POST http://backend/)"

  kubectl --context "$CTX" apply -f "$CHECKER_DIR/3/backend-policy-l7.json" >/dev/null 2>&1
  sleep 3

  read -r get_rc get_code <<<"$(live_probe frontend http://backend/)"
  read -r post_rc post_code <<<"$(live_probe frontend -X POST http://backend/)"
  read -r client_rc client_code <<<"$(live_probe client http://backend/)"

  printf 'baseline(L4-only) GET: rc=%s code=%s\nbaseline(L4-only) POST: rc=%s code=%s\nafter(L7) GET: rc=%s code=%s\nafter(L7) POST: rc=%s code=%s\nafter(L7) client: rc=%s code=%s\n' \
    "$base_get_rc" "$base_get_code" "$base_post_rc" "$base_post_code" "$get_rc" "$get_code" "$post_rc" "$post_code" "$client_rc" "$client_code" \
    > "$CHECKER_DIR/3/l7-http-runtime.txt"

  baseline_ok=true
  reachable "$base_get_rc" "$base_get_code" || baseline_ok=false
  reachable "$base_post_rc" "$base_post_code" || baseline_ok=false

  after_ok=true
  exact_code "$get_rc" "$get_code" "200" || after_ok=false
  exact_code "$post_rc" "$post_code" "403" || after_ok=false
  transport_denied "$client_rc" "$client_code" || after_ok=false

  if [[ "$policy_ok" == "true" && "$policies_ok" == "true" && "$baseline_ok" == "true" && "$after_ok" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: the final backend-policy for TCP/80 must contain exactly one toPorts entry with exactly one rules.http entry (method GET, path /) - no separate L4-only rule left next to it, no extra methods/paths, no extra ports/peers."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: only 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS - no other CiliumNetworkPolicy, standard NetworkPolicy, or cluster-wide CiliumClusterwideNetworkPolicy."
    elif [[ "$baseline_ok" != "true" ]]; then
      echo "HINT: with only the L4-only variant of your policy applied (same selector/port, no rules.http), both GET and POST must reach backend with a real HTTP status - L4-only policy does not inspect HTTP (rc=$base_get_rc/$base_get_code GET, rc=$base_post_rc/$base_post_code POST)."
    elif ! exact_code "$get_rc" "$get_code" "200"; then
      echo "HINT: after re-applying the L7 policy, GET / must return exactly 200 (got rc=$get_rc code=$get_code) - check the L7 rule's method/path match the actual request exactly."
    elif ! exact_code "$post_rc" "$post_code" "403"; then
      echo "HINT: after re-applying the L7 policy, POST / must return exactly 403 (got rc=$post_rc code=$post_code) - it should be denied by the L7 policy since only GET was allowed."
    else
      echo "HINT: 'client' must still receive a transport-level deny (HTTPCODE:000, exit 7/28) on this task too - the L3/L4 restriction from task 2 must remain in effect while you add the L7 rule (got rc=$client_rc code=$client_code)."
    fi
    cat "$CHECKER_DIR/3/l7-http-runtime.txt"
    record_result 1
  fi
}

@test "4. DNS-aware Cilium policy resolves allowed.cks102.test and permits only HTTPS" {
  mkdir -p "$CHECKER_DIR/4"

  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy frontend-fqdn -n "$NS" -o json 2>/dev/null)
  if [[ -z "$policy" || "$policy" == "null" ]]; then
    echo "HINT: CiliumNetworkPolicy 'frontend-fqdn' not found in $NS."
    record_result 1
    return
  fi

  policy_ok=$(printf '%s' "$policy" | jq -r '
    def dns_port53_ok:
      ([.toPorts[]?
        | select((.rules.dns // []) | any(.matchPattern == "*"))
        | .ports[]?] ) as $entries
      | ($entries | length) as $n
      | (($entries | map(select(.port != "53" or (.endPort // null) != null)) | length) == 0)
        and (
          ($n == 1 and ($entries[0].protocol == "ANY"))
          or
          ($n == 2 and (($entries | map(.protocol) | sort) == ["TCP","UDP"]))
        );

    def dns_rule:
      ((.toEndpoints // []) | length == 1)
      and (.toEndpoints[0].matchLabels | length == 2)
      and (.toEndpoints[0].matchLabels["k8s:io.kubernetes.pod.namespace"] == "kube-system")
      and (.toEndpoints[0].matchLabels["k8s:k8s-app"] == "kube-dns")
      and ((.toEndpoints[0].matchExpressions // []) | length == 0)
      and ((.toPorts // []) | length == 1)
      and dns_port53_ok
      and ((.toFQDNs // []) | length == 0)
      and ((.toCIDR // []) | length == 0)
      and ((.toCIDRSet // []) | length == 0)
      and ((.toEntities // []) | length == 0)
      and ((.toServices // []) | length == 0)
      and ((.toGroups // []) | length == 0)
      and ((.toNodes // []) | length == 0);

    def fqdn_rule:
      ((.toFQDNs // []) | length == 1)
      and (.toFQDNs[0].matchName == "allowed.cks102.test")
      and ((.toFQDNs[0].matchPattern // "") == "")
      and ((.toPorts // []) | length == 1)
      and ((.toPorts[0].ports // []) | length == 1)
      and (.toPorts[0].ports[0].port == "443")
      and (.toPorts[0].ports[0].protocol == "TCP")
      and ((.toPorts[0].ports[0].endPort // null) == null)
      and ((.toPorts[0].rules // {}) == {})
      and ((.toEndpoints // []) | length == 0)
      and ((.toCIDR // []) | length == 0)
      and ((.toCIDRSet // []) | length == 0)
      and ((.toEntities // []) | length == 0)
      and ((.toServices // []) | length == 0)
      and ((.toGroups // []) | length == 0)
      and ((.toNodes // []) | length == 0);

    # Обязательный внутренний поток frontend -> backend:80, сохранённый из заданий 2-3:
    # frontend-fqdn включает egress default-deny для frontend, поэтому без этого правила
    # уже разрешённый backend-доступ был бы заблокирован.
    def backend_rule:
      ((.toEndpoints // []) | length == 1)
      and (.toEndpoints[0].matchLabels == {"app":"backend"})
      and ((.toEndpoints[0].matchExpressions // []) | length == 0)
      and ((.toPorts // []) | length == 1)
      and ((.toPorts[0].ports // []) | length == 1)
      and (.toPorts[0].ports[0].port == "80")
      and (.toPorts[0].ports[0].protocol == "TCP")
      and ((.toPorts[0].ports[0].endPort // null) == null)
      and ((.toPorts[0].rules // {}) == {})
      and ((.toFQDNs // []) | length == 0)
      and ((.toCIDR // []) | length == 0)
      and ((.toCIDRSet // []) | length == 0)
      and ((.toEntities // []) | length == 0)
      and ((.toServices // []) | length == 0)
      and ((.toGroups // []) | length == 0)
      and ((.toNodes // []) | length == 0);

    (.spec.endpointSelector.matchLabels == {"role":"frontend"})
    and ((.spec.endpointSelector.matchExpressions // []) | length == 0)
    and ((.spec.egress // []) | length == 3)
    and ((.spec.egress // []) as $e
         | (any($e[]?; dns_rule))
           and (any($e[]?; backend_rule))
           and (any($e[]?; fqdn_rule))
           and (all($e[]?; dns_rule or backend_rule or fqdn_rule)))
  ' 2>/dev/null)

  frontend_labels=$(kubectl --context "$CTX" get pod frontend -n "$NS" -o json 2>/dev/null | jq -r '.metadata.labels.role')
  selector_matches_real_frontend=false
  [[ "$frontend_labels" == "frontend" ]] && selector_matches_real_frontend=true

  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  # Чекер сам доказывает before/after для DNS-aware egress, без student-artifact: временно
  # снимает уже применённый frontend-fqdn (egress откатывается к default-allow), проверяет
  # baseline на lab-owned fixture (allowed.cks102.test/blocked.cks102.test резолвятся в
  # 198.18.0.10/198.18.0.20 - синтетические IP вне Kubernetes address space, а не
  # ClusterIP: Cilium toFQDNs не применяет allow-правило к IP внутри кластера, поэтому
  # фикстура полностью под контролем этой лабы, но живёт в отдельном network namespace на
  # control-plane узле - в отличие от example.com/www.google.com здесь нет и не может быть
  # "inconclusive" ветки, фикстура обязана быть доступна всегда), затем накатывает policy
  # обратно и проверяет итоговое поведение + regression для backend из заданий 2-3.
  printf '%s' "$policy" | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' \
    > "$CHECKER_DIR/4/frontend-fqdn.json"
  kubectl --context "$CTX" delete ciliumnetworkpolicy frontend-fqdn -n "$NS" --wait=true >/dev/null 2>&1
  sleep 3

  base_dns_ok=false
  kubectl --context "$CTX" exec -n "$NS" frontend -- getent hosts allowed.cks102.test >/dev/null 2>&1 && base_dns_ok=true
  read -r base_https_rc base_https_code <<<"$(live_probe frontend --max-time 10 -k https://allowed.cks102.test/)"
  read -r base_http_rc base_http_code <<<"$(live_probe frontend http://allowed.cks102.test:80/)"
  read -r base_blocked_rc base_blocked_code <<<"$(live_probe frontend --max-time 10 -k https://blocked.cks102.test/)"

  if [[ "$base_dns_ok" != "true" ]] || ! reachable "$base_https_rc" "$base_https_code" \
      || ! reachable "$base_http_rc" "$base_http_code" || ! reachable "$base_blocked_rc" "$base_blocked_code"; then
    echo "HINT: lab-owned FQDN fixture (allowed.cks102.test/blocked.cks102.test) is not reachable even WITHOUT frontend-fqdn applied - this is an infrastructure problem (fixture network namespace/CoreDNS hosts entries from k8s-1/scripts/master.sh), not a policy problem. Baseline: dns_ok=$base_dns_ok https: rc=$base_https_rc code=$base_https_code http: rc=$base_http_rc code=$base_http_code blocked: rc=$base_blocked_rc code=$base_blocked_code" >&2
    kubectl --context "$CTX" apply -f "$CHECKER_DIR/4/frontend-fqdn.json" >/dev/null 2>&1
    record_result 1
    return
  fi

  kubectl --context "$CTX" apply -f "$CHECKER_DIR/4/frontend-fqdn.json" >/dev/null 2>&1
  sleep 5

  dns_after_ok=false
  kubectl --context "$CTX" exec -n "$NS" frontend -- getent hosts allowed.cks102.test >/dev/null 2>&1 && dns_after_ok=true
  read -r https_rc https_code <<<"$(live_probe frontend --max-time 10 -k https://allowed.cks102.test/)"
  read -r http_rc http_code <<<"$(live_probe frontend http://allowed.cks102.test:80/)"
  read -r blocked_rc blocked_code <<<"$(live_probe frontend --max-time 10 -k https://blocked.cks102.test/)"
  read -r backend_get_rc backend_get_code <<<"$(live_probe frontend http://backend/)"
  read -r backend_post_rc backend_post_code <<<"$(live_probe frontend -X POST http://backend/)"

  {
    printf 'baseline dns_ok=%s allowed_https: rc=%s code=%s\nbaseline allowed_http: rc=%s code=%s\nbaseline blocked_https: rc=%s code=%s\n' \
      "$base_dns_ok" "$base_https_rc" "$base_https_code" "$base_http_rc" "$base_http_code" "$base_blocked_rc" "$base_blocked_code"
    printf 'after dns_ok=%s allowed_https: rc=%s code=%s\nafter allowed_http: rc=%s code=%s\nafter blocked_https: rc=%s code=%s\n' \
      "$dns_after_ok" "$https_rc" "$https_code" "$http_rc" "$http_code" "$blocked_rc" "$blocked_code"
    printf 'regression GET: rc=%s code=%s\nregression POST: rc=%s code=%s\n' \
      "$backend_get_rc" "$backend_get_code" "$backend_post_rc" "$backend_post_code"
  } > "$CHECKER_DIR/4/fqdn-runtime.txt"

  # Lab-owned fixture: baseline reachability уже доказана выше и не может быть
  # inconclusive - все три runtime-результата ниже обязательны.
  https_result_ok=true
  reachable "$https_rc" "$https_code" || https_result_ok=false
  http_result_ok=true
  transport_denied "$http_rc" "$http_code" || http_result_ok=false
  google_result_ok=true
  transport_denied "$blocked_rc" "$blocked_code" || google_result_ok=false

  backend_regression_ok=true
  exact_code "$backend_get_rc" "$backend_get_code" "200" || backend_regression_ok=false
  exact_code "$backend_post_rc" "$backend_post_code" "403" || backend_regression_ok=false

  if [[ "$policy_ok" == "true" && "$selector_matches_real_frontend" == "true" && "$policies_ok" == "true" \
        && "$dns_after_ok" == "true" && "$https_result_ok" == "true" && "$http_result_ok" == "true" && "$google_result_ok" == "true" \
        && "$backend_regression_ok" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: frontend-fqdn must select exactly {role: frontend} (no matchExpressions) and contain exactly three egress rules: (1) DNS to kube-system/kube-dns with an exact port-53 rules.dns allow-set, (2) an internal rule to toEndpoints {app: backend} on exact TCP/80 (no endPort, no L7 rules), (3) toFQDNs matchName allowed.cks102.test with an exact TCP/443 toPorts and no extra rules/peers/ports."
    elif [[ "$selector_matches_real_frontend" != "true" ]]; then
      echo "HINT: frontend-fqdn's endpointSelector must actually match the real frontend Pod's labels."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: only 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS."
    elif [[ "$dns_after_ok" != "true" ]]; then
      echo "HINT: DNS resolution for allowed.cks102.test from frontend does not work after frontend-fqdn was re-applied. The DNS egress rule (toEndpoints kube-dns, rules.dns) must actually let DNS queries through."
    elif [[ "$https_result_ok" != "true" ]]; then
      echo "HINT: allowed.cks102.test:443 was reachable without any frontend-fqdn policy (rc=$base_https_rc code=$base_https_code) but is not reachable after re-applying it (rc=$https_rc code=$https_code) - it must remain allowed by toFQDNs matchName allowed.cks102.test on TCP/443."
    elif [[ "$http_result_ok" != "true" ]]; then
      echo "HINT: allowed.cks102.test:80 was reachable without policy (rc=$base_http_rc code=$base_http_code) but did not get a transport-level deny after re-applying frontend-fqdn (rc=$http_rc code=$http_code) - only TCP/443 should be allowed for allowed.cks102.test."
    elif [[ "$google_result_ok" != "true" ]]; then
      echo "HINT: blocked.cks102.test:443 was reachable without policy (rc=$base_blocked_rc code=$base_blocked_code) but did not get a transport-level deny after re-applying frontend-fqdn (rc=$blocked_rc code=$blocked_code) - toFQDNs must match only allowed.cks102.test, not blocked.cks102.test."
    else
      echo "HINT: frontend -> backend regressed after re-applying frontend-fqdn (GET: rc=$backend_get_rc code=$backend_get_code, expected 200; POST: rc=$backend_post_rc code=$backend_post_code, expected 403). frontend-fqdn adds egress default-deny for frontend - it must also contain an explicit internal rule allowing toEndpoints {app: backend} on TCP/80."
    fi
    cat "$CHECKER_DIR/4/fqdn-runtime.txt"
    record_result 1
  fi
}

@test "5. Hubble evidence correlates exact frontend-to-backend GET and POST test cases" {
  mkdir -p "$CHECKER_DIR/5"

  # Чекер сам генерирует трафик и сам ловит Hubble evidence - ровно так, как это
  # придётся делать на экзамене, без student-artifact.
  cilium hubble port-forward > "$CHECKER_DIR/5/port-forward.log" 2>&1 &
  local pf_pid=$!
  sleep 3

  local start
  start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  hubble observe --from-pod "$NS/frontend" --to-pod "$NS/backend" \
    --protocol http --since "$start" --output json --follow \
    > "$CHECKER_DIR/5/hubble-observe.json" 2>/dev/null &
  local obs_pid=$!
  sleep 2

  kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 http://backend/ -o /dev/null >/dev/null 2>&1 || true
  kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -X POST http://backend/ -o /dev/null >/dev/null 2>&1 || true
  sleep 5
  kill "$obs_pid" "$pf_pid" 2>/dev/null || true
  sleep 1

  local allowed denied
  allowed=$(jq -s --arg ns "$NS" '[.[] | (.flow // .) as $f | select(
    $f.source.namespace == $ns and $f.source.pod_name == "frontend" and
    $f.destination.namespace == $ns and $f.destination.pod_name == "backend" and
    $f.l7.http.method == "GET" and ($f.l7.http.url | endswith("/")) and
    $f.verdict == "FORWARDED"
  )] | length' "$CHECKER_DIR/5/hubble-observe.json" 2>/dev/null)
  [[ -z "$allowed" ]] && allowed=0
  denied=$(jq -s --arg ns "$NS" '[.[] | (.flow // .) as $f | select(
    $f.source.namespace == $ns and $f.source.pod_name == "frontend" and
    $f.destination.namespace == $ns and $f.destination.pod_name == "backend" and
    $f.l7.http.method == "POST" and ($f.l7.http.url | endswith("/")) and
    $f.verdict == "DROPPED"
  )] | length' "$CHECKER_DIR/5/hubble-observe.json" 2>/dev/null)
  [[ -z "$denied" ]] && denied=0

  if [[ "$allowed" -ge 1 && "$denied" -ge 1 ]]; then
    record_result 0
  else
    if [[ "$allowed" -lt 1 ]]; then
      echo "HINT: no FORWARDED flow found for frontend->backend GET / - your L7 policy must let GET through (see task 3)."
    else
      echo "HINT: no DROPPED flow found for frontend->backend POST / - your L7 policy must deny POST with a 403 (see task 3)."
    fi
    echo "exact Hubble correlation missing: allowed=$allowed denied=$denied"
    record_result 1
  fi
}

@test "6. Composite portal-policy: /public/* open to any endpoint, /private/* restricted to finance" {
  mkdir -p "$CHECKER_DIR/6"

  portal_pod=$(kubectl --context "$CTX" get pod portal -n production -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
  finance_pod=$(kubectl --context "$CTX" get pod finance-client -n finance -o jsonpath='{.metadata.name}' 2>/dev/null)
  external_pod=$(kubectl --context "$CTX" get pod client -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  svc_port=$(kubectl --context "$CTX" get svc portal -n production -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)

  if [[ "$portal_pod" != "portal" || -z "$finance_pod" || -z "$external_pod" || "$svc_port" != "80" ]]; then
    echo "HINT: task 6 fixtures are missing - need Pod 'portal' (label app=portal) + Service 'portal' port 80 in namespace 'production', Pod 'finance-client' in namespace 'finance', and the existing Pod 'client' in namespace '$NS' from task 1."
    echo "portal_pod=$portal_pod finance_pod=$finance_pod external_pod=$external_pod svc_port=$svc_port"
    record_result 1
    return
  fi

  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy portal-policy -n production -o json 2>/dev/null)
  if [[ -z "$policy" || "$policy" == "null" ]]; then
    echo "HINT: CiliumNetworkPolicy 'portal-policy' not found in namespace 'production'."
    record_result 1
    return
  fi

  # Точный итоговый allow-set: ровно два ingress-правила на TCP/80 - одно с
  # fromEndpoints:[{}] (любая identity) и rules.http path matching /public/, второе с
  # fromEndpoints по namespace finance и rules.http path matching /private/. Порядок
  # правил в массиве не имеет значения для Cilium, поэтому проверяем оба варианта.
  policy_ok=$(printf '%s' "$policy" | jq -r '
    def http_rule_ok($pathfrag):
      ((.toPorts // []) | length) == 1
      and ((.toPorts[0].ports // []) | length) == 1
      and (.toPorts[0].ports[0].port == "80")
      and (.toPorts[0].ports[0].protocol == "TCP")
      and ((.toPorts[0].ports[0].endPort // null) == null)
      and ((.toPorts[0].rules.http // []) | length) == 1
      and (.toPorts[0].rules.http[0].method == "GET")
      and (.toPorts[0].rules.http[0].path | test($pathfrag));
    # NOTE: fromEndpoints containing a bare empty selector looks like "match any
    # identity" but is NOT: Cilium implicitly scopes a fromEndpoints selector with no
    # explicit namespace label to the policy own namespace, even for an empty selector -
    # verified live, a policy using a literal empty selector here gives cross-namespace
    # clients a transport-level deny instead of the intended any-identity admit. The only
    # way to genuinely match any identity regardless of namespace is a matchExpressions
    # Exists check on the reserved namespace label (true for every Pod, whatever the
    # actual namespace value is).
    def any_rule:
      ((.fromEndpoints // []) | length == 1)
      and ((.fromEndpoints[0].matchLabels // {}) == {})
      and ((.fromEndpoints[0].matchExpressions // []) | length == 1)
      and (.fromEndpoints[0].matchExpressions[0].key == "k8s:io.kubernetes.pod.namespace")
      and (.fromEndpoints[0].matchExpressions[0].operator == "Exists");
    def finance_rule:
      ((.fromEndpoints // []) | length == 1)
      and (.fromEndpoints[0].matchLabels["k8s:io.kubernetes.pod.namespace"] == "finance")
      and ((.fromEndpoints[0].matchLabels | length) == 1)
      and ((.fromEndpoints[0].matchExpressions // []) | length == 0);
    (.spec.endpointSelector.matchLabels == {"app":"portal"})
    and ((.spec.ingress // []) | length == 2)
    and (any(.spec.ingress[]; any_rule and http_rule_ok("public")))
    and (any(.spec.ingress[]; finance_rule and http_rule_ok("private")))
  ' 2>/dev/null)

  policies_ok=false
  no_unexpected_policies "production" portal-policy && policies_ok=true

  # Чекер сам доказывает before/after: снимает portal-policy, проверяет baseline (оба
  # path со ОБОИХ namespace реально отдают 200 без policy - иначе deny в task 6 ничего
  # не доказывает), затем накатывает policy обратно.
  printf '%s' "$policy" | jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' \
    > "$CHECKER_DIR/6/portal-policy.json"
  kubectl --context "$CTX" delete ciliumnetworkpolicy portal-policy -n production --wait=true >/dev/null 2>&1
  sleep 3

  # live_probe assumes pods live in $NS; portal/finance-client live in other namespaces,
  # so call kubectl directly here instead.
  base_fin_pub_code=$(kubectl --context "$CTX" exec -n finance finance-client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/public/ 2>/dev/null)
  base_fin_priv_code=$(kubectl --context "$CTX" exec -n finance finance-client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/private/ 2>/dev/null)
  base_ext_pub_code=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/public/ 2>/dev/null)
  base_ext_priv_code=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/private/ 2>/dev/null)

  baseline_ok=true
  [[ "$base_fin_pub_code" =~ ^2 ]] || baseline_ok=false
  [[ "$base_fin_priv_code" =~ ^2 ]] || baseline_ok=false
  [[ "$base_ext_pub_code" =~ ^2 ]] || baseline_ok=false
  [[ "$base_ext_priv_code" =~ ^2 ]] || baseline_ok=false

  kubectl --context "$CTX" apply -f "$CHECKER_DIR/6/portal-policy.json" >/dev/null 2>&1
  sleep 3

  fin_pub_code=$(kubectl --context "$CTX" exec -n finance finance-client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/public/ 2>/dev/null)
  fin_priv_code=$(kubectl --context "$CTX" exec -n finance finance-client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/private/ 2>/dev/null)
  ext_pub_code=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/public/ 2>/dev/null)
  ext_priv_code=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://portal.production/private/ 2>/dev/null)

  {
    printf 'baseline finance public=%s private=%s\nbaseline external public=%s private=%s\n' \
      "$base_fin_pub_code" "$base_fin_priv_code" "$base_ext_pub_code" "$base_ext_priv_code"
    printf 'after finance public=%s private=%s\nafter external public=%s private=%s\n' \
      "$fin_pub_code" "$fin_priv_code" "$ext_pub_code" "$ext_priv_code"
  } > "$CHECKER_DIR/6/portal-runtime.txt"

  after_ok=true
  [[ "$fin_pub_code" == "200" ]] || after_ok=false
  [[ "$fin_priv_code" == "200" ]] || after_ok=false
  [[ "$ext_pub_code" == "200" ]] || after_ok=false
  [[ "$ext_priv_code" == "403" ]] || after_ok=false

  if [[ "$policy_ok" == "true" && "$policies_ok" == "true" && "$baseline_ok" == "true" && "$after_ok" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: 'portal-policy' must select {app: portal} and contain exactly two ingress rules on TCP/80: one with fromEndpoints:[{}] (matches any identity) allowing GET on a path matching /public/, and one with fromEndpoints matching namespace 'finance' allowing GET on a path matching /private/."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: only 'portal-policy' is expected to exist as a policy resource in namespace 'production'."
    elif [[ "$baseline_ok" != "true" ]]; then
      echo "HINT: with portal-policy temporarily removed, BOTH /public/ and /private/ must return a 2xx status from BOTH finance-client and the external client - if not, this is a connectivity/fixture problem unrelated to your policy, and task 6's deny proves nothing."
    elif [[ "$fin_pub_code" != "200" || "$fin_priv_code" != "200" ]]; then
      echo "HINT: finance-client must get 200 on BOTH /public/* and /private/* after the policy is applied - the fromEndpoints:[{}] rule already matches the finance identity too, so finance should also get /public/*."
    elif [[ "$ext_pub_code" != "200" ]]; then
      echo "HINT: the external client (namespace '$NS') must still get 200 on /public/* - that path must be open to any cluster endpoint."
    else
      echo "HINT: the external client (namespace '$NS') must get exactly 403 on /private/* (Envoy L7 deny), not a transport-level deny - the fromEndpoints:[{}] rule already admits the TCP connection for everyone, so /private/* denial happens at L7, not L4."
    fi
    cat "$CHECKER_DIR/6/portal-runtime.txt" 2>/dev/null
    record_result 1
  fi
}
