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
  [ "$result" == "2" ]
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
  result=$(kubectl get svc  hr-web-app -o  jsonpath='{.spec.type}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "NodePort" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "NodePort" ]
}


@test "11.2 Expose the hr-web-app as service.NodePort " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  hr-web-app -o jsonpath='{.spec.ports..nodePort}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "30082" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "30082" ]
}

@test "11.3 Expose the hr-web-app as service. target Port " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get svc  hr-web-app -o jsonpath='{.spec.ports..targetPort}'  --context cluster1-admin@cluster1  )
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
  ssh -oStrictHostKeyChecking=no $control_plane_node "sudo etcdutl snapshot status /var/work/tests/artifacts/13/etcd-backup.db"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# 3 , 33