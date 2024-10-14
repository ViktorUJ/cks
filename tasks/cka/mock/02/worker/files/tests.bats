#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1 find a pod in dev-1 namespace with labels `team=finance` and maximum memory usage  " {
  echo '4'>>/var/work/tests/result/all
  result=$(kubectl get po -n dev-1 -l usage=max -o jsonpath='{.items..metadata.name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "pod4" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod4" ]
}

#4 4

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

# 1  5


@test "3. Create a namespace named team-elephant  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ns  team-elephant -o jsonpath={.metadata.name}  --context cluster1-admin@cluster1 )
  if [[ "$result" == "team-elephant" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "team-elephant" ]
}

# 1 6


@test "4. Create pod alpine with image alpine:3.15 and make sure it is running on node with label disk=ssd " {
  echo '2'>>/var/work/tests/result/all
  node=$(kubectl get no -l disk=ssd -o jsonpath={.items..metadata.name} --context cluster1-admin@cluster1 )
  pod_node=$(kubectl get po  alpine -o jsonpath='{.spec.nodeName}' --context cluster1-admin@cluster1 )
  if [[ "$node" == "$pod_node" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$node" == "$pod_node" ]
}

# 2 8


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

# 2 10

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

#3 13

@test "7 Create a pod web-srv based on image viktoruj/ping_pong. Container name " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po web-srv -o jsonpath='{.spec.containers[*].name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == 'app1' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'app1' ]
}

#1 14

@test "8 Scale down number of replicas to 1 redis-node-xxxx " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment redis-node  -n db-redis  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == '1' ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == '1' ]
}

#1 15

@test "9 Write cli commands with shows pods from kube-system namespace in json format" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/9.sh) <(kubectl get po -n dev-2 -o json --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

#1 16

@test "10.1 Create a Persistent Volume. capacity " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.capacity.storage}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "100Mi" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "100Mi" ]
}

@test "10.2 Create a Persistent Volume. hostPath " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.hostPath.path}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "/pv/analytics" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "/pv/analytics" ]
}

@test "10.3 Create a Persistent Volume. check storage " {
  echo '6'>>/var/work/tests/result/all
  kubectl exec analytics   --context cluster1-admin@cluster1  -- sh -c 'echo "analytics">/pv/analytics/test'
  work_node=$(kubectl get no -l node_name=node_2 --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $work_node "sudo cat /pv/analytics/test | grep 'analytics' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '6'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# 8 24


@test "11.1 Update Kubernetes.api version " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  version -o json --context cluster2-admin@cluster2  | jq -r '.serverVersion.gitVersion'       )
  if [[ "$result" == "v1.28.4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.28.4" ]
}

@test "11.2 Update Kubernetes. control-plane kubeletVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items..status.nodeInfo.kubeletVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.28.4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.28.4" ]
}

@test "11.3 Update Kubernetes. control-plane kubeProxyVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items..status.nodeInfo.kubeProxyVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.28.4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.28.4" ]
}

@test "11.4 Update Kubernetes. work node  kubeProxyVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 -o jsonpath='{.items..status.nodeInfo.kubeProxyVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.28.4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.28.4" ]
}


@test "11.5 Update Kubernetes. work node  kubeletVersion " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 -o jsonpath='{.items..status.nodeInfo.kubeletVersion}' --context cluster2-admin@cluster2 )
  if [[ "$result" == "v1.28.4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "v1.28.4" ]
}

@test "11.6 Update Kubernetes.control-plane Ready " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --context cluster2-admin@cluster2 --no-headers | cut -d' ' -f4 )
  if [[ "$result" == "Ready" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Ready" ]
}

@test "11.7 Update Kubernetes.work node is ready " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get nodes -l node_name=node_2 --context cluster2-admin@cluster2 --no-headers | cut -d' ' -f4 )
  if [[ "$result" == "Ready" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Ready" ]
}

#7 31

@test "12.1 Create new ingress . path= cat " {
  echo '2'>>/var/work/tests/result/all
  curl cka.local:30102/cat  | grep 'cat-server'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]

}
@test "12.2 Create new ingress . check rewrite-target " {
  echo '2'>>/var/work/tests/result/all
  curl cka.local:30102/cat
  set +e
  curl cka.local:30102/cat  | grep 'URL' | grep 'cat'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]

}

