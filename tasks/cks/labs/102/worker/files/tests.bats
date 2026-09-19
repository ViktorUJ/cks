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

# Извлекает CURL_EXIT и HTTPCODE из первой строки artifact-файла, содержащей label
# (например label="baseline frontend"), в формате "label: ... CURL_EXIT=<n> HTTPCODE=<code>".
# Печатает "<exit> <code>" через пробел, либо ничего, если строка/поля не найдены.
extract_artifact_probe() {
  local file="$1" label="$2" line
  line=$(grep -F "$label" "$file" 2>/dev/null | head -1)
  [[ -z "$line" ]] && return 1
  local exit_code http_code
  exit_code=$(sed -n 's/.*CURL_EXIT=\([0-9][0-9]*\).*/\1/p' <<<"$line")
  http_code=$(sed -n 's/.*HTTPCODE=\([0-9][0-9][0-9]\).*/\1/p' <<<"$line")
  [[ -z "$exit_code" || -z "$http_code" ]] && return 1
  printf '%s %s\n' "$exit_code" "$http_code"
}

# Проверяет, что artifact содержит label с CURL_EXIT=0 и реальным HTTP status (1xx-5xx).
artifact_probe_reachable() {
  local file="$1" label="$2" values rc code
  values=$(extract_artifact_probe "$file" "$label") || return 1
  read -r rc code <<<"$values"
  [[ "$rc" == "0" && "$code" =~ ^[1-5][0-9][0-9]$ ]]
}

# Проверяет, что artifact содержит label с exact expected HTTPCODE и CURL_EXIT=0.
artifact_probe_exact_code() {
  local file="$1" label="$2" expected_code="$3" values rc code
  values=$(extract_artifact_probe "$file" "$label") || return 1
  read -r rc code <<<"$values"
  [[ "$rc" == "0" && "$code" == "$expected_code" ]]
}

