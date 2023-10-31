#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#1
@test "1. Deploy a pod named webhttpd  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po webhttpd -n apx-z993845  -o jsonpath='{.spec.containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "httpd:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "httpd:alpine" ]
}

#2
@test "2.1 Create a deployment named hr-web-app.Image " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get deployment  nginx-app  -o jsonpath='{.spec..containers..image}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "nginx:alpine-slim" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:alpine-slim" ]
}

@test "2.2 Create a deployment named hr-web-app.Replicas " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get deployment  nginx-app  -o jsonpath='{.spec.replicas}'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

#3
@test "3.1 Create a namespace named dev-db " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get namespaces dev-db -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "dev-db" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "dev-db" ]
}

@test "3.2 Create a secret named dbpassword with key.pwd and pwd.my-secret-pw " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get secrets -n dev-db dbpassword -o jsonpath='{.data.pwd}' --context cluster1-admin@cluster1 | base64 --decode )
  if [[ "$result" == "my-secret-pw" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "my-secret-pw" ]
}

@test "3.3 Create a pod with proper name and in the right namespace." {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod -n dev-db db-pod -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "db-pod" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "db-pod" ]
}

@test "3.4 Use environment variable as a secret" {
  echo '1'>>/var/work/tests/result/all
  result=$(echo $(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.key}' --context cluster1-admin@cluster1):$(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}' --context cluster1-admin@cluster1 ))
  if [[ "$result" == "pwd:dbpassword" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pwd:dbpassword" ]
}

#4
@test "4. ReplicaSet has 2 ready replicas" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get rs rs-app2223 -n rsapp -o jsonpath='{.status.readyReplicas}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

#5 
@test "5.1 Deployment msg was created.Image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps -n messaging msg -o jsonpath='{.spec.template..image}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "redis" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "redis" ]
}

@test "5.2 Create a service msg-service.Type" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get svc -n messaging msg-service -o jsonpath='{.spec.type}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "ClusterIP" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "ClusterIP" ]
}

@test "5.3 Create a service msg-service.Port" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(k get svc -n messaging msg-service -o jsonpath='{.spec.ports..port}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "6379" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "6379" ]
}

#6
@test "6 Update environment variable value to GREEN" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pods text-printer  -o jsonpath='{.spec.containers..env..value}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "GREEN" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "GREEN" ]
}

#7
@test "7.1 Check pod capability.SYS_TIME" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod appsec-pod -o jsonpath='{.spec.containers..capabilities.add[0]}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "SYS_TIME" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "SYS_TIME" ]
}

# 8
@test "8. Check logs from pod app-xyz3322" {
  echo '1'>>/var/work/tests/result/all
  grep "app-xyz3322" /opt/logs/app-xyz123.log
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

#9
#Update from controlplane to node 01
@test "9.1 Check controlplane taint" {
  echo '1'>>/var/work/tests/result/all
  node_name=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane)].metadata.name}'  --context cluster1-admin@cluster1)
  result=$(kubectl get node $node_name -o jsonpath='{.spec.taints[?(.key == "app_type")].value}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "alpha" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "alpha" ]
}

