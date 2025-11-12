#!/usr/bin/env bats
# ICA Mock Exam - Task 16: Expose Service via Istio Gateway
# Validates Gateway and VirtualService configuration for ingress

export KUBECONFIG=/home/ubuntu/.kube/_config
CONTEXT="cluster3-admin@cluster3"
NAMESPACE="copper"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  [ "$?" -eq 0 ]
}

# Task 16: Expose Service via Istio Gateway (3 points)

@test "16.1 Gateway exists in istio-system namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get gateway -n istio-system --context $CONTEXT | grep -q "echo"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.2 Gateway selector is istio: ingressgateway" {
  echo '0.5' >> /var/work/tests/result/all
  gw_name=$(kubectl get gateway -n istio-system --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  selector=$(kubectl get gateway $gw_name -n istio-system --context $CONTEXT -o jsonpath='{.spec.selector.istio}')
  if [[ "$selector" == "ingressgateway" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$selector" == "ingressgateway" ]
}

@test "16.3 Gateway hosts includes echo.example.com" {
  echo '0.5' >> /var/work/tests/result/all
  gw_name=$(kubectl get gateway -n istio-system --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  hosts=$(kubectl get gateway $gw_name -n istio-system --context $CONTEXT -o jsonpath='{.spec.servers[*].hosts[*]}')
  # Accept either explicit echo.example.com or wildcard *
  if echo "$hosts" | grep -qE "echo\.example\.com|\*"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$hosts" | grep -qE "echo\.example\.com|\*"
}

@test "16.4 VirtualService exists in copper namespace" {
  echo '0.5' >> /var/work/tests/result/all
  kubectl get virtualservice -n $NAMESPACE --context $CONTEXT | grep -q "copper"
  result=$?
  if [[ "$result" == "0" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$result" == "0" ]
}

@test "16.5 VirtualService hosts includes echo.example.com" {
  echo '0.5' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  hosts=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.hosts[*]}')
  if echo "$hosts" | grep -q "echo.example.com"; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  echo "$hosts" | grep -q "echo.example.com"
}

@test "16.6 VirtualService references the Gateway" {
  echo '0.25' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  gateways=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.gateways[*]}')
  if echo "$gateways" | grep -q "echo-gateway\|istio-system/"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$gateways" | grep -q "echo-gateway\|istio-system/"
}

@test "16.7 VirtualService routes to copper-echo service" {
  echo '0.25' >> /var/work/tests/result/all
  vs_name=$(kubectl get virtualservice -n $NAMESPACE --context $CONTEXT -o jsonpath='{.items[0].metadata.name}')
  host=$(kubectl get virtualservice $vs_name -n $NAMESPACE --context $CONTEXT -o jsonpath='{.spec.http[0].route[0].destination.host}')
  if echo "$host" | grep -q "copper-echo"; then
    echo '0.25' >> /var/work/tests/result/ok
  fi
  echo "$host" | grep -q "copper-echo"
}

@test "16.8 Service is accessible via ingress gateway" {
  echo '0.5' >> /var/work/tests/result/all

  # Get NodePort - cluster3 uses istio-ingressgateway (not istio-demo-ingress)
  NODE_PORT=$(kubectl get svc istio-ingressgateway -n istio-system --context $CONTEXT -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

  # Get node IP
  NODE_IP=$(kubectl get nodes --context $CONTEXT -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

  # Test access via ingress
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "Host: echo.example.com" http://$NODE_IP:$NODE_PORT/mars)

  if [[ "$http_code" == "200" ]]; then
    echo '0.5' >> /var/work/tests/result/ok
  fi
  [ "$http_code" == "200" ]
}

# Total: 3 points for Task 16