# Проверяет, что artifact содержит label с transport-level deny (HTTPCODE=000, exit 7/28).
artifact_probe_transport_denied() {
  local file="$1" label="$2" values rc code
  values=$(extract_artifact_probe "$file" "$label") || return 1
  read -r rc code <<<"$values"
  [[ "$code" == "000" && "$rc" =~ ^(7|28)$ ]]
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
  artifact=/var/work/tests/artifacts/2/l3-l4.txt

  # Checker не создаёт/не перезаписывает student artifact - это часть acceptance criteria.
  if [[ ! -s "$artifact" ]]; then
    echo "HINT: /var/work/tests/artifacts/2/l3-l4.txt is missing or empty. Follow the README workflow: record baseline (before backend-policy) and after-policy CURL_EXIT/HTTPCODE for both frontend and client into this file yourself."
    record_result 1
    return
  fi

  # Строго проверяем содержимое artifact по README acceptance criteria, а не только
  # то, что файл непустой - иначе произвольный текст мог бы пройти этот шаг.
  artifact_ok=true
  artifact_fail_reason=""
  if ! artifact_probe_reachable "$artifact" "baseline frontend"; then
    artifact_ok=false
    artifact_fail_reason="baseline frontend must show CURL_EXIT=0 with a real HTTP status (1xx-5xx)"
  elif ! artifact_probe_reachable "$artifact" "baseline client"; then
    artifact_ok=false
    artifact_fail_reason="baseline client must show CURL_EXIT=0 with a real HTTP status (1xx-5xx) - both identities must reach backend before any policy exists"
  elif ! artifact_probe_exact_code "$artifact" "after-policy frontend" "200"; then
    artifact_ok=false
    artifact_fail_reason="after-policy frontend must show CURL_EXIT=0 with HTTPCODE=200"
  elif ! artifact_probe_transport_denied "$artifact" "after-policy client"; then
    artifact_ok=false
    artifact_fail_reason="after-policy client must show HTTPCODE=000 with curl exit 7 or 28 (transport-level deny, not just 'not 200')"
  fi

  if [[ "$artifact_ok" != true ]]; then
    echo "HINT: /var/work/tests/artifacts/2/l3-l4.txt content does not match the required baseline/after-policy evidence: $artifact_fail_reason."
    cat "$artifact"
    record_result 1
    return
  fi

  # Точный итоговый allow-set: app=backend selector, role=frontend source, TCP/80 без
  # endPort и без лишних портов. check_result запускается один раз в конце всей лабы,
  # поэтому к этому моменту backend-policy уже может (и должна) содержать L7 http rule
  # из задания 3 - этот тест проверяет только L3/L4 shape, не запрещая L7 rule.
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
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

  # Additive policy state: check_result запускается один раз после выполнения всей
  # лабы, поэтому здесь оценивается финальное состояние кластера - к этому моменту
  # frontend-fqdn из задания 4 уже обязана существовать. Допустимый policy set:
  # backend-policy и frontend-fqdn. Любая другая CiliumNetworkPolicy, standard
  # NetworkPolicy или CiliumClusterwideNetworkPolicy может additively расширить
  # effective allow-set. Историческое состояние "только backend-policy без L7"
  # из задания 2 уже проверено через student artifact l3-l4.txt выше.
  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  # Собственные runtime-проверки checker-а пишутся в отдельный каталог, не в student artifact.
  mkdir -p "$CHECKER_DIR/2"
  # curl намеренно может вернуть ненулевой exit code для 'client' (transport-level deny
  # - это и есть ожидаемый правильный результат). В этой версии Bats `set +e` НЕ подавляет
  # её собственный ERR-trap (`trap ... err` + `set -E`) для команды внутри command
  # substitution - trap всё равно сработает и завалит тест, даже если сам shell формально
  # "не должен" падать на ненулевом exit code. Единственный надёжный способ - captur'ить
  # реальный exit code через ветку if/else, а не через `$?` после отдельной команды.
  if allowed=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/); then
    allowed_rc=0
  else
    allowed_rc=$?
  fi
  if blocked=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/); then
    blocked_rc=0
  else
    blocked_rc=$?
  fi
  printf 'frontend: rc=%s output=%s\nclient: rc=%s output=%s\n' "$allowed_rc" "$allowed" "$blocked_rc" "$blocked" > "$CHECKER_DIR/2/l3-l4-runtime.txt"

  # client deny должен быть именно transport-level (нет HTTP response), а не "просто не 200".
  blocked_is_transport_deny=false
  if [[ "$blocked_rc" =~ ^(7|28)$ && "$blocked" == "000" ]]; then
    blocked_is_transport_deny=true
  fi

  if [[ "$policy_ok" == "true" && "$policies_ok" == "true" && "$allowed_rc" -eq 0 && "$allowed" == "200" && "$blocked_is_transport_deny" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: CiliumNetworkPolicy 'backend-policy' must select exactly endpointSelector {app: backend}, exactly one ingress rule with fromEndpoints {role: frontend}, and exactly one toPorts entry for TCP/80 with no endPort - no extra ports, no extra peers."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: after completing the whole lab, exactly 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS - no other CiliumNetworkPolicy, standard NetworkPolicy, or cluster-wide CiliumClusterwideNetworkPolicy. Cilium policies are additive, so an extra policy may widen the effective allow-set."
    elif [[ "$allowed_rc" -ne 0 || "$allowed" != "200" ]]; then
      echo "HINT: 'frontend' could not reach backend on port 80 (rc=$allowed_rc status=$allowed) even though it should be allowed. Check the fromEndpoints selector actually matches the frontend Pod's real labels."
    else
      echo "HINT: 'client' (role: untrusted) must receive a transport-level deny (HTTPCODE:000 with curl exit 7 or 28), not just 'any non-200'. Got rc=$blocked_rc status=$blocked. A real HTTP response (403/404/...) means the network path still exists and L3/L4 deny is not proven. Check that fromEndpoints is scoped to role=frontend only."
    fi
    cat "$CHECKER_DIR/2/l3-l4-runtime.txt"
    echo "--- student artifact ---"
    cat "$artifact"
    record_result 1
  fi
}

@test "3. Cilium L7 policy permits GET / and denies POST / with 403" {
  artifact=/var/work/tests/artifacts/3/l7-http.txt

  if [[ ! -s "$artifact" ]]; then
    echo "HINT: /var/work/tests/artifacts/3/l7-http.txt is missing or empty. Record baseline (L4-only, before the L7 rule) and after-policy GET/POST CURL_EXIT/HTTPCODE into this file yourself."
    record_result 1
    return
  fi

  # Строго проверяем содержимое artifact: baseline GET/POST должны реально достигать
  # backend (L4-only ещё не смотрит внутрь HTTP), after-policy GET=200, POST=403.
  artifact_ok=true
  artifact_fail_reason=""
  if ! artifact_probe_reachable "$artifact" "baseline GET"; then
    artifact_ok=false
    artifact_fail_reason="baseline GET / must show CURL_EXIT=0 with a real HTTP status (1xx-5xx) while the L4-only policy from task 2 was still in effect"
  elif ! artifact_probe_reachable "$artifact" "baseline POST"; then
    artifact_ok=false
    artifact_fail_reason="baseline POST / must show CURL_EXIT=0 with a real HTTP status (1xx-5xx) - L4-only policy does not inspect HTTP, so POST must reach backend too"
  elif ! artifact_probe_exact_code "$artifact" "after-policy GET" "200"; then
    artifact_ok=false
    artifact_fail_reason="after-policy GET / must show CURL_EXIT=0 with HTTPCODE=200"
  elif ! artifact_probe_exact_code "$artifact" "after-policy POST" "403"; then
    artifact_ok=false
    artifact_fail_reason="after-policy POST / must show CURL_EXIT=0 with HTTPCODE=403 (L7 deny, not a connection failure)"
  fi

  if [[ "$artifact_ok" != true ]]; then
    echo "HINT: /var/work/tests/artifacts/3/l7-http.txt content does not match the required baseline/after-policy evidence: $artifact_fail_reason."
    cat "$artifact"
    record_result 1
    return
  fi

  # Точный итоговый allow-set для TCP/80: тот же selector/peer/port из задания 2, плюс
  # ровно один L7 http rule (GET /), без дублирующего L4-only правила на том же порту и без
  # дополнительных methods/paths.
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy backend-policy -n "$NS" -o json 2>/dev/null)
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

  # Additive policy state: check_result оценивает финальное состояние всей лабы -
  # frontend-fqdn из задания 4 уже обязана существовать к этому моменту.
  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  mkdir -p "$CHECKER_DIR/3"
  if get_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/); then
    get_rc=0
  else
    get_rc=$?
  fi
  if post_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/); then
    post_rc=0
  else
    post_rc=$?
  fi
  printf 'GET /: rc=%s status=%s\nPOST /: rc=%s status=%s\n' "$get_rc" "$get_code" "$post_rc" "$post_code" > "$CHECKER_DIR/3/l7-http-runtime.txt"

  # client (role: untrusted) не должен быть допущен и на этом этапе - иначе задание 2 регрессировало.
  if client_blocked=$(kubectl --context "$CTX" exec -n "$NS" client -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/); then
    client_blocked_rc=0
  else
    client_blocked_rc=$?
  fi
  client_still_denied=false
  if [[ "$client_blocked_rc" =~ ^(7|28)$ && "$client_blocked" == "000" ]]; then
    client_still_denied=true
  fi

  if [[ "$policy_ok" == "true" && "$policies_ok" == "true" && "$get_rc" -eq 0 && "$get_code" == "200" && "$post_rc" -eq 0 && "$post_code" == "403" && "$client_still_denied" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: The final backend-policy for TCP/80 must contain exactly one toPorts entry with exactly one rules.http entry (method GET, path /) - no separate L4-only rule left next to it, no extra methods/paths, no extra ports/peers."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: after completing the whole lab, exactly 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS - no other CiliumNetworkPolicy, standard NetworkPolicy, or cluster-wide CiliumClusterwideNetworkPolicy. Cilium policies are additive, so an extra policy may widen the effective allow-set."
    elif [[ "$get_rc" -ne 0 || "$get_code" != "200" ]]; then
      echo "HINT: GET / from frontend did not return 200 (rc=$get_rc status=$get_code). Check the L7 rule's method/path match the actual request exactly."
    elif [[ "$post_rc" -ne 0 || "$post_code" != "403" ]]; then
      echo "HINT: POST / did not return 403 (rc=$post_rc status=$post_code) - it should be denied by the L7 policy since only GET was allowed. A denied L7 request from an already-allowed L3/L4 endpoint results in HTTP 403, not a connection failure."
    else
      echo "HINT: 'client' must still receive a transport-level deny (HTTPCODE:000, exit 7/28) on this task too - the L3/L4 restriction from task 2 must remain in effect while you add the L7 rule."
    fi
    cat "$CHECKER_DIR/3/l7-http-runtime.txt"
    echo "--- student artifact ---"
    cat "$artifact"
    record_result 1
  fi
}

@test "4. DNS-aware Cilium policy resolves example.com and permits only HTTPS" {
  artifact=/var/work/tests/artifacts/4/fqdn.txt

  if [[ ! -s "$artifact" ]]; then
    echo "HINT: /var/work/tests/artifacts/4/fqdn.txt is missing or empty. Record a preflight (before frontend-fqdn exists) and after-policy result for example.com HTTPS/HTTP and www.google.com HTTPS yourself."
    record_result 1
    return
  fi

  # Строго проверяем содержимое artifact: preflight DNS + все три preflight probes должны
  # быть записаны. after-policy интерпретируется только относительно preflight - если
  # preflight endpoint уже был недоступен, его after-policy результат остаётся
  # inconclusive и не проверяется как allow/deny (это не best-effort external check,
  # а требование именно к наличию evidence, независимо от исхода).
  artifact_ok=true
  artifact_fail_reason=""
  if ! grep -q 'preflight dns: OK' "$artifact"; then
    artifact_ok=false
    artifact_fail_reason="artifact must record 'preflight dns: OK' - DNS resolution for example.com must actually work before frontend-fqdn is applied ('preflight dns: FAIL' is not a valid baseline for this task)"
  elif ! extract_artifact_probe "$artifact" "preflight example.com HTTPS" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'preflight example.com HTTPS' CURL_EXIT/HTTPCODE line"
  elif ! extract_artifact_probe "$artifact" "preflight example.com HTTP" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'preflight example.com HTTP' CURL_EXIT/HTTPCODE line"
  elif ! extract_artifact_probe "$artifact" "preflight www.google.com HTTPS" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'preflight www.google.com HTTPS' CURL_EXIT/HTTPCODE line"
  elif ! extract_artifact_probe "$artifact" "after-policy example.com HTTPS" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'after-policy example.com HTTPS' CURL_EXIT/HTTPCODE line"
  elif ! extract_artifact_probe "$artifact" "after-policy example.com HTTP" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'after-policy example.com HTTP' CURL_EXIT/HTTPCODE line"
  elif ! extract_artifact_probe "$artifact" "after-policy www.google.com HTTPS" >/dev/null; then
    artifact_ok=false
    artifact_fail_reason="artifact must record a parseable 'after-policy www.google.com HTTPS' CURL_EXIT/HTTPCODE line"
  fi

  if [[ "$artifact_ok" != true ]]; then
    echo "HINT: /var/work/tests/artifacts/4/fqdn.txt content does not match the required preflight/after-policy evidence: $artifact_fail_reason."
    cat "$artifact"
    record_result 1
    return
  fi

  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy frontend-fqdn -n "$NS" -o json 2>/dev/null)
  policy_ok=$(printf '%s' "$policy" | jq -r '
    # Семантический DNS allow-set: принимаем либо один port entry {port:53, protocol:ANY},
    # либо ровно два port entries {port:53, protocol:UDP} + {port:53, protocol:TCP}.
    # Запрещаем любые дополнительные ports/protocols/endPort.
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
      and (.toFQDNs[0].matchName == "example.com")
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

  # exact selector означает, что endpointSelector.matchLabels выбирает РЕАЛЬНОГО frontend
  # (role=frontend, без лишних условий, из-за которых policy перестала бы его выбирать).
  frontend_labels=$(kubectl --context "$CTX" get pod frontend -n "$NS" -o json 2>/dev/null | jq -r '.metadata.labels.role')
  selector_matches_real_frontend=false
  if [[ "$frontend_labels" == "frontend" ]]; then
    selector_matches_real_frontend=true
  fi

  # Additive policy state: точный допустимый policy set на этом этапе -
  # backend-policy (с L7 из задания 3) и frontend-fqdn.
  policies_ok=false
  no_unexpected_policies "$NS" backend-policy frontend-fqdn && policies_ok=true

  mkdir -p "$CHECKER_DIR/4"

  # Обязательный (blocking) runtime DNS-check после policy: DNS к example.com должен
  # реально разрешаться - без этого toFQDNs не может построить FQDN-to-IP mapping.
  dns_after_policy_ok=false
  if kubectl --context "$CTX" exec -n "$NS" frontend -- getent hosts example.com >/dev/null 2>&1; then
    dns_after_policy_ok=true
  fi

  # Runtime reachability для трёх контрольных endpoint, интерпретируется baseline-aware:
  # проверяем artifact-preflight студента (уже провалидирован выше как parseable), и
  # только если endpoint был доступен на preflight - требуем конкретный after-policy
  # результат. Если preflight endpoint был недоступен - оставляем inconclusive.
  read -r pre_https_rc pre_https_code <<<"$(extract_artifact_probe "$artifact" "preflight example.com HTTPS")"
  read -r pre_http_rc pre_http_code <<<"$(extract_artifact_probe "$artifact" "preflight example.com HTTP")"
  read -r pre_google_rc pre_google_code <<<"$(extract_artifact_probe "$artifact" "preflight www.google.com HTTPS")"

  if https_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/); then
    https_rc=0
  else
    https_rc=$?
  fi
  if http_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://example.com:80/); then
    http_rc=0
  else
    http_rc=$?
  fi
  if google_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/); then
    google_rc=0
  else
    google_rc=$?
  fi
  printf 'dns_after_policy=%s\nexample.com HTTPS: rc=%s status=%s\nexample.com HTTP: rc=%s status=%s\nwww.google.com HTTPS: rc=%s status=%s\n' \
    "$dns_after_policy_ok" "$https_rc" "$https_code" "$http_rc" "$http_code" "$google_rc" "$google_code" > "$CHECKER_DIR/4/fqdn-runtime.txt"

  https_result_ok=true
  if [[ "$pre_https_rc" == "0" && "$pre_https_code" =~ ^[1-5][0-9][0-9]$ ]]; then
    # preflight был reachable -> after-policy должен остаться reachable (allowed FQDN/port).
    [[ "$https_rc" -eq 0 && "$https_code" =~ ^[1-5][0-9][0-9]$ ]] || https_result_ok=false
  fi
  http_result_ok=true
  if [[ "$pre_http_rc" == "0" && "$pre_http_code" =~ ^[1-5][0-9][0-9]$ ]]; then
    # preflight был reachable -> after-policy должен получить transport deny (только 443 разрешён).
    [[ "$http_code" == "000" && "$http_rc" =~ ^(7|28)$ ]] || http_result_ok=false
  fi
  google_result_ok=true
  if [[ "$pre_google_rc" == "0" && "$pre_google_code" =~ ^[1-5][0-9][0-9]$ ]]; then
    # preflight был reachable -> after-policy должен получить transport deny (только example.com разрешён).
    [[ "$google_code" == "000" && "$google_rc" =~ ^(7|28)$ ]] || google_result_ok=false
  fi

  # Обязательный (blocking) regression-check: frontend-fqdn включает egress default-deny
  # для frontend, поэтому без явного правила к backend уже разрешённый в заданиях 2-3
  # поток frontend -> backend:80 был бы заблокирован. Задание 5 также зависит от этого
  # потока для Hubble evidence, поэтому регрессия здесь должна проваливать это задание.
  # Если policy студента ошибочно регрессировала внутренний доступ до transport-level
  # deny, curl вернёт ненулевой exit code - это ожидаемо детектируемый fail сценарий,
  # а не сбой самого checker-а, поэтому пробы также защищены от bats fail-on-nonzero-exit.
  if backend_get_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://backend/); then
    backend_get_rc=0
  else
    backend_get_rc=$?
  fi
  if backend_post_code=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -sS --max-time 5 -X POST -o /dev/null -w '%{http_code}' http://backend/); then
    backend_post_rc=0
  else
    backend_post_rc=$?
  fi
  printf 'regression frontend->backend GET: rc=%s status=%s\nregression frontend->backend POST: rc=%s status=%s\n' \
    "$backend_get_rc" "$backend_get_code" "$backend_post_rc" "$backend_post_code" >> "$CHECKER_DIR/4/fqdn-runtime.txt"
  backend_regression_ok=true
  [[ "$backend_get_rc" -eq 0 && "$backend_get_code" == "200" ]] || backend_regression_ok=false
  [[ "$backend_post_rc" -eq 0 && "$backend_post_code" == "403" ]] || backend_regression_ok=false

  if [[ "$policy_ok" == "true" && "$selector_matches_real_frontend" == "true" && "$policies_ok" == "true" \
        && "$dns_after_policy_ok" == "true" && "$https_result_ok" == "true" && "$http_result_ok" == "true" && "$google_result_ok" == "true" \
        && "$backend_regression_ok" == "true" ]]; then
    record_result 0
  else
    if [[ "$policy_ok" != "true" ]]; then
      echo "HINT: frontend-fqdn must select exactly {role: frontend} (no matchExpressions) and contain exactly three egress rules: (1) DNS to kube-system/kube-dns with an exact port-53 rules.dns allow-set (either one ANY/53 entry, or exactly UDP/53 + TCP/53, no endPort, no extra ports, no matchExpressions on the DNS peer) and no other peers, (2) an internal rule to toEndpoints {app: backend} on exact TCP/80 (no endPort, no L7 rules) to preserve the flow from tasks 2-3, (3) toFQDNs matchName example.com with an exact TCP/443 toPorts and no extra rules/peers/ports. Any additional port, peer, protocol, or FQDN makes the policy too broad."
    elif [[ "$selector_matches_real_frontend" != "true" ]]; then
      echo "HINT: frontend-fqdn's endpointSelector must actually match the real frontend Pod's labels - an extra label condition that the real Pod does not have means the policy silently applies to nothing."
    elif [[ "$policies_ok" != "true" ]]; then
      echo "HINT: only 'backend-policy' and 'frontend-fqdn' are expected to exist as policy resources in $NS at this stage - no other CiliumNetworkPolicy, standard NetworkPolicy, or cluster-wide CiliumClusterwideNetworkPolicy. Cilium policies are additive, so an extra policy may widen the effective allow-set."
    elif [[ "$dns_after_policy_ok" != "true" ]]; then
      echo "HINT: DNS resolution for example.com from frontend does not work after frontend-fqdn was applied. The DNS egress rule (toEndpoints kube-dns, rules.dns) must actually let DNS queries through, or Cilium cannot build the FQDN-to-IP mapping for toFQDNs."
    elif [[ "$https_result_ok" != "true" ]]; then
      echo "HINT: example.com:443 was reachable on preflight (rc=$pre_https_rc http=$pre_https_code) but is not reachable after policy (rc=$https_rc http=$https_code) - it must remain allowed by toFQDNs matchName example.com on TCP/443."
    elif [[ "$http_result_ok" != "true" ]]; then
      echo "HINT: example.com:80 was reachable on preflight (rc=$pre_http_rc http=$pre_http_code) but did not get a transport-level deny after policy (rc=$http_rc http=$http_code) - only TCP/443 should be allowed for example.com, port 80 must be denied."
    elif [[ "$google_result_ok" != "true" ]]; then
      echo "HINT: www.google.com was reachable on preflight (rc=$pre_google_rc http=$pre_google_code) but did not get a transport-level deny after policy (rc=$google_rc http=$google_code) - toFQDNs must match only example.com, not a broader pattern."
    else
      echo "HINT: frontend -> backend regressed after frontend-fqdn was applied (GET: rc=$backend_get_rc http=$backend_get_code, expected 200; POST: rc=$backend_post_rc http=$backend_post_code, expected 403). frontend-fqdn adds egress default-deny for frontend - it must also contain an explicit internal rule allowing toEndpoints {app: backend} on TCP/80, or the L3/L4/L7 policy from tasks 2-3 becomes unreachable and task 5's Hubble evidence becomes impossible to capture."
    fi
    cat "$CHECKER_DIR/4/fqdn-runtime.txt"
    echo "--- student artifact ---"
    cat "$artifact"
    echo "policy_ok=$policy_ok selector_matches_real_frontend=$selector_matches_real_frontend policies_ok=$policies_ok dns_after_policy_ok=$dns_after_policy_ok https_result_ok=$https_result_ok http_result_ok=$http_result_ok google_result_ok=$google_result_ok backend_regression_ok=$backend_regression_ok"
    record_result 1
  fi
}

