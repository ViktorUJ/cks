#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#1
@test "1. Create a secret secret1 with value key1=value1 in the namespace jellyfish  " {
  echo '2'>>/var/work/tests/result/all
  result=$(kubectl exec app1  -n jellyfish -- sh -c 'echo $PASSWORD'  --context cluster1-admin@cluster1 )
  if [[ "$result" == "value1" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "value1" ]
}

# 2 2

@test "2.1 Create a cron job cron-job1.image  " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec..spec.containers..image}' )
  if [[ "$result" == "viktoruj/ping_pong:alpine" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong:alpine" ]
}

@test "2.2 Create a cron job cron-job1. Concurrency policy  " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.concurrencyPolicy}' )
  if [[ "$result" == "Forbid" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Forbid" ]
}

@test "2.3 Create a cron job cron-job1. Command  " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec..spec.containers..command}' )
  if [[ "$result" == "[\"echo\",\"Hello from CKAD mock\"]" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "[\"echo\",\"Hello from CKAD mock\"]" ]
}


@test "2.4 Create a cron job cron-job1. Run every 15 minutes " {
  echo '0.5'>>/var/work/tests/result/all
  result=$( kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.schedule}' )
  if [[ "$result" == "*/15 * * * *" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "*/15 * * * *" ]
}

@test "2.5 Create a cron job cron-job1. Tolerate 4 failures " {
  echo '0.5'>>/var/work/tests/result/all
  result=$( kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' )
  if [[ "$result" == "4" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "4" ]
}

@test "2.6 Create a cron job cron-job1. Completions 3 times" {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.jobTemplate.spec.completions}')
  if [[ "$result" == "3" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

@test "2.7 Create a cron job cron-job1. imagePullPolicy" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers..imagePullPolicy}')
  if [[ "$result" == "IfNotPresent" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "IfNotPresent" ]
}

@test "3.1 Deployment my-deployment in the namespace baracuda. Rollback deployment " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment  my-deployment -n baracuda    --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..image}')
  if [[ "$result" == "viktoruj/ping_pong" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong" ]
}

@test "3.2 Deployment my-deployment in the namespace baracuda. Replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl  get deployment  my-deployment -n baracuda    --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

@test "4.1 Create deployment  shark-app in the shark namespace. Image " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment  shark-app -n shark   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..image}')
  if [[ "$result" == "viktoruj/ping_pong" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong" ]
}

@test "4.2 Create deployment  shark-app in the shark namespace. Port " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get deployment  shark-app -n shark   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec..ports..containerPort}')
  if [[ "$result" == "8080" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "8080" ]
}

@test "4.3 Create deployment  shark-app in the shark namespace. Environment variable ENV1 = 8080  " {
  echo '0.5'>>/var/work/tests/result/all
  result=$(kubectl  get deployment  shark-app -n shark   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec..env}')
  if [[ "$result" == "[{\"name\":\"ENV1\",\"value\":\"8080\"}]" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "[{\"name\":\"ENV1\",\"value\":\"8080\"}]" ]
}

@test "5 Build container image using given manifest " {
  echo '2'>>/var/work/tests/result/all
  podman image rm localhost/ckad:0.0.1
  podman load -i /var/work/5/5.tar
  podman image ls  | grep ckad| grep '0.0.1'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.1 Update sword-app deployment in the swordfish namespace. user with ID 5000 " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment sword-app  -n swordfish    --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec..securityContext.runAsUser}')
  if [[ "$result" == "5000" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "5000" ]
}

@test "6.2 Update sword-app deployment in the swordfish namespace. restrict privilege escalation " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment sword-app  -n swordfish    --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec..securityContext.allowPrivilegeEscalation}')
  if [[ "$result" == "false" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "false" ]
}

@test "7 Fix app in meg NS . Can access to the app http://ckad.local:30102/app " {
  echo '6'>>/var/work/tests/result/all
  curl http://ckad.local:30102/app  | grep megApp
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '6'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "8  Fix web-app in namespace tuna. It needs  to communicate with mysql-db " {
  echo '4'>>/var/work/tests/result/all
  kubectl exec web-app  -n tuna  -- curl mysql-db:3306 --connect-timeout 1
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "9.1 Deployment main-app in  salmon namespace new version . old  version replicas =7  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment main-app   -n salmon   --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "7" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "7" ]
}

@test "9.2 Deployment main-app in  salmon namespace new version . new  version replicas =3  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment main-app-v2   -n salmon   --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}')
  if [[ "$result" == "3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}



@test "9.3 Deployment main-app in  salmon namespace new version . new  version  image = viktoruj/ping_pong:latest  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment main-app-v2   -n salmon   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..image}')
  if [[ "$result" == "viktoruj/ping_pong:latest" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong:latest" ]
}

@test "9.4 Deployment main-app in  salmon namespace new version . new  version  env SERVER_NAME=appV2  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployment main-app-v2   -n salmon   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..env[?(@.name=="SERVER_NAME")].value}')
  if [[ "$result" == "appV2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "appV2" ]
}

@test "9.5 Deployment main-app in  salmon namespace new version . new  version  labels.app  " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl  get deployment main-app-v2   -n salmon   --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.metadata.labels.app}')
  if [[ "$result" == "main-app" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "main-app" ]
}

# 10
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
# 8