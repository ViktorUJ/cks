[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 115 - ეტალონური გადაწყვეტა (ლოგირება: Fluent Bit, CloudWatch Logs, ფილტრაცია, retention)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე, `aws` CLI კონფიგურირებულია იმავე ანგარიშისთვის და
რეგიონისთვის. IRSA-როლის სახელი და log group-ის სახელი ფაილშია `~/lab115_hints.txt`.

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## დავალება 1. Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## დავალება 2. სიმპტომი: ლოგები ქრება collector-ის გარეშე

შექმენით Deployment, რომლის კონტეინერი ბეჭდავს მარკერს და crash-ს იძლევა - Deployment-ის
`restartPolicy: Always` ხელახლა ქმნის კონტეინერს იმავე პოდში, მაგრამ პოდის სახელი
უცვლელი რჩება კონტეინერის რესტარტების განმავლობაში (ეს ცალკე შემთხვევაა პოდის
წაშლისგან):

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

ორივე გამოძახება აჩვენებს `BEFORE_MARKER_LAB115`-ს - პოდი ცოცხალია, ხელმისაწვდომია
როგორც მიმდინარე, ისევე წინა კონტეინერის გაშვება. ახლა ვსიმულირებთ, რა ხდება, როცა
მთელი პოდი ხელახლა შექმნილია (ნოუდის ჩანაცვლება, Karpenter-ის consolidation, Deployment-ის
განახლება) - წავშლით პოდს თავად:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Deployment-მა შექმნა პოდი ახალი სახელით. მოვთხოვოთ ძველი სახელი:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

მივიღებთ `Error from server (NotFound): pods "..." not found` - crash-ის ჩავარდნილი
გაშვების ლოგები გაქრა პოდთან ერთად, არსად არ დარჩა, საიდანაც ისინი ამოვიღოთ (სექცია
34.1). ჩავწეროთ ეს არტეფაქტში:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## დავალება 3. Fluent Bit DaemonSet IRSA-როლით

დაამატეთ AWS chart-რეპოზიტორი და მოამზადეთ `values.yaml` როლის annotation-ით, OOM-დაცვით
backpressure-ის ქვეშ (`Mem_Buf_Limit`, `storage.type filesystem`, სექცია 34.7) და
output-ით CloudWatch Logs-ში:

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

დავადასტუროთ, რომ როლის annotation და OOM-დაცვა მოხვდა ConfigMap-ში:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## დავალება 4. ფიქსი დამტკიცებულია: ლოგები მოიძებნება პოდის წაშლის შემდეგ

იგივე სცენარი, რაც დავალება 2-ში, მაგრამ ახლა Fluent Bit უკვე ატარებს ლოგებს ნოუდიდან.
ამჯერად კონტეინერი crash-ს არ იძლევა - ის ცოცხლობს იმდენ ხანს, რომ ხაზი გადაგზავნილი
იქნეს:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # ვუტარებთ Fluent Bit-ს დროს ფაილის წასაკითხავად და ჩანაწერის გადასაგზავნელად

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

ისევ `NotFound` - მაგრამ ამჯერად ხაზი არ დაკარგულა, ის უკვე CloudWatch Logs-შია:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

ხაზი მოიძებნა, მიუხედავად იმისა, რომ ამ სახელის პოდი უკვე წაშლილია - Fluent Bit-მა ის
ნოუდიდან გადაგზავნა ჯერ კიდევ პოდის გაქრობის წინ. ჩავწეროთ ეს არტეფაქტში:

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

## დავალება 5. ფილტრაცია: ხმაურის ჩამოკვეთა ჩატანის წინ

დაამატეთ `FILTER grep` სექცია `values.yaml`-ში, რომ ჩამოაშოროთ ხაზები `/healthz`-ით
ზუსტად ნოუდზე, CloudWatch-ში ჩატანის წინ (სექცია 34.6 - ხმაურის ჩამოკვეთა წყაროზე
უფრო ეკონომიურია, ვიდრე საცავის გასუფთავება ფაქტის შემდეგ):

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

მხოლოდ იმის შემდეგ, რაც Fluent Bit-ის ახალი პოდები ავმართებია, ვქმნით ტრაფიკს ხმაურიანი
ხაზითა და ჩვეულებრივით:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

შემოწმდეს ფილტრის ორივე მხარე:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# ცარიელია - ხაზი ჩამოაშორა grep ფილტრმა

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# ჩანაწერი არსებობს - ფილტრი არ ეხება ჩვეულებრივ ხაზებს
```

ჩავწეროთ განმარტება:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep with Exclude log /healthz ჩამოაშორა ხაზი "GET /healthz 200" ზუსტად ნოუდზე,
CloudWatch Logs-ში გადაგზავნის წინ - log group-ში ეს ჩანაწერი საერთოდ არ არსებობს.
ჩვეულებრივი ხაზი NORMAL_MARKER_LAB115 ფილტრს არ ეხება და აღწევს CloudWatch-ში. ხმაურის
ასეთი ჩამოკვეთა უფრო ეკონომიურია, ვიდრე ლოგების გასუფთავება საცავში ფაქტის შემდეგ:
ingestion-ზე ვიხდით ფულს, და გაფილტრული ხაზი ingestion-ს არასდროს ქმნის (სექცია 34.6).
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## დავალება 6. Retention-პოლიტიკა log group-ზე

ნაგულისხმევად, ლოგები CloudWatch-ში ინახება სამუდამოდ (`retentionInDays` ცარიელია).
დავაყალიბოთ პერიოდი:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## დავალება 7. Multiline: stack trace ერთ ჩანაწერად

`input.multilineParser` უკვე ატარებს `cri`-ს - ის აერთიანებს იმას, რასაც კონტეინერის
runtime თავად ყოფს, ერთ სრულ JSON log-ხაზში. `python`-ის, ჩაშენებული parser-ის, იმავე
ველში მძიმის მეშვეობით დამატება არ იმუშავებს: `cri` ემთხვევა ნებისმიერ CRI-ხაზის
`start_state`-ს, ამიტომ Fluent Bit მხოლოდ მას იყენებს, და საქმე `python`-მდე
საერთოდ არ მიდის (issue fluent/fluent-bit #5235 - რამდენიმე parser ერთ
`multiline.parser`-ში მუშაობს მხოლოდ, თუ მათი `start_state` მნიშვნელობები არ
ემთხვევა ერთმანეთს). სწორი გზა არის ცალკე `multiline` FILTER ჩაშენებული `python`
ტიპით (სექცია 34.7), რომელიც უნდა გაეშვას pipeline-ში `kubernetes` FILTER-ის წინ
(გაერთიანებული ჩანაწერები ხელახლა ემიტირდება pipeline-ის თავში, და თუ `kubernetes`
მათ multiline ფილტრის წინ დაამუშავებდა, ის ხელახლა გამოეყენებოდა შედეგზე):

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

სექცია `filter.enabled: false` თეშავს chart-ის ჩაშენებულ `kubernetes` FILTER-ს (ის
უკვე `additionalFilters`-შია, `multiline` FILTER-თან და დავალება 5-ის ძველ `grep`
FILTER-თან ერთად - `filter.enabled: false`-ის გარეშე კონფიგში იქნებოდა ორი
`kubernetes` FILTER-ი ზედიზედ, მეორე ზედმეტი). გამოვიყენოთ ის:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

მხოლოდ იმის შემდეგ, რაც Fluent Bit გადაირესტარტდება, ვბეჭდავთ ოთხ ხაზს ზედიზედ,
სიმულირებულ Python Traceback-ს:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

შემოწმდეს, რომ ყველა ოთხივე ხაზი მოვიდა ერთ CloudWatch-ჩანაწერად, არა ოთხად:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

output-ში ერთი message შეიცავს ორივეს, `Traceback`-საც და `CRASH_TRACE_LAB115`-საც -
`python` parser-მა გააერთიანა ოთხი log-ხაზი ერთ ჩანაწერად. მის გარეშე, CloudWatch
მიიღებდა ოთხ ცალკეულ event-ს, და Logs Insights ამას ჩათვლიდა ოთხ სხვადასხვა
"crash"-ად. ჩავწეროთ ეს:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "FILTER multiline ჩაშენებული python ტიპით გააერთიანა Traceback-ის 4 ხაზი"
  echo "ერთ CloudWatch-ჩანაწერად, 4 ცალკეულ event-ად გაყოფის ნაცვლად."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## სწრაფი შემოწმება

```bash
check_result
```
