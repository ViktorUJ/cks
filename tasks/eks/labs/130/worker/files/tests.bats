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
  if [[ -s "$f" ]] && [[ "$status" == "COMPLETE" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or scan status=$status (expected COMPLETE)"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Pod referencing the image by @sha256 digest exists in eks-130" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get po -n "$NS" -l app=digest-app -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null)
  if [[ "$image" == *"$REPO@sha256:"* ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pod image=$image, expected it to reference $REPO@sha256:..."
    result=1
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
