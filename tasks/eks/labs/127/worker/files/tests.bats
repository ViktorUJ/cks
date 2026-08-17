#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-127"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-127 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Audit does not block: latest-audit-pod was admitted with :latest tag" {
  echo '1' >> /var/work/tests/result/all
  pol=$(kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.metadata.name}' 2>/dev/null)
  image=$(kubectl get pod latest-audit-pod -n "$NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  if [[ "$pol" == "disallow-latest-tag" ]] && [[ "$image" == *:latest ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "policy=$pol latest-audit-pod image=$image"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Deny blocks: binding switched to Deny, denied.txt saved, latest-deny-pod absent" {
  echo '1' >> /var/work/tests/result/all
  actions=$(kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding \
    -o jsonpath='{.spec.validationActions}' 2>/dev/null)
  f=/var/work/tests/artifacts/3/denied.txt
  denied_pod=$(kubectl get pod latest-deny-pod -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  if [[ "$actions" == *Deny* ]] && [[ -s "$f" ]] && grep -qi 'latest' "$f" \
    && grep -q 'запрещён' "$f" && [[ -z "$denied_pod" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "actions=$actions file=$f denied_pod=$denied_pod"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Legit pod with an explicit tag is not blocked by Deny and actually runs" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get pod tagged-pod -n "$NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
  # Проверять только имя образа недостаточно: под с несуществующим тегом тоже пройдёт
  # допуск и останется в ErrImagePull. Ждём Running, иначе утверждение "политика не
  # мешает легитимному поду" ничем не подтверждено.
  phase=""
  for i in $(seq 1 18); do
    phase=$(kubectl get pod tagged-pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
    [[ "$phase" == "Running" ]] && break
    sleep 10
  done
  if [[ -n "$image" ]] && [[ "$image" != *:latest ]] && [[ "$phase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "tagged-pod image=$image phase=$phase"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Second CEL policy enforces resources.requests" {
  echo '1' >> /var/work/tests/result/all
  pol=$(kubectl get validatingadmissionpolicy require-resources-requests -o jsonpath='{.metadata.name}' 2>/dev/null)
  actions=$(kubectl get validatingadmissionpolicybinding require-resources-requests-binding \
    -o jsonpath='{.spec.validationActions}' 2>/dev/null)
  bad_pod=$(kubectl get pod no-requests-pod -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null || true)
  req=$(kubectl get pod requests-ok-pod -n "$NS" \
    -o jsonpath='{.spec.containers[0].resources.requests}' 2>/dev/null)
  # Тот же принцип, что в тесте 4: разрешённый под должен доехать до Running.
  phase=""
  for i in $(seq 1 18); do
    phase=$(kubectl get pod requests-ok-pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
    [[ "$phase" == "Running" ]] && break
    sleep 10
  done
  if [[ "$pol" == "require-resources-requests" ]] && [[ "$actions" == *Deny* ]] \
    && [[ -z "$bad_pod" ]] && [[ -n "$req" ]] && [[ "$phase" == "Running" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "policy=$pol actions=$actions bad_pod=$bad_pod requests=$req phase=$phase"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. failurePolicy Fail is set and artifact explains no webhook risk" {
  echo '1' >> /var/work/tests/result/all
  fp=$(kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}' 2>/dev/null)
  f=/var/work/tests/artifacts/6/failurepolicy.txt
  if [[ "$fp" == "Fail" ]] && [[ -s "$f" ]] && grep -qi 'webhook' "$f" && grep -qi 'apiserver' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "failurePolicy=$fp file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}
