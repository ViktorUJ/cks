#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests

}

#1

@test "1.1 NS prod " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get ns prod  -o jsonpath={.metadata.name})
  if [[ "$result" == "prod" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "prod" ]
}

@test "1.2 deplyment app-server .image  = viktoruj/ping_pong  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployments.apps app-server   -n prod  -o jsonpath={.spec.template.spec.containers..image})
  if [[ "$result" == "viktoruj/ping_pong" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "viktoruj/ping_pong" ]
}

@test "1.3 deplyment app-server .replicas = 2  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  get deployments.apps app-server   -n prod  -o jsonpath={.spec.replicas})
  if [[ "$result" == "2" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "2" ]
}

@test "1.4 deplyment app-server . ENV SRV_PORT = 80  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps app-server -n prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="ping-pong")].env[?(@.name=="SRV_PORT")].value}')
  if [[ "$result" == "80" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "80" ]
}


@test "1.5 deplyment app-server . ENV SERVER_NAME = app-server  " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployments.apps app-server -n prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="ping-pong")].env[?(@.name=="SERVER_NAME")].value}')
  if [[ "$result" == "app-server" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "app-server" ]
}

@test "1.6 service app-server . port = 80  " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get svc -n prod app-server  -o jsonpath={.spec.ports..port})
  if [[ "$result" == "80" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "80" ]
}

@test "1.7 service app-server . targetPort = 80  " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get svc -n prod app-server  -o jsonpath={.spec.ports..targetPort})
  if [[ "$result" == "80" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "80" ]
}

@test "1.8 service app-server . selector app = app-server  " {
  echo '1'>>/var/work/tests/result/all
  result=$( kubectl get svc -n prod app-server  -o jsonpath={.spec.selector.app})
  if [[ "$result" == "app-server" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "app-server" ]
}

@test "1.9 service app-server .  curl  response  - > Servername: app-server" {
  echo '1'>>/var/work/tests/result/all
  kubectl run -i --tty --rm debug -n prod  --image=alpine --restart=Never -- sh -c "apk add curl>/dev/null; curl -s app-server --max-time 1 " | grep 'Server Name' | grep 'app-server'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
