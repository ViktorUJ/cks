#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-116"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-116 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Deployment probe is ready and the IMDS request from the pod timed out" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy probe -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy probe -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/2/imds.txt
  if [[ "$image" == *curl* ]] && [[ "$ready" == "1" ]] && [[ -s "$f" ]] && grep -qi 'timeout\|timed out' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "probe image=$image ready=$ready; file $f must exist and mention a timeout"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3 shows HttpTokens=required and hop limit 1 on the node" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/metadata_options.txt
  hop=$(grep -oE '"HttpPutResponseHopLimit"[[:space:]]*:[[:space:]]*[0-9]+' "$f" 2>/dev/null | grep -oE '[0-9]+$')
  tokens=$(grep -oE '"HttpTokens"[[:space:]]*:[[:space:]]*"[a-zA-Z]+"' "$f" 2>/dev/null | grep -oE '"[a-zA-Z]+"$' | tr -d '"')
  if [[ -s "$f" ]] && [[ "$hop" == "1" ]] && [[ "$tokens" == "required" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f: HttpPutResponseHopLimit=$hop HttpTokens=$tokens (expected 1 / required)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Pod Security Admission rejects a privileged pod in the restricted namespace" {
  echo '1' >> /var/work/tests/result/all
  enforce=$(kubectl get ns "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
  privpod=$(kubectl get pod priv-test -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  f=/var/work/tests/artifacts/4/psa_reject.txt
  if [[ "$enforce" == "restricted" ]] && [[ -z "$privpod" ]] && [[ -s "$f" ]] \
     && grep -qi 'privileged' "$f" && grep -qi 'restricted\|violat' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ns enforce=$enforce privpod=$privpod; file $f must exist and mention privileged and restricted/violat"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Pod safe-pod complies with restricted and is Running" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get pod safe-pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  nonroot=$(kubectl get pod safe-pod -n "$NS" -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null)
  if [[ "$phase" == "Running" ]] && [[ "$nonroot" == "true" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "safe-pod phase=$phase runAsNonRoot=$nonroot"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact 6 confirms private control plane access and lists VPC endpoints" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/private_endpoint.txt
  if [[ -s "$f" ]] && grep -qi 'true' "$f" && grep -qi 's3' "$f" && grep -qi 'ecr' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not confirm true / mention s3 and ecr endpoints"
    result=1
  fi
  [ "$result" == "0" ]
}
