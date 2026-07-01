#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 ping-pong pod is injected with a sidecar (2/2)" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n default -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ping-pong pods total=$total, injected=$injected (namespace not enabled for injection?)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 VirtualService references only subsets defined in the DestinationRule" {
  echo '1' >> /var/work/tests/result/all

  refs=$(kubectl get virtualservice -n default -o json | jq -c '[.items[].spec.http[]?.route[]?.destination | select((.host // "") | test("^ping-pong")) | .subset] | map(select(. != null)) | unique')
  defined=$(kubectl get destinationrule -n default -o json | jq -c '[.items[] | select((.spec.host // "") | test("^ping-pong")) | .spec.subsets[]?.name] | unique')
  missing=$(jq -n --argjson r "$refs" --argjson d "$defined" '($r - $d) | length')
  refcount=$(jq -n --argjson r "$refs" '$r | length')

  if [[ "$refcount" -gt 0 ]] && [[ "$missing" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "VS subsets=$refs, DR subsets=$defined, dangling=$missing"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Application is reachable through the gateway (200)" {
  echo '1' >> /var/work/tests/result/all

  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 12 http://myapp.local:32080/ 2>/dev/null || true)

  if [[ "$code" == "200" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "gateway returned '$code' (expected 200 after fixing the routing)"
    result=1
  fi

  [ "$result" == "0" ]
}
