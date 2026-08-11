#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-128"
NSB="eks-128-backend"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Gateway API CRDs installed and both namespaces exist" {
  echo '1' >> /var/work/tests/result/all
  crd=$(kubectl get crd gateways.gateway.networking.k8s.io \
    -o jsonpath='{.metadata.name}' 2>/dev/null)
  ns1=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  ns2=$(kubectl get ns "$NSB" -o jsonpath='{.metadata.name}' 2>/dev/null)
  result=1
  if [[ "$crd" == "gateways.gateway.networking.k8s.io" ]] && [[ "$ns1" == "$NS" ]] && \
     [[ "$ns2" == "$NSB" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "crd=$crd ns1=$ns1 ns2=$ns2"
  fi
  [ "$result" == "0" ]
}

@test "2. AWS Load Balancer Controller and Gateway class ALB (L7)" {
  echo '1' >> /var/work/tests/result/all
  lbc_ready=$(kubectl get deploy aws-load-balancer-controller -n kube-system \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  gc_controller=$(kubectl get gatewayclass aws-alb \
    -o jsonpath='{.spec.controllerName}' 2>/dev/null)
  result=1
  for i in $(seq 1 30); do
    programmed=$(kubectl get gateway web -n "$NS" \
      -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
    if [[ "${lbc_ready:-0}" -ge 1 ]] && \
       [[ "$gc_controller" == "gateway.k8s.aws/alb" ]] && [[ "$programmed" == "True" ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "lbc_ready=$lbc_ready gc_controller=$gc_controller programmed=$programmed"
  fi
  [ "$result" == "0" ]
}

@test "3. HTTPRoute app on ALB is Accepted, Gateway has an address" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/alb.txt
  result=1
  for i in $(seq 1 30); do
    accepted=$(kubectl get httproute app -n "$NS" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
    addr=$(kubectl get gateway web -n "$NS" \
      -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
    if [[ "$accepted" == "True" ]] && [[ -n "$addr" ]] && [[ -s "$f" ]] && \
       grep -q '"Type": "application"' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "accepted=$accepted addr=$addr file=$f"
  fi
  [ "$result" == "0" ]
}

@test "4. AWS Gateway API Controller and Gateway class amazon-vpc-lattice" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy -n aws-application-networking-system \
    -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
  gc_controller=$(kubectl get gatewayclass amazon-vpc-lattice \
    -o jsonpath='{.spec.controllerName}' 2>/dev/null)
  result=1
  for i in $(seq 1 30); do
    programmed=$(kubectl get gateway mesh -n "$NS" \
      -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
    if [[ "${ready:-0}" -ge 1 ]] && \
       [[ "$gc_controller" == "application-networking.k8s.aws/gateway-api-controller" ]] && \
       [[ "$programmed" == "True" ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "ready=$ready gc_controller=$gc_controller programmed=$programmed"
  fi
  [ "$result" == "0" ]
}

@test "5. Symptom: HTTPRoute rates without ReferenceGrant is RefNotPermitted" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/refnotpermitted.txt
  backend_ns=$(kubectl get httproute rates -n "$NS" \
    -o jsonpath='{.spec.rules[0].backendRefs[0].namespace}' 2>/dev/null)
  result=1
  for i in $(seq 1 20); do
    reason=$(kubectl get httproute rates -n "$NS" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}' 2>/dev/null)
    status=$(kubectl get httproute rates -n "$NS" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
    if [[ "$backend_ns" == "$NSB" ]] && [[ "$status" == "False" ]] && \
       [[ "$reason" == "RefNotPermitted" ]] && [[ -s "$f" ]] && \
       grep -q 'RefNotPermitted' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 5
  done
  if [[ "$result" != "0" ]]; then
    echo "backend_ns=$backend_ns status=$status reason=$reason file=$f"
  fi
  [ "$result" == "0" ]
}

@test "6. Fix: ReferenceGrant resolves the cross-namespace reference" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/resolved.txt
  rg_from_kind=$(kubectl get referencegrant -n "$NSB" \
    -o jsonpath='{.items[0].spec.from[0].kind}' 2>/dev/null)
  rg_from_ns=$(kubectl get referencegrant -n "$NSB" \
    -o jsonpath='{.items[0].spec.from[0].namespace}' 2>/dev/null)
  rg_to_kind=$(kubectl get referencegrant -n "$NSB" \
    -o jsonpath='{.items[0].spec.to[0].kind}' 2>/dev/null)
  result=1
  for i in $(seq 1 20); do
    status=$(kubectl get httproute rates -n "$NS" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
    if [[ "$rg_from_kind" == "HTTPRoute" ]] && [[ "$rg_from_ns" == "$NS" ]] && \
       [[ "$rg_to_kind" == "Service" ]] && [[ "$status" == "True" ]] && [[ -s "$f" ]] && \
       grep -q 'ResolvedRefs' "$f" && grep -q 'True' "$f"; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 5
  done
  if [[ "$result" != "0" ]]; then
    echo "rg_from_kind=$rg_from_kind rg_from_ns=$rg_from_ns rg_to_kind=$rg_to_kind status=$status file=$f"
  fi
  [ "$result" == "0" ]
}
