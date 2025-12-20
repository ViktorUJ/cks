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

@test "2.8 Create a cron job cron-job1. failedJobsHistoryLimit" {
  echo '0.5'>>/var/work/tests/result/all
  result=$( kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.failedJobsHistoryLimit}')
  if [[ "$result" == "7" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "7" ]
}

@test "2.9 Create a cron job cron-job1. successfulJobsHistoryLimit" {
  echo '0.5'>>/var/work/tests/result/all
  result=$( kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.successfulJobsHistoryLimit}')
  if [[ "$result" == "5" ]]; then
   echo '0.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "5" ]
}

@test "2.10 Create a cron job cron-job1. activeDeadlineSeconds" {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl  get cronjobs.batch  cron-job1 -n rnd  --context cluster1-admin@cluster1 -o jsonpath='{.spec.jobTemplate.spec.activeDeadlineSeconds}')
  if [[ "$result" == "10" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "10" ]
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
  podman load -i /var/work/5/ckad.tar
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


@test "11.1 Create secret and  create pod with  environment variable  from secret. Create a namespace dev-db " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get namespaces dev-db -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "dev-db" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "dev-db" ]
}

@test "11.2 Create secret and  create pod with  environment variable  from secret. Create a secret dbpassword " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get secrets -n dev-db dbpassword -o jsonpath='{.data.pwd}' --context cluster1-admin@cluster1 | base64 --decode )
  if [[ "$result" == "my-secret-pwd" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "my-secret-pwd" ]
}

@test "11.3 Create secret and  create pod with  environment variable  from secret .Create a pod " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod -n dev-db db-pod -o jsonpath='{.metadata.name}' --context cluster1-admin@cluster1 )
  if [[ "$result" == "db-pod" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "db-pod" ]
}

