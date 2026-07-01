#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 web StatefulSet pods have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=web --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=web -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -ge 2 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 web is a headless Service with a named port" {
  echo '1' >> /var/work/tests/result/all

  cip=$(kubectl get svc web -n app -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  pname=$(kubectl get svc web -n app -o jsonpath='{.spec.ports[0].name}' 2>/dev/null)

  if [[ "$cip" == "None" ]] && [[ -n "$pname" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web service clusterIP='$cip', first port name='$pname' (expected None + a named port)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 PeerAuthentication STRICT is applied in namespace app" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get peerauthentication -n app -o json | jq '[.items[] | select(.spec.mtls.mode=="STRICT")] | length')
  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No PeerAuthentication with mtls.mode=STRICT in namespace app"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 replica web-0 is reachable by its stable DNS over mTLS" {
  echo '1' >> /var/work/tests/result/all

  body=""
  for i in $(seq 12); do
    body=$(kubectl exec -n app deploy/app-client -c curl -- \
      curl -s --max-time 8 http://web-0.web.app.svc.cluster.local:8080/ 2>/dev/null || true)
    echo "$body" | grep -q 'web-0' && break
    sleep 5
  done

  if echo "$body" | grep -q 'web-0'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web-0 not reachable by stable DNS (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 replica web-1 is reachable by its stable DNS over mTLS" {
  echo '1' >> /var/work/tests/result/all

  body=$(kubectl exec -n app deploy/app-client -c curl -- \
    curl -s --max-time 8 http://web-1.web.app.svc.cluster.local:8080/ 2>/dev/null || true)

  if echo "$body" | grep -q 'web-1'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web-1 not reachable by stable DNS (body='$body')"
    result=1
  fi

  [ "$result" == "0" ]
}
