[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 115 - 參考解決方案(日誌:Fluent Bit、CloudWatch Logs、過濾、保留)

所有命令都在工作機上透過 SSH 執行。kubectl 已經配置好供這個集群使用,`aws` CLI 也配
置為使用同一個帳戶和區域。IRSA 角色名稱和日誌組名稱都在檔案 `~/lab115_hints.txt` 中。

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## 任務 1。Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## 任務 2。症狀:沒有收集器時日誌會消失

創建一個 Deployment,其容器印出一個標記後崩潰 - Deployment 的 `restartPolicy: Always`
會在同一個 pod 內重新創建容器,但 pod 名稱在容器重啟過程中不會改變(這與 pod 被刪除是
不同的情況):

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

兩個命令都會顯示 `BEFORE_MARKER_LAB115` - 這個 pod 還活著,無論是目前的還是之前的容器
運行記錄都能取得。現在我們模擬整個 pod 被重新創建時會發生什麼(節點替換、Karpenter
consolidation、Deployment 更新)- 我們直接刪除這個 pod:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Deployment 用新的名稱創建了一個 pod。讓我們查詢舊名稱:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

我們得到的是 `Error from server (NotFound): pods "..." not found` - 崩潰運行的日誌隨
著 pod 一起消失了,已經無處可以取回(第 34.1 節)。把這一切記錄到產物中:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## 任務 3。帶有 IRSA 角色的 Fluent Bit DaemonSet

添加 AWS chart 倉庫,並準備帶有角色 annotation、反壓下 OOM 防護
(`Mem_Buf_Limit`、`storage.type filesystem`,第 34.7 節)以及輸出到 CloudWatch Logs
的 `values.yaml`:

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

確認角色 annotation 和 OOM 防護都已經進入 ConfigMap:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## 任務 4。修復得到驗證:pod 刪除後仍能找到日誌

與任務 2 是同樣的場景,但現在 Fluent Bit 已經在從節點串流日誌了。這一次容器不會崩
潰 - 它存活的時間足夠讓這一行被發送出去:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # 給 Fluent Bit 時間讀取檔案並發送這筆記錄

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

同樣是 `NotFound` - 但這一次這一行沒有丟失,它已經在 CloudWatch Logs 中了:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

即使名稱對應的 pod 已經被刪除,這一行仍能被找到 - Fluent Bit 在 pod 消失之前就已經把
它從節點發送出去了。把這一切記錄到產物中:

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

## 任務 5。過濾:在發送之前削減噪音

在 `values.yaml` 中添加一個 `FILTER grep` 區段,在寫入 CloudWatch 之前就在節點上丟棄
帶有 `/healthz` 的行(第 34.6 節 - 在源頭削減噪音比事後清理存儲更划算):

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

只有在新的 Fluent Bit pod 都啟動之後,我們才生成帶有一行噪音和一行正常內容的流量:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

檢查過濾器的兩側:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# 空的 - 這一行被 grep 過濾器丟棄了

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# 記錄還在 - 過濾器不會影響正常的行
```

記錄下說明:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep 搭配 Exclude log /healthz 在節點上就把 "GET /healthz 200" 這一行丟棄了,
在送往 CloudWatch Logs 之前 - 因此日誌組裡根本沒有這筆記錄。正常的行 NORMAL_MARKER_LAB115
不會被過濾器影響,會抵達 CloudWatch。用這種方式削減雜訊,比事後在儲存中清理日誌更便宜:
你要為 ingestion 付費,而被過濾掉的行不會產生 ingestion(第 34.6 節)。
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## 任務 6。日誌組上的保留策略

預設情況下,CloudWatch 中的日誌會永久保留(`retentionInDays` 為空)。設定一個期限:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## 任務 7。多行:一筆 stack trace 記錄

`input.multilineParser` 中已經有 `cri` - 它會把容器 runtime 本身拆散的內容合併成一整
行 JSON 日誌。試圖用逗號把內建的 `python` parser 加進去是行不通的:`cri` 會匹配任何一
行 CRI 的 `start_state`,所以 Fluent Bit 只會套用這一個,永遠輪不到 `python`
(issue fluent/fluent-bit #5235 - 同一個 `multiline.parser` 中的多個 parser,只有在它
們的 `start_state` 不重疊時才能一起生效)。正確的做法是使用一個帶有內建 `python` 類型
的獨立 `multiline` FILTER(第 34.7 節),它必須在管線中運行在 `kubernetes` FILTER 之
前(合併後的記錄會在管線起始處重新發送,如果 `kubernetes` 在 multiline 過濾器之前就
已經處理過它們,結果會被再處理一次):

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

`filter.enabled: false` 這個區段停用了 chart 內建的 `kubernetes` FILTER(它已經隨著
`multiline` FILTER 以及任務 5 中舊有的 `grep` FILTER 一起進入了 `additionalFilters` -
如果沒有 `filter.enabled: false`,配置中會連續出現兩個 `kubernetes` FILTER,第二個是
多餘的)。套用它:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

只有在 Fluent Bit 重啟之後,我們才連續印出四行,模擬一個 Python Traceback:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

檢查這四行是否作為一筆 CloudWatch 記錄到達,而不是四筆:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

輸出中,有一筆訊息同時包含 `Traceback` 和 `CRASH_TRACE_LAB115` - `python` parser 把這
四行日誌合併成了一筆記錄。如果沒有它,CloudWatch 會收到四筆獨立的事件,Logs Insights
會把它們算成四次不同的「崩潰」。記錄下這一點:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "帶有內建 python 類型的 FILTER multiline 把四行 Traceback 合併成了"
  echo "一筆 CloudWatch 記錄,而不是把它們拆成四筆獨立的事件。"
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## 快速檢查

```bash
check_result
```
