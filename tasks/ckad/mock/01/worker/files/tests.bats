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
# 1 1

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
# 1 2

#3
@test "3.1 Create secret and  create pod with  environment variable  from secret. Create a namespace dev-db " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get namespaces dev-db -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "dev-db" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "dev-db" ]
}

@test "3.2 Create secret and  create pod with  environment variable  from secret. Create a secret dbpassword " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get secrets -n dev-db dbpassword -o jsonpath='{.data.pwd}' --context cluster1-admin@cluster1 | base64 --decode )
  if [[ "$result" == "my-secret-pwd" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "my-secret-pwd" ]
}

@test "3.3 Create secret and  create pod with  environment variable  from secret .Create a pod " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod -n dev-db db-pod -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "db-pod" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "db-pod" ]
}

@test "3.4 Create secret and  create pod with  environment variable  from secret .Use environment variable from  secret" {
  echo '1'>>/var/work/tests/result/all
  result=$(echo $(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.key}' --context cluster1-admin@cluster1):$(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}' --context cluster1-admin@cluster1 ))
  if [[ "$result" == "pwd:dbpassword" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pwd:dbpassword" ]
}
# 4  6

#4
@test "4.Fix replicaset. ReplicaSet has 2 ready replicas" {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl get rs rs-app2223 -n rsapp -o jsonpath='{.status.readyReplicas}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "2" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}
# 2 8

#5
@test "5.1 Create deployment msg and service msg-service.Image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps -n messaging msg -o jsonpath='{.spec.template..image}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "redis" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "redis" ]
}

@test "5.2 Create deployment msg and service msg-service.Service type" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get svc msg-service  -n messaging  -o jsonpath='{.spec.type}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "ClusterIP" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "ClusterIP" ]
}

@test "5.3 Create deployment msg and service msg-service.Port" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get svc -n messaging msg-service -o jsonpath='{.spec.ports..port}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "6379" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "6379" ]
}
# 2 10

#6
@test "6 Update environment variable value to GREEN" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pods text-printer  -o jsonpath='{.spec.containers..env..value}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "GREEN" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "GREEN" ]
}
# 1 11

#7
@test "7.1 Run pod appsec-pod.SYS_TIME" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod appsec-pod -o jsonpath='{.spec.containers..capabilities.add[0]}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "SYS_TIME" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "SYS_TIME" ]
}

@test "7.2 Run pod appsec-pod.check user id" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl exec  appsec-pod  --context cluster1-admin@cluster1 -- sh -c 'id' | cut -d' ' -f1)
  if [[ "$result" == "uid=0(root)" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "uid=0(root)" ]
}

@test "7.3 Run pod appsec-pod.image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod appsec-pod -o jsonpath='{.spec.containers..image}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "ubuntu:22.04" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "ubuntu:22.04" ]
}

@test "7.4 Run pod appsec-pod.pod is Running " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod appsec-pod  --context cluster1-admin@cluster1 | grep 'appsec-pod' |cut -d' ' -f9 )
  if [[ "$result" == "Running" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Running" ]
}
# 4 15

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
# 1 16

# 9
@test "9.1 Add a taint to the node .Create a pod with toleration.node taint effect " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get node -l work_type=redis -o jsonpath='{.items..spec.taints..effect}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "NoSchedule" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "NoSchedule" ]
}

@test "9.2 Add a taint to the node .Create a pod with toleration.node taint key" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get node -l work_type=redis -o jsonpath='{.items..spec.taints..key}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "app_type" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "app_type" ]
}

@test "9.3 Add a taint to the node .Create a pod with toleration.node taint valuey" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get node -l work_type=redis -o jsonpath='{.items..spec.taints..value}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "alpha" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "alpha" ]
}

@test "9.4 Check pod tolerations" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pods alpha -o jsonpath='{.spec.tolerations[?(.key == "app_type")].value}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "alpha" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "alpha" ]
}
# 4 20

# 10
@test "10.1 Check controlplane label.app_type" {
  echo '2'>>/var/work/tests/result/all
  node_name=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane)].metadata.name}' --context cluster1-admin@cluster1)
  result=$(kubectl get node $node_name -o jsonpath='{.metadata.labels.app_type}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "beta" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "beta" ]
}

@test "10.2 Check running pods " {
  echo '2'>>/var/work/tests/result/all
  node_name=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane)].metadata.name}' --context cluster1-admin@cluster1)
  result=$(kubectl get po -o wide   --context cluster1-admin@cluster1 | grep 'beta-apps'| grep 'Running' | grep $node_name | wc -l  )
  if [[ "$result" == "3" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}
# 4 24

# 11
@test "11.1 Create new ingress . path= cat " {
  echo '2'>>/var/work/tests/result/all
  curl ckad.local:30102/cat  | grep 'cat-server'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]

}
@test "11.2 Create new ingress . check rewrite-target " {
  echo '2'>>/var/work/tests/result/all
  set +e
  curl ckad.local:30102/cat  | grep 'URL' | grep 'cat'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]

}
# 4 28

# 12
@test "12.1 Create a new pod nginx1233 in the web-ns namespace.command" {
  echo '1'>>/var/work/tests/result/all
  kubectl get pods -n web-ns nginx1233 -o jsonpath='{.spec..livenessProbe.exec.command}' --context cluster1-admin@cluster1 | grep -E "ls.*\/var\/www\/html\/"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "12.2 Create a new pod nginx1233 in the web-ns namespace.delay and period" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod -n web-ns nginx1233 -o json --context cluster1-admin@cluster1 | jq -r '"\(.spec.containers[0].livenessProbe.initialDelaySeconds) \(.spec.containers[0].livenessProbe.periodSeconds)"')
  if [[ "$result" == "10 60" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "10 60" ]
}
# 2 30


