#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-129"
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text 2>/dev/null | awk '{print $1}')

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-129 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. PV s3-pv (s3.csi.aws.com, real bucket) and PVC s3-pvc are Bound" {
  echo '1' >> /var/work/tests/result/all
  driver=$(kubectl get pv s3-pv -o jsonpath='{.spec.csi.driver}' 2>/dev/null)
  bucket=$(kubectl get pv s3-pv -o jsonpath='{.spec.csi.volumeAttributes.bucketName}' 2>/dev/null)
  am=$(kubectl get pv s3-pv -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null)
  sc=$(kubectl get pv s3-pv -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
  mo=$(kubectl get pv s3-pv -o jsonpath='{.spec.mountOptions[0]}' 2>/dev/null)
  # Имя бакета берём из переменной наверху файла: она требует s3:ListAllMyBuckets, которого
  # у воркера раньше не было - тест не мог пройти в принципе (real_bucket оставался пустым).
  real_bucket="$BUCKET"
  phase=$(kubectl get pvc s3-pvc -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$driver" == "s3.csi.aws.com" ]] && [[ "$bucket" == "$real_bucket" ]] \
    && [[ -n "$bucket" ]] && [[ "$am" == "ReadWriteMany" ]] && [[ "$sc" == "" ]] \
    && [[ "$mo" == *"region"* ]] && [[ "$phase" == "Bound" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pv driver=$driver bucket=$bucket real_bucket=$real_bucket am=$am sc=$sc mo=$mo pvc_phase=$phase"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. New file create and read (readme.txt) both work through the PVC" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy mountpoint-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  vol=$(kubectl get deploy mountpoint-app -n "$NS" \
    -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
  f1=/var/work/tests/artifacts/3/create.txt
  f2=/var/work/tests/artifacts/3/read.txt
  if [[ "$ready" == "1" ]] && [[ "$vol" == "s3-pvc" ]] \
    && [[ -s "$f1" ]] && grep -q 'test' "$f1" \
    && [[ -s "$f2" ]] && grep -q 'mountpoint demo bucket' "$f2"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "mountpoint-app ready=$ready vol=$vol; create.txt or read.txt missing/empty/wrong content"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. rename inside the volume fails and the bucket is untouched" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/rename.txt
  # Вживую mv на Mountpoint отвечает "Function not implemented" (ENOSYS - вызов rename не
  # реализован), а не "Operation not permitted" (EPERM из задания 5). Принимаем оба текста,
  # но дополнительно проверяем факт со стороны AWS: newfile.txt на месте, renamed.txt нет.
  # Эту часть артефактом не подделать.
  keys=$(aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' \
    --output text 2>/dev/null || true)
  if [[ -s "$f" ]] && grep -qiE 'Function not implemented|Operation not permitted' "$f" \
    && [[ "$keys" == *"newfile.txt"* ]] && [[ "$keys" != *"renamed.txt"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file=$f bucket=$BUCKET keys='$keys' (need newfile.txt present, renamed.txt absent)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. append and mid-file write fail, artifact explains why" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/5/writesemantics.txt
  if [[ -s "$f" ]] && grep -qi 'Operation not permitted' "$f" \
    && grep -qiE 'append|rename|середин' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention Operation not permitted / append-rename-середин"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Backup artifact explains no EBS snapshot and confirms bucket versioning" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/backup.txt
  if [[ -s "$f" ]] && grep -qi 'versioning' "$f" \
    && grep -qiE 'snapshot|снапшот' "$f" \
    && grep -qi 'Enabled' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention versioning/snapshot-снапшот/Enabled"
    result=1
  fi
  [ "$result" == "0" ]
}
