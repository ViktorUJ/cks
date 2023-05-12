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


@test "1.2  Container Runtime Sandbox gVisor.node label " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get no -l node_name=node_2 --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.labels.RuntimeClass}')
  if [[ "$result" == "runsc" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.3  Container Runtime Sandbox gVisor. deployment1 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment1   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}


@test "1.4  Container Runtime Sandbox gVisor. deployment2 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment2   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.5  Container Runtime Sandbox gVisor. deployment3 nodeSelector " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment3   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath={.spec.template.spec.nodeSelector.RuntimeClass})
  if [[ "$result" == "runsc" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "runsc" ]
}

@test "1.6  Container Runtime Sandbox gVisor. RuntimeClass deployment1  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment1   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.7  Container Runtime Sandbox gVisor. RuntimeClass deployment2  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment2   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.8  Container Runtime Sandbox gVisor. RuntimeClass deployment3  " {
  echo '.3'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment3   -n team-purple  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.runtimeClassName}')
  if [[ "$result" == "gvisor" ]]; then
   echo '.3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "gvisor" ]
}

@test "1.9  Container Runtime Sandbox gVisor. logs dmesg  " {
  echo '.7'>>/var/work/tests/result/all
  cat /var/work/tests/artifacts/1/gvisor-dmesg | grep 'Starting gVisor'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.7'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# all =4