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
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "groups user " | grep docker
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.2. Check docker socket configuration" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "stat -c %G /var/run/docker.sock" | grep root
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "1.3. Docker is NOT exposed on TCP 2375" {
  echo '1' >>/var/work/tests/result/all
  set +e
  timeout 2s ssh -oBatchMode=yes -oStrictHostKeyChecking=no -oConnectTimeout=5 docker-worker 'ss -ltn  | grep -qE "[:.]2375(\\s|$)"'
  result=$?
  set -e
  if [[ "$result" == "1" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "1" ]
}

@test "1.4. Docker daemon is running" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "1.5. Docker socket is active" {
  echo '1' >>/var/work/tests/result/all
  timeout 2s ssh -oStrictHostKeyChecking=no docker-worker "systemctl is-active docker.socket" | grep active
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
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


@test "4.1 Check  Ingress using the provided certificate. " {
  echo '2'>>/var/work/tests/result/all
  timeout 2 curl https://cks.local:31139 -kv 2>&1  | grep 'CN=cks.local'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4.2 Check  Ingress redirect from http to https. " {
  echo '2'>>/var/work/tests/result/all
  timeout 2 curl http://cks.local:30102  2>&1  | grep '308 Permanent Redirect'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '2'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



@test "5.1 Network policy. can connect from prod NS to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec prod-app -n prod --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.2 Network policy. can  connect from stage NS  and  label: role=db-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec stage-app -n stage --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.3 Network policy. can connect from any Namespaces and have label: role=db-external-connect  to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  kubectl exec all-app -n default --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s ' | grep 'mysql'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "5.4 Network policy. can't connect from stage NameSpace all pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec not-db-app -n stage  --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "5.5 Network policy. can't connect all   pod   to prod-db  " {
  echo '1'>>/var/work/tests/result/all
  set +e
  kubectl exec all-not-db-app -n default   --context cluster6-admin@cluster6 -- sh -c ' curl db.prod-db.svc:3306 --connect-timeout 1 -s '
  result=$?
  set -e
  if (( $result > 0 )); then
   echo '1'>>/var/work/tests/result/ok
  fi
   (( $result > 0 ))
}

@test "5.6 Network policy. can connect from all    pod   to google.com  " {
  echo '1'>>/var/work/tests/result/all
  set +e && kubectl exec all-not-db-app -n default    --context cluster6-admin@cluster6 -- sh -c ' curl https://google.com --connect-timeout 1 -s '
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}



@test "6.1 Deployment  security . check prevent escalation  " {
  echo '1'>>/var/work/tests/result/all
  kubectl  get deployment secure -n secure --context cluster6-admin@cluster6  -o yaml  | grep allowPrivilegeEscalation | grep false |grep -v '{}'| wc -l  | grep 3
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}


@test "6.2 Deployment  security . Read only root file system c1  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.3 Deployment  security . Read only root file system c2  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c2 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.4 Deployment  security . Read only root file system c3  " {
  echo '.5'>>/var/work/tests/result/all
  set +e
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c3 -- sh -c 'echo "test" >/var/tmp_xxx'
  result=$?
  set -e
   if (( $result > 0 )); then
   echo '.5'>>/var/work/tests/result/ok
  fi
  (( $result > 0 ))
}

@test "6.5 Deployment  security . user_id,  c1  " {
  echo '.5'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '.5'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.6 Deployment  security . user_id,  c2  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c2 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
@test "6.7 Deployment  security . user_id,  c3  " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c3 -- sh -c 'id ' | grep 3000
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "6.8 Deployment  security . allow wread to /tmp/  container c1 " {
  echo '1'>>/var/work/tests/result/all
  pod=$(kubectl  get po  -n secure --context cluster6-admin@cluster6 -o jsonpath='{.items..metadata.name}')
  kubectl  exec $pod  -n secure --context cluster6-admin@cluster6  -c c1 -- sh -c 'echo "test">/tmp/test '
  result=$?
   if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
