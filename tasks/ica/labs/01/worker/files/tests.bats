#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 Istio control plane (istiod) is installed and running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "istiod deployment is not ready (Istio not installed?)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "1.2 Istio ingress gateway is running" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy istio-ingressgateway -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "istio-ingressgateway deployment is not ready"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2.1 Namespace default is enabled for sidecar injection" {
  echo '1' >> /var/work/tests/result/all
  inj=$(kubectl get ns default -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
  if [[ "$inj" == "enabled" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "namespace default istio-injection='$inj' (expected enabled)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2.2 Bookinfo pods are injected with a sidecar" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer)
  injected=$(kubectl get pods -n default -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "default pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Bookinfo productpage is reachable through the gateway" {
  echo '1' >> /var/work/tests/result/all

  body=$(curl -s --max-time 15 http://myapp.local:32080/productpage 2>/dev/null || true)

  if echo "$body" | grep -q "Simple Bookstore App"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "productpage did not return the expected title (gateway/VirtualService not configured?)"
    result=1
  fi

  [ "$result" == "0" ]
}
