#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#1
@test "1. Create a secret secret1 with value key1=value1 in the namespace jellyfish  " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl exec app1  -n jellyfish -- sh -c 'echo $PASSWORD'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "value1" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "value1" ]
}

# 2 2
