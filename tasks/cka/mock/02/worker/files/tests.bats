#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1 find a pod in dev-1 namespace with labels `team=finance` and maximum memory usage  " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po -n dev-1 -l usage=max -o jsonpath='{.items..metadata.name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "pod4" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod4" ]
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




@test "3. Create a namespace named team-elephant  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ns  team-elephant -o jsonpath={.metadata.name}  --context cluster1-admin@cluster1 )
  if [[ "$result" == "team-elephant" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "team-elephant" ]
}

@test "4. Create pod alpine with image alpine:3.15 and make sure it is running on node with label disk=ssd " {
  echo '2'>>/var/work/tests/result/all
  node=$(kubectl get no -l disk=ssd -o jsonpath={.items..metadata.name} --context cluster1-admin@cluster1 )
  pod_node=$(kubectl get po  alpine -o jsonpath='{.spec.nodeName}' --context cluster1-admin@cluster1 )
  if [[ "$node" == "$pod_node" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$node" == "$pod_node" ]
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


@test "6.1 Create a service web-app-svc to expose the web-app deployment on port 8080 on cluster nodes . selector " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc web-app-svc -n dev-2 -o jsonpath='{..selector.app}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'web-app' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'web-app' ]
}

@test "6.2 Create a service web-app-svc to expose the web-app deployment on port 8080 on cluster nodes . port " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc web-app-svc -n dev-2 -o jsonpath='{..ports..port}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == '8080' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == '8080' ]
}

@test "6.3 Create a service web-app-svc to expose the web-app deployment on port 8080 on cluster nodes . type " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc web-app-svc -n dev-2 -o jsonpath='{..spec.type}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'NodePort' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'NodePort' ]
}

@test "7 Create a pod web-srv based on image viktoruj/ping_pong. Container name " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po web-srv -o jsonpath='{.spec.containers[*].name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'app1' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'app1' ]
}

@test "8 Scale down number of replicas to 1 redis-node-xxxx " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment redis-node  -n db-redis  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == '1' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == '1' ]
}


@test "9 Write cli commands with shows pods from all namespaces in json format" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/9.sh) <(kubectl get po -A  -o json --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
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

@test "14.2 Create a DaemonSet named team-elephant-ds . ds  label team=team-elephant" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath='{.metadata.labels.team}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'team-elephant' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'team-elephant' ]
}

@test "14.3 Create a DaemonSet named team-elephant-ds . ds  label env=dev" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath='{.metadata.labels.env}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'dev' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'dev' ]
}

@test "14.4 Create a DaemonSet named team-elephant-ds . po  label team=team-elephant" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath={.spec.template.metadata.labels.team}  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'team-elephant' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'team-elephant' ]
}
@test "14.5 Create a DaemonSet named team-elephant-ds . po  label env=dev" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath={.spec.template.metadata.labels.env}  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'dev' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'dev' ]
}

@test "14.6 Create a DaemonSet named team-elephant-ds . image = viktoruj/ping_pong" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath='{.spec.template.spec.containers..image}' --context cluster1-admin@cluster1 )
  if [[ "$result" == 'viktoruj/ping_pong' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'viktoruj/ping_pong' ]
}

@test "14.7 Create a DaemonSet named team-elephant-ds . requests CPU= 50m" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath='{.spec.template.spec.containers..resources.requests.cpu}' --context cluster1-admin@cluster1 )
  if [[ "$result" == '50m' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '50m' ]
}

@test "14.8 Create a DaemonSet named team-elephant-ds . requests Memory = 50Mi " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get ds  team-elephant-ds -n team-elephant  -o jsonpath='{.spec.template.spec.containers..resources.requests.memory}' --context cluster1-admin@cluster1 )
  if [[ "$result" == '50Mi' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '50Mi' ]
}
# 5 xxxx

@test "16 Write cli commands with shows the latest events in the whole cluster" {
  echo '2'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/16.sh) <(kubectl get events --sort-by=".metadata.creationTimestamp" -A --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 2

@test "17 Write cli commands with show names of all namespaced api resources in Kubernetes cluster" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/17.sh) <(kubectl api-resources --namespaced=true --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 1
