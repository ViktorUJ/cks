#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-104"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-104 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. ServiceAccount s3-reader-irsa annotated with the IRSA role ARN" {
  echo '1' >> /var/work/tests/result/all
  role_arn=$(kubectl get sa s3-reader-irsa -n "$NS" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  if [[ "$role_arn" == *irsa-role* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa s3-reader-irsa role-arn annotation=$role_arn"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Pod irsa-app uses the annotated SA and reads via assumed IRSA role" {
  echo '1' >> /var/work/tests/result/all
  sa=$(kubectl get pod irsa-app -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  f=/var/work/tests/artifacts/3/irsa_identity.txt
  if [[ "$sa" == "s3-reader-irsa" ]] && [[ -s "$f" ]] && grep -qi 'assumed-role' "$f" \
     && grep -qi 'irsa-role' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "irsa-app serviceAccountName=$sa; file $f must show assumed-role of the irsa-role"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Artifact 4/s3_read.txt shows the object fetched from S3 via IRSA" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/s3_read.txt
  if [[ -s "$f" ]] && grep -qi 'hello from s3' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not contain the expected S3 object body"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Pod Identity association exists for namespace eks-104 and SA secret-reader-podid" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/association.txt
  if [[ -s "$f" ]] && grep -qi 'secret-reader-podid' "$f" && grep -qi "$NS" "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention the SA and namespace of the association"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Pod podid-app reads the secret via assumed Pod Identity role, not the node role" {
  echo '1' >> /var/work/tests/result/all
  sa=$(kubectl get pod podid-app -n "$NS" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  f=/var/work/tests/artifacts/6/secret_read.txt
  if [[ "$sa" == "secret-reader-podid" ]] && [[ -s "$f" ]] \
     && grep -qi 'pod-identity-role' "$f" && grep -qi 'demo123\|username' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "podid-app serviceAccountName=$sa; file $f must show assumed pod-identity-role and secret content"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact 7/node_role_denied.txt shows IMDS/node role has no access to the bucket" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/node_role_denied.txt
  if [[ -s "$f" ]] && grep -qi 'AccessDenied\|not authorized' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show an AccessDenied from the node role"
    result=1
  fi
  [ "$result" == "0" ]
}
