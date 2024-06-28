#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests

}

#1

@test "1.1 PriorityClass  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get priorityclasses.scheduling.k8s.io  monitoring  -o jsonpath='{.value}')
  if [[ "$result" == "1000000000" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1000000000" ]
}

@test "1.2 DaemonSet PriorityClass  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get daemonsets.apps -n monitoring  monitoring-system  -o jsonpath='{.spec.template.spec.priorityClassName}')
  if [[ "$result" == "monitoring" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "monitoring" ]
}

@test "1.3 monitoring-system pods ready   " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get po -n monitoring  | grep Running | wc -l)
  if [[ "$result" == "3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}
