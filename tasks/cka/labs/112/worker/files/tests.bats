#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. etcd snapshot exists at /var/work/tests/artifacts/etcd/etcd-backup.db" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/etcd/etcd-backup.db
  if [[ -s "$f" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "$f missing/empty (скопируйте снапшот с control plane на worker)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Cluster healthy after restore: kube-system pods Ready, API up" {
  echo '1' >> /var/work/tests/result/all
  api=$(kubectl get --raw='/healthz' --context $CTX 2>/dev/null)
  notready=$(kubectl get pods -n kube-system --context $CTX --no-headers 2>/dev/null | grep -Ev 'Running|Completed' | wc -l)
  if [[ "$api" == "ok" ]] && [[ "$notready" == "0" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "healthz=$api kube-system-notready=$notready"; result=1; fi
  [ "$result" == "0" ]
}
