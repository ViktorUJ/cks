#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 both tcp-echo versions have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=tcp-echo --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=tcp-echo -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -ge 2 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "tcp-echo pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Gateway exposes a TCP server on port 31400" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get gateway -n app -o json | jq '[
    .items[]
    | select([.spec.servers[]? | select(.port.protocol=="TCP") | .port.number] | index(31400))
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Gateway with a TCP server on port 31400"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 VirtualService has a TCP route to tcp-echo" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get virtualservice -n app -o json | jq '[
    .items[]
    | select([.spec.tcp[]?.route[]?.destination.host // empty] | map(select(startswith("tcp-echo"))) | length > 0)
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No VirtualService with a tcp route to tcp-echo"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 raw TCP through the gateway is echoed by tcp-echo" {
  echo '1' >> /var/work/tests/result/all

  resp=""
  for i in $(seq 12); do
    resp=$(timeout 6 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; printf "hello\n" >&3; head -n 1 <&3' 2>/dev/null || true)
    if echo "$resp" | grep -q 'hello' && echo "$resp" | grep -qE 'one|two'; then break; fi
    sleep 5
  done

  if echo "$resp" | grep -q 'hello' && echo "$resp" | grep -qE 'one|two'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "TCP echo through the gateway failed (response='$resp')"
    result=1
  fi

  [ "$result" == "0" ]
}
