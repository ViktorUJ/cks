#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 k8s1_controlPlane_1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Cert health-check report is correct (/home/ubuntu/answers/certs.txt)" {
  echo '1' >> /var/work/tests/result/all
  file=/home/ubuntu/answers/certs.txt
  exp=$($SSH "sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate" 2>/dev/null | cut -d= -f2- | xargs)
  got=$(grep '^apiserver_notafter=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  ca=$(grep '^ca_cn=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]] && [[ "$ca" == "kubernetes" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "certs.txt: apiserver_notafter='$got' (expected '$exp'), ca_cn='$ca' (expected 'kubernetes')"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. CoreDNS restored (readyReplicas >= 1)" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl -n kube-system get deploy coredns --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]] 2>/dev/null; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "coredns readyReplicas=$ready"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Network facts report is correct (/home/ubuntu/answers/net.txt)" {
  echo '1' >> /var/work/tests/result/all
  file=/home/ubuntu/answers/net.txt
  exp_cidr=$($SSH "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml | head -1" 2>/dev/null | cut -d= -f2- | xargs)
  got_cidr=$(grep '^pod_cidr=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  got_ds=$(grep '^cni_daemonset=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  if [[ -n "$exp_cidr" ]] && [[ "$got_cidr" == "$exp_cidr" ]] && [[ "$got_ds" == "calico-node" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "net.txt: pod_cidr='$got_cidr' (expected '$exp_cidr'), cni_daemonset='$got_ds' (expected 'calico-node')"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Pod dns-tuned has dnsConfig ndots=2, dns-default uses default DNS" {
  echo '1' >> /var/work/tests/result/all
  tuned=$(kubectl get po dns-tuned --context $CTX -o jsonpath='{.spec.dnsConfig.options[?(@.name=="ndots")].value}' 2>/dev/null)
  defphase=$(kubectl get po dns-default --context $CTX -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$tuned" == "2" ]] && [[ "$defphase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "dns-tuned ndots=$tuned (expected 2), dns-default phase=$defphase (expected Running)"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. ndots report is correct (/home/ubuntu/answers/dns.txt)" {
  echo '1' >> /var/work/tests/result/all
  file=/home/ubuntu/answers/dns.txt
  exp=$(kubectl exec dns-default --context $CTX -- cat /etc/resolv.conf 2>/dev/null | grep -oE 'ndots:[0-9]+' | cut -d: -f2 | xargs)
  got=$(grep '^default_ndots=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  tuned=$(grep '^tuned_ndots=' "$file" 2>/dev/null | cut -d= -f2- | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]] && [[ "$tuned" == "2" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "dns.txt: default_ndots='$got' (expected '$exp'), tuned_ndots='$tuned' (expected '2')"; result=1; fi
  [ "$result" == "0" ]
}