@test "11.4 Create secret and  create pod with  environment variable  from secret .Use environment variable from  secret" {
  echo '1'>>/var/work/tests/result/all
  result=$(echo $(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.key}' --context cluster1-admin@cluster1):$(kubectl get pod -n dev-db db-pod -o jsonpath='{.spec.containers[0].env[?(@.name=="MYSQL_ROOT_PASSWORD")].valueFrom.secretKeyRef.name}' --context cluster1-admin@cluster1 ))
  if [[ "$result" == "pwd:dbpassword" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pwd:dbpassword" ]
}

@test "12. Check logs from pod app-xyz3322" {
  echo '1'>>/var/work/tests/result/all
  grep "app-xyz3322" /opt/logs/app-xyz123.log
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

# 13
@test "13.1 Create a new pod nginx1233 in the web-ns namespace.command" {
  echo '1'>>/var/work/tests/result/all
  kubectl get pods -n web-ns nginx1233 -o jsonpath='{.spec..livenessProbe.exec.command}' --context cluster1-admin@cluster1 | grep -E "ls.*\/var\/www\/html\/"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "13.2 Create a new pod nginx1233 in the web-ns namespace.delay and period" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get pod -n web-ns nginx1233 -o json --context cluster1-admin@cluster1 | jq -r '"\(.spec.containers[0].livenessProbe.initialDelaySeconds) \(.spec.containers[0].livenessProbe.periodSeconds)"')
  if [[ "$result" == "10 60" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "10 60" ]
}


@test "14 Check installed helm chart" {
  echo '4'>>/var/work/tests/result/all
  result=$(helm get metadata prom -n monitoring -o json  --kube-context cluster1-admin@cluster1  | jq -r '"\(.name) \(.chart) \(.status)"')
  if [[ "$result" == "prom kube-prometheus-stack deployed" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "prom kube-prometheus-stack deployed" ]
}

# 4

@test "15.1 Create service account with the name pod-sa in  Namespace team-elephant" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get sa  pod-sa -n team-elephant   --context cluster1-admin@cluster1 -o jsonpath='{.metadata.name}' )
  if [[ "$result" == "pod-sa" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa" ]
}

@test "15.2 Create  Role pod-sa-role  resource:pods  " {
  echo '1'>>/var/work/tests/result/all
  kubectl get role pod-sa-role -n team-elephant  -o jsonpath='{.rules[*].resources}' --context cluster1-admin@cluster1 | grep 'pods'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.3 Create  Role pod-sa-role .  verb : list and get" {
  echo '1'>>/var/work/tests/result/all
  kubectl get role pod-sa-role -n team-elephant -o jsonpath='{.rules[*].verbs}' --context cluster1-admin@cluster1 | grep 'list' | grep 'get'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.4 Create RoleBinding pod-sa-roleBinding . sa = pod-sa" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding  pod-sa-roleBinding -n team-elephant -o jsonpath='{.subjects[?(.kind=="ServiceAccount")].name}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "pod-sa" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa" ]
}

@test "15.5 Create RoleBinding pod-sa-roleBinding . roleRef.kind = role " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding  pod-sa-roleBinding -n team-elephant -o jsonpath='{.roleRef.kind}' --context cluster1-admin@cluster1   )
  if [[ "$result" == "Role" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "Role" ]
}

@test "15.6 Create RoleBinding pod-sa-roleBinding . roleRef.name = pod-sa-role " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  rolebinding pod-sa-roleBinding -n team-elephant -o jsonpath='{.roleRef.name}' --context cluster1-admin@cluster1  )
  if [[ "$result" == "pod-sa-role" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "pod-sa-role" ]
}

@test "15.7 get list pod from pod pod-sa in team-elephant " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec pod-sa  -n team-elephant  --context cluster1-admin@cluster1  -- sh -c 'curl  GET https://kubernetes.default/api/v1/namespaces/team-elephant/pods/  -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "15.8 get list pod from pod pod-sa in default (forbidden) " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec pod-sa  -n team-elephant  --context cluster1-admin@cluster1  -- sh -c 'curl  GET https://kubernetes.default/api/v1/namespaces/default/pods/  -s -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" -k' | grep 'pods is forbidden'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "16.1 collect logs from legacy app . from app1 " {
  echo '3'>>/var/work/tests/result/all
  kubectl exec checker -n legacy -- sh -c 'curl legacy-app:8081/xxxx_test_app1' --context cluster1-admin@cluster1
  sleep 3
  kubectl logs  -l app=legacy-app  -n legacy  -c log --context cluster1-admin@cluster1  --tail=-1| grep 'xxxx_test_app1'
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}

@test "16.2 collect logs from legacy app . from app2 " {
  echo '3'>>/var/work/tests/result/all
  kubectl exec checker -n legacy -- sh -c 'curl legacy-app:8082/yyyy_test_app2' --context cluster1-admin@cluster1
  sleep 3
  kubectl logs  -l app=legacy-app  -n legacy  -c log --context cluster1-admin@cluster1  --tail=-1| grep 'yyyy_test_app2'
  result=$?
  if [[ "$result" == '0' ]]; then
   echo '3'>>/var/work/tests/result/ok
  fi
  [ "$result" == '0' ]
}

@test "17 collect logs from 4 pods with label   app_name=xxx  in namespace app-x  " {
  echo '4'>>/var/work/tests/result/all
  result=$(cat /opt/17/17.log | grep enableLoadCpu | wc -l  )
  if [[ "$result" == "4" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "4" ]
}

@test "18.1 Convert existing pod in namespace app-y  to deployment deployment-app-y  . replicas = 1  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  deployment  deployment-app-y -n app-y  --context cluster1-admin@cluster1 -o jsonpath='{.spec.replicas}' )
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "18.2 Convert existing pod in namespace app-y  to deployment deployment-app-y  . image = viktoruj/ping_pong:alpine " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get  deployment  deployment-app-y -n app-y  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..image}')
  if [[ "$result" == "viktoruj/ping_pong:alpine" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong:alpine" ]
}

@test "18.3 Convert existing pod in namespace app-y  to deployment deployment-app-y  . env SERVER_NAME = app-y  " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get  deployment  deployment-app-y -n app-y  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..env[?(@.name=="SERVER_NAME")].value}')
  if [[ "$result" == "app-y" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "app-y" ]
}

@test "18.4 Convert existing pod in namespace app-y  to deployment deployment-app-y  . allowPrivilegeEscalation =  false " {
  echo '1'>>/var/work/tests/result/all
  result=$(  kubectl get  deployment  deployment-app-y -n app-y  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..securityContext.allowPrivilegeEscalation}')
  if [[ "$result" == "false" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "false" ]
}

@test "18.5 Convert existing pod in namespace app-y  to deployment deployment-app-y  . privileged =  false" {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get  deployment  deployment-app-y -n app-y  --context cluster1-admin@cluster1 -o jsonpath='{.spec.template.spec.containers..securityContext.privileged}')
  if [[ "$result" == "false" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "false" ]
}

@test "19 create configmap from file  and mount it to deployment " {
  echo '4'>>/var/work/tests/result/all
  pod=$(kubectl get po -n app-z -o jsonpath='{.items[*].metadata.name}' --context cluster1-admin@cluster1 )
  kubectl exec $pod -n app-z --context cluster1-admin@cluster1  -- cat  /appConfig/ingress_nginx_conf.yaml  >/tmp/19.log
  diff /tmp/19.log /var/work/19/ingress_nginx_conf.yaml
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "20 create deployment app  in namespace app-20 with init container " {
  echo '4'>>/var/work/tests/result/all
  pod=$(kubectl get po -n app-20 -o jsonpath='{.items[*].metadata.name}' --context cluster1-admin@cluster1 )
  kubectl exec $pod -n app-20  --context cluster1-admin@cluster1  -- cat /configs/app.config | grep 'hello from init'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '4'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "21.1 create deployment app-21 " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment app-21 --context cluster1-admin@cluster1 | grep '3/3'| cut -d' ' -f1)
  if [[ "$result" == "app-21" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "app-21" ]
}

@test "21.2 fix manifest /var/work/21/app-21.yaml  " {
  echo '1'>>/var/work/tests/result/all
  cat /var/work/21/app-21.yaml | grep apiVersion | grep 'apps/v1'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
