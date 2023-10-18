#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1. Deploy a pod named webhttpd  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po webhttpd -n apx-z993845  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "httpd:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "httpd:alpine" ]
}

#2 2

@test "2.1 Create a deployment named hr-web-app.Image " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get deployment  nginx-app  -o jsonpath='{.spec..containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "nginx:alpine-slim" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:alpine-slim" ]
}

@test "2.2 Create a deployment named hr-web-app.Replicas " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get deployment  nginx-app  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

# 1 3