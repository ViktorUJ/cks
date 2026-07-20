#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
CTX="cluster1-admin@cluster1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
  echo '' > /var/work/tests/result/requests
}

@test "1. CRD operators.stable.example.com (group, kind Operator, scope Namespaced)" {
  echo '1' >> /var/work/tests/result/all
  grp=$(kubectl get crd operators.stable.example.com --context $CTX -o jsonpath='{.spec.group}' 2>/dev/null)
  kind=$(kubectl get crd operators.stable.example.com --context $CTX -o jsonpath='{.spec.names.kind}' 2>/dev/null)
  scope=$(kubectl get crd operators.stable.example.com --context $CTX -o jsonpath='{.spec.scope}' 2>/dev/null)
  if [[ "$grp" == "stable.example.com" ]] && [[ "$kind" == "Operator" ]] && [[ "$scope" == "Namespaced" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "crd group=$grp kind=$kind scope=$scope"; result=1; fi
  [ "$result" == "0" ]
}

@test "2. Helm release prom in namespace monitoring" {
  echo '1' >> /var/work/tests/result/all
  rel=$(helm ls -n monitoring -o json 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -c '^prom$')
  ns=$(kubectl get ns monitoring --context $CTX -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$rel" -ge 1 ]] && [[ "$ns" == "monitoring" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "helm release prom count=$rel ns=$ns"; result=1; fi
  [ "$result" == "0" ]
}

@test "3. Kustomize overlay applied: deployment kapp (3 replicas) in kustns" {
  echo '1' >> /var/work/tests/result/all
  rep=$(kubectl get deploy kapp -n kustns --context $CTX -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [[ "$rep" == "3" ]]; then
    echo '1' >> /var/work/tests/result/ok; result=0
  else echo "kapp replicas=$rep in kustns"; result=1; fi
  [ "$result" == "0" ]
}