#4 35

@test "13.1 Create service account with the name pod-sa in  Namespace team-elephant" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get sa  pod-sa -n team-elephant   --context cluster1-admin@cluster1 -o jsonpath='{.metadata.name}' )
  if [[ "$result" == "pod-sa" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa" ]
}

@test "13.2 Create  Role pod-sa-role  resource:pods  " {
  echo '1'>>/var/work/tests/result/all
  kubectl get role pod-sa-role -n team-elephant  -o jsonpath='{.rules[*].resources}' --context cluster1-admin@cluster1 | grep 'pods'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.3 Create  Role pod-sa-role .  verb : list and get" {
  echo '1'>>/var/work/tests/result/all
  kubectl get role pod-sa-role -n team-elephant -o jsonpath='{.rules[*].verbs}' --context cluster1-admin@cluster1 | grep 'list' | grep 'get'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.4 Create RoleBinding pod-sa-roleBinding . sa = pod-sa" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding  pod-sa-roleBinding -n team-elephant -o jsonpath='{.subjects[?(.kind=="ServiceAccount")].name}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "pod-sa" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa" ]
}

@test "13.5 Create RoleBinding pod-sa-roleBinding . roleRef.kind = role " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding  pod-sa-roleBinding -n team-elephant -o jsonpath='{.roleRef.kind}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "Role" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Role" ]
}

@test "13.6 Create RoleBinding pod-sa-roleBinding . roleRef.name = pod-sa-role " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding pod-sa-roleBinding -n team-elephant -o jsonpath='{.roleRef.name}' --context cluster1-admin@cluster1  )
  if [[ "$result" == "pod-sa-role" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa-role" ]
}

@test "13.7 get list pod from pod pod-sa in team-elephant " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec pod-sa  -n team-elephant  --context cluster1-admin@cluster1  -- sh -c 'curl  GET https://kubernetes.default/api/v1/namespaces/team-elephant/pods/  -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.8 get list pod from pod pod-sa in default (forbidden) " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec pod-sa  -n team-elephant  --context cluster1-admin@cluster1  -- sh -c 'curl  GET https://kubernetes.default/api/v1/namespaces/default/pods/  -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k' | grep 'pods is forbidden'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 8 43

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
# 5 48

@test "15.1 collect logs from legacy app . from app1 " {
  echo '3'>>/var/work/tests/result/all
  kubectl exec checker -n legacy -- sh -c 'curl legacy-app:8081/xxxx_test_app1' --context cluster1-admin@cluster1
  sleep 3
  kubectl logs  -l app=legacy-app  -n legacy  -c log --context cluster1-admin@cluster1| grep 'xxxx_test_app1'
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}

@test "15.2 collect logs from legacy app . from app2 " {
  echo '3'>>/var/work/tests/result/all
  kubectl exec checker -n legacy -- sh -c 'curl legacy-app:8082/yyyy_test_app2' --context cluster1-admin@cluster1
  sleep 3
  kubectl logs  -l app=legacy-app  -n legacy  -c log --context cluster1-admin@cluster1| grep 'yyyy_test_app2'
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}


# 6 54

@test "16 Write cli commands with shows the latest events in the whole cluster" {
  echo '2'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/16.sh) <(kubectl get events --sort-by=".metadata.creationTimestamp" -A --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 2 56

@test "17 Write cli commands with show names of all namespaced api resources in Kubernetes cluster" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /var/work/artifact/17.sh) <(kubectl api-resources --namespaced=true --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 1 57

@test "18 Fix cluster 3 .work node is  ready " {
  echo '4'>>/var/work/tests/result/all
  set +e
  kubectl get nodes --context cluster3-admin@cluster3 --no-headers  | grep 'NotReady'
  result=$?
  set -e
  if [[  "$result" != "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" != "0" ]
}

#4 61


@test "19.1 Create static pod stat-podv in the default namespace. Expose it via service stat-pod-svc . Memory = 128Mi " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get po -l run=stat-podv  -o jsonpath='{.items..spec.containers..resources.requests.memory}' --context cluster1-admin@cluster1 )
  if [[ "$result" == '128Mi' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '128Mi' ]
}

@test "19.2 Create static pod stat-podv in the default namespace. Expose it via service stat-pod-svc . Cpu = 100m " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get po -l run=stat-podv  -o jsonpath='{.items..spec.containers..resources.requests.cpu}' --context cluster1-admin@cluster1 )
  if [[ "$result" == '100m' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '100m' ]
}

@test "19.3 Create static pod stat-podv in the default namespace. Expose it via service stat-pod-svc . image  " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get po -l run=stat-podv  -o jsonpath='{.items..spec.containers..image}' --context cluster1-admin@cluster1 )
  if [[ "$result" == 'viktoruj/ping_pong:latest' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == 'viktoruj/ping_pong:latest' ]
}

