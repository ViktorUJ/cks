#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 app workloads have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l 'app in (frontend,good,bad)' --no-headers 2>/dev/null | wc -l)
  inj=$(kubectl get pods -n app -l 'app in (frontend,good,bad)' -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -ge 3 ]] && [[ "$total" -eq "$inj" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "app pods total=$total injected=$inj"; result=1
  fi
  [ "$result" == "0" ]
}

@test "2.1 mesh-wide STRICT PeerAuthentication exists" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get peerauthentication -n istio-system -o json 2>/dev/null | jq '[
    .items[] | select(.spec.mtls.mode=="STRICT") | select((.spec.selector // null) == null)
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "No mesh-wide (istio-system, no selector) PeerAuthentication with mode STRICT"; result=1
  fi
  [ "$result" == "0" ]
}

@test "2.2 STRICT mTLS rejects the sidecar-less legacy client" {
  echo '1' >> /var/work/tests/result/all

  code="200"
  for i in $(seq 10); do
    code=$(kubectl exec -n legacy deploy/legacy -c curl -- \
      curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://frontend.app.svc.cluster.local:8080/ 2>/dev/null || echo 000)
    if [[ "$code" != "200" ]]; then break; fi
    sleep 5
  done

  if [[ "$code" != "200" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "legacy (no sidecar) still reaches frontend (code=$code); STRICT mTLS not effective"; result=1
  fi
  [ "$result" == "0" ]
}

@test "3.1 default-deny AuthorizationPolicy exists in app" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get authorizationpolicy -n app -o json 2>/dev/null | jq '[
    .items[] | select((.spec.rules // []) | length == 0) | select((.spec.action // "ALLOW") == "ALLOW")
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "No default-deny AuthorizationPolicy (empty spec) in app"; result=1
  fi
  [ "$result" == "0" ]
}

@test "3.2 authorized client (good) reaches frontend" {
  echo '1' >> /var/work/tests/result/all

  code="000"
  for i in $(seq 10); do
    code=$(kubectl exec -n app deploy/good -c curl -- \
      curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://frontend.app.svc.cluster.local:8080/ 2>/dev/null || echo 000)
    if [[ "$code" == "200" ]]; then break; fi
    sleep 5
  done

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "good client did not get 200 from frontend (code=$code)"; result=1
  fi
  [ "$result" == "0" ]
}

@test "3.3 unauthorized client (bad) is denied by AuthorizationPolicy" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n app deploy/bad -c curl -- \
    curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://frontend.app.svc.cluster.local:8080/ 2>/dev/null || echo 000)

  if [[ "$code" == "403" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "bad client was not denied with 403 (code=$code)"; result=1
  fi
  [ "$result" == "0" ]
}

@test "4.1 meshConfig sets outboundTrafficPolicy REGISTRY_ONLY" {
  echo '1' >> /var/work/tests/result/all

  if kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' 2>/dev/null | grep -q 'REGISTRY_ONLY'; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "meshConfig has no outboundTrafficPolicy REGISTRY_ONLY"; result=1
  fi
  [ "$result" == "0" ]
}

@test "4.2 egress to an undeclared external host is blocked" {
  echo '1' >> /var/work/tests/result/all

  code="200"
  for i in $(seq 8); do
    code=$(kubectl exec -n app deploy/good -c curl -- \
      curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://www.example.com/ 2>/dev/null || echo 000)
    if [[ "$code" != "200" ]]; then break; fi
    sleep 5
  done

  if [[ "$code" != "200" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "external egress not blocked (code=$code); REGISTRY_ONLY not effective"; result=1
  fi
  [ "$result" == "0" ]
}

@test "5.1 mesh-editor SA may create VirtualServices" {
  echo '1' >> /var/work/tests/result/all

  ans=$(kubectl auth can-i create virtualservices.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app 2>/dev/null || true)
  if [[ "$ans" == "yes" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "mesh-editor cannot create VirtualServices (ans=$ans)"; result=1
  fi
  [ "$result" == "0" ]
}

@test "5.2 mesh-editor SA is denied creating EnvoyFilters" {
  echo '1' >> /var/work/tests/result/all

  ans=$(kubectl auth can-i create envoyfilters.networking.istio.io --as=system:serviceaccount:app:mesh-editor -n app 2>/dev/null || true)
  if [[ "$ans" == "no" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "mesh-editor is able to create EnvoyFilters (ans=$ans); RBAC too broad"; result=1
  fi
  [ "$result" == "0" ]
}

@test "6.1 Gatekeeper rejects PeerAuthentication mode: DISABLE" {
  echo '1' >> /var/work/tests/result/all

  out=$(cat <<'EOF' | kubectl apply -f - 2>&1 || true
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: gk-test-disable
  namespace: app
spec:
  mtls:
    mode: DISABLE
EOF
)
  # clean up if it slipped through
  kubectl delete peerauthentication gk-test-disable -n app --wait=false >/dev/null 2>&1 || true

  if echo "$out" | grep -qiE 'denied|admission|violat|gatekeeper'; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "PeerAuthentication mode DISABLE was NOT rejected (out=$out)"; result=1
  fi
  [ "$result" == "0" ]
}

@test "7.1 NetworkPolicy restricts ingress in app (defense in depth)" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get networkpolicy -n app -o json 2>/dev/null | jq '[
    .items[] | select((.spec.policyTypes // []) | index("Ingress"))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "No Ingress NetworkPolicy in app"; result=1
  fi
  [ "$result" == "0" ]
}
