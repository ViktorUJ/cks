#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-121"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-121 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Artifact 2/unauthorized.txt shows Unauthorized for the unmapped test role" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/unauthorized.txt
  if [[ -s "$f" ]] && grep -qi 'unauthorized' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show Unauthorized"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Access entry fix: artifact 3/authorized.txt lists pods, no Unauthorized" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/authorized.txt
  if [[ -s "$f" ]] && grep -q 'NAMESPACE' "$f" && ! grep -qi 'unauthorized' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, missing pod list, or still shows Unauthorized"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Artifact 4/forbidden.txt shows Forbidden and explains it against Unauthorized" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/forbidden.txt
  if [[ -s "$f" ]] && grep -qi 'forbidden' "$f" && grep -qi 'unauthorized' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention both Forbidden and Unauthorized"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. ServiceAccount demo-reader (eks-121) reads S3 via the assumed IRSA role" {
  echo '1' >> /var/work/tests/result/all
  role_arn=$(kubectl get sa demo-reader -n "$NS" \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/irsa_ok.txt
  if [[ "$role_arn" == *irsa-role* ]] && [[ -s "$f" ]] \
     && grep -qi 'assumed-role' "$f" && grep -qi 'hello from s3' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa demo-reader role-arn=$role_arn; file $f must show assumed-role and S3 content"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. ServiceAccount demo-reader-broken (default) gets AccessDenied on the same role" {
  echo '1' >> /var/work/tests/result/all
  role_arn=$(kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  f=/var/work/tests/artifacts/6/broken.txt
  if [[ "$role_arn" == *irsa-role* ]] && [[ -s "$f" ]] \
     && grep -Eqi 'accessdenied|not authorized|webidentityerr' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sa demo-reader-broken role-arn=$role_arn; file $f must show AccessDenied/WebIdentityErr"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact 7/diagnostics.txt compares annotations and explains sub/namespace mismatch" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/diagnostics.txt
  if [[ -s "$f" ]] && grep -qi 'sub' "$f" && grep -qi 'namespace' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention sub and namespace"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Artifact 8/summary.txt compares the two access axes (RBAC vs trust policy)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/8/summary.txt
  if [[ -s "$f" ]] && grep -qi 'rbac' "$f" && grep -qi 'trust policy' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention RBAC and trust policy"
    result=1
  fi
  [ "$result" == "0" ]
}