@test "19.4 Create static pod stat-podv in the default namespace. Expose it via service stat-pod-svc . is pod static   " {
  echo '0.5'>>/var/work/tests/result/all
  controlPlane_name=$(kubectl get no --context cluster1-admin@cluster1 | grep 'control-plane' | cut -d' ' -f1)
  kubectl get po -l run=stat-podv  -o jsonpath='{.items..metadata.name}' --context cluster1-admin@cluster1  | grep $controlPlane_name
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}

@test "19.5 Create static pod stat-podv in the default namespace. Expose it via service stat-pod-svc . curl {controlPlane}:nodePort   " {
  echo '2'>>/var/work/tests/result/all
  controlPlane_name=$(kubectl get no --context cluster1-admin@cluster1 | grep 'control-plane' | cut -d' ' -f1)
  curl $controlPlane_name:30084 | grep 'ping_pong_server'
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}

#4 65

@test "20.1 Take a backup of the etcd cluster.check backup " {
  echo '2'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster4-admin@cluster4  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo ETCDCTL_API=3 etcdctl snapshot status /var/work/tests/artifacts/20/etcd-backup.db"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.2 Take a backup of the etcd cluster.check  restored etcd   " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get secret  etcd-check --context cluster4-admin@cluster4 -o jsonpath='{.data.aa}' | base64 -d)
  if [[ "$result" == "aa" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "aa" ]
}

@test "20.3 Take a backup of the etcd cluster.check  pods  ready in kube-system   " {
  echo '2'>>/var/work/tests/result/all
  all_pods=$(kubectl get po  -n kube-system --no-headers  --context cluster4-admin@cluster4 | wc -l)
  ready_pods=$(kubectl get po  -n kube-system --no-headers  --context cluster4-admin@cluster4 |grep 'Running'| wc -l )

  if [[ "$all_pods" == "$ready_pods" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$all_pods" == "$ready_pods" ]
}

#6 71


@test "21.1 Network policy. can connect from prod NS to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec prod-pod -n prod --context cluster5-admin@cluster5 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "21.2 Network policy. can  connect from stage NS  and  label: role=db-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec db-connect-stage-pod -n stage --context cluster5-admin@cluster5 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "21.3 Network policy. can connect from any Namespaces and have label: role=db-external-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec all-pod-db-external -n user-client --context cluster5-admin@cluster5 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "21.4 Network policy. can't connect from stage NameSpace all pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-stage-pod -n stage  --context cluster5-admin@cluster5 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "21.5 Network policy. can't connect all   pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-pod -n user-client   --context cluster5-admin@cluster5 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
  echo '1'>>/var/work/tests/result/ok
  fi
   (( $result > 0 ))
}

@test "21.6 Network policy. can connect from all    pod   to google.com  " {
  echo '1'>>/var/work/tests/result/all
  set +e && kubectl exec all-pod -n user-client   --context cluster5-admin@cluster5 -- sh -c ' curl https://google.com --connect-timeout 1 -s '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 6 77
