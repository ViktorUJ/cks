#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#3
@test "3. Create a namespace named team-elephant  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ns  team-elephant -o jsonpath={.metadata.name}  --context cluster1-admin@cluster1 )
  if [[ "$result" == "team-elephant" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "team-elephant" ]
}

# 1 1