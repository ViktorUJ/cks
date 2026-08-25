#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-103"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Deployment baseline is ready and artifact 1/maxpods.txt has all nine keys matching" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy baseline -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy baseline -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=baseline -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  fargate=$(echo "$nodes" | grep -o 'fargate-' | wc -l)
  f=/var/work/tests/artifacts/1/maxpods.txt
  keys="node instance_type eni ips_per_eni vcpu formula cap expected_max_pods actual_allocatable_pods"
  missing=0
  for k in $keys; do
    grep -q "^${k}=" "$f" 2>/dev/null || missing=1
  done
  expected=$(grep '^expected_max_pods=' "$f" 2>/dev/null | cut -d= -f2)
  actual=$(grep '^actual_allocatable_pods=' "$f" 2>/dev/null | cut -d= -f2)
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && [[ "$fargate" -eq 0 ]] \
     && [[ -s "$f" ]] && [[ "$missing" -eq 0 ]] && [[ -n "$expected" ]] \
     && [[ "$expected" == "$actual" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "baseline image=$image ready=$ready fargate_hits=$fargate missing_keys=$missing expected=$expected actual=$actual"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Prefix delegation is on, deployment scale is ready, new node beats old node" {
  echo '1' >> /var/work/tests/result/all
  cluster=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
  addon_env=$(aws eks describe-addon --cluster-name "$cluster" --addon-name vpc-cni \
    --query 'addon.configurationValues' --output text 2>/dev/null)
  ready=$(kubectl get deploy scale -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/2/prefixdelegation.txt
  old_node=$(grep '^old_node=' "$f" 2>/dev/null | cut -d= -f2)
  new_node=$(grep '^new_node=' "$f" 2>/dev/null | cut -d= -f2)
  old_pods=$(grep '^old_node_allocatable_pods=' "$f" 2>/dev/null | cut -d= -f2)
  new_pods=$(grep '^new_node_allocatable_pods=' "$f" 2>/dev/null | cut -d= -f2)
  if [[ "$addon_env" == *ENABLE_PREFIX_DELEGATION*true* ]] && [[ "$ready" == "6" ]] \
     && [[ -s "$f" ]] && [[ -n "$old_node" ]] && [[ -n "$new_node" ]] \
     && [[ "$old_node" != "$new_node" ]] && [[ -n "$old_pods" ]] && [[ -n "$new_pods" ]] \
     && [[ "$new_pods" -gt "$old_pods" ]] && grep -qi 'prefix' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "addon_env=$addon_env ready=$ready old_node=$old_node new_node=$new_node old_pods=$old_pods new_pods=$new_pods"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3/cidrplan.txt sizes the subnet with /20 and warm pool headroom" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/cidrplan.txt
  if [[ -s "$f" ]] && grep -q '251' "$f" && grep -q '1019' "$f" && grep -q '4091' "$f" \
     && grep -q '/20' "$f" && grep -qi 'warm pool' "$f" && grep -qi 'rolling update' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not justify /20 with warm pool and rolling update"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Secondary CIDR 100.64.0.0/16 is associated and a subnet exists in it" {
  echo '1' >> /var/work/tests/result/all
  vpc=$(aws eks describe-cluster --name "$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
  state=$(aws ec2 describe-vpcs --vpc-ids "$vpc" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text 2>/dev/null)
  subnet=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" "Name=cidr-block,Values=100.64.1.0/24" \
    --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
  f=/var/work/tests/artifacts/4/secondary_cidr.txt
  if [[ "$state" == "associated" ]] && [[ "$subnet" != "None" ]] && [[ -n "$subnet" ]] \
     && [[ -s "$f" ]] && grep -q '100.64.0.0/16' "$f" && grep -qi 'associated' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "vpc=$vpc state=$state subnet=$subnet file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5/diagnostics.txt explains address exhaustion diagnostics" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/diagnostics.txt
  if [[ -s "$f" ]] && grep -q 'FailedCreatePodSandBox' "$f" && grep -q 'InsufficientCidrBlocks' "$f" \
     && grep -q 'AvailableIpAddressCount' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention the three diagnostic markers"
    result=1
  fi
  [ "$result" == "0" ]
}
