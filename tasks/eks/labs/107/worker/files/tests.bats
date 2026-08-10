#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-107"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-107 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. StorageClass efs-sc uses efs.csi.aws.com and the real fileSystemId" {
  echo '1' >> /var/work/tests/result/all
  prov=$(kubectl get sc efs-sc -o jsonpath='{.provisioner}' 2>/dev/null)
  mode=$(kubectl get sc efs-sc -o jsonpath='{.parameters.provisioningMode}' 2>/dev/null)
  fsid=$(kubectl get sc efs-sc -o jsonpath='{.parameters.fileSystemId}' 2>/dev/null)
  real_fsid=$(aws efs describe-file-systems --region eu-central-1 \
    --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
    --output text 2>/dev/null)
  if [[ "$prov" == "efs.csi.aws.com" ]] && [[ "$mode" == "efs-ap" ]] \
    && [[ -n "$fsid" ]] && [[ "$fsid" == "$real_fsid" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "efs-sc provisioner=$prov mode=$mode fsid=$fsid real_fsid=$real_fsid"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. PVC shared-data is ReadWriteMany, 5Gi, on efs-sc, Bound" {
  echo '1' >> /var/work/tests/result/all
  sc=$(kubectl get pvc shared-data -n "$NS" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
  mode=$(kubectl get pvc shared-data -n "$NS" -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
  size=$(kubectl get pvc shared-data -n "$NS" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
  phase=$(kubectl get pvc shared-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$sc" == "efs-sc" ]] && [[ "$mode" == "ReadWriteMany" ]] \
    && [[ "$size" == "5Gi" ]] && [[ "$phase" == "Bound" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "shared-data sc=$sc mode=$mode size=$size phase=$phase"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Deployment writer (3 replicas, spread by zone) all Running on shared-data" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy writer -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy writer -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  claim=$(kubectl get deploy writer -n "$NS" \
    -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
  tsc_key=$(kubectl get deploy writer -n "$NS" \
    -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null)
  nodes=$(kubectl get po -n "$NS" -l app=writer -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  zones=""
  for n in $nodes; do
    z=$(kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}' 2>/dev/null)
    zones="$zones $z"
  done
  zone_count=$(echo "$zones" | tr ' ' '\n' | sort -u | grep -c '.')
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "3" ]] \
    && [[ "$claim" == "shared-data" ]] \
    && [[ "$tsc_key" == "topology.kubernetes.io/zone" ]] \
    && [[ "$zone_count" -ge 2 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "writer image=$image ready=$ready claim=$claim tsc_key=$tsc_key zones=$zones"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Artifact 5/readback.txt: data written from one replica is visible from another" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/readback.txt
  if [[ -s "$f" ]] && grep -qi 'efs-rwx-test' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not contain the shared marker line"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Artifact 6/pv.yaml + explanation: EFS PV has no zone nodeAffinity" {
  echo '1' >> /var/work/tests/result/all
  pv=$(kubectl get pv -o jsonpath='{range .items[*]}{.spec.claimRef.name}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | awk '$1=="shared-data"{print $2}')
  affinity=$(kubectl get pv "$pv" -o jsonpath='{.spec.nodeAffinity}' 2>/dev/null)
  f1=/var/work/tests/artifacts/6/pv.yaml
  f2=/var/work/tests/artifacts/6/explanation.txt
  if [[ -n "$pv" ]] && [[ -z "$affinity" ]] && [[ -s "$f1" ]] \
    && [[ -s "$f2" ]] && grep -qi 'nodeAffinity' "$f2"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pv=$pv nodeAffinity=$affinity; files $f1 / $f2 missing/empty or no mention of nodeAffinity"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact 7: SG rule for NFS 2049 confirmed via AWS CLI, with diagnosis" {
  echo '1' >> /var/work/tests/result/all
  f1=/var/work/tests/artifacts/7/sg-rule.txt
  f2=/var/work/tests/artifacts/7/diagnosis.txt
  if [[ -s "$f1" ]] && grep -q '2049' "$f1" \
    && [[ -s "$f2" ]] && grep -q '2049' "$f2" \
    && grep -qiE 'FailedMount|таймаут|timeout' "$f2"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f1 missing/empty or no 2049; file $f2 missing/empty or no timeout wording"
    result=1
  fi
  [ "$result" == "0" ]
}
