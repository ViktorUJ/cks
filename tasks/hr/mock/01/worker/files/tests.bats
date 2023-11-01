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

@test "2.2 Create a deployment named hr-web-app.Replicas " {
  echo '1'>>/var/work/tests/result/all
  result=$(kubectl get deployment  test-app -n dev-team  -o jsonpath='{.spec.replicas}'  --context cluster2-admin@cluster2 )
  if [[ "$result" == "4" ]]; then
   echo '1'>>/var/work/tests/result/ok
  fi
  [ "$result" == "4" ]
}
