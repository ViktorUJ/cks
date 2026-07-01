#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 app pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 PeerAuthentication STRICT is applied in namespace app" {
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

@test "3.1 In-mesh client still reaches the app over mTLS (200)" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n app deploy/mesh-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/ 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "in-mesh client got HTTP code '$code' (expected 200)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Legacy plaintext client is rejected under STRICT" {
  echo '1' >> /var/work/tests/result/all

  code=$(kubectl exec -n legacy deploy/legacy-client -c curl -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/ 2>/dev/null || true)

  # Under STRICT the server sidecar resets plaintext connections -> curl returns
  # 000 (no HTTP response). Any non-200 means the plaintext client was blocked.
  if [[ "$code" != "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "legacy plaintext client still reached the app (code=$code); STRICT not enforced"
    result=1
  fi

  [ "$result" == "0" ]
}
