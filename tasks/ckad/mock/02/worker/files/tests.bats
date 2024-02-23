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