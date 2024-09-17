#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}



@test "22.1 Update Kubernetes.api version " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  version -o json --context cluster2-admin@cluster2  | jq -r '.serverVersion.gitVersion'       )
  if [[ "$result" == "v1.29.1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.29.1" ]
}

@test "22.2 Update Kubernetes. control-plane kubeletVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items..status.nodeInfo.kubeletVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.29.1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.29.1" ]
}

@test "22.3 Update Kubernetes. control-plane kubeProxyVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items..status.nodeInfo.kubeProxyVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.29.1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.29.1" ]
}

@test "22.4 Update Kubernetes. work node  kubeProxyVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 -o jsonpath='{.items..status.nodeInfo.kubeProxyVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.29.1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.29.1" ]
}


@test "22.5 Update Kubernetes. work node  kubeletVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 -o jsonpath='{.items..status.nodeInfo.kubeletVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.29.1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.29.1" ]
}

@test "22.6 Update Kubernetes.control-plane Ready " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2 --no-headers | cut -d' ' -f4 )
  if [[ "$result" == "Ready" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Ready" ]
}

@test "22.7 Update Kubernetes.work node Ready " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 --context cluster2-admin@cluster2 --no-headers | cut -d' ' -f4 )
  if [[ "$result" == "Ready" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Ready" ]
}

#7 , 73
