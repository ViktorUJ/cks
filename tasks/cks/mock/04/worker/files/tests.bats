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
  if [["$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.3. Docker is NOT exposed on TCP 2375" {
  echo '1' >>/var/work/tests/result/all
  run bash -o pipefail -c 'ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=5 docker-worker "ss -ltn" | grep -qE "[:.]2375(\\s|$)"'

  if [ "$status" -eq 0 ]; then
    echo "FAIL: tcp/2375 is opened" >&2
  fi

  [ "$status" -ne 0 ]

  if [ "$status" -ne 0 ]; then
    echo '1' >> /var/work/tests/result/ok
  fi

}


@test "2.1 Check that ALL pods have injection" {
  echo '1' >> /var/work/tests/result/all

  total_pods=$(kubectl get pods -n market --no-headers  --context cluster12-admin@cluster12 | wc -l)

  pods_with_sidecar=$(kubectl get pods -n market -o json --context cluster12-admin@cluster12 | jq -r '.items[] | select(.spec.containers[].name == "istio-proxy") | .metadata.name' | wc -l)

  if [[ "$total_pods" -eq "$pods_with_sidecar" ]] && [[ "$total_pods" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Total pods: $total_pods, Pods with sidecar: $pods_with_sidecar"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Check if mtls enabled" {
  echo '1' >> /var/work/tests/result/all
  mtls_policies=$(kubectl get peerauthentication -n market -o json --context cluster12-admin@cluster12 | jq -r '.items[] | select(.spec.mtls.mode == "STRICT") | .metadata.name' | wc -l)
  if [[ "$mtls_policies" -gt 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    result=1
  fi
  [ "$result" == "0" ]
}


