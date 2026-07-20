#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. kube-scheduler is healthy and scheduling works" {
  echo '1' >> /var/work/tests/result/all
  sched=$(kubectl -n kube-system get pods -l component=kube-scheduler --context $CTX -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  ready=$(kubectl -n kube-system get pods -l component=kube-scheduler --context $CTX -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  canary=$(kubectl get pod sched-check -n default --context $CTX -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$sched" == "Running" ]] && [[ "$ready" == "true" ]] && [[ "$canary" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "scheduler phase=$sched ready=$ready sched-check=$canary"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. All nodes are Ready (worker kubelet fixed)" {
  echo '1' >> /var/work/tests/result/all
  total=$(kubectl get nodes --context $CTX --no-headers 2>/dev/null | wc -l)
  ready=$(kubectl get nodes --context $CTX -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$total" -ge 2 ]] && [[ "$ready" == "$total" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes total=$total ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Broken static pod on control plane is fixed and Running" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get pods -n default --context $CTX -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}' 2>/dev/null | grep '^staticweb-' | awk '{print $2}' | head -1)
  if [[ "$phase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "staticweb mirror pod phase=$phase"; result=1; fi
  [ "$result" == "0" ]
}
