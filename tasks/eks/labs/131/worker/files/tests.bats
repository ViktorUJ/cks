#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-131"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-131 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Deployment web has topology spread and 3 Ready replicas in >=2 zones" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  tsc_key=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null)
  tsc_unsat=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].whenUnsatisfiable}' 2>/dev/null)
  tsc_mlk=$(kubectl get deploy web -n "$NS" -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].matchLabelKeys[0]}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=web -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  zones=""
  for n in $nodes; do
    z=$(kubectl get node "$n" -o jsonpath="{.metadata.labels['topology\.kubernetes\.io/zone']}" 2>/dev/null)
    zones="$zones $z"
  done
  uniq_zones=$(echo "$zones" | tr ' ' '\n' | sort -u | grep -c '.')
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "3" ]] && \
     [[ "$tsc_key" == "topology.kubernetes.io/zone" ]] && \
     [[ "$tsc_unsat" == "DoNotSchedule" ]] && \
     [[ "$tsc_mlk" == "pod-template-hash" ]] && \
     [[ "$uniq_zones" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "web image=$image ready=$ready tsc_key=$tsc_key tsc_unsat=$tsc_unsat tsc_mlk=$tsc_mlk zones=$zones"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3/drain_blocked.txt explains PDB minAvailable blocking drain" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/drain_blocked.txt
  if [[ -s "$f" ]] && grep -qi 'pdb' "$f" && grep -qi 'minavailable' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention PDB and minAvailable"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. PDB web-pdb relaxed to minAvailable=2 and drain confirmed" {
  echo '1' >> /var/work/tests/result/all
  min=$(kubectl get pdb web-pdb -n "$NS" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/drain_ok.txt
  if [[ "$min" == "2" ]] && [[ -s "$f" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pdb minAvailable=$min; file $f missing/empty"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. PDB web-pdb has unhealthyPodEvictionPolicy AlwaysAllow with explanation" {
  echo '1' >> /var/work/tests/result/all
  policy=$(kubectl get pdb web-pdb -n "$NS" -o jsonpath='{.spec.unhealthyPodEvictionPolicy}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/unhealthy_policy.txt
  if [[ "$policy" == "AlwaysAllow" ]] && [[ -s "$f" ]] && grep -qi 'alwaysallow' "$f" \
     && grep -qiE 'crashloopbackoff|нездоров' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "policy=$policy; file $f missing/empty or missing keywords"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Rolling update of web finished with no pods stuck Pending" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  updated=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  pending=$(kubectl get po -n "$NS" -l app=web --field-selector=status.phase=Pending \
    --no-headers 2>/dev/null | wc -l)
  f=/var/work/tests/artifacts/6/rollout.txt
  if [[ "$ready" == "3" ]] && [[ "$updated" == "3" ]] && [[ "$pending" -eq 0 ]] \
     && [[ -s "$f" ]] && grep -qi 'rolled out' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ready=$ready updated=$updated pending=$pending; file $f missing/empty"
    result=1
  fi
  [ "$result" == "0" ]
}