@test "5. Hubble evidence correlates exact frontend-to-backend GET and POST test cases" {
  artifact=/var/work/tests/artifacts/5/hubble-observe.json
  window=/var/work/tests/artifacts/5/test-window.txt

  if [[ ! -s "$artifact" || ! -s "$window" ]]; then
    echo "HINT: hubble-observe.json or test-window.txt is missing or empty. Run 'hubble observe --output json' filtered on this namespace WHILE task 2/3 requests are happening, not after they finish, and record the start timestamp in test-window.txt."
    record_result 1
    return
  fi

  # test-window.txt должен содержать реальный RFC3339 start timestamp этого прогона -
  # без него старые flow из предыдущего запуска могли бы засчитаться как evidence.
  start_ts=$(sed -n 's/^start=\([0-9T:.Z-]*\).*/\1/p' "$window" | head -1)
  start_epoch=""
  if [[ -n "$start_ts" ]]; then
    start_epoch=$(date -u -d "$start_ts" +%s 2>/dev/null || true)
  fi

  if [[ -z "$start_epoch" ]]; then
    echo "HINT: test-window.txt must contain a line 'start=<RFC3339 UTC timestamp>' recorded right before you began the controlled capture, so old Hubble events from a previous run cannot be mistaken for this test's evidence."
    cat "$window"
    record_result 1
    return
  fi

  allowed=$(jq -s --argjson start_epoch "$start_epoch" '
    def norm_time: (. // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
    [.[] | . as $top | (.flow // .) as $f | select(
      $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
      $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
      $f.l7.http.method == "GET" and ($f.l7.http.url | endswith("/")) and
      $f.verdict == "FORWARDED" and
      (($top.time // $f.time) | norm_time) >= $start_epoch
    )] | length' "$artifact" 2>/dev/null || echo 0)
  denied=$(jq -s --argjson start_epoch "$start_epoch" '
    def norm_time: (. // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;
    [.[] | . as $top | (.flow // .) as $f | select(
      $f.source.namespace == "cks-102" and $f.source.pod_name == "frontend" and
      $f.destination.namespace == "cks-102" and $f.destination.pod_name == "backend" and
      $f.l7.http.method == "POST" and ($f.l7.http.url | endswith("/")) and
      $f.verdict == "DROPPED" and
      (($top.time // $f.time) | norm_time) >= $start_epoch
    )] | length' "$artifact" 2>/dev/null || echo 0)

  if [[ "$allowed" -ge 1 && "$denied" -ge 1 ]] \
    && grep -q 'source=cks-102/frontend destination=cks-102/backend' "$window" \
    && grep -q 'allowed=GET / denied=POST /' "$window"; then
    record_result 0
  else
    if [[ "$allowed" -lt 1 ]]; then
      echo "HINT: No FORWARDED flow found matching frontend->backend GET / at or after the recorded start=$start_ts. Capture Hubble output during (not before, and not from a previous run) the actual GET request."
    elif [[ "$denied" -lt 1 ]]; then
      echo "HINT: No DROPPED flow found matching frontend->backend POST / at or after the recorded start=$start_ts. Capture Hubble output during the actual POST request that gets the L7 403, in the current run."
    elif ! grep -q 'source=cks-102/frontend destination=cks-102/backend' "$window"; then
      echo "HINT: test-window.txt must contain a line starting with 'source=cks-102/frontend destination=cks-102/backend' - use this exact format to summarize the correlated flow."
    else
      echo "HINT: test-window.txt must also contain a line 'allowed=GET / denied=POST /' summarizing both outcomes in this exact format."
    fi
    echo "exact Hubble correlation missing: allowed=$allowed denied=$denied start=$start_ts artifact=$artifact window=$window"
    record_result 1
  fi
}
