#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 cacerts secret exists in istio-system with the required keys" {
  echo '1' >> /var/work/tests/result/all

  keys=$(kubectl get secret cacerts -n istio-system -o json 2>/dev/null | jq -r '.data | keys | join(",")')
  ok=1
  for k in ca-cert.pem ca-key.pem root-cert.pem cert-chain.pem; do
    echo "$keys" | grep -q "$k" || ok=0
  done

  if [[ "$ok" -eq 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cacerts secret missing or incomplete (keys=$keys)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.2 istiod control plane is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "istiod is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 app pod has Envoy sidecar injected" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  injected=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r '.items[] | select(([.spec.containers[].name] + [.spec.initContainers[]?.name]) | index("istio-proxy")) | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$injected" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, injected=$injected"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 workload trust root chains to the custom CA (CKS-Lab)" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  root=$(istioctl proxy-config secret "$pod" -n app -o json 2>/dev/null | jq -r '.dynamicActiveSecrets[]? | select(.name=="ROOTCA") | .secret.validationContext.trustedCa.inlineBytes')
  subject=$(echo "$root" | base64 -d 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)

  if echo "$subject" | grep -q 'CKS-Lab'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "workload ROOTCA is not the custom CA (subject='$subject')"
    result=1
  fi

  [ "$result" == "0" ]
}
