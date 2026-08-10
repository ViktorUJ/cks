#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-112"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-112 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Deployment fg-app (viktoruj/ping_pong, 2 replicas, Guaranteed) runs on Fargate" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy fg-app -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy fg-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  req_cpu=$(kubectl get deploy fg-app -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  lim_cpu=$(kubectl get deploy fg-app -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=fg-app -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  non_fargate=$(echo "$nodes" | tr ' ' '\n' | grep -vc '^fargate-')
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && [[ "$req_cpu" == "$lim_cpu" ]] \
    && [[ -n "$req_cpu" ]] && [[ -n "$nodes" ]] && [[ "$non_fargate" -eq 0 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "fg-app image=$image ready=$ready req_cpu=$req_cpu lim_cpu=$lim_cpu nodes=$nodes"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3/capacity.txt shows the CapacityProvisioned annotation" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/capacity.txt
  if [[ -s "$f" ]] && grep -qi 'vCPU' "$f" && grep -qi 'GB' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show vCPU/GB capacity"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Privileged pod is rejected on Fargate, artifact explains why" {
  echo '1' >> /var/work/tests/result/all
  phase=$(kubectl get po fg-privileged -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/privileged.txt
  if [[ "$phase" != "Running" ]] && [[ -s "$f" ]] && grep -qi 'privileged' "$f" && grep -qi 'fargate' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "fg-privileged phase=$phase; file $f must exist and mention privileged and Fargate"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Ephemeral storage extended to 30Gi and pod runs" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy fg-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  req_st=$(kubectl get deploy fg-app -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.ephemeral-storage}' 2>/dev/null)
  lim_st=$(kubectl get deploy fg-app -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.ephemeral-storage}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]] && [[ "$req_st" == "$lim_st" ]] && [[ "$req_st" == "30Gi" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "fg-app ready=$ready req_storage=$req_st lim_storage=$lim_st (expected 30Gi, requests=limits)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact 6/costmodel.txt explains Fargate vs node group cost structure" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/costmodel.txt
  if [[ -s "$f" ]] && grep -qi 'vCPU' "$f" && grep -qi 'под' "$f" \
    && grep -qiE 'node group|нод|инстанс' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention vCPU, pod and node group/instance"
    result=1
  fi
  [ "$result" == "0" ]
}