# 13
@test "13.1 Create a new job hi-job.Image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get jobs.batch hi-job -o jsonpath='{.spec..image}' --context cluster1-admin@cluster1)
  if [[ "$result" == "busybox" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "busybox" ]
}

@test "13.2 Create a new job hi-job.Command" {
  echo '1'>>/var/work/tests/result/all
  pod=$( kubectl get po --context cluster1-admin@cluster1 | grep hi-job | tail -1 | cut -d' ' -f1)
  kubectl logs $pod  --context cluster1-admin@cluster1 | grep -E "hello world"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.3 Create a new job hi-job.backoffLimit and completions" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get job hi-job -o json --context cluster1-admin@cluster1 | jq -r '"\(.spec.backoffLimit) \(.spec.completions)"')
  if [[ "$result" == "6 3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "6 3" ]
}
# 3 33

# 14
@test "14.1 Create a new pod alpha container.Image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod multi-pod -o jsonpath='{.spec.containers[?(@.name=="alpha")].image}' --context cluster1-admin@cluster1)
  if [[ "$result" == "nginx:alpine-slim" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:alpine-slim" ]
}

@test "14.2 Create a new pod alpha container.Env" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod multi-pod -o jsonpath='{.spec.containers[?(@.name=="alpha")].env[?(@.name=="type")].value}' --context cluster1-admin@cluster1)
  if [[ "$result" == "alpha" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "alpha" ]
}

@test "14.3 Create new pod beta container.Image" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod multi-pod -o jsonpath='{.spec.containers[?(@.name=="beta")].image}' --context cluster1-admin@cluster1)
  if [[ "$result" == "busybox" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "busybox" ]
}

@test "14.4 Create new pod beta container.Command" {
  echo '0.5'>>/var/work/tests/result/all
  kubectl get pod multi-pod -o jsonpath='{.spec.containers[?(@.name=="beta")].command}' --context cluster1-admin@cluster1 | grep -E "sleep.*4800"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "14.5 Create new pod beta container.Env" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get pod multi-pod -o jsonpath='{.spec.containers[?(@.name=="beta")].env[?(@.name=="type")].value}' --context cluster1-admin@cluster1)
  if [[ "$result" == "beta" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "beta" ]
}
# 4 37

# 15
@test "15.1 Create a Persistent Volume. capacity " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.capacity.storage}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "100Mi" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "100Mi" ]
}

@test "15.2 Create a Persistent Volume. hostPath " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pv pv-analytics -o jsonpath='{.spec.hostPath.path}'  --context cluster1-admin@cluster1  )
  if [[ "$result" == "/pv/analytics" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "/pv/analytics" ]
}

@test "15.3 Create a Persistent Volume. check storage " {
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
# 8 45

# 16
@test "16.1 Check CRD.group" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.group}' --context cluster1-admin@cluster1)
  if [[ "$result" == "stable.example.com" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "stable.example.com" ]
}

@test "16.2 Check CRD Scheme.name" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.versions..openAPIV3Schema..spec.properties.name.type}' --context cluster1-admin@cluster1)
  if [[ "$result" == "string" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "string" ]
}

@test "16.3 Check CRD Scheme.email" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.versions..openAPIV3Schema..spec.properties.email.type}' --context cluster1-admin@cluster1)
  if [[ "$result" == "string" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "string" ]
}

@test "16.4 Check CRD Scheme.age" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.versions..openAPIV3Schema..spec.properties.age.type}' --context cluster1-admin@cluster1)
  if [[ "$result" == "integer" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "integer" ]
}

@test "16.5 Check CRD names.kind" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.names.kind}' --context cluster1-admin@cluster1)
  if [[ "$result" == "Operator" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Operator" ]
}

@test "16.6 Check CRD names.plural" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.names.plural}' --context cluster1-admin@cluster1)
  if [[ "$result" == "operators" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "operators" ]
}

@test "16.7 Check CRD names.singular" {
  echo '0.25'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.names.singular}' --context cluster1-admin@cluster1)
  if [[ "$result" == "operator" ]]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ "$result" == "operator" ]
}

@test "16.8 Check CRD names.shortNames" {
  echo '0.25'>>/var/work/tests/result/all
  result=$(kubectl get crd operators.stable.example.com -o jsonpath='{.spec.names.shortNames[]}' --context cluster1-admin@cluster1)
  if [[ "$result" == "op" ]]; then
   echo '0.25'>>/var/work/tests/result/ok
  fi
  [ "$result" == "op" ]
}
# 6 51

# 17
@test "17.1 Check command to check CPU and Mem of the nodes" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /opt/18/nodes.txt) <(kubectl top nodes --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "17.2 Check command to check pod CPU and Mem sorted by cpu consumtion" {
  echo '1'>>/var/work/tests/result/all
  diff <(bash /opt/18/pods.txt) <(kubectl top pod --all-namespaces --sort-by cpu --context cluster1-admin@cluster1)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
# 2 53

# 18
@test "18 Check installed helm chart" {
  echo '4'>>/var/work/tests/result/all
  result=$(helm get metadata prom -n monitoring -o json  --kube-context cluster1-admin@cluster1  | jq -r '"\(.name) \(.chart) \(.status)"')
  if [[ "$result" == "prom kube-prometheus-stack deployed" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "prom kube-prometheus-stack deployed" ]
}
# 4 58
