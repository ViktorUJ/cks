#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1. Deploy a pod named nginx-pod using the nginx:alpine image " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po nginx-pod  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "nginx:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:alpine" ]
}

# 1 ,  1

@test "2.1 Deploy a messaging pod using the redis:alpine image with the labels set to tier=msg . image " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po messaging  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "redis:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "redis:alpine" ]
}
# 1  , 2

@test "2.2 Deploy a messaging pod using the redis:alpine image with the labels set to tier=msg . label " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po messaging  -o  jsonpath='{.metadata.labels.tier}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "msg" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "msg" ]
}

# 1 , 3

@test "3 Create a namespace named apx-x9984574 " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ns  apx-x9984574  -o  jsonpath='{.metadata.name}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "apx-x9984574" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "apx-x9984574" ]
}

# 1 , 4

@test "4 Get the list of nodes in JSON format " {
  echo '2'>>/var/work/tests/result/all
  result=$(cat /var/work/tests/artifacts/4/nodes.json |  jq -r '.items[].kind' | uniq )
  if [[ "$result" == "Node" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Node" ]
}

# 2, 6

@test "5.1 Create a service messaging-service.Port " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  messaging-service  -o  jsonpath='{.spec.ports..port}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "6379" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "6379" ]
}

@test "5.2 Create a service messaging-service.Type " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  messaging-service  -o jsonpath='{.spec.type}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "ClusterIP" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "ClusterIP" ]
}

# 2, 8


@test "6.1 Create a deployment named hr-web-app.Image " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  hr-web-app  -o jsonpath='{.spec..containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "nginx:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:alpine" ]
}

@test "6.2 Create a deployment named hr-web-app.Replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  hr-web-app  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

# 2 , 10

@test "7 Create a static pod named static-busybox  " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po -l pod-type=static-pod -o jsonpath='{.items..metadata.annotations.kubernetes\.io/config\.source}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "file" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "file" ]
}

# 2 , 12

@test "8 Create a POD in the finance namespace named temp-bus   " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po temp-bus -n finance   -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "redis:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "redis:alpine" ]
}

# 1 , 13

@test "9 Use JSON PATH query to retrieve the osImages " {
  echo '3'>>/var/work/tests/result/all
  result=$(cat /var/work/tests/artifacts/9/os.json | grep 'Ubuntu 20.04.6 LTS' | wc -l)
  if [[ "$result" == "2" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

# 3 , 16


@test "10.1 Create a pod called multi-pod with two containers.Container alpha  image   " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po multi-pod   -o jsonpath='{.spec.containers[?(.name=="alpha")].image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "nginx" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx" ]
}

@test "10.2 Create a pod called multi-pod with two containers.Container alpha    variable  name" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po multi-pod   -o jsonpath='{.spec.containers[?(.name=="alpha")].env[?(.name=="name")].value}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "alpha" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "alpha" ]
}

@test "10.3 Create a pod called multi-pod with two containers.Container beta  image   " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po multi-pod   -o jsonpath='{.spec.containers[?(.name=="beta")].image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "busybox" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "busybox" ]
}

@test "10.4 Create a pod called multi-pod with two containers.Container beta variable  name" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po multi-pod   -o jsonpath='{.spec.containers[?(.name=="beta")].env[?(.name=="name")].value}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "beta" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "beta" ]
}

@test "10.5 Create a pod called multi-pod with two containers. pod   phase  = Running" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po multi-pod --context cluster1-admin@cluster1 | grep multi-pod | cut -d' ' -f9 )
  if [[ "$result" == "Running" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Running" ]
}


# 5 , 21


@test "11.1 Expose the hr-web-app as service.Type " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  hr-web-app-service -o  jsonpath='{.spec.type}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "NodePort" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "NodePort" ]
}


@test "11.2 Expose the hr-web-app as service.NodePort " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  hr-web-app-service -o jsonpath='{.spec.ports..nodePort}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "30082" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "30082" ]
}

@test "11.3 Expose the hr-web-app as service. target Port " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  hr-web-app-service -o jsonpath='{.spec.ports..targetPort}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "80" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "80" ]
}


# 3 , 24

@test "12.1 Create a Persistent Volume. capacity " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.capacity.storage}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "100Mi" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "100Mi" ]
}

