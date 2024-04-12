#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
  for i in {1..100}; do curl -s  http://ckad.local:30102/app | grep 'Server Name' >>/var/work/tests/result/requests; done
  [ "$?" -eq 0 ]

}

#1

@test "1.1 Check routing to version 2  " {
  echo '1'>>/var/work/tests/result/all
  total=$(cat /var/work/tests/result/requests | wc -l )
  app2=$(cat /var/work/tests/result/requests |grep megApp2 | wc -l )
  percentage=$((100 * app2 / total))
  if [ $percentage -ge 20 ] && [ $percentage -le 40 ]; then
    result=0
  else
    result=1
  fi
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.2 Check ingress v2 canary-weight  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ing -n meg meg-app2 -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/canary-weight}')
  if [[ "$result" == "30" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "30" ]
}
