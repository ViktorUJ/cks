#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Deployment web (ns net) has 2 ready replicas" {
  echo '1' >> /var/work/tests/result/all
  r=$(kubectl -n net get deploy web --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$r" == "2" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web readyReplicas=$r"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. ClusterIP service web-svc has endpoints" {
  echo '1' >> /var/work/tests/result/all
  eps=$(kubectl -n net get endpoints web-svc --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$eps" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web-svc endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. NodePort service web-np on nodePort 30080" {
  echo '1' >> /var/work/tests/result/all
  t=$(kubectl -n net get svc web-np --context $CTX -o jsonpath='{.spec.type}' 2>/dev/null)
  np=$(kubectl -n net get svc web-np --context $CTX -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  if [[ "$t" == "NodePort" ]] && [[ "$np" == "30080" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web-np type=$t nodePort=$np"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. Headless service web-h (clusterIP None)" {
  echo '1' >> /var/work/tests/result/all
  cip=$(kubectl -n net get svc web-h --context $CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  if [[ "$cip" == "None" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "web-h clusterIP=$cip (expected None)"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. Ingress web-ing routes web.local to web-svc:80" {
  echo '1' >> /var/work/tests/result/all
  host=$(kubectl -n net get ingress web-ing --context $CTX -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  svc=$(kubectl -n net get ingress web-ing --context $CTX -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  port=$(kubectl -n net get ingress web-ing --context $CTX -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
  if [[ "$host" == "web.local" ]] && [[ "$svc" == "web-svc" ]] && [[ "$port" == "80" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "ingress host=$host svc=$svc port=$port"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. NetworkPolicy deny-all (default-deny Ingress) in ns net" {
  echo '1' >> /var/work/tests/result/all
  types=$(kubectl -n net get netpol deny-all --context $CTX -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null)
  sel=$(kubectl -n net get netpol deny-all --context $CTX -o jsonpath='{.spec.podSelector.matchLabels}' 2>/dev/null)
  if echo "$types" | grep -qw Ingress && [[ -z "$sel" || "$sel" == "{}" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "deny-all policyTypes='$types' podSelector='$sel'"; result=1; fi
  [ "$result" == "0" ]
}

@test "7. JSONPath: nodePort of web-np saved to answers/nodeport.txt" {
  echo '1' >> /var/work/tests/result/all
  exp=$(kubectl -n net get svc web-np --context $CTX -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null | xargs)
  got=$(cat /home/ubuntu/answers/nodeport.txt 2>/dev/null | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "nodeport.txt='$got' expected='$exp'"; result=1; fi
  [ "$result" == "0" ]
}