@test "12.2 Create a Persistent Volume. hostPath " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.hostPath.path}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "/pv/analytics" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "/pv/analytics" ]
}

@test "12.3 Create a Persistent Volume. check storage " {
  echo '4'>>/var/work/tests/result/all
  kubectl exec analytics   --context cluster1-admin@cluster1  -- sh -c 'echo "analytics">/pv/analytics/test'
  work_node=$(kubectl get no -l node_name=node_2 --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $work_node "sudo cat /pv/analytics/test | grep 'analytics' "
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 6 , 30

@test "13 Take a backup of the etcd cluster " {
  echo '3'>>/var/work/tests/result/all
  control_plane_node=$(kubectl get no -l node-role.kubernetes.io/control-plane --context cluster1-admin@cluster1  -o jsonpath='{.items..metadata.name}')
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo ETCDCTL_API=3 etcdctl snapshot status /var/work/tests/artifacts/13/etcd-backup.db"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 3 , 33


@test "14.1 Create a Pod called redis-storage.volume_type_sizeLimit " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po  redis-storage -o jsonpath='{.spec.volumes[?(.name=="data")].emptyDir.sizeLimit}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "500Mi" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "500Mi" ]
}

@test "14.2 Create a Pod called redis-storage.volumeMounts_mountPath " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get po  redis-storage -o jsonpath='{.spec.containers[?(.name=="redis-storage")].volumeMounts[?(.name=="data")].mountPath}' --context cluster1-admin@cluster1  )
  if [[ "$result" == "/data/redis" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "/data/redis" ]
}

# 4 , 37

@test "15 Create a new pod called super-user-pod " {
  echo '2'>>/var/work/tests/result/all
  kubectl get po  super-user-pod -o jsonpath='{.spec.containers[?(.name=="super-user-pod")].securityContext.capabilities.add}' --context cluster1-admin@cluster1 | grep 'SYS_TIME'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 2 , 39

@test "16 Create a new deployment called nginx-deploy .  rollout history " {
  echo '3'>>/var/work/tests/result/all
  kubectl  rollout history deployment nginx-deploy --revision 2 --context cluster1-admin@cluster1 | grep Image| grep nginx:1.17
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 3 , 42


@test "17.1 Create a new user called john. csr " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get csr  john-developer -o jsonpath='{.status.conditions..type}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "Approved" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Approved" ]
}

@test "17.2 Create a new user called john. role exist " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get role developer -n development -o jsonpath={.metadata.name}  --context cluster1-admin@cluster1 )
  if [[ "$result" == "developer" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "developer" ]
}

@test "17.3 Create a new user called john. rolebinding exist" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get rolebinding developer-role-binding  -n development -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "developer-role-binding" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "developer-role-binding" ]
}


@test "17.4 Create a new user called john. permission pod - create " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl auth can-i create pods --as=john --namespace=development  --context cluster1-admin@cluster1 )
  if [[ "$result" == "yes" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}

@test "17.5 Create a new user called john. permission pod - list " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl auth can-i list pods --as=john --namespace=development  --context cluster1-admin@cluster1 )
  if [[ "$result" == "yes" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}

@test "17.6 Create a new user called john. permission pod - get " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl auth can-i get pods --as=john --namespace=development  --context cluster1-admin@cluster1 )
  if [[ "$result" == "yes" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "yes" ]
}

@test "17.7 Create a new user called john. permission pod - delete " {
  echo '0.5'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i delete pods --as=john --namespace=development  --context cluster1-admin@cluster1 )
  set -e
  if [[ "$result" == "no" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "no" ]
}

