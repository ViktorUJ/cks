#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/_config

@test "0  Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  [ "$?" -eq 0 ]

}

@test "1. aws cli , ec2  tag  env_name=hr-mock " {
  echo '1'>>/var/work/tests/result/all
  aws ec2 describe-instances --region eu-north-1 --filters "Name=tag:env_name,Values=hr-mock" --output json > /var/work/tests/artifacts/1/ec2_2.json
  diff <(jq -r '.Reservations[].Instances[].InstanceId' /var/work/tests/artifacts/1/ec2_1.json) <(jq -r '.Reservations[].Instances[].InstanceId' /var/work/tests/artifacts/1/ec2_2.json)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "2.1 update deployment named test-app.Image_tag " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  test-app -n dev-team  -o jsonpath='{.spec..containers..image}'  --context cluster2-admin@cluster2 )
  if [[ "$result" == "nginx:stable" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "nginx:stable" ]
}

@test "2.2 update deployment named test-app.Replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  test-app -n dev-team  -o jsonpath='{.spec.replicas}'  --context cluster2-admin@cluster2 )
  if [[ "$result" == "4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "4" ]
}

@test "3. install helm  release  name=kube-prometheus-stack" {
  echo '1'>>/var/work/tests/result/all
  helm list   -n monitoring  --kube-context  cluster1-admin@cluster1  -o json | jq -r '.[0].chart' | grep 'kube-prometheus-stack' | grep '45.4.0'
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "4. check metrics in prometeus from prod app" {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl  exec  test-prom -n prod --context cluster1-admin@cluster1 -- sh -c 'curl -s  kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=requests_per_second | jq -r ".data.result[].metric.pod" | wc -l')
  if [[ "$result" == "3" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "3" ]
}

@test "5. cluster1 . get node with label work_type=infra " {
  echo '1'>>/var/work/tests/result/all
  kubectl get no    -l work_type=infra  --context cluster1-admin@cluster1 -o json  > /var/work/tests/artifacts/5/nodes_2.json
  diff <(jq -r '.items[].metadata.name' /var/work/tests/artifacts/5/nodes_2.json) <(jq -r '.items[].metadata.name' /var/work/tests/artifacts/5/nodes.json)
  result=$?
  if [[ "$result" == "0" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}
