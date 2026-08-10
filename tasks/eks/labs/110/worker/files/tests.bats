#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-110"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-110 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Artifact confirms the network policy enforcer is enabled" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/enforcer.txt
  if [[ -s "$f" ]] && grep -qi 'aws-network-policy-agent' "$f" \
     && grep -qi 'enableNetworkPolicy' "$f" && grep -qi 'true' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not confirm aws-network-policy-agent / enableNetworkPolicy=true"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. api plus client are up and client reaches api before any policy" {
  echo '1' >> /var/work/tests/result/all
  api_img=$(kubectl get deploy api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  api_ready=$(kubectl get deploy api -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  svc_port=$(kubectl get svc api -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  client_img=$(kubectl get deploy client -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  client_ready=$(kubectl get deploy client -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/3/connectivity_before.txt
  if [[ "$api_img" == *ping_pong* ]] && [[ "$api_ready" == "2" ]] && [[ "$svc_port" == "8080" ]] \
     && [[ "$client_img" == *curl* ]] && [[ "$client_ready" == "1" ]] \
     && [[ -s "$f" ]] && grep -q 'HTTP_CODE=200' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api_img=$api_img api_ready=$api_ready svc_port=$svc_port client_img=$client_img client_ready=$client_ready"
    echo "file $f must contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Default deny ingress blocks client from reaching api" {
  echo '1' >> /var/work/tests/result/all
  types=$(kubectl get networkpolicy default-deny-ingress -n "$NS" -o jsonpath='{.spec.policyTypes[0]}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/connectivity_denied.txt
  if [[ "$types" == "Ingress" ]] && [[ -s "$f" ]] && ! grep -q 'HTTP_CODE=200' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "networkpolicy default-deny-ingress policyTypes=$types; file $f must exist and NOT contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Label-based allow: frontend reaches api, unlabeled client-other stays blocked" {
  echo '1' >> /var/work/tests/result/all
  np_target=$(kubectl get networkpolicy allow-frontend-to-api -n "$NS" \
    -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
  np_from=$(kubectl get networkpolicy allow-frontend-to-api -n "$NS" \
    -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}' 2>/dev/null)
  frontend_ready=$(kubectl get deploy frontend -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  frontend_label=$(kubectl get deploy frontend -n "$NS" \
    -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  other_label=$(kubectl get deploy client-other -n "$NS" \
    -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  fa=/var/work/tests/artifacts/5/allowed_frontend.txt
  fb=/var/work/tests/artifacts/5/blocked_other.txt
  if [[ "$np_target" == "api" ]] && [[ "$np_from" == "frontend" ]] \
     && [[ "$frontend_ready" == "1" ]] && [[ "$frontend_label" == "frontend" ]] \
     && [[ "$other_label" != "frontend" ]] \
     && [[ -s "$fa" ]] && grep -q 'HTTP_CODE=200' "$fa" \
     && [[ -s "$fb" ]] && ! grep -q 'HTTP_CODE=200' "$fb"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "np_target=$np_target np_from=$np_from frontend_ready=$frontend_ready"
    echo "frontend_label=$frontend_label other_label=$other_label"
    echo "file $fa must contain HTTP_CODE=200, file $fb must NOT contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Egress policy allows api and DNS, blocks arbitrary external access" {
  echo '1' >> /var/work/tests/result/all
  eg_types=$(kubectl get networkpolicy restrict-egress -n "$NS" -o jsonpath='{.spec.policyTypes[0]}' 2>/dev/null)
  eg_target=$(kubectl get networkpolicy restrict-egress -n "$NS" \
    -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
  fdns=/var/work/tests/artifacts/6/egress_dns_api.txt
  fext=/var/work/tests/artifacts/6/egress_external_blocked.txt
  if [[ "$eg_types" == "Egress" ]] && [[ "$eg_target" == "frontend" ]] \
     && [[ -s "$fdns" ]] && grep -q 'HTTP_CODE=200' "$fdns" \
     && [[ -s "$fext" ]] && ! grep -q 'HTTP_CODE=200' "$fext"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "eg_types=$eg_types eg_target=$eg_target"
    echo "file $fdns must contain HTTP_CODE=200, file $fext must NOT contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}
