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

@test "3. Artifact 3/drain_blocked.txt holds a real blocked drain, not just words" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/drain_blocked.txt
  # Слов PDB и minAvailable недостаточно: их можно написать, не запуская drain вовсе.
  # Требуем вывод настоящей попытки выселения - вживую kubectl drain печатает
  # "error when evicting pods/... global timeout reached" и/или
  # "Cannot evict pod as it would violate the pod's disruption budget".
  if [[ -s "$f" ]] && grep -qi 'pdb' "$f" && grep -qi 'minavailable' "$f" \
     && grep -qiE 'global timeout reached|cannot evict pod|error when evicting' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or without PDB/minAvailable/eviction evidence"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. PDB relaxed to minAvailable=2, drain really evicted a pod, web is back to 3" {
  echo '1' >> /var/work/tests/result/all
  min=$(kubectl get pdb web-pdb -n "$NS" -o jsonpath='{.spec.minAvailable}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/drain_ok.txt
  # Непустого файла мало: успешный drain печатает "pod/... evicted" и "node/... drained",
  # а после лечения все три реплики обязаны снова быть готовы (замена встала на другой ноде).
  if [[ "$min" == "2" ]] && [[ -s "$f" ]] && grep -qi 'evicted' "$f" \
     && grep -qi 'drained' "$f" && [[ "$ready" == "3" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pdb minAvailable=$min ready=$ready; file $f missing/empty or without evicted/drained"
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

@test "6. Rolling update done, new revision is spread across zones within maxSkew" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  updated=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
  pending=$(kubectl get po -n "$NS" -l app=web --field-selector=status.phase=Pending \
    --no-headers 2>/dev/null | wc -l)
  f=/var/work/tests/artifacts/6/rollout.txt
  # Факт "выкатка прошла" сам по себе ничего не говорит про topology spread: она проходит и
  # без matchLabelKeys (проверено на стенде). Поэтому считаем перекос НОВОЙ ревизии по зонам
  # и требуем, чтобы он укладывался в maxSkew=1 - именно это обещает ограничение.
  # все поды после выкатки принадлежат одной ревизии, поэтому hash берём с любого из них
  hash=$(kubectl get po -n "$NS" -l app=web \
    -o jsonpath='{.items[0].metadata.labels.pod-template-hash}' 2>/dev/null || true)
  zones=""
  for n in $(kubectl get po -n "$NS" -l app=web,pod-template-hash="$hash" \
      -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null || true); do
    zones="$zones $(kubectl get node "$n" \
      -o jsonpath="{.metadata.labels['topology\.kubernetes\.io/zone']}" 2>/dev/null || true)"
  done
  counts=$(echo "$zones" | tr ' ' '\n' | grep . | sort | uniq -c | awk '{print $1}')
  max=$(echo "$counts" | sort -n | tail -1)
  min=$(echo "$counts" | sort -n | head -1)
  skew=$(( ${max:-0} - ${min:-0} ))
  if [[ "$ready" == "3" ]] && [[ "$updated" == "3" ]] && [[ "$pending" -eq 0 ]] \
     && [[ -s "$f" ]] && grep -qi 'rolled out' "$f" && [[ "$skew" -le 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ready=$ready updated=$updated pending=$pending hash=$hash zones='$zones' skew=$skew"
    result=1
  fi
  [ "$result" == "0" ]
}
