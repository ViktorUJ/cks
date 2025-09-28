#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1.1. Check if user was removed from docker group" {
  echo '1'>>/var/work/tests/result/all
  set +e
  ssh -oStrictHostKeyChecking=no docker-worker "groups user " | grep docker
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.2. Check docker socket configuration" {
  echo '1' >>/var/work/tests/result/all
  ssh -oStrictHostKeyChecking=no docker-worker "stat -c %G /var/run/docker.sock" | grep root
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.3. Docker is NOT exposed on TCP 2375" {
  echo '1' >>/var/work/tests/result/all
  set +e
  ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=5 docker-worker 'ss -ltn  | grep -qE "[:.]2375(\\s|$)"'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.4. Docker daemon is running" {
  echo '1' >>/var/work/tests/result/all
  ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.5. Docker socket is active" {
  echo '1' >>/var/work/tests/result/all
  ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker.socket" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
