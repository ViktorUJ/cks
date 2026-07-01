#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 istiod control plane is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Deployment istiod is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 meshConfig outboundTrafficPolicy.mode is REGISTRY_ONLY" {
  echo '1' >> /var/work/tests/result/all

  mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' 2>/dev/null)
  mode=$(echo "$mesh" | grep -A2 'outboundTrafficPolicy' | grep -oE 'REGISTRY_ONLY' | head -n1)
  if [[ "$mode" == "REGISTRY_ONLY" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "meshConfig outboundTrafficPolicy.mode is not REGISTRY_ONLY"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 meshConfig accessLogFile is enabled (/dev/stdout)" {
  echo '1' >> /var/work/tests/result/all

  mesh=$(kubectl get configmap istio -n istio-system -o jsonpath='{.data.mesh}' 2>/dev/null)
  alf=$(echo "$mesh" | grep -E 'accessLogFile' | grep -oE '/dev/stdout' | head -n1)
  if [[ "$alf" == "/dev/stdout" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "meshConfig accessLogFile is not set to /dev/stdout"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 extra ingress gateway (ingressgateway-internal) is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy ingressgateway-internal -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Deployment ingressgateway-internal is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 default istio-ingressgateway is still running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Deployment istio-ingressgateway is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}
