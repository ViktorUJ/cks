#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

# Discover the two cluster contexts (renamed to cluster1*/cluster2* by the
# worker PC bootstrap).
ctx1() { kubectl config get-contexts -o name 2>/dev/null | grep -m1 cluster1; }
ctx2() { kubectl config get-contexts -o name 2>/dev/null | grep -m1 cluster2; }

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 istiod is running in both clusters" {
  echo '1' >> /var/work/tests/result/all
  C1=$(ctx1); C2=$(ctx2)

  a=$(kubectl --context "$C1" -n istio-system get deploy istiod -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)
  b=$(kubectl --context "$C2" -n istio-system get deploy istiod -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)

  if [[ "${a:-0}" -ge 1 ]] && [[ "${b:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "istiod availableReplicas: cluster1=$a cluster2=$b"; result=1
  fi
  [ "$result" == "0" ]
}

@test "2.1 both clusters share the same root CA (cacerts)" {
  echo '1' >> /var/work/tests/result/all
  C1=$(ctx1); C2=$(ctx2)

  r1=$(kubectl --context "$C1" -n istio-system get secret cacerts -o jsonpath='{.data.root-cert\.pem}' 2>/dev/null || true)
  r2=$(kubectl --context "$C2" -n istio-system get secret cacerts -o jsonpath='{.data.root-cert\.pem}' 2>/dev/null || true)

  if [[ -n "$r1" ]] && [[ "$r1" == "$r2" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "cacerts root-cert missing or differs between clusters"; result=1
  fi
  [ "$result" == "0" ]
}

@test "3.1 cross-cluster remote secrets are installed in both clusters" {
  echo '1' >> /var/work/tests/result/all
  C1=$(ctx1); C2=$(ctx2)

  n1=$(kubectl --context "$C1" -n istio-system get secret -l istio/multiCluster=true --no-headers 2>/dev/null | wc -l)
  n2=$(kubectl --context "$C2" -n istio-system get secret -l istio/multiCluster=true --no-headers 2>/dev/null | wc -l)

  if [[ "${n1:-0}" -ge 1 ]] && [[ "${n2:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "remote secrets: cluster1=$n1 cluster2=$n2"; result=1
  fi
  [ "$result" == "0" ]
}

@test "4.1 sample app deployed (v1 in cluster1, v2 in cluster2, sleep client)" {
  echo '1' >> /var/work/tests/result/all
  C1=$(ctx1); C2=$(ctx2)

  v1=$(kubectl --context "$C1" -n sample get deploy helloworld-v1 -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)
  v2=$(kubectl --context "$C2" -n sample get deploy helloworld-v2 -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)
  sl=$(kubectl --context "$C1" -n sample get deploy sleep -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)

  if [[ "${v1:-0}" -ge 1 ]] && [[ "${v2:-0}" -ge 1 ]] && [[ "${sl:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "helloworld-v1(c1)=$v1 helloworld-v2(c2)=$v2 sleep(c1)=$sl"; result=1
  fi
  [ "$result" == "0" ]
}

@test "4.2 cross-cluster load balancing reaches both v1 and v2" {
  echo '1' >> /var/work/tests/result/all
  C1=$(ctx1)

  out=""
  for i in $(seq 10); do
    out=$(kubectl --context "$C1" -n sample exec deploy/sleep -c sleep -- \
      sh -c 'for i in $(seq 20); do curl -s --max-time 3 helloworld:5000/hello; echo; done' 2>/dev/null || true)
    if echo "$out" | grep -q 'version: v1' && echo "$out" | grep -q 'version: v2'; then break; fi
    sleep 6
  done

  if echo "$out" | grep -q 'version: v1' && echo "$out" | grep -q 'version: v2'; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else
    echo "cross-cluster LB not observed (need both v1 and v2). last output:"; echo "$out" | sort -u | tail -5
    result=1
  fi
  [ "$result" == "0" ]
}
