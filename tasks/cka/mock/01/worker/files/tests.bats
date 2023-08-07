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