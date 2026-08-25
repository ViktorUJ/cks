#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-106"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-106 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. StorageClass gp3-immediate uses ebs.csi.aws.com with Immediate binding" {
  echo '1' >> /var/work/tests/result/all
  prov=$(kubectl get sc gp3-immediate -o jsonpath='{.provisioner}' 2>/dev/null)
  mode=$(kubectl get sc gp3-immediate -o jsonpath='{.volumeBindingMode}' 2>/dev/null)
  if [[ "$prov" == "ebs.csi.aws.com" ]] && [[ "$mode" == "Immediate" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "gp3-immediate provisioner=$prov mode=$mode"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. StatefulSet db (5Gi on gp3-immediate) and its PVC exist" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get sts db -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  sc=$(kubectl get sts db -n "$NS" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' 2>/dev/null)
  size=$(kubectl get sts db -n "$NS" -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' 2>/dev/null)
  pvc=$(kubectl get pvc -n "$NS" --no-headers 2>/dev/null | grep -c '^data-db-0 ')
  if [[ "$image" == *ping_pong* ]] && [[ "$sc" == "gp3-immediate" ]] \
    && [[ "$size" == "5Gi" ]] && [[ "$pvc" -ge 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "db image=$image sc=$sc size=$size pvc_hits=$pvc"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Diagnosis artifact explains Immediate zone binding (lucky vs guaranteed)" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/diagnosis.txt
  if [[ -s "$f" ]] && grep -q 'Immediate' "$f" \
    && grep -q 'nodeAffinity' "$f" \
    && grep -qiE 'zone|зона' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention Immediate/nodeAffinity/zone-зона"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. StorageClass gp3 (WaitForFirstConsumer) and db-fixed pod is Running in the volume zone" {
  echo '1' >> /var/work/tests/result/all
  prov=$(kubectl get sc gp3 -o jsonpath='{.provisioner}' 2>/dev/null)
  mode=$(kubectl get sc gp3 -o jsonpath='{.volumeBindingMode}' 2>/dev/null)
  expand=$(kubectl get sc gp3 -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
  phase=$(kubectl get po db-fixed-0 -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  node=$(kubectl get po db-fixed-0 -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
  node_zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null)
  pv=$(kubectl get pvc data-db-fixed-0 -n "$NS" -o jsonpath='{.spec.volumeName}' 2>/dev/null)
  pv_zone=$(kubectl get pv "$pv" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}' 2>/dev/null)
  if [[ "$prov" == "ebs.csi.aws.com" ]] && [[ "$mode" == "WaitForFirstConsumer" ]] \
    && [[ "$expand" == "true" ]] && [[ "$phase" == "Running" ]] \
    && [[ -n "$node_zone" ]] && [[ "$node_zone" == "$pv_zone" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "gp3 prov=$prov mode=$mode expand=$expand; db-fixed-0 phase=$phase node_zone=$node_zone pv_zone=$pv_zone"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. PVC data-db-fixed-0 expanded from 5Gi to 10Gi" {
  echo '1' >> /var/work/tests/result/all
  cap=$(kubectl get pvc data-db-fixed-0 -n "$NS" -o jsonpath='{.status.capacity.storage}' 2>/dev/null)
  req=$(kubectl get pvc data-db-fixed-0 -n "$NS" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
  if [[ "$cap" == "10Gi" ]] && [[ "$req" == "10Gi" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "data-db-fixed-0 capacity=$cap requests=$req"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Snapshot db-snap of data-db-fixed-0 and a restore PVC exist (best effort)" {
  echo '1' >> /var/work/tests/result/all
  src=$(kubectl get volumesnapshot db-snap -n "$NS" -o jsonpath='{.spec.source.persistentVolumeClaimName}' 2>/dev/null)
  class=$(kubectl get volumesnapshot db-snap -n "$NS" -o jsonpath='{.spec.volumeSnapshotClassName}' 2>/dev/null)
  ds_kind=$(kubectl get pvc data-restored -n "$NS" -o jsonpath='{.spec.dataSource.kind}' 2>/dev/null)
  ds_name=$(kubectl get pvc data-restored -n "$NS" -o jsonpath='{.spec.dataSource.name}' 2>/dev/null)
  if [[ "$src" == "data-db-fixed-0" ]] && [[ -n "$class" ]] \
    && [[ "$ds_kind" == "VolumeSnapshot" ]] && [[ "$ds_name" == "db-snap" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "db-snap source=$src class=$class; data-restored dataSource.kind=$ds_kind name=$ds_name"
    result=1
  fi
  [ "$result" == "0" ]
}
