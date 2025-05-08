#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1. Check if user was removed from docker group" {
  echo '2'>>/var/work/tests/result/all
  set +e
  groups user | grep docker
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "2. Check docker socket configuration" {
  echo '2' >>/var/work/tests/result/all
  if [[ "$(stat -c %G /var/run/docker.sock)" == "root" ]] && grep -q "SocketGroup=root" /lib/systemd/system/docker.socket; then
    result="0"
  else
    result="1"
  fi

  if [["$result" == "0" ]]; then
    echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "3. Check if Docker is not exposed through a TCP socket" {
  echo '1'>>/var/work/tests/result/all
  set +e
  netstat -tuln | grep -q 'docker'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}
