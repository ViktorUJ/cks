#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-125"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Auto Mode is enabled with general-purpose node pool" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/1/automode.txt
  # Имя кластера берём из kubeconfig, а НЕ из list-clusters[0]: если в аккаунте есть
  # второй кластер, индекс 0 укажет на чужой, и тест начнёт врать.
  cluster=$(kubectl config current-context 2>/dev/null | awk -F/ '{print $NF}')
  enabled=$(aws eks describe-cluster --name "$cluster" \
    --query 'cluster.computeConfig.enabled' --output text 2>/dev/null)
  pools=$(kubectl get nodepools -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  result=1
  if [[ "$enabled" == "True" ]] && [[ "$pools" == *general-purpose* ]] && [[ -s "$f" ]] && \
     grep -q '"enabled": true' "$f" && grep -q 'general-purpose' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "enabled=$enabled pools=$pools file=$f"
  fi
  [ "$result" == "0" ]
}

@test "2. Built-in system NodePool stays disabled" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/2/twopools.txt
  pools=$(kubectl get nodepools -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  result=1
  if [[ "$pools" != *system* ]] && [[ -s "$f" ]] && grep -q 'system' "$f" && \
     grep -q 'CriticalAddonsOnly' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "pools=$pools file=$f"
  fi
  [ "$result" == "0" ]
}

@test "3. Workload on general-purpose and EKS-owned built-in NodePool" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/3/builtin.txt
  image=$(kubectl get deploy web -n "$NS" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  ready=$(kubectl get deploy web -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  nodes=$(kubectl get pods -n "$NS" -l app=web -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null)
  on_fargate=0
  for n in $nodes; do
    [[ "$n" == fargate-* ]] && on_fargate=1
  done
  # Артефакт обязан показывать РЕАЛЬНЫЙ результат: правка встроенного пула проходит
  # (никакого admission-запрета нет), но объект принадлежит сервису. Поэтому ищем
  # признак принятой правки и владельца объекта, а не выдуманный отказ.
  result=1
  if [[ "$image" == *ping_pong* ]] && [[ "$ready" == "2" ]] && [[ "$on_fargate" == "0" ]] && \
     [[ -s "$f" ]] && grep -qi 'patched' "$f" && \
     grep -qiE 'managed-by|eks-auto-mode' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "image=$image ready=$ready on_fargate=$on_fargate file=$f"
  fi
  [ "$result" == "0" ]
}

@test "4. No operator access to an Auto Mode node, but the host is not hidden" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/4/nossh.txt
  # Раньше тест принимал любое слово error, и его удовлетворял AccessDenied на права
  # самого воркера - то есть доказательства не было. Теперь нужны три факта, каждый
  # из которых относится к САМОЙ ноде: нет ключевой пары, SSM не подключён, а хост
  # виден привилегированному поду (Bottlerocket).
  result=1
  if [[ -s "$f" ]] && grep -qi 'notconnected' "$f" && grep -qi 'bottlerocket' "$f" && \
     grep -qiE 'keyname|ключ' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty: need KeyName, SSM notconnected and Bottlerocket proof"
  fi
  [ "$result" == "0" ]
}

@test "5. Custom NodePool with explicit limits" {
  echo '1' >> /var/work/tests/result/all
  cpu_limit=$(kubectl get nodepool custom-limited \
    -o jsonpath='{.spec.limits.cpu}' 2>/dev/null)
  nodeclass=$(kubectl get nodepool custom-limited \
    -o jsonpath='{.spec.template.spec.nodeClassRef.name}' 2>/dev/null)
  result=1
  if [[ "$cpu_limit" == "10" ]] && [[ "$nodeclass" == "default" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "cpu_limit=$cpu_limit nodeclass=$nodeclass"
  fi
  [ "$result" == "0" ]
}
