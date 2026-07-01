#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

SVC="http://ping-pong.app.svc.cluster.local:8080/"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 namespace app is in ambient mode (no sidecars)" {
  echo '1' >> /var/work/tests/result/all

  mode=$(kubectl get ns app -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)
  has_sidecar=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '[.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy"))] | length')

  if [[ "$mode" == "ambient" ]] && [[ "${has_sidecar:-0}" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ns dataplane-mode='$mode', pods with sidecar=$has_sidecar (expected ambient / 0)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 waypoint proxy is running in namespace app" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy waypoint -n app -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "waypoint deployment is not ready in namespace app"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 AuthorizationPolicy allows the GET method" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get authorizationpolicy -n app -o json | jq '[
    .items[]
    | select([.spec.rules[]?.to[]?.operation.methods[]?] | index("GET"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No AuthorizationPolicy in namespace app allowing the GET method"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 GET is allowed through the waypoint (200)" {
  echo '1' >> /var/work/tests/result/all

  code=""
  for i in $(seq 12); do
    code=$(kubectl exec -n app deploy/app-client -c curl -- \
      curl -s -o /dev/null -w "%{http_code}" --max-time 8 -X GET "$SVC" 2>/dev/null || true)
    [[ "$code" == "200" ]] && break
    sleep 5
  done

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "GET returned '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 DELETE is denied by the L7 policy (403)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n app deploy/app-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 8 -X DELETE "$SVC" 2>/dev/null || true)

  if [[ "$code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "DELETE returned '$code' (expected 403)"
    result=1
  fi

  [ "$result" == "0" ]
}
