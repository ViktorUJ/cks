#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#1
@test "1. Deploy a pod named webhttpd  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po webhttpd -n apx-z993845  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "httpd:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "httpd:alpine" ]
}
# 1 1
