#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests

}

#1

@test "1 Create a Gateway  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get  gateway nginx-gateway  -n nginx-gateway  -o jsonpath='{.spec.gatewayClassName}'  )
  if [[ "$result" == "nginx" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx" ]
}

@test "2 Create default restrict " {
  echo '1'>>/var/work/tests/result/all
  curl non-domain.example:30102 -s | grep 'Server Name' | grep 'restricted'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.1 Create HTTPRoute cka.local with  header environment: dev " {
  echo '1'>>/var/work/tests/result/all
  curl cka.local:30102 -s -H "environment: dev"  | grep 'Server Name' | grep 'dev'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3.2 Create HTTPRoute cka.local  default " {
  echo '1'>>/var/work/tests/result/all
  curl cka.local:30102 -s  | grep 'Server Name' | grep 'production'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4 Create HTTPRoute  dev-cka.local " {
  echo '1'>>/var/work/tests/result/all
  curl dev-cka.local:30102 -s  | grep 'Server Name' | grep 'dev'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.1 Create HTTPRoute weight-cka.local  .  app-weight-v1 " {
 for i in {1..100}; do curl -s  weight-cka.local:30102 | grep 'Server Name' >>/var/work/tests/result/requests; done
  echo '1'>>/var/work/tests/result/all
  total=$(cat /var/work/tests/result/requests | wc -l )
  app1=$(cat /var/work/tests/result/requests |grep app-weight-v1 | wc -l )
  percentage=$((100 * app1 / total))
  if [ $percentage -ge 60 ] && [ $percentage -le 80 ]; then
    result=0
  else
    result=1
  fi
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.2 Create HTTPRoute weight-cka.local  .  app-weight-v2 " {
  echo '1'>>/var/work/tests/result/all
  total=$(cat /var/work/tests/result/requests | wc -l )
  app1=$(cat /var/work/tests/result/requests |grep app-weight-v2 | wc -l )
  percentage=$((100 * app1 / total))
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

@test "6.1 Create HTTPRoute  header-cka.local  . header User-Type" {
  echo '1'>>/var/work/tests/result/all
  curl header-cka.local:30102 -s  -H "X-CH: CH" -H "User-City: TBC" | grep 'User-Type' | grep 'test-user'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.2 Create HTTPRoute  header-cka.local  . header User-City" {
  echo '1'>>/var/work/tests/result/all
  curl header-cka.local:30102 -s  -H "X-CH: CH" -H "User-City: TBC" | grep 'User-City' | grep 'NYC'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.3 Create HTTPRoute  header-cka.local  . header X-CH" {
  echo '1'>>/var/work/tests/result/all
  set +e
  curl header-cka.local:30102 -s  -H "X-CH: CH" -H "User-City: TBC" | grep 'X-CH'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}