#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 k8s1_controlPlane_1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. CNI installed: all nodes (>=2) are Ready" {
  echo '1' >> /var/work/tests/result/all
  total=$(kubectl get nodes --context $CTX --no-headers 2>/dev/null | wc -l)
  ready=$(kubectl get nodes --context $CTX -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "^True$")
  if [[ "$total" -ge 2 ]] && [[ "$ready" == "$total" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodes total=$total ready=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. CoreDNS is healthy after CNI (readyReplicas >= 1)" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl -n kube-system get deploy coredns --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]] 2>/dev/null; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "coredns readyReplicas=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Cross-node pod networking: netprobe 2 pods Running on 2 distinct nodes" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl -n netlab get deploy netprobe --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  nodes=$(kubectl -n netlab get pods -l app=netprobe --context $CTX -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | tr ' ' '\n' | sort -u | grep -c .)
  if [[ "$ready" == "2" ]] && [[ "$nodes" == "2" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "netprobe readyReplicas=$ready distinctNodes=$nodes"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Low-level network report is correct (/home/ubuntu/answers/net-lowlevel.txt)" {
  echo '1' >> /var/work/tests/result/all
  file=/home/ubuntu/answers/net-lowlevel.txt
  got_conf=$(grep '^cni_conf=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  got_dev=$(grep '^default_route_dev=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  conf_ok=no
  if [[ -n "$got_conf" ]] && $SSH "sudo ls /etc/cni/net.d 2>/dev/null" 2>/dev/null | tr -d '\r' | grep -Fxq "$got_conf"; then conf_ok=yes; fi
  exp_dev=$($SSH "ip -o route show default" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' | xargs)
  if [[ "$conf_ok" == "yes" ]] && [[ -n "$exp_dev" ]] && [[ "$got_dev" == "$exp_dev" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "net-lowlevel.txt: cni_conf='$got_conf' (present=$conf_ok), default_route_dev='$got_dev' (expected '$exp_dev')"; result=1; fi
  [ "$result" == "0" ]
}
