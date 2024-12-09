#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests

}

#1

@test "1.1 check private api from finance namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n finance finance  --  curl http://portal.production/private/api123 --connect-timeout 1 | grep 'http://portal.production/private/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.2 check public api from finance namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n finance finance  --  curl http://portal.production/public/api123  --connect-timeout 1 | grep 'http://portal.production/public/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.3 check private api from external namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n external external  --  curl http://portal.production/private/api123   --connect-timeout 1 | grep 'Access denied'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.4 check public api from external namespace  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  exec  -n external external  --  curl http://portal.production/public/api123  --connect-timeout 1 | grep 'http://portal.production/public/api123'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
