#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
TARGET="v1.33.2"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Control plane node upgraded to ${TARGET} and Ready" {
  echo '1' >> /var/work/tests/result/all
  cp=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --context $CTX -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null)
  rd=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --context $CTX -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  if [[ "$cp" == "$TARGET" ]] && [[ "$rd" == "True" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "control-plane version=$cp ready=$rd (target $TARGET)"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. All nodes upgraded to ${TARGET} and Ready" {
  echo '1' >> /var/work/tests/result/all
  total=$(kubectl get nodes --context $CTX --no-headers 2>/dev/null | wc -l)
  ontarget=$(kubectl get nodes --context $CTX -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' 2>/dev/null | tr ' ' '\n' | grep -c "^${TARGET}$")
  ready=$(kubectl get nodes --context $CTX -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$ontarget" == "$total" ]] && [[ "$ready" == "$total" ]] && [[ "$total" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes total=$total onTarget=$ontarget ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}
