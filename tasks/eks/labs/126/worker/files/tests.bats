#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-126"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-126 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. AmazonEKSVPCResourceController is attached to the cluster IAM role" {
  echo '1' >> /var/work/tests/result/all
  # Имя кластера из kubeconfig, а не list-clusters[0]: второй кластер в аккаунте сбил бы
  # индекс, и тест проверял бы роль чужого кластера.
  cluster=$(kubectl config current-context 2>/dev/null | awk -F/ '{print $NF}')
  role_name=$(aws eks describe-cluster --name "$cluster" --query 'cluster.roleArn' --output text 2>/dev/null | sed 's|.*/||')
  attached=$(aws iam list-attached-role-policies --role-name "$role_name" \
    --query "AttachedPolicies[?PolicyName=='AmazonEKSVPCResourceController'].PolicyName" \
    --output text 2>/dev/null)
  f=/var/work/tests/artifacts/2/prereqs.txt
  if [[ "$attached" == "AmazonEKSVPCResourceController" ]] && [[ -s "$f" ]] \
     && grep -q 'AmazonEKSVPCResourceController' "$f" && grep -q 'ENABLE_POD_ENI' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "role=$role_name attached=$attached file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "3. SecurityGroupPolicy secured-sgp references an existing security group" {
  echo '1' >> /var/work/tests/result/all
  sgp_sg=$(kubectl get securitygrouppolicy secured-sgp -n "$NS" \
    -o jsonpath='{.spec.securityGroups.groupIds[0]}' 2>/dev/null)
  selector=$(kubectl get securitygrouppolicy secured-sgp -n "$NS" \
    -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
  f=/var/work/tests/artifacts/3/sg_id.txt
  file_sg=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
  if [[ -n "$sgp_sg" ]] && [[ "$sgp_sg" == "$file_sg" ]] && [[ "$selector" == "secured" ]] \
     && aws ec2 describe-security-groups --group-ids "$sgp_sg" >/dev/null 2>&1; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "sgp_sg=$sgp_sg file_sg=$file_sg selector=$selector"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "4. Deployment secured-app exists with label app=secured and artifact records the probe symptom" {
  echo '1' >> /var/work/tests/result/all
  image=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  label=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
  f=/var/work/tests/artifacts/4/pod_not_ready.txt
  if [[ "$image" == *ping_pong* ]] && [[ "$label" == "secured" ]] && [[ -s "$f" ]] \
     && grep -qiE 'Readiness probe failed|Unhealthy' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "image=$image label=$label file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "5. Probe fixed: secured-app is 1/1 Ready after the node-SG inbound rule" {
  echo '1' >> /var/work/tests/result/all
  ready=$(kubectl get deploy secured-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  f=/var/work/tests/artifacts/5/pod_ready.txt
  if [[ "$ready" == "1" ]] && [[ -s "$f" ]] && grep -q '1/1' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "ready=$ready file=$f"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6. DNS fixed: artifact explains the missing inbound rule on port 53" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/dns_fix.txt
  # Пакет теряется НЕ на egress пода (там дефолтный allow-all), а на входе принимающей
  # стороны - cluster primary SG, за которой живёт CoreDNS на Fargate. Артефакт должен
  # показывать именно это, поэтому ищем порт и признак входящего правила.
  if [[ -s "$f" ]] && grep -q '53' "$f" && grep -qiE 'inbound|входящ|ingress' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not mention 53 and the inbound rule side"
    result=1
  fi
  [ "$result" == "0" ]
}

@test "6a. DNS really resolves from a pod covered by the SecurityGroupPolicy" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/6/dns_fix.txt
  # Живая проверка вместо доверия артефакту: поднимаем свой под с меткой app=secured,
  # то есть под тем же SecurityGroupPolicy, и требуем успешного резолва.
  node_selector='{"spec":{"nodeSelector":{"work_type":"nitro"}}}'
  kubectl delete pod dns-verify -n "$NS" --ignore-not-found >/dev/null 2>&1
  kubectl run dns-verify -n "$NS" --image=busybox --restart=Never --labels='app=secured' \
    --overrides="$node_selector" --command -- \
    sh -c 'nslookup kubernetes.default.svc.cluster.local' >/dev/null 2>&1
  result=1
  for i in $(seq 1 20); do
    phase=$(kubectl get pod dns-verify -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$phase" == "Succeeded" ]] || [[ "$phase" == "Failed" ]]; then
      break
    fi
    sleep 5
  done
  logs=$(kubectl logs dns-verify -n "$NS" 2>/dev/null || true)
  if grep -qi 'Address' <<< "$logs" && ! grep -qi 'timed out' <<< "$logs"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "dns-verify logs: $logs"
  fi
  kubectl delete pod dns-verify -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
  [ "$result" == "0" ]
}

@test "7. Same-node trap: artifact compares secured-app and CoreDNS nodes" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/same_node_trap.txt
  # Берём под именно Deployment, а не диагностические поды: они в этой лабе тоже носят
  # метку app=secured, чтобы на них действовал SecurityGroupPolicy.
  app_node=$(kubectl get pod -n "$NS" -l app=secured \
    -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.spec.nodeName}{"\n"}{end}' \
    2>/dev/null | head -1)
  # Эксперимент должен быть ПРОВЕДЁН, а не описан: в артефакте ждём состояние до починки
  # (timed out) и разбор разницы между режимами strict и standard.
  if [[ -s "$f" ]] && [[ -n "$app_node" ]] && grep -q "$app_node" "$f" \
     && grep -qiE 'timed out' "$f" \
     && grep -qi 'strict' "$f" && grep -qi 'standard' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty, app_node=$app_node not found, or trap not explained"
    result=1
  fi
  [ "$result" == "0" ]
}
