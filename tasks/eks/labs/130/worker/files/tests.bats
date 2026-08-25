#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-130"
REPO="eks-lab130/app"
REGION="eu-central-1"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. ECR repository eks-lab130/app is IMMUTABLE with scanOnPush" {
  echo '1' >> /var/work/tests/result/all
  mut=$(aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" \
    --query 'repositories[0].imageTagMutability' --output text 2>/dev/null)
  scan=$(aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" \
    --query 'repositories[0].imageScanningConfiguration.scanOnPush' --output text 2>/dev/null)
  if [[ "$mut" == "IMMUTABLE" ]] && [[ "$scan" == "True" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "repo=$REPO mutability=$mut scanOnPush=$scan"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "2. Image v1 pushed to eks-lab130/app" {
  echo '1' >> /var/work/tests/result/all
  tags=$(aws ecr describe-images --repository-name "$REPO" --region "$REGION" \
    --query 'imageDetails[].imageTags' --output text 2>/dev/null)
  if echo "$tags" | grep -qw 'v1'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "repo=$REPO tags=$tags"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. Artifact 3/denied.txt proves IMMUTABLE rejected the repeat push of v1" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/denied.txt
  if [[ -s "$f" ]] && grep -qi 'v1' "$f" && grep -Eqi 'immutable|already exists|ImageTagAlreadyExists' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention v1 and immutable/already exists"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Artifact 4/scan-summary.txt holds scan findings summary for v1" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/scan-summary.txt
  status=$(aws ecr describe-image-scan-findings --repository-name "$REPO" \
    --image-id imageTag=v1 --region "$REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  # Статус проверяем и живьём, и в артефакте: у образа FROM scratch скан отдаёт FAILED с
  # UnsupportedImageError, и такой отчёт не должен считаться успешной проверкой образа.
  if [[ -s "$f" ]] && [[ "$status" == "COMPLETE" ]] && grep -q 'COMPLETE' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty/without COMPLETE or scan status=$status (expected COMPLETE)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Pod pulled by @sha256 digest from private ECR and is Running" {
  echo '1' >> /var/work/tests/result/all
  # Ссылки по digest недостаточно: раньше тест проверял только строку образа и проходил при
  # поде в CrashLoopBackOff. Вживую так и было - podman с x86_64 воркера пушит одноарочный
  # манифест, Karpenter поднимал arm64-ноду, и контейнер умирал с exitCode 255 и пустыми
  # логами. Поэтому требуем Running без перезапусков: это доказывает и pull из приватного
  # ECR по digest, и то, что образ подходит ноде.
  # ВАЖНО (errexit): bats выполняет тест с set -e, поэтому пустой список подов роняет тест на
  # самом присваивании - вместо понятного сообщения студент видит ссылку на строку теста.
  # Гасим через || true и читаем все поля ВНУТРИ цикла, иначе под, созданный позже, не увидим.
  result=1
  for i in $(seq 1 40); do
    image=$(kubectl get po -n "$NS" -l app=digest-app \
      -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || true)
    phase=$(kubectl get po -n "$NS" -l app=digest-app \
      -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
    restarts=$(kubectl get po -n "$NS" -l app=digest-app \
      -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null || true)
    if [[ "$image" == *"$REPO@sha256:"* ]] && [[ "$phase" == "Running" ]] \
      && [[ "${restarts:-0}" == "0" ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 15
  done
  if [[ "$result" != "0" ]]; then
    echo "pod image=$image phase=$phase restarts=$restarts (need $REPO@sha256:..., Running, 0 restarts)"
  fi
  [ "$result" == "0" ]
}

@test "6. Pull through cache rule for registry.k8s.io cached the pause image" {
  echo '1' >> /var/work/tests/result/all
  rule=$(aws ecr describe-pull-through-cache-rules --region "$REGION" \
    --query "pullThroughCacheRules[?ecrRepositoryPrefix=='k8s-cache'].upstreamRegistryUrl" \
    --output text 2>/dev/null)
  cached=$(aws ecr describe-repositories --region "$REGION" \
    --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName" \
    --output text 2>/dev/null)
  if [[ "$rule" == "registry.k8s.io" ]] && [[ -n "$cached" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "rule upstream=$rule cached_repo=$cached"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "7. Docker Hub pull through cache rule with a Secrets Manager credential is configured" {
  echo '1' >> /var/work/tests/result/all
  secret=$(aws secretsmanager describe-secret \
    --secret-id ecr-pullthroughcache/dockerhub-creds --region "$REGION" \
    --query 'Name' --output text 2>/dev/null)
  rule=$(aws ecr describe-pull-through-cache-rules --region "$REGION" \
    --query "pullThroughCacheRules[?ecrRepositoryPrefix=='docker-hub'].credentialArn" \
    --output text 2>/dev/null)
  if [[ "$secret" == ecr-pullthroughcache/dockerhub-creds* ]] && [[ "$rule" == *dockerhub-creds* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "secret=$secret rule_credential_arn=$rule"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "8. Lifecycle policy is attached to eks-lab130/app" {
  echo '1' >> /var/work/tests/result/all
  policy=$(aws ecr get-lifecycle-policy --repository-name "$REPO" --region "$REGION" \
    --query 'lifecyclePolicyText' --output text 2>/dev/null)
  if [[ -n "$policy" ]] && echo "$policy" | grep -q 'rulePriority'; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "repo=$REPO lifecycle_policy=$policy"
    result=1
  fi
  [ "$result" == "0" ]
}
