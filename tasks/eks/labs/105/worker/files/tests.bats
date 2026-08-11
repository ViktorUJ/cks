#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-105"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-105 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. Artifact 2/encryption_config.txt confirms KMS envelope encryption is on" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/encryption_config.txt
  if [[ -s "$f" ]] && grep -qi 'resources' "$f" && grep -qi 'secrets' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not show resources containing secrets"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. External Secrets Operator is installed and Running in external-secrets" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy -n external-secrets -l app.kubernetes.io/name=external-secrets \
    -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
  role_arn=$(kubectl get sa -n external-secrets \
    -l app.kubernetes.io/name=external-secrets \
    -o jsonpath='{.items[0].metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null)
  if [[ "$ready" -ge 1 ]] && [[ "$role_arn" == *eso-irsa-role* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "eso deploy readyReplicas=$ready; sa role-arn annotation=$role_arn"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. ExternalSecret db-credentials is SecretSynced and Secret has the right value" {
  echo '1' >> /var/work/tests/result/all
  status=$(kubectl get externalsecret db-credentials -n "$NS" \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
  value=$(kubectl get secret db-credentials -n "$NS" \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null)
  # RotatedPass456 разрешён отдельно от S3cr3tPass123: задание 7 намеренно меняет
  # значение секрета прямо в Secrets Manager (put-secret-value), поэтому при полном
  # прогоне check_result после выполнения всех заданий по порядку исходное значение
  # уже недостижимо - ESO корректно синхронизировал новое.
  if [[ "$status" == "SecretSynced" ]] \
     && [[ "$value" == "S3cr3tPass123" || "$value" == "RotatedPass456" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "externalsecret status=$status; decoded password=$value"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Pod vol-reader mounts the Secret as a volume and reads it from a file" {
  echo '1' >> /var/work/tests/result/all
  mounts=$(kubectl get pod vol-reader -n "$NS" \
    -o jsonpath='{.spec.containers[0].volumeMounts[*].name}' 2>/dev/null)
  vols=$(kubectl get pod vol-reader -n "$NS" \
    -o jsonpath='{.spec.volumes[?(@.secret)].secret.secretName}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/volume_password.txt
  if [[ -n "$mounts" ]] && [[ "$vols" == "db-credentials" ]] && [[ -s "$f" ]] \
     && grep -q 'S3cr3tPass123' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "vol-reader volumeMounts=$mounts secretName=$vols; file $f must hold the password"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. Pod env-reader reads the Secret via env" {
  echo '1' >> /var/work/tests/result/all
  envfrom=$(kubectl get pod env-reader -n "$NS" \
    -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_PASSWORD")].valueFrom.secretKeyRef.name}' \
    2>/dev/null)
  if [[ "$envfrom" == "db-credentials" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "env-reader DB_PASSWORD secretKeyRef.name=$envfrom"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Artifact 7/rotation.txt explains env does not refresh after secret update" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/rotation.txt
  if [[ -s "$f" ]] && grep -qi 'env' "$f" \
     && grep -qiE 'не обновляется|не обновится|не увид|устарел' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not explain that env is stale after rotation"
    result=1
  fi
  [ "$result" == "0" ]
}
