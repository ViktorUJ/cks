#!/usr/bin/env bats
# Тесты выполняются на первой control plane ноде (cp1). kubeconfig — admin.conf.
K="sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. HA: >= 3 control-plane nodes and all nodes Ready (нечётный кворум)" {
  echo '1' >> /var/work/tests/result/all
  cp=$($K get nodes -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | wc -l)
  total=$($K get nodes --no-headers 2>/dev/null | wc -l)
  ready=$($K get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$cp" -ge 3 ]] && [[ "$ready" == "$total" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "control-plane nodes=$cp (нужно >=3), total=$total, ready=$ready (join cp2 и cp3)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. etcd quorum: >= 3 running etcd pods in kube-system" {
  echo '1' >> /var/work/tests/result/all
  total=$($K -n kube-system get pods -l component=etcd --no-headers 2>/dev/null | wc -l)
  running=$($K -n kube-system get pods -l component=etcd -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c "^Running$")
  if [[ "$total" -ge 3 ]] && [[ "$running" -ge 3 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "etcd pods total=$total running=$running (нужно >=3 членов etcd для нечётного кворума)"; result=1; fi
  [ "$result" == "0" ]
}
