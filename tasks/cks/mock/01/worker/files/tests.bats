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

# all =4 , task =4

# task 2

@test "2.1  Image Vulnerability Scanning. deployment1  " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment1   -n team-xxx  --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.2  Image Vulnerability Scanning. deployment2  " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment2   -n team-xxx  --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "1" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "2.3  Image Vulnerability Scanning. deployment3  " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment3   -n team-xxx  --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.4  Image Vulnerability Scanning. deployment4  " {
  echo '.5'>>/var/work/tests/result/all
  result=$(kubectl get  deployment deployment4   -n team-xxx  --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

#  all =6 , task =2


# task 3
@test "3.1 Enable audit log. cluster are available " {
  echo '1'>>/var/work/tests/result/all
  kubectl get  ns   --context cluster2-admin@cluster2
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.2 Enable audit log. check secrets in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'secrets' | grep 'Metadata'| grep 'prod' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.3 Enable audit log. check configmap in log " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo chmod +r /var/logs/kubernetes-api.log ;cat /var/logs/kubernetes-api.log | grep 'configmap' | grep 'RequestResponse'| grep 'billing'"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# all = 6  , task =7

#task 4

@test "4.1 CIS Benchmark. check 1.2.18 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.2.18 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 CIS Benchmark. check 1.3.2 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.3.2 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.3 CIS Benchmark. check 1.4.1 " {
  echo '.75'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo kube-bench | grep 1.4.1 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.4 CIS Benchmark. check 4.2.6 " {
  echo '.75'>>/var/work/tests/result/all
  worker_node=$(kubectl get no -l work_type=worker --context cluster3-admin@cluster3  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $worker_node "sudo kube-bench | grep 4.2.6 | grep PASS"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '.75'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}