@test "17.8 Create a new user called john. permission pod - update " {
  echo '0.5'>>/var/work/tests/result/all
  set +e
  result=$(kubectl auth can-i update pods --as=john --namespace=development  --context cluster1-admin@cluster1 )
  set -e
  if [[ "$result" == "no" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "no" ]
}

# 6 , 48


@test "18.1 Create service account with the name pvviewer, clusterrole,pod .sa " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get sa  pvviewer  --context cluster1-admin@cluster1 -o jsonpath='{.metadata.name}' )
  if [[ "$result" == "pvviewer" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pvviewer" ]
}

@test "18.2 Create service account with the name pvviewer, clusterrole,pod . clusterrole_resources " {
  echo '1'>>/var/work/tests/result/all
  kubectl get ClusterRole pvviewer-role -o jsonpath='{.rules[*].resources}' --context cluster1-admin@cluster1 | grep 'persistentvolumes'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "18.3 Create service account with the name pvviewer, clusterrole,pod . clusterrole_verbs " {
  echo '0.5'>>/var/work/tests/result/all
  kubectl get ClusterRole pvviewer-role -o jsonpath='{.rules[*].verbs}' --context cluster1-admin@cluster1 | grep 'list'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "18.4 Create service account with the name pvviewer, clusterrole,pod . rrolebinding_sa " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get  clusterrolebinding  pvviewer-role-binding -o jsonpath='{.subjects[?(.kind=="ServiceAccount")].name}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "pvviewer" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pvviewer" ]
}

@test "18.5 Create service account with the name pvviewer, clusterrole,pod . rolebinding_roleRef_kind " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get  clusterrolebinding  pvviewer-role-binding -o jsonpath='{.roleRef.kind}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "ClusterRole" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "ClusterRole" ]
}

@test "18.6 Create service account with the name pvviewer, clusterrole,pod . rolebinding_roleRef_name " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get  clusterrolebinding pvviewer-role-binding -o jsonpath='{.roleRef.name}' --context cluster1-admin@cluster1  )
  if [[ "$result" == "pvviewer-role" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pvviewer-role" ]
}

@test "18.7 Create service account with the name pvviewer, clusterrole,pod . list pv from  pod " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec pvviewer --context cluster1-admin@cluster1  -- sh -c 'curl https://kubernetes.default/api/v1/persistentvolumes/pv-18  -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k' | grep path | grep "/tmp/pv-18"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 5 , 53

@test "19.1 Create a Pod called non-root-pod .runAsUser " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get po  non-root-pod -o jsonpath='{.spec.securityContext.runAsUser}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "1000" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1000" ]
}

@test "19.2 Create a Pod called non-root-pod .fsGroup " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get po  non-root-pod -o jsonpath='{.spec.securityContext.fsGroup}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "2000" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2000" ]
}

#2 , 55


@test "20.1 Create  secret , configmap . create pod with mount secret and configmap. secret exist " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get secrets -n prod-apps prod-secret -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "prod-secret" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "prod-secret" ]
}

@test "20.2 Create  secret , configmap . create pod with mount secret and configmap. configmap exist " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get configmap -n prod-apps prod-config -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "prod-config" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "prod-config" ]
}

@test "20.3 Create  secret , configmap . create pod with mount secret and configmap. phase  = Running  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app2 --context cluster1-admin@cluster1 -- sh -c  'cat  /app/secrets/var2' | grep 'bbb'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.4 Create  secret , configmap . create pod with mount secret and configmap. container1 /app/configs " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app1 --context cluster1-admin@cluster1 -- sh -c  'cat /app/configs/config.yaml' | grep 'test config'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.5 Create  secret , configmap . create pod with mount secret and configmap. container1 env var1 " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app1 --context cluster1-admin@cluster1 -- sh -c  'echo $var1' | grep 'aaa'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.6 Create  secret , configmap . create pod with mount secret and configmap. container1 env var2 " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app1 --context cluster1-admin@cluster1 -- sh -c  'echo $var2' | grep 'bbb'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.7 Create  secret , configmap . create pod with mount secret and configmap. container2 /app/secrets/var1 " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app2 --context cluster1-admin@cluster1 -- sh -c  'cat  /app/secrets/var1' | grep 'aaa'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20.8 Create  secret , configmap . create pod with mount secret and configmap. container2 /app/secrets/var2 " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec prod-app  -n prod-apps -c app2 --context cluster1-admin@cluster1 -- sh -c  'cat  /app/secrets/var2' | grep 'bbb'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


# 8, 63

