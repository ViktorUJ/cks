#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-123"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-123 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Inventory artifact lists default and stateful NodePool" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/inventory.txt
  if [[ -s "$f" ]] && grep -q 'default' "$f" && grep -q 'stateful' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not list both NodePools"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. StatefulSet db (3 replicas) tolerates taint and runs on stateful pool" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get sts db -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get sts db -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  tol=$(kubectl get sts db -n "$NS" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="dedicated")].value}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=db -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  offpool=0
  for n in $nodes; do
    wt=$(kubectl get node "$n" -o jsonpath='{.metadata.labels.work_type}' 2>/dev/null)
    [[ "$wt" != "stateful" ]] && offpool=1
  done
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "3" ]] && [[ "$tol" == "stateful" ]] && [[ "$offpool" -eq 0 ]] && [[ -n "$nodes" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "db image=$image ready=$ready toleration=$tol nodes=$nodes offpool=$offpool"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. PodDisruptionBudget db-pdb protects StatefulSet db" {
  echo '1' >> /var/work/tests/result/all
  maxun=$(kubectl get pdb db-pdb -n "$NS" -o jsonpath='{.spec.maxUnavailable}' 2>/dev/null)
  sel=$(kubectl get pdb db-pdb -n "$NS" -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
  if [[ "$maxun" == "1" ]] && [[ "$sel" == "db" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "db-pdb maxUnavailable=$maxun selector.app=$sel"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5 documents blocked consolidation attempt (PDB observation)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/consolidation.txt
  if [[ -s "$f" ]] && grep -qi 'pdb' "$f" && grep -Eqi 'unconsolidatable|prevents pod evict|prevents.*evict' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention pdb + Unconsolidatable/prevents pod eviction"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Point fix: do-not-disrupt only on db-0, explained in artifact 6" {
  echo '1' >> /var/work/tests/result/all
  ann0=$(kubectl get po db-0 -n "$NS" -o jsonpath='{.metadata.annotations.karpenter\.sh/do-not-disrupt}' 2>/dev/null)
  ann1=$(kubectl get po db-1 -n "$NS" -o jsonpath='{.metadata.annotations.karpenter\.sh/do-not-disrupt}' 2>/dev/null)
  ann2=$(kubectl get po db-2 -n "$NS" -o jsonpath='{.metadata.annotations.karpenter\.sh/do-not-disrupt}' 2>/dev/null)
  f=/var/work/tests/artifacts/6/fix.txt
  if [[ "$ann0" == "true" ]] && [[ -z "$ann1" ]] && [[ -z "$ann2" ]] \
     && [[ -s "$f" ]] && grep -qi 'pdb' "$f" && grep -qi 'do-not-disrupt' "$f" && grep -Eqi 'budget|бюджет' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "db-0 annotation=$ann0 db-1=$ann1 db-2=$ann2; file $f must exist and mention pdb, do-not-disrupt, budget"
    result=1
  fi
  [ "$result" == "0" ]
}
