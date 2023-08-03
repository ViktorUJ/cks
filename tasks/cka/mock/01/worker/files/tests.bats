#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1.1  Container Runtime Sandbox gVisor.RuntimeClass " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get runtimeclasses.node.k8s.io  gvisor  --context cluster1-admin@cluster1  -o jsonpath={.handler})
  if [[ "$result" == "runsc" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

