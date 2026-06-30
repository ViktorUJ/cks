#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config

OLD_REV="1-28-1"
NEW_REV="1-29-1"
NEW_VER="1.29.1"

@test "0 Init  " {
  echo ''>/var/work/tests/result/all
  echo ''>/var/work/tests/result/ok
  echo ''>/var/work/tests/result/requests
}

@test "1.1 Istio base CRDs are installed" {
  echo '1' >> /var/work/tests/result/all

  if kubectl get crd virtualservices.networking.istio.io >/dev/null 2>&1 \
     && kubectl get crd destinationrules.networking.istio.io >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Istio CRDs not found (base chart not installed?)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.2 Old-revision control plane (istiod-$OLD_REV) is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy "istiod-${OLD_REV}" -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Deployment istiod-${OLD_REV} is not ready"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "1.3 New-revision control plane (istiod-$NEW_REV) is running" {
  echo '1' >> /var/work/tests/result/all

  ready=$(kubectl get deploy "istiod-${NEW_REV}" -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Deployment istiod-${NEW_REV} is not ready"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.1 Namespace app is migrated to the new revision" {
  echo '1' >> /var/work/tests/result/all

  rev=$(kubectl get ns app -o jsonpath='{.metadata.labels.istio\.io/rev}' 2>/dev/null)
  if [[ "$rev" == "$NEW_REV" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "Namespace app istio.io/rev='$rev' (expected $NEW_REV)"
    result=1
  fi

  [ "$result" == "0" ]
}

@test "2.2 app pods run the new-revision sidecar (proxy $NEW_VER)" {
  echo '1' >> /var/work/tests/result/all

  total=$(kubectl get pods -n app -l app=ping-pong --no-headers 2>/dev/null | wc -l)
  # istio-proxy may be a regular container or a native sidecar (initContainer)
  new=$(kubectl get pods -n app -l app=ping-pong -o json | jq -r --arg v "$NEW_VER" '
    .items[]
    | select(([.spec.containers[], .spec.initContainers[]?] | map(select(.name=="istio-proxy") | .image) | any(test(":" + $v + "$") or test(":" + $v + "-"))))
    | .metadata.name' | sort -u | wc -l)

  if [[ "$total" -gt 0 ]] && [[ "$total" -eq "$new" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "app pods total=$total, with proxy $NEW_VER=$new"
    result=1
  fi

  [ "$result" == "0" ]
}
