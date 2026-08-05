#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-101"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-101 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Deployment web (viktoruj/ping_pong, 3 replicas) runs on EC2 nodes, not Fargate" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=web -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  fargate=$(echo "$nodes" | grep -o 'fargate-' | wc -l)
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "3" ]] && [[ "$fargate" -eq 0 ]] && [[ -n "$nodes" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web image=$image ready=$ready nodes=$nodes fargate_hits=$fargate"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3/nodes.txt lists both a Fargate node and an EC2 node" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/nodes.txt
  if [[ -s "$f" ]] && grep -q 'fargate-' "$f" && grep -q 'ip-' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not list both fargate and ec2 nodes"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Artifact 4/podip.txt holds a web pod IP inside the VPC CIDR 10.10.0.0/16" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/podip.txt
  if [[ -s "$f" ]] && grep -Eq '(^|[^0-9])10\.10\.' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or IP is not from 10.10.0.0/16"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5/ami.txt shows the workload node runs Amazon Linux (AL2023)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/ami.txt
  if [[ -s "$f" ]] && grep -qi 'Amazon Linux' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention Amazon Linux"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Deployment batch (6 replicas, cpu requests) is fully scheduled by Karpenter" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy batch -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  req=$(kubectl get deploy batch -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  if [[ "$ready" == "6" ]] && [[ -n "$req" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "batch ready=$ready cpu_request=$req"
    result=1
  fi
  [ "$result" == "0" ]
}
