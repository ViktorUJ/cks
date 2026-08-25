#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-111"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-111 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Deployment spotapp (4 replicas) tolerates spot-lab taint and lands on spot nodes" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy spotapp -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy spotapp -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  tgps=$(kubectl get deploy spotapp -n "$NS" -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}' 2>/dev/null)
  prestop=$(kubectl get deploy spotapp -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].lifecycle.preStop.exec.command}' 2>/dev/null)
  tol=$(kubectl get deploy spotapp -n "$NS" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="dedicated")].value}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  all_spot="1"
  if [[ -z "$nodes" ]]; then
    all_spot="0"
  fi
  for node in $nodes; do
    cap=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.karpenter\.sh/capacity-type}' 2>/dev/null)
    if [[ "$cap" != "spot" ]]; then
      all_spot="0"
    fi
  done
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "4" ]] && [[ "$tgps" == "60" ]] \
     && [[ "$prestop" == *sleep* ]] && [[ "$tol" == "spot-lab" ]] && [[ "$all_spot" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "spotapp image=$image ready=$ready tgps=$tgps prestop=$prestop tol=$tol all_spot=$all_spot nodes=$nodes"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifacts confirm spot nodes and NodePool diversification (c/m/r categories)" {
  echo '1' >> /var/work/tests/result/all
  f1=/var/work/tests/artifacts/3/nodes.txt
  f2=/var/work/tests/artifacts/3/nodepool.txt
  ok1="0"
  ok2="0"
  if [[ -s "$f1" ]] && grep -qw 'spot' "$f1"; then
    ok1="1"
  fi
  if [[ -s "$f2" ]] && grep -qw 'c' "$f2" && grep -qw 'm' "$f2" && grep -qw 'r' "$f2"; then
    ok2="1"
  fi
  if [[ "$ok1" == "1" ]] && [[ "$ok2" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f1 must list a spot node; file $f2 must list categories c, m, r"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. PodDisruptionBudget spotapp-pdb with minAvailable 3" {
  echo '1' >> /var/work/tests/result/all
  ma=$(kubectl get pdb spotapp-pdb -n "$NS" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  sel=$(kubectl get pdb spotapp-pdb -n "$NS" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
  if [[ "$ma" == "3" ]] && [[ "$sel" == "spotapp" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pdb minAvailable=$ma selector.app=$sel"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Drain shows PDB blocks only voluntary eviction beyond minAvailable" {
  echo '1' >> /var/work/tests/result/all
  allowed=$(kubectl get pdb spotapp-pdb -n "$NS" -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/drain.txt
  if [[ -n "$allowed" ]] && [[ "$allowed" -le 1 ]] && [[ -s "$f" ]] \
     && grep -qi 'pdb' "$f" && grep -qiE 'добровольн|voluntary' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pdb disruptionsAllowed=$allowed; file $f must mention PDB and добровольн/voluntary"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact confirms Karpenter interruption handling is configured" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/interruption.txt
  if [[ -s "$f" ]] && grep -qi 'interrupt' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention interruption handling"
    result=1
  fi
  [ "$result" == "0" ]
}