@test "21.1 Resolve dns  svc and pod . pod  " {
  echo '1.5'>>/var/work/tests/result/all
  set +e
  podip=$( kubectl get po nginx-resolver -o jsonpath='{.status.podIP}' --context cluster1-admin@cluster1  )
  pod_ip=$( kubectl get po nginx-resolver -o jsonpath='{.status.podIP}' --context cluster1-admin@cluster1  | sed 's/\./-/g' )
  cat /var/work/tests/artifacts/21/nginx.pod |  grep "$pod_ip" | grep "$podip"
  result=$?
  set -e
  if [[ "$result" == "0" ]]; then
   echo '1.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "21.2 Resolve dns  svc and pod . svc  " {
  echo '1.5'>>/var/work/tests/result/all
  set +e
  svcip=$( kubectl get svc nginx-resolver-service -o jsonpath='{.spec.clusterIP}' --context cluster1-admin@cluster1  )
  svc="nginx-resolver-service.default.svc.cluster.local"
  cat /var/work/tests/artifacts/21/nginx.svc  |  grep "$svc" | grep "$svcip"
  result=$?
  set -e
  if [[ "$result" == "0" ]]; then
   echo '1.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

#3 , 66

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

##

@test "23.1 Network policy. can connect from prod NS to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec prod-pod -n prod --context cluster1-admin@cluster1 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "23.2 Network policy. can  connect from stage NS  and  label: role=db-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec db-connect-stage-pod -n stage --context cluster1-admin@cluster1 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "23.3 Network policy. can connect from any Namespaces and have label: role=db-external-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec all-pod-db-external -n user-client --context cluster1-admin@cluster1 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "23.4 Network policy. can't connect from stage NameSpace all pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-stage-pod -n stage  --context cluster1-admin@cluster1 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "23.5 Network policy. can't connect all   pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-pod -n user-client   --context cluster1-admin@cluster1 -- sh -c ' curl mysql.prod-db.svc --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
  echo '1'>>/var/work/tests/result/ok
  fi
   (( $result > 0 ))
}

@test "23.6 Network policy. can connect from all    pod   to google.com  " {
  echo '1'>>/var/work/tests/result/all
  set +e && kubectl exec all-pod -n user-client   --context cluster1-admin@cluster1 -- sh -c ' curl https://google.com --connect-timeout 1 -s '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 6, 79


@test "24 create daemonset on all nodes ( control-plane too ) " {
  echo '6'>>/var/work/tests/result/all
  nodes=$(kubectl  get no --context cluster1-admin@cluster1 | grep ip| wc -l )
  pods=$(kubectl  get po -n app-system --context cluster1-admin@cluster1 | grep  Running | wc -l )
  result=$?
  if [[ "$nodes" == "$pods" ]]; then
   echo '6'>>/var/work/tests/result/ok
  fi
  [ "$nodes" == "$pods" ]
}

# 6, 85

@test "25.1 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . deployment_replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps  important-app2 -n app2-system  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

@test "25.2 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . PodDisruptionBudget min available  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get poddisruptionbudgets.policy -n app2-system important-app2 --context cluster1-admin@cluster1 -o jsonpath='{.spec.minAvailable}' )
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "25.3 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . PodDisruptionBudget selector  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get poddisruptionbudgets.policy -n app2-system important-app2 --context cluster1-admin@cluster1 -o jsonpath='{.spec.selector.matchLabels.app}' )
  if [[ "$result" == "important-app2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "important-app2" ]
}

@test "25.4 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . deployment  PodAntiAffinity topologyKey" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps  important-app2 -n app2-system  -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution..topologyKey}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "kubernetes.io/hostname" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "kubernetes.io/hostname" ]
}

@test "25.5 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . deployment  tolerations key" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps  important-app2 -n app2-system  -o jsonpath='{.spec.template.spec.tolerations..key}'  --context cluster1-admin@cluster1)
  if [[ "$result" == "node-role.kubernetes.io/control-plane" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "node-role.kubernetes.io/control-plane" ]
}

@test "25.6 create deployment  and spread them on all nodes( control-plane too )+ PodDisruptionBudget . pod by node" {
  echo '3'>>/var/work/tests/result/all
  result=$(kubectl get po -n app2-system -o wide --context cluster1-admin@cluster1 | grep Running|  grep ip  | cut -d' ' -f25 | uniq  |wc -l)
  if [[ "$result" == "3" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

# 8, 93
