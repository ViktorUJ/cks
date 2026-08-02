#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. Namespace ckad-101 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns ckad-101 --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "ckad-101" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "ckad-101" ]
}

@test "2. Pod web (image viktoruj/ping_pong, label tier=frontend) in ckad-101" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get po web -n ckad-101 --context $CTX -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  label=$(kubectl get po web -n ckad-101 --context $CTX -o jsonpath='{.metadata.labels.tier}' 2>/dev/null)
  if [[ "$image" == *ping_pong* ]] && [[ "$label" == "frontend" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web pod image=$image label.tier=$label"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Deployment api in ckad-101 has 4 ready replicas (image viktoruj/ping_pong)" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy api -n ckad-101 --context $CTX -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy api -n ckad-101 --context $CTX -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "4" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api deploy image=$image readyReplicas=$ready"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Service api-svc (ClusterIP, port 80) selects deployment api pods" {
  echo '1' >> /var/work/tests/result/all
  port=$(kubectl get svc api-svc -n ckad-101 --context $CTX -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  eps=$(kubectl get endpoints api-svc -n ckad-101 --context $CTX -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
  if [[ "$port" == "80" ]] && [[ "$eps" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "api-svc port=$port endpoints=$eps"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Service web-np (NodePort 30101, port 80) in ckad-101" {
  echo '1' >> /var/work/tests/result/all
  type=$(kubectl get svc web-np -n ckad-101 --context $CTX -o jsonpath='{.spec.type}' 2>/dev/null)
  port=$(kubectl get svc web-np -n ckad-101 --context $CTX -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  nodePort=$(kubectl get svc web-np -n ckad-101 --context $CTX -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
  if [[ "$type" == "NodePort" ]] && [[ "$port" == "80" ]] && [[ "$nodePort" == "30101" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web-np type=$type port=$port nodePort=$nodePort"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. JSONPath: pod names of ckad-101 saved to artifacts file" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/pods.txt
  if [[ -s "$f" ]] && grep -q "api" "$f" && grep -q "web" "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not contain expected pod names"
    result=1
  fi
  [ "$result" == "0" ]
}
