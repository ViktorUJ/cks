#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 cert-manager controller is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy cert-manager -n cert-manager -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cert-manager controller is not ready"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.2 istio-csr agent is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy cert-manager-istio-csr -n cert-manager -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cert-manager-istio-csr is not ready"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 istiod built-in CA server is disabled" {
  echo '1' >> /var/work/tests/result/all

  val=$(kubectl get deploy istiod -n istio-system -o json | jq -r '.spec.template.spec.containers[].env[]? | select(.name=="ENABLE_CA_SERVER") | .value')
  if [[ "$val" == "false" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "istiod ENABLE_CA_SERVER='$val' (expected false)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 cert-manager is issuing certs (CertificateRequests exist)" {
  echo '1' >> /var/work/tests/result/all

  cnt=$(kubectl get certificaterequests.cert-manager.io -n istio-system --no-headers 2>/dev/null | wc -l)
  if [[ "${cnt:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "No CertificateRequests in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.2 workload certificate is issued by cert-manager" {
  echo '1' >> /var/work/tests/result/all

  pod=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  issuer=$(istioctl proxy-config secret "$pod" -n app -o json 2>/dev/null | jq -r '.dynamicActiveSecrets[]? | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' | base64 -d 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)

  if echo "$issuer" | grep -qi 'cert-manager'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "workload cert issuer is '$issuer' (expected to include cert-manager)"
    result=1
  fi

  [ "$result" == "0" ]
}
