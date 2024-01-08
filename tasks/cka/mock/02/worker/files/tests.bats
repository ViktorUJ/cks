#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}


@test "2.1 Deploy a util pod. Image " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get po util -n dev  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "busybox:1.36" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "busybox:1.36" ]
}

@test "2.2 Deploy a util pod. command " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get po util -n dev  -o jsonpath='{.spec.containers..command}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == '["sleep","3600"]' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '["sleep","3600"]' ]
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


@test "5.1 Create deployment web-app. Image " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  web-app  -o jsonpath='{.spec..containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "viktoruj/ping_pong:latest" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong:latest" ]
}

@test "5.2 Create a deployment named hr-web-app.Replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  web-app  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}


@test "7 Create a pod web-srv based on image viktoruj/ping_pong. Container name " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po web-srv -o jsonpath='{.spec.containers[*].name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'app1' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'app1' ]
}

@test "14.1 Create a DaemonSet named team-elephant-ds . is running on all nodes ( control-plane too ) " {
  echo '1'>>/var/work/tests/result/all
  nodes=$(kubectl  get no --context cluster1-admin@cluster1 | grep ip| wc -l )
  pods=$(kubectl  get po -n team-elephant --context cluster1-admin@cluster1 |grep 'team-elephant-ds' | grep  Running | wc -l )
  if [[ "$nodes" == "$pods" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$nodes" == "$pods" ]
}
