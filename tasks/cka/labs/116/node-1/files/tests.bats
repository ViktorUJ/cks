#!/usr/bin/env bats
# Тесты выполняются на control plane ноде (cp). kubeconfig администратора — admin.conf.
K="sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Control plane initialized (kubeadm init) and node cp registered" {
  echo '1' >> /var/work/tests/result/all
  result=1
  if sudo test -f /etc/kubernetes/admin.conf; then
    names=$($K get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if echo "$names" | grep -qw cp; then
      echo '1' >> /var/work/tests/result/ok; result=0
    else echo "control plane admin.conf есть, но нода cp не найдена: '$names'"; fi
  else echo "нет /etc/kubernetes/admin.conf — kubeadm init не выполнен"; fi
  [ "$result" == "0" ]
}

@test "2. CNI installed: control plane node cp is Ready" {
  echo '1' >> /var/work/tests/result/all
  st=$($K get node cp -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$st" == "True" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "нода cp Ready=$st (нужна установка CNI)"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Worker node joined: 2 nodes total and all Ready" {
  echo '1' >> /var/work/tests/result/all
  total=$($K get nodes --no-headers 2>/dev/null | wc -l)
  ready=$($K get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$total" -ge 2 ]] && [[ "$ready" == "$total" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes total=$total ready=$ready (нужно join worker-ноды)"; result=1; fi
  [ "$result" == "0" ]
}
