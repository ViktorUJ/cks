#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 app and shop workloads have Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  ok=1
  for ns in app shop; do
    total=$(kubectl get pods -n $ns -l 'app in (frontend,catalog)' --no-headers 2>/dev/null | wc -l)
    inj=$(kubectl get pods -n $ns -l 'app in (frontend,catalog)' -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)
    if [[ "$total" -lt 1 ]] || [[ "$total" -ne "$inj" ]]; then ok=0; echo "ns=$ns total=$total inj=$inj"; fi
  done

  if [[ "$ok" == "1" ]]; then echo '1' >> /var/work/tests/result/ok; result=0; else result=1; fi
  [ "$result" == "0" ]
}

@test "2.1 meshConfig defines discoverySelectors" {
  echo '1' >> /var/work/tests/result/all

  if kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' 2>/dev/null | grep -q 'discoverySelectors'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "meshConfig (configmap istio) has no discoverySelectors"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 discovery selectors drop the legacy namespace from the mesh" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n shop -l app=catalog -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  seen=1
  for i in $(seq 12); do
    cl=$(kubectl exec -n shop "$pod" -c istio-proxy -- pilot-agent request GET clusters 2>/dev/null || true)
    if ! echo "$cl" | grep -q 'legacy-app.legacy.svc.cluster.local'; then seen=0; break; fi
    sleep 5
  done

  if [[ "$seen" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "legacy-app.legacy still present in shop proxy clusters (discoverySelectors not effective)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 app namespace has a Sidecar with a restricted egress scope" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get sidecar -n app -o json 2>/dev/null | jq '[
    .items[]
    | select(.spec.egress != null)
    | select(([.spec.egress[].hosts[]] | index("*/*")) == null)
  ] | length')

  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Sidecar in app with a restricted egress (still allows */*)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 Sidecar scope drops shop from the app proxy config" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n app -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  seen=1
  for i in $(seq 12); do
    cl=$(kubectl exec -n app "$pod" -c istio-proxy -- pilot-agent request GET clusters 2>/dev/null || true)
    if ! echo "$cl" | grep -q 'catalog.shop.svc.cluster.local'; then seen=0; break; fi
    sleep 5
  done

  if [[ "$seen" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "catalog.shop still present in app proxy clusters (Sidecar egress not effective)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.1 an OPA Gatekeeper ConstraintTemplate exists" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get constrainttemplates.templates.gatekeeper.sh -o name 2>/dev/null | wc -l)
  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No Gatekeeper ConstraintTemplate found"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "4.2 Gatekeeper rejects a namespace that violates the policy" {
  echo '1' >> /var/work/tests/result/all

  name="gk-probe-$RANDOM"
  out=$(kubectl create ns "$name" 2>&1 || true)
  if echo "$out" | grep -qiE 'denied|admission|violat|gatekeeper'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Namespace without required label was NOT rejected (out=$out)"
    kubectl delete ns "$name" --wait=false >/dev/null 2>&1 || true
    result=1
  fi

  [ "$result" == "0" ]
}

@test "5.1 istiod exposes golden-signal metrics" {
  echo '1' >> /var/work/tests/result/all

  out=""
  for i in $(seq 12); do
    out=$(kubectl exec -n shop deploy/probe -c probe -- \
      curl -s --max-time 5 http://istiod.istio-system:15014/metrics 2>/dev/null || true)
    if echo "$out" | grep -q 'pilot_proxy_convergence_time'; then break; fi
    sleep 5
  done

  if echo "$out" | grep -q 'pilot_proxy_convergence_time' && echo "$out" | grep -q 'pilot_xds_pushes'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "istiod golden-signal metrics not reachable at istiod:15014/metrics"
    result=1
  fi

  [ "$result" == "0" ]
}
