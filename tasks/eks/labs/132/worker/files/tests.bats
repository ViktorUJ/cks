#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-132"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-132 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. api and client run on the cilium-demo pool and reach each other" {
  echo '1' >> /var/work/tests/result/all
  api_img=$(kubectl get deploy api -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  api_ready=$(kubectl get deploy api -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  svc_port=$(kubectl get svc api -n "$NS" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  client_img=$(kubectl get deploy client -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  client_ready=$(kubectl get deploy client -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  api_node_sel=$(kubectl get deploy api -n "$NS" -o jsonpath='{.spec.template.spec.nodeSelector.work_type}' 2>/dev/null)
  client_node_sel=$(kubectl get deploy client -n "$NS" -o jsonpath='{.spec.template.spec.nodeSelector.work_type}' 2>/dev/null)
  f=/var/work/tests/artifacts/2/connectivity_before.txt
  if [[ "$api_img" == *ping_pong* ]] && [[ "$api_ready" == "2" ]] && [[ "$svc_port" == "8080" ]] \
     && [[ "$client_img" == *curl* ]] && [[ "$client_ready" == "1" ]] \
     && [[ "$api_node_sel" == "cilium-demo" ]] && [[ "$client_node_sel" == "cilium-demo" ]] \
     && [[ -s "$f" ]] && grep -q 'HTTP_CODE=200' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api_img=$api_img api_ready=$api_ready svc_port=$svc_port"
    echo "client_img=$client_img client_ready=$client_ready"
    echo "api_node_sel=$api_node_sel client_node_sel=$client_node_sel"
    echo "file $f must contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Cilium DaemonSet is Running only on cilium-demo nodes" {
  echo '1' >> /var/work/tests/result/all
  ds_sel=$(kubectl get ds cilium -n kube-system -o jsonpath='{.spec.template.spec.nodeSelector.work_type}' 2>/dev/null)
  phases=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
  not_running=$(echo "$phases" | tr ' ' '\n' | grep -vc '^Running$' || true)
  count=$(echo "$phases" | tr ' ' '\n' | grep -c '^Running$' || true)
  f=/var/work/tests/artifacts/3/cilium_status.txt
  if [[ "$ds_sel" == "cilium-demo" ]] && [[ "$count" -ge 1 ]] && [[ "$not_running" -eq 0 ]] \
     && [[ -s "$f" ]] && grep -q 'Cilium:' "$f" && grep -q 'OK' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ds_sel=$ds_sel running_count=$count not_running=$not_running"
    echo "file $f must contain 'Cilium:' and 'OK'"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Pod IPs still come from the VPC CIDR (chaining, not full replacement)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/podips.txt
  hits=$(grep -o '10\.10\.' "$f" 2>/dev/null | wc -l)
  if [[ -s "$f" ]] && [[ "$hits" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or fewer than 2 addresses from 10.10.0.0/16"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. CiliumNetworkPolicy L7 allows GET only" {
  echo '1' >> /var/work/tests/result/all
  target=$(kubectl get cnp cilium-l7-allow-get -n "$NS" \
    -o jsonpath='{.spec.endpointSelector.matchLabels.app}' 2>/dev/null)
  method=$(kubectl get cnp cilium-l7-allow-get -n "$NS" \
    -o jsonpath='{.spec.ingress[0].toPorts[0].rules.http[0].method}' 2>/dev/null)
  fa=/var/work/tests/artifacts/5/allowed_get.txt
  fb=/var/work/tests/artifacts/5/blocked_post.txt
  if [[ "$target" == "api" ]] && [[ "$method" == "GET" ]] \
     && [[ -s "$fa" ]] && grep -q 'HTTP_CODE=200' "$fa" \
     && [[ -s "$fb" ]] && ! grep -q 'HTTP_CODE=200' "$fb"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "target=$target method=$method"
    echo "file $fa must contain HTTP_CODE=200, file $fb must NOT contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. CiliumNetworkPolicy restricts egress to a single FQDN" {
  echo '1' >> /var/work/tests/result/all
  target=$(kubectl get cnp cilium-fqdn-allow-aws -n "$NS" \
    -o jsonpath='{.spec.endpointSelector.matchLabels.app}' 2>/dev/null)
  fqdn=$(kubectl get cnp cilium-fqdn-allow-aws -n "$NS" \
    -o jsonpath='{.spec.egress[0].toFQDNs[0].matchName}' 2>/dev/null)
  fa=/var/work/tests/artifacts/6/allowed_fqdn.txt
  fb=/var/work/tests/artifacts/6/blocked_other_domain.txt
  if [[ "$target" == "client" ]] && [[ "$fqdn" == "aws.amazon.com" ]] \
     && [[ -s "$fa" ]] && grep -Eq 'HTTP_CODE=(2|3)[0-9][0-9]' "$fa" \
     && [[ -s "$fb" ]] && ! grep -q 'HTTP_CODE=200' "$fb"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "target=$target fqdn=$fqdn"
    echo "file $fa must contain HTTP_CODE=2xx/3xx, file $fb must NOT contain HTTP_CODE=200"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Hubble relay is up and captured a DROPPED flow" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy hubble-relay -n kube-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/7/hubble_denied.txt
  if [[ "$ready" -ge 1 ]] 2>/dev/null && [[ -s "$f" ]] && grep -q 'DROPPED' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "hubble-relay ready=$ready; file $f must exist and contain DROPPED"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Comparison artifact covers L7, FQDN, Hubble and the chapter 8 scope note" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/8/comparison.txt
  if [[ -s "$f" ]] && grep -q 'L7' "$f" && grep -q 'FQDN' "$f" && grep -q 'Hubble' "$f" \
     && grep -qiE 'глава 8|chapter 8' "$f" && grep -qi 'blue' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f must contain L7, FQDN, Hubble, a chapter 8 reference and 'blue'"
    result=1
  fi
  [ "$result" == "0" ]
}
