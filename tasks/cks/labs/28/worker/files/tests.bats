#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

# 1
@test "1 Check that proper deployment was scaled to 0" {
  echo '1'>>/var/work/tests/result/all
  app1_replicas=$(kubectl get deployments.apps -n north app1 -o jsonpath='{.spec.replicas}')
  app2_replicas=$(kubectl get deployments.apps -n north app2 -o jsonpath='{.spec.replicas}')
  app3_replicas=$(kubectl get deployments.apps -n north app3 -o jsonpath='{.spec.replicas}')
  if [[ "$app1_replicas" == "1" && "$app2_replicas" == "1" && "$app3_replicas" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [[ "$app1_replicas" == "1" && "$app2_replicas" == "1" && "$app3_replicas" == "0" ]]
}
