#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. nginx-resolver pod + service, DNS records saved to files" {
  echo '1' >> /var/work/tests/result/all
  svc=$(kubectl get svc nginx-resolver-service --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  eps=$(kubectl get endpoints nginx-resolver-service --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  f1=/var/work/tests/artifacts/dns/nginx.svc
  f2=/var/work/tests/artifacts/dns/nginx.pod
  if [[ "$svc" == "nginx-resolver-service" ]] && [[ "$eps" -ge 1 ]] && [[ -s "$f1" ]] && [[ -s "$f2" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "svc=$svc eps=$eps files: $(ls -l $f1 $f2 2>/dev/null)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Ingress for /cat (ns cat, rewrite-target, backend cat)" {
  echo '1' >> /var/work/tests/result/all
  path=$(kubectl get ingress -n cat --context $CTX -o json 2>/dev/null | jq -r '.items[0].spec.rules[0].http.paths[] | select(.path=="/cat") | .path' | head -1)
  bk=$(kubectl get ingress -n cat --context $CTX -o json 2>/dev/null | jq -r '.items[0].spec.rules[0].http.paths[] | select(.path=="/cat") | .backend.service.name' | head -1)
  ann=$(kubectl get ingress -n cat --context $CTX -o json 2>/dev/null | jq -r '.items[0].metadata.annotations["nginx.ingress.kubernetes.io/rewrite-target"]')
  if [[ "$path" == "/cat" ]] && [[ "$bk" == "cat" ]] && [[ "$ann" == "/" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "ingress path=$path backend=$bk rewrite=$ann"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. NetworkPolicies in prod-db: default-deny + allow from prod namespace" {
  echo '1' >> /var/work/tests/result/all
  # default-deny: политика с пустым podSelector и Ingress
  deny=$(kubectl get netpol -n prod-db --context $CTX -o json 2>/dev/null | jq -r '[.items[] | select((.spec.podSelector == {}) and (.spec.policyTypes | index("Ingress")) and ((.spec.ingress // []) | length == 0))] | length')
  # allow: политика с namespaceSelector в from
  allow=$(kubectl get netpol -n prod-db --context $CTX -o json 2>/dev/null | jq -r '[.items[] | select([.spec.ingress[]?.from[]?.namespaceSelector] | length > 0)] | length')
  if [[ "$deny" -ge 1 ]] && [[ "$allow" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "prod-db default-deny=$deny allow-from-ns=$allow"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Migration: Gateway shop-gw + HTTPRoute shop-route equivalent to Ingress (ns gw)" {
  echo '1' >> /var/work/tests/result/all
  gwcls=$(kubectl get gateway shop-gw -n gw --context $CTX -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null)
  host=$(kubectl get httproute shop-route -n gw --context $CTX -o jsonpath='{.spec.hostnames[0]}' 2>/dev/null)
  path=$(kubectl get httproute shop-route -n gw --context $CTX -o json 2>/dev/null | jq -r '.spec.rules[0].matches[0].path.value' 2>/dev/null)
  bk=$(kubectl get httproute shop-route -n gw --context $CTX -o json 2>/dev/null | jq -r '.spec.rules[0].backendRefs[0].name' 2>/dev/null)
  parent=$(kubectl get httproute shop-route -n gw --context $CTX -o jsonpath='{.spec.parentRefs[0].name}' 2>/dev/null)
  if [[ -n "$gwcls" ]] && [[ "$host" == "shop.local" ]] && [[ "$path" == "/api" ]] && [[ "$bk" == "shop" ]] && [[ "$parent" == "shop-gw" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "gw class=$gwcls host=$host path=$path backend=$bk parent=$parent"; result=1; fi
  [ "$result" == "0" ]
}
