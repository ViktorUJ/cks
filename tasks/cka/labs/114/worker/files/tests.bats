#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. ReplicaSet rs-app2223 (ns rsapp) has 2 ready replicas" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get rs rs-app2223 -n rsapp --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$ready" == "2" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "rs-app2223 readyReplicas=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Service svc-broken (ns tsvc) now has endpoints" {
  echo '1' >> /var/work/tests/result/all
  eps=$(kubectl get endpoints svc-broken -n tsvc --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$eps" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "svc-broken endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Deployment capp (ns cfgapp) is ready (ConfigMap fixed)" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy capp -n cfgapp --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "capp readyReplicas=$ready"; result=1; fi
  [ "$result" == "0" ]
}
