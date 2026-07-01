#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 ztunnel (ambient L4 data plane) is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get daemonset ztunnel -n istio-system -o jsonpath='{.status.numberReady}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "1.2 Namespace default is enrolled into ambient" {
  echo '1' >> /var/work/tests/result/all
  mode=$(kubectl get ns default -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
  if [[ "$mode" == "ambient" ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else echo "dataplane-mode='$mode'"; result=1; fi
  [ "$result" == "0" ]
}

@test "1.3 App pods have NO sidecar (ambient)" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default -l 'app in (ping-pong,curl-client)' --no-headers 2>/dev/null | wc -l)
  no_sidecar=$(kubectl get pods -n default -l 'app in (ping-pong,curl-client)' -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy") | not) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$no_sidecar" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "total=$total, without sidecar=$no_sidecar (ambient pods must have no istio-proxy)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Waypoint proxy is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy waypoint -n default -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "3.1 L7 AuthorizationPolicy allows only GET" {
  echo '1' >> /var/work/tests/result/all
  ap=$(kubectl get authorizationpolicy -n default -o json | jq -r '
    .items[]
    | select((.spec.action // "ALLOW") == "ALLOW")
    | select([ .spec.rules[]?.to[]?.operation.methods[]? ] | index("GET"))
    | .metadata.name' | wc -l)
  if [[ "$ap" -gt 0 ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "4.1 GET request is allowed (200)" {
  echo '1' >> /var/work/tests/result/all
  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 12 http://ping-pong:8080/ 2>/dev/null || true)
  if [[ "$code" == "200" ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else echo "GET got $code"; result=1; fi
  [ "$result" == "0" ]
}

@test "4.2 POST request is denied by the waypoint (403)" {
  echo '1' >> /var/work/tests/result/all
  code=$(kubectl exec -n default deploy/curl-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 12 -X POST http://ping-pong:8080/ 2>/dev/null || true)
  if [[ "$code" == "403" ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else echo "POST got $code (expected 403)"; result=1; fi
  [ "$result" == "0" ]
}
