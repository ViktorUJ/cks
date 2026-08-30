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
    cat /var/work/tests/artifacts/3/l7-http.txt
    record_result 1
  fi
}

@test "4. DNS-aware Cilium policy allows example.com and blocks another external FQDN" {
  mkdir -p /var/work/tests/artifacts/4
  policy=$(kubectl --context "$CTX" get ciliumnetworkpolicy frontend-fqdn -n "$NS" -o json 2>/dev/null)
  fqdn_ok=$(printf '%s' "$policy" | jq -r '[.spec.egress[]?.toFQDNs[]?.matchName] | index("example.com") != null' 2>/dev/null)
  dns_ok=$(printf '%s' "$policy" | jq -r '[.spec.egress[]?.toEndpoints[]?.matchLabels["k8s:k8s-app"]] | index("kube-dns") != null' 2>/dev/null)
  allowed=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -k -sS --max-time 10 -o /dev/null -w '%{http_code}' https://example.com/ 2>&1)
  allowed_rc=$?
  blocked=$(kubectl --context "$CTX" exec -n "$NS" frontend -- curl -k -sS --max-time 5 -o /dev/null -w '%{http_code}' https://www.google.com/ 2>&1)
  blocked_rc=$?
  printf 'example.com: rc=%s status=%s\nwww.google.com: rc=%s status=%s\n' "$allowed_rc" "$allowed" "$blocked_rc" "$blocked" > /var/work/tests/artifacts/4/fqdn.txt

  if [[ "$fqdn_ok" == "true" && "$dns_ok" == "true" && "$allowed_rc" -eq 0 && "$allowed" =~ ^[23][0-9][0-9]$ ]] && [[ "$blocked_rc" -ne 0 || ! "$blocked" =~ ^[23][0-9][0-9]$ ]]; then
    record_result 0
  else
    cat /var/work/tests/artifacts/4/fqdn.txt
    record_result 1
  fi
}

@test "5. Hubble observe output for cks-102 is saved and non-empty" {
  artifact=/var/work/tests/artifacts/5/hubble-observe.json
  if [[ -s "$artifact" ]] && (grep -q '"flow"' "$artifact" || grep -q -- '->' "$artifact"); then
    record_result 0
  else
    echo "Hubble artifact is missing, empty, or does not contain a flow: $artifact"
    record_result 1
  fi
}
