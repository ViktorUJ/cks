#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 Check if ingress rule is working" {
  echo '1'>>/var/work/tests/result/all
  node_ip=$(kubectl get nodes -o wide | awk 'NR==2 {print $6}')
  curl -s --connect-timeout 1 --max-time 1  "http://$node_ip:30800" --header "Host: myapp.local"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.2 Check if mtls enabled" {
  echo '1'>>/var/work/tests/result/all
  kubectl get cnp -n myapp -o yaml | grep deny-all && kubectl get cnp -n myapp -o yaml | grep "mode: required"
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

