#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. snapshot S1 exists at /var/work/tests/artifacts/etcd/etcd-snapshot-1.db" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/etcd/etcd-snapshot-1.db
  if [[ -s "$f" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "$f missing/empty (скопируйте снапшот S1 с control plane на worker)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. snapshot S2 exists at /var/work/tests/artifacts/etcd/etcd-snapshot-2.db" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/etcd/etcd-snapshot-2.db
  if [[ -s "$f" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "$f missing/empty (скопируйте снапшот S2 с control plane на worker)"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Cluster healthy after restore: kube-system pods Ready, API up" {
  echo '1' >> /var/work/tests/result/all
  api=$(kubectl get --raw='/healthz' --context $CTX 2>/dev/null)
  notready=$(kubectl get pods -n kube-system --context $CTX --no-headers 2>/dev/null | grep -Ev 'Running|Completed' | wc -l)
  if [[ "$api" == "ok" ]] && [[ "$notready" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "healthz=$api kube-system-notready=$notready"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Restored from S2: namespace snapshot-demo with configmap and deployment present" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns snapshot-demo --context $CTX --no-headers 2>/dev/null | wc -l)
  cm=$(kubectl -n snapshot-demo get cm demo-config --context $CTX --no-headers 2>/dev/null | wc -l)
  dp=$(kubectl -n snapshot-demo get deploy demo-web --context $CTX --no-headers 2>/dev/null | wc -l)
  if [[ "$ns" == "1" ]] && [[ "$cm" == "1" ]] && [[ "$dp" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "snapshot-demo ns=$ns cm=$cm deploy=$dp (ожидается восстановление из снапшота S2)"; result=1; fi
  [ "$result" == "0" ]
}
