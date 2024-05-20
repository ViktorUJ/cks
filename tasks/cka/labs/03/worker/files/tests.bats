#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

#1

@test "1.1 Check routing by  header  X-Appversion =  v2 " {
  echo '1'>>/var/work/tests/result/all
  curl -H "X-Appversion: v2" http://ckad.local:30102/app -s  | grep megApp2
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.2 Check routing by  header  X-Appversion =  v3 " {
  echo '1'>>/var/work/tests/result/all
  result=$(curl -H "X-Appversion: v3" http://ckad.local:30102/app -s  | grep megApp | cut -d':' -f2 | tr -d '\n' | tr -d ' ')
  if [[ "$result" == "megApp" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "megApp" ]
}


@test "1.3 Check routing without  header  X-Appversion  " {
  echo '1'>>/var/work/tests/result/all
  result=$(curl  http://ckad.local:30102/app -s  | grep megApp | cut -d':' -f2 | tr -d '\n' | tr -d ' ')
  if [[ "$result" == "megApp" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "megApp" ]
}
