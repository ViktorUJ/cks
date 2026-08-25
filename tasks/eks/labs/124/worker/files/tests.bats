#!/usr/bin/env bats
export KUBECONFIG=/home/ubuntu/.kube/config
NS="eks-124"

@test "0 Init" {
  echo '' > /var/work/tests/result/all
  echo '' > /var/work/tests/result/ok
}

@test "1. Namespace eks-124 exists" {
  echo '1' >> /var/work/tests/result/all
  result=$(kubectl get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
  if [[ "$result" == "$NS" ]]; then
    echo '1' >> /var/work/tests/result/ok
  fi
  [ "$result" == "$NS" ]
}

@test "2. kube-prometheus-stack is installed and Prometheus is Running" {
  echo '1' >> /var/work/tests/result/all
  result=1
  for i in $(seq 1 30); do
    svc=$(kubectl get svc -n monitoring kube-prometheus-stack-prometheus \
      -o jsonpath='{.metadata.name}' 2>/dev/null)
    ready=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
    fail_count=$(echo "$ready" | grep -o 'false' | wc -l)
    # Без requests под Prometheus остаётся BestEffort: Karpenter не учитывает его
    # потребность при выборе ноды, а kubelet выселяет такие поды первыми при давлении
    # памяти - метрика для KEDA исчезает вместе с подом.
    qos=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus \
      -o jsonpath='{.items[*].status.qosClass}' 2>/dev/null)
    if [[ -n "$svc" ]] && [[ -n "$ready" ]] && [[ "$fail_count" -eq 0 ]] && \
       [[ -n "$qos" ]] && [[ "$qos" != *BestEffort* ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "monitoring svc=$svc prometheus ready=$ready qos=$qos (waited up to 5 minutes)"
  fi
  [ "$result" == "0" ]
}

@test "3. KEDA operator and metrics apiserver are Running in keda namespace" {
  echo '1' >> /var/work/tests/result/all
  result=1
  for i in $(seq 1 18); do
    op=$(kubectl get pods -n keda -l app=keda-operator \
      -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    ma=$(kubectl get pods -n keda -l app=keda-operator-metrics-apiserver \
      -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ "$op" == *Running* ]] && [[ "$ma" == *Running* ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "keda-operator phase=$op keda-operator-metrics-apiserver phase=$ma (waited up to 3 minutes)"
  fi
  [ "$result" == "0" ]
}

@test "4. Deployment demo-app (ping_pong, cpu request, 1 replica) is Ready" {
  echo '1' >> /var/work/tests/result/all
  result=1
  for i in $(seq 1 12); do
    image=$(kubectl get deploy demo-app -n "$NS" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    cpu=$(kubectl get deploy demo-app -n "$NS" \
      -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    ready=$(kubectl get deploy demo-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [[ "$image" == *ping_pong* ]] && [[ -n "$cpu" ]] && [[ "$ready" == "1" ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 10
  done
  if [[ "$result" != "0" ]]; then
    echo "demo-app image=$image cpu=$cpu ready=$ready"
  fi
  [ "$result" == "0" ]
}

@test "5. ScaledObject demo-app (prometheus trigger) created HPA keda-hpa-demo-app" {
  echo '1' >> /var/work/tests/result/all
  result=1
  for i in $(seq 1 12); do
    trigger=$(kubectl get scaledobject demo-app -n "$NS" \
      -o jsonpath='{.spec.triggers[0].type}' 2>/dev/null)
    target=$(kubectl get scaledobject demo-app -n "$NS" \
      -o jsonpath='{.spec.scaleTargetRef.name}' 2>/dev/null)
    hpa=$(kubectl get hpa keda-hpa-demo-app -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)
    if [[ "$trigger" == "prometheus" ]] && [[ "$target" == "demo-app" ]] && \
       [[ "$hpa" == "keda-hpa-demo-app" ]]; then
      echo '1' >> /var/work/tests/result/ok
      result=0
      break
    fi
    sleep 5
  done
  if [[ "$result" != "0" ]]; then
    echo "trigger=$trigger target=$target hpa=$hpa"
  fi
  [ "$result" == "0" ]
}

@test "6. Load from stress-generator scales demo-app above minReplicaCount" {
  echo '1' >> /var/work/tests/result/all
  fb=/var/work/tests/artifacts/6/hpa_before.txt
  fa=/var/work/tests/artifacts/6/hpa_after.txt
  # REPLICAS - предпоследняя колонка. Позицию с начала строки брать нельзя: у внешней
  # метрики kubectl печатает TARGETS как "378m/100m (avg)", это ДВА поля, и $6 попадает
  # в MAXPODS. Последняя колонка всегда AGE, поэтому REPLICAS - это $(NF-1).
  before_replicas=$(awk 'NR==2 {print $(NF-1)}' "$fb" 2>/dev/null)
  after_replicas=$(awk 'NR==2 {print $(NF-1)}' "$fa" 2>/dev/null)
  result=1
  # Артефакты - основное доказательство: их сохраняют пока нагрузка ещё активна.
  if [[ -s "$fb" ]] && [[ -s "$fa" ]] && [[ -n "$after_replicas" ]] && \
     [[ "$after_replicas" -gt 1 ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    # Запасной путь: возможно check_result запущен пока нагрузка ещё крутится
    # и артефакты не сохранены - ждём роста реплик по живому кластеру.
    for i in $(seq 1 24); do
      current=$(kubectl get hpa keda-hpa-demo-app -n "$NS" \
        -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
      if [[ -n "$current" ]] && [[ "$current" -gt 1 ]]; then
        echo '1' >> /var/work/tests/result/ok
        result=0
        break
      fi
      sleep 10
    done
  fi
  if [[ "$result" != "0" ]]; then
    echo "before=$before_replicas after=$after_replicas live_current=$current"
  fi
  [ "$result" == "0" ]
}

@test "7. After removing load, demo-app scales back to minReplicaCount" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/7/hpa_after_cooldown.txt
  # Та же ловушка с колонками, что и в тесте 6: REPLICAS - это $(NF-1), а не $6.
  cooldown_replicas=$(awk 'NR==2 {print $(NF-1)}' "$f" 2>/dev/null)
  result=1
  if [[ -s "$f" ]] && [[ "$cooldown_replicas" == "1" ]]; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    # Запасной путь: check_result мог быть запущен раньше, чем закончился
    # scaleDown (по умолчанию окно стабилизации до 5 минут) - ждём по кластеру.
    for i in $(seq 1 30); do
      current=$(kubectl get hpa keda-hpa-demo-app -n "$NS" \
        -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
      if [[ "$current" == "1" ]]; then
        echo '1' >> /var/work/tests/result/ok
        result=0
        break
      fi
      sleep 10
    done
  fi
  if [[ "$result" != "0" ]]; then
    echo "file $f cooldown_replicas=$cooldown_replicas live_current=$current"
  fi
  [ "$result" == "0" ]
}

@test "8. Artifact compares a plain HPA against a KEDA-managed HPA" {
  echo '1' >> /var/work/tests/result/all
  f=/var/work/tests/artifacts/8/hpa_compare.txt
  if [[ -s "$f" ]] && grep -qi 'keda-hpa' "$f" && grep -qi 'HPA' "$f" && \
     grep -qi 'KEDA' "$f" && grep -qiE 'control|manage|управля' "$f"; then
    echo '1' >> /var/work/tests/result/ok
    result=0
  else
    echo "file $f missing/empty or does not explain HPA vs keda-hpa relationship"
    result=1
  fi
  [ "$result" == "0" ]
}
