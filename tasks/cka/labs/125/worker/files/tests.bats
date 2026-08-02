#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Deployment web (ns dns) has 2 ready replicas" {
  echo '1' >> /var/work/tests/result/all
  r=$(kubectl -n dns get deploy web --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$r" == "2" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web readyReplicas=$r"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. ClusterIP service web-svc has endpoints (A-record source)" {
  echo '1' >> /var/work/tests/result/all
  eps=$(kubectl -n dns get endpoints web-svc --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$eps" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web-svc endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Headless service web-h (clusterIP None) has endpoints" {
  echo '1' >> /var/work/tests/result/all
  cip=$(kubectl -n dns get svc web-h --context $CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  eps=$(kubectl -n dns get endpoints web-h --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$cip" == "None" ]] && [[ "$eps" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web-h clusterIP=$cip endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Pod client has dnsConfig option ndots=2" {
  echo '1' >> /var/work/tests/result/all
  v=$(kubectl -n dns get pod client --context $CTX -o jsonpath='{.spec.dnsConfig.options[?(@.name=="ndots")].value}' 2>/dev/null)
  if [[ "$v" == "2" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "client dnsConfig ndots=$v (expected 2)"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. CoreDNS Corefile forwards mycorp.local to 10.10.0.10" {
  echo '1' >> /var/work/tests/result/all
  cf=$(kubectl -n kube-system get configmap coredns --context $CTX -o jsonpath='{.data.Corefile}' 2>/dev/null)
  if echo "$cf" | grep -q "mycorp.local" && echo "$cf" | grep -q "10.10.0.10"; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "Corefile has no mycorp.local -> 10.10.0.10 forward"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. JSONPath: ClusterIP of web-svc saved to answers/clusterip.txt" {
  echo '1' >> /var/work/tests/result/all
  exp=$(kubectl -n dns get svc web-svc --context $CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null | xargs)
  got=$(cat /home/ubuntu/answers/clusterip.txt 2>/dev/null | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "clusterip.txt='$got' expected='$exp'"; result=1; fi
  [ "$result" == "0" ]
}
