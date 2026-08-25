[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лаба 115 - эталонное решение (логирование: Fluent Bit, CloudWatch Logs, фильтрация, retention)

Все команды выполняются на рабочей машине (worker) по SSH. kubectl уже настроен на
кластер, `aws` CLI настроен на тот же аккаунт и регион. Имя роли IRSA и имя log group -
в файле `~/lab115_hints.txt`.

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## Задание 1. Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## Задание 2. Симптом: логи исчезают без сборщика

Создаём Deployment, чей контейнер печатает маркер и падает - `restartPolicy: Always`
у Deployment пересоздаёт контейнер внутри того же пода, но имя пода не меняется между
перезапусками контейнера (это отдельный случай от удаления пода):

```bash
kubectl create deployment flaky-before -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo BEFORE_MARKER_LAB115; sleep 5; exit 1'
kubectl wait --for=condition=Available deployment/flaky-before -n eks-115 --timeout=60s \
  2>/dev/null || true
sleep 15

POD=$(kubectl get po -n eks-115 -l app=flaky-before -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n eks-115
kubectl logs "$POD" -n eks-115 --previous
```

Оба вызова показывают `BEFORE_MARKER_LAB115` - под жив, доступны текущий и предыдущий
запуск контейнера. Теперь имитируем то, что происходит при пересоздании пода целиком
(смена ноды, консолидация Karpenter, обновление Deployment) - удаляем сам под:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Deployment создал под под новым именем. Обращаемся к старому имени:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

Получаем `Error from server (NotFound): pods "..." not found` - логи упавшего запуска
исчезли вместе с подом, забрать их неоткуда (раздел 34.1). Фиксируем в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## Задание 3. Fluent Bit DaemonSet с ролью IRSA

Добавляем репозиторий чартов AWS и готовим `values.yaml` с аннотацией роли, защитой
от OOM при backpressure (`Mem_Buf_Limit`, `storage.type filesystem`, раздел 34.7) и
выводом в CloudWatch Logs:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

cat > ~/values.yaml <<EOF
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "${ROLE_ARN}"

service:
  extraService: |
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_PORT    2020
    storage.path /var/fluent-bit/state/flb-storage/

input:
  memBufLimit: 50MB
  multilineParser: "cri"
  extraInputs: |
    storage.type      filesystem

cloudWatchLogs:
  enabled: true
  region: "eu-central-1"
  logGroupName: "${LOG_GROUP}"
  logStreamPrefix: "fluentbit-"
  autoCreateGroup: true
EOF

helm install aws-for-fluent-bit eks/aws-for-fluent-bit \
  --namespace amazon-cloudwatch --create-namespace \
  -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
kubectl get pods -n amazon-cloudwatch -o wide
```

Проверяем, что аннотация роли и защита от OOM легли в ConfigMap:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## Задание 4. Починка доказана: логи находятся после удаления пода

Тот же сценарий, что в задании 2, но теперь Fluent Bit уже стримит логи с ноды.
Контейнер на этот раз не падает - живёт достаточно долго, чтобы строка успела уйти:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # даём Fluent Bit время вычитать файл и отправить запись

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

Снова `NotFound` - но теперь строка не потеряна, она уже в CloudWatch Logs:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

Строка находится, хотя под с этим именем уже удалён - Fluent Bit успел вывезти её с
ноды до того, как под исчез. Фиксируем в артефакт:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "OLD_POD_NAME=$POD2"
  cat /tmp/notfound2.txt
  echo "=== found in CloudWatch Logs ==="
  cat /tmp/found_after.txt
} > /var/work/tests/artifacts/4/after_fixed.txt
cat /var/work/tests/artifacts/4/after_fixed.txt
```

## Задание 5. Фильтрация: режем шум до отправки

Добавляем секцию `FILTER grep` в `values.yaml`, чтобы дропать строки со `/healthz`
ещё на ноде, до ingestion в CloudWatch (раздел 34.6 - резать шум в источнике дешевле,
чем чистить хранилище постфактум):

```bash
cat >> ~/values.yaml <<'EOF'

additionalFilters: |
  [FILTER]
      Name   grep
      Match  kube.*
      Exclude log /healthz
EOF

helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Только после того как новые поды Fluent Bit поднялись, генерируем трафик с шумной и с
нормальной строкой:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

Проверяем обе стороны фильтра:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# пусто - строка дропнута фильтром grep

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# запись есть - обычные строки фильтр не трогает
```

Фиксируем объяснение:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep с Exclude log /healthz дропнул строку "GET /healthz 200" ещё на ноде, до
отправки в CloudWatch Logs - в log group этой записи нет вовсе. Обычная строка
NORMAL_MARKER_LAB115 фильтр не трогает и она доходит до CloudWatch. Резать шум таким
способом дешевле, чем чистить логи в хранилище постфактум: платится ingestion, а
отфильтрованная строка ingestion не создаёт (раздел 34.6).
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## Задание 6. Retention policy на log group

По умолчанию логи в CloudWatch хранятся вечно (`retentionInDays` пусто). Ставим срок:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## Задание 7. Многострочность: стектрейс - одна запись

`input.multilineParser` уже держит `cri` - он склеивает то, что режет сам container
runtime, до целой JSON-строки лога. Добавить туда через запятую встроенный парсер
`python` не получится: `cri` матчит `start_state` любой CRI-строки, поэтому Fluent
Bit применяет только его, и до `python` очередь не доходит (issue fluent/fluent-bit
#5235 - несколько parser-ов в одном `multiline.parser` работают только если их
`start_state` не пересекаются). Правильный путь - отдельный FILTER `multiline` со
встроенным типом `python` (раздел 34.7), который должен идти в конвейере раньше
FILTER `kubernetes` (склеенные записи заново эмитятся в голову пайплайна, и если
`kubernetes` уже отработал по ним раньше multiline-фильтра, он применится второй
раз к результату):

```bash
cat >> ~/values.yaml <<'EOF'

filter:
  enabled: false

additionalFilters: |
  [FILTER]
      Name                  multiline
      Match                 kube.*
      multiline.key_content log
      multiline.parser      python

  [FILTER]
      Name                kubernetes
      Match               kube.*
      Kube_URL            https://kubernetes.default.svc.cluster.local:443
      Merge_Log           On
      Merge_Log_Key       data
      Keep_Log            On
      K8S-Logging.Parser  On
      K8S-Logging.Exclude On
      Buffer_Size         32k

  [FILTER]
      Name   grep
      Match  kube.*
      Exclude log /healthz
EOF
```

Секция `filter.enabled: false` отключает встроенный в чарт FILTER `kubernetes`
(он и так уходит в `additionalFilters` вместе с FILTER `multiline` и старым FILTER
`grep` из задания 5 - без `filter.enabled: false` в конфиге было бы два FILTER
`kubernetes` подряд, второй лишний). Применяем:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Только после перезапуска Fluent Bit печатаем четыре строки подряд, имитирующие Python
Traceback:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

Проверяем, что все четыре строки пришли одной записью CloudWatch, а не четырьмя:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

В выводе одно сообщение содержит и `Traceback`, и `CRASH_TRACE_LAB115` - парсер `python`
склеил четыре строки лога в одну запись. Без него в CloudWatch легли бы четыре отдельных
события, и Logs Insights считал бы это четырьмя разными "падениями". Фиксируем:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "FILTER multiline со встроенным типом python склеил 4 строки Traceback в"
  echo "одну запись CloudWatch, а не разбил их на 4 отдельных события."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## Быстрая проверка

```bash
check_result
```
