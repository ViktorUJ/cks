#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Namespace drill exists" {
  echo '1' >> /var/work/tests/result/all
  ns=$(kubectl get ns drill --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$ns" == "drill" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "ns drill not found"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Deployment api (ns drill) has 3 ready replicas" {
  echo '1' >> /var/work/tests/result/all
  r=$(kubectl -n drill get deploy api --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$r" == "3" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "api readyReplicas=$r"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Service api-svc (ns drill) has endpoints" {
  echo '1' >> /var/work/tests/result/all
  eps=$(kubectl -n drill get endpoints api-svc --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$eps" -ge 1 ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "api-svc endpoints=$eps"; result=1; fi
  [ "$result" == "0" ]
}

@test "4. ConfigMap cfg (APP_COLOR=blue) and Secret sec (key PASSWORD) exist in drill" {
  echo '1' >> /var/work/tests/result/all
  color=$(kubectl -n drill get cm cfg --context $CTX -o jsonpath='{.data.APP_COLOR}' 2>/dev/null)
  pass=$(kubectl -n drill get secret sec --context $CTX -o jsonpath='{.data.PASSWORD}' 2>/dev/null)
  if [[ "$color" == "blue" ]] && [[ -n "$pass" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "cfg APP_COLOR=$color secret PASSWORD set=$([[ -n "$pass" ]] && echo yes || echo no)"; result=1; fi
  [ "$result" == "0" ]
}

@test "5. JSONPath: node kubelet versions saved to answers/versions.txt" {
  echo '1' >> /var/work/tests/result/all
  exp=$(kubectl get nodes --context $CTX -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' 2>/dev/null | xargs)
  got=$(cat /home/ubuntu/answers/versions.txt 2>/dev/null | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "versions.txt='$got' expected='$exp'"; result=1; fi
  [ "$result" == "0" ]
}

@test "6. JSONPath: container images in ns drill saved to answers/images.txt" {
  echo '1' >> /var/work/tests/result/all
  exp=$(kubectl -n drill get pods --context $CTX -o jsonpath='{.items[*].spec.containers[*].image}' 2>/dev/null | tr ' ' '\n' | sort | xargs)
  got=$(cat /home/ubuntu/answers/images.txt 2>/dev/null | tr ' ' '\n' | sort | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "images.txt (sorted)='$got' expected='$exp'"; result=1; fi
  [ "$result" == "0" ]
}

@test "7. JSONPath: ClusterIP of api-svc saved to answers/api-ip.txt" {
  echo '1' >> /var/work/tests/result/all
  exp=$(kubectl -n drill get svc api-svc --context $CTX -o jsonpath='{.spec.clusterIP}' 2>/dev/null | xargs)
  got=$(cat /home/ubuntu/answers/api-ip.txt 2>/dev/null | xargs)
  if [[ -n "$exp" ]] && [[ "$got" == "$exp" ]]; then echo '1' >> /var/work/tests/result/ok; result=0
  else echo "api-ip.txt='$got' expected='$exp'"; result=1; fi
  [ "$result" == "0" ]
}
