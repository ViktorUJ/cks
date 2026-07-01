#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 Flagger controller is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy flagger -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Flagger controller is not ready in istio-system"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Canary resource for podinfo defines a progressive analysis" {
  echo '1' >> /var/work/tests/result/all

  step=$(kubectl get canary podinfo -n test -o jsonpath='{.spec.analysis.stepWeight}' 2>/dev/null)
  target=$(kubectl get canary podinfo -n test -o jsonpath='{.spec.targetRef.name}' 2>/dev/null)

  if [[ "$target" == "podinfo" ]] && [[ "${step:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Canary podinfo missing or has no analysis.stepWeight (target='$target', stepWeight='$step')"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 Flagger initialized the canary (podinfo-primary is ready)" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy podinfo-primary -n test -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "podinfo-primary is not ready (Flagger has not initialized the canary)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "3.1 Canary was promoted: primary now runs podinfo 6.0.1" {
  echo '1' >> /var/work/tests/result/all

  img=$(kubectl get deploy podinfo-primary -n test -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null)
  if echo "$img" | grep -q '6.0.1'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "podinfo-primary image is '$img' (expected 6.0.1 after canary promotion)"
    result=1
  fi

  [ "$result" == "0" ]
}
