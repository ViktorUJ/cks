#!/usr/bin/env bats
# ICA Mock Exam - Task 20: Selective Sidecar Injection
# Validates selective sidecar injection using namespace label and pod annotations

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="turquoise"


@test "9.1 Namespace turquoise has istio-injection=enabled label" {
  echo '0.5' >> /var/work/tests/result/all
  injection_label=$(kubectl get namespace $NAMESPACE --context $CONTEXT -o jsonpath='{.metadata.labels.istio-injection}')
  result=1
  if [[ "$injection_label" == "enabled" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "9.2 turquoise-echo deployment exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get deployment turquoise-echo -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "9.3 turquoise-echo deployment has sidecar.istio.io/inject=false annotation" {
  echo '0.5' >> /var/work/tests/result/all
  inject_annotation=$(kubectl get deployment turquoise-echo -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.template.metadata.annotations.sidecar\.istio\.io/inject}')
  result=1
  if [[ "$inject_annotation" == "false" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "9.4 turquoise-echo pod has only 1 container (no sidecar)" {
  echo '0.5' >> /var/work/tests/result/all
  container_count=$(kubectl get pod -n $NAMESPACE --context $CONTEXT -l app=turquoise-echo -o jsonpath='{.items[0].spec.containers[*].name}' | wc -w)
  result=1
  if [[ "$container_count" == "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "9.5 sleep-turquoise pod exists" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get pod sleep-turquoise -n $NAMESPACE --context $CONTEXT > /dev/null 2>&1
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "9.6 sleep-turquoise pod has 2 containers (app + istio-proxy)" {
  echo '0.5' >> /var/work/tests/result/all
  container_count=$(kubectl get pod sleep-turquoise -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | wc -w)
  result=1
  if [[ "$container_count" == "2" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

@test "9.7 sleep-turquoise has istio-proxy container" {
  echo '0.5' >> /var/work/tests/result/all
  proxy_exists=$(kubectl get pod sleep-turquoise -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.containers[*].name}' | grep -c "istio-proxy")
  result=1
  if [[ "$proxy_exists" -ge "1" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
    result=0
  fi
  [ "$result" == "0" ]
}

