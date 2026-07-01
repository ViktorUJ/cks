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

@test "2.1 Sidecar resource scopes egress to the local namespace" {
  echo '1' >> /var/work/tests/result/all

  own=$(kubectl get sidecar -n app -o json | jq '[.items[] | select([.spec.egress[]?.hosts[]?] | index("./*"))] | length')
  allns=$(kubectl get sidecar -n app -o json | jq '[.items[] | select([.spec.egress[]?.hosts[]?] | index("*/*"))] | length')

  if [[ "${own:-0}" -ge 1 ]] && [[ "${allns:-0}" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Sidecar egress not scoped to local namespace (own=$own, all-namespaces=$allns)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 app proxy no longer knows the 'other' namespace service" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  clusters=$(istioctl proxy-config clusters "$pod" -n app 2>/dev/null)

  if echo "$clusters" | grep -q 'backend.other'; then
    echo "app proxy still has a cluster for backend.other (Sidecar scoping not applied)"
    result=1
  else
    echo '1' >> /var/work/tests/result/ok
    result=0
  fi

  [ "$result" == "0" ]
}

@test "3.2 app proxy still knows its own namespace service" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  clusters=$(istioctl proxy-config clusters "$pod" -n app 2>/dev/null)

  if echo "$clusters" | grep -q 'ping-pong.app'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app proxy lost the cluster for its own service ping-pong.app"
    result=1
  fi

  [ "$result" == "0" ]
}
