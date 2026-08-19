[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 115 - 参考解答(ロギング:Fluent Bit、CloudWatch Logs、フィルタリング、リテンション)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl はすでにクラスタ用に
設定されており、`aws` CLI も同じアカウントとリージョン用に設定されています。IRSA ロー
ル名とロググループ名はファイル `~/lab115_hints.txt` にあります。

```bash
source ~/lab115_hints.txt 2>/dev/null || true
ROLE_ARN=$(grep '^role_arn' ~/lab115_hints.txt | awk '{print $3}')
LOG_GROUP=$(grep '^log_group_name' ~/lab115_hints.txt | awk '{print $3}')
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
echo "$ROLE_ARN"
echo "$LOG_GROUP"
```

## タスク 1。Namespace `eks-115`

```bash
kubectl create namespace eks-115
```

## タスク 2。症状:収集エージェントがないとログが消える

マーカーを出力してからクラッシュするコンテナを持つ Deployment を作成します - Deployment
の `restartPolicy: Always` は同じ Pod 内でコンテナを再作成しますが、コンテナの再起動を
またいで Pod 名は変わりません(これは Pod 削除とは別のケースです):

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

両方の呼び出しで `BEFORE_MARKER_LAB115` が表示されます - Pod は生きており、現在と直前の
コンテナ実行の両方が利用可能です。ここで、Pod 全体が再作成される場合(ノード交換、
Karpenter の consolidation、Deployment の更新)に何が起きるかを模擬します - Pod 自体を
削除します:

```bash
kubectl delete pod "$POD" -n eks-115
sleep 10
kubectl get po -n eks-115 -l app=flaky-before
```

Deployment は新しい名前で Pod を作成しました。古い名前を照会してみます:

```bash
kubectl logs "$POD" -n eks-115 2>&1 | tee /tmp/notfound.txt
```

`Error from server (NotFound): pods "..." not found` が返ります - クラッシュした実行
のログは Pod と一緒に消え、もはやどこからも取得できません(34.1 節)。これをアーティ
ファクトに記録します:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "OLD_POD_NAME=$POD"
  echo "BEFORE_MARKER_LAB115"
  cat /tmp/notfound.txt
} > /var/work/tests/artifacts/2/before_symptom.txt
cat /var/work/tests/artifacts/2/before_symptom.txt
```

## タスク 3。IRSA ロールを持つ Fluent Bit DaemonSet

AWS のチャートリポジトリを追加し、ロールのアノテーション、バックプレッシャー時の OOM
保護(`Mem_Buf_Limit`、`storage.type filesystem`、34.7 節)、CloudWatch Logs への出力
を持つ `values.yaml` を用意します:

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

ロールのアノテーションと OOM 保護が ConfigMap に反映されていることを確認します:

```bash
kubectl get sa aws-for-fluent-bit -n amazon-cloudwatch -o yaml | grep role-arn
kubectl get cm aws-for-fluent-bit -n amazon-cloudwatch -o jsonpath='{.data.fluent-bit\.conf}' \
  | grep -E 'Mem_Buf_Limit|storage.type'
```

## タスク 4。修正の確認:Pod 削除後もログが見つかる

タスク 2 と同じシナリオですが、今度は Fluent Bit がすでにノードからログをストリーミング
しています。今回はコンテナはクラッシュせず、行が送信されるまで十分に長く生き続けます:

```bash
kubectl create deployment flaky-after -n eks-115 \
  --image=busybox:1.36 -- sh -c 'echo AFTER_MARKER_LAB115; sleep 3600'
kubectl rollout status deployment/flaky-after -n eks-115

sleep 60   # Fluent Bit がファイルを読み取ってレコードを送信する時間を与える

POD2=$(kubectl get po -n eks-115 -l app=flaky-after -o jsonpath='{.items[0].metadata.name}')
echo "$POD2"

kubectl delete pod "$POD2" -n eks-115
sleep 10
kubectl logs "$POD2" -n eks-115 2>&1 | tee /tmp/notfound2.txt
```

再び `NotFound` になります - しかし今回はその行は失われておらず、すでに CloudWatch
Logs にあります:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "AFTER_MARKER_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/found_after.txt
```

この名前の Pod がすでに削除されているにもかかわらず、その行は見つかります - Fluent Bit
は Pod が消える前に、すでにそれをノードから送信していたのです。これをアーティファクト
に記録します:

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

## タスク 5。フィルタリング:送信前にノイズを削減する

`values.yaml` に `FILTER grep` セクションを追加し、`/healthz` を含む行をノード上で、
CloudWatch への取り込み前に破棄します(34.6 節 - 元でノイズを削減する方が、後からスト
レージを整理するより安いです):

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

新しい Fluent Bit の Pod が起動した後にのみ、ノイズの多い行と正常な行を持つトラフィック
を生成します:

```bash
kubectl run access-log-gen -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'echo "GET /healthz 200"; sleep 3; echo NORMAL_MARKER_LAB115; sleep 3600'

sleep 60
```

フィルタの両側を確認します:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "healthz" --query 'events' --output text
# empty - 行は grep フィルタによって破棄された

aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "NORMAL_MARKER_LAB115" --query 'events[*].message' --output text
# レコードが存在する - フィルタは正常な行に触れない
```

説明を記録します:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/filter_check.txt <<'EOF'
FILTER grep の Exclude log /healthz は、"GET /healthz 200" という行をノード上で、
CloudWatch Logs への送信前に破棄しました - ロググループにはこのレコードが一切ありません。
通常の行 NORMAL_MARKER_LAB115 はフィルタに触れられず、CloudWatch に到達します。このように
ノイズを削るほうが、後からストレージ内のログを掃除するより安価です: ingestion に対して課金
され、フィルタで除外された行は ingestion を発生させません (セクション 34.6)。
EOF
cat /var/work/tests/artifacts/5/filter_check.txt
```

## タスク 6。ロググループのリテンションポリシー

デフォルトでは、CloudWatch のログは永久に保持されます(`retentionInDays` は空)。期間
を設定します:

```bash
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7

mkdir -p /var/work/tests/artifacts/6
aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[].[logGroupName,retentionInDays]" --output table \
  | tee /var/work/tests/artifacts/6/retention.txt
```

## タスク 7。Multiline:1 件のレコードとしてのスタックトレース

`input.multilineParser` にはすでに `cri` が設定されています - これはコンテナランタイム
自体が分割したものを、まとまった 1 つの JSON ログ行に結合します。そこに組み込みの
`python` パーサーをカンマで追加してもうまくいきません:`cri` は任意の CRI 行の
`start_state` にマッチしてしまうため、Fluent Bit はそれだけを適用し、`python` には到達
しません(issue fluent/fluent-bit #5235 - 単一の `multiline.parser` 内の複数のパーサー
は、それぞれの `start_state` の値が重複しない場合にのみ機能します)。正しいアプローチ
は、組み込みの `python` タイプを持つ別の `multiline` FILTER です(34.7 節)。これは
`kubernetes` FILTER より前にパイプライン内で実行される必要があります(結合されたレコー
ドはパイプラインの先頭から再発行されるため、multiline フィルタより前に `kubernetes` が
すでにそれらを処理していると、その結果に対して二重に適用されてしまいます):

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

`filter.enabled: false` セクションは、チャートに組み込まれている `kubernetes` FILTER を
無効にします(それはすでに `multiline` FILTER と、タスク 5 の古い `grep` FILTER ととも
に `additionalFilters` に含まれています - `filter.enabled: false` がなければ、設定に
`kubernetes` FILTER が 2 回連続で入ってしまい、2 番目は冗長になります)。これを適用しま
す:

```bash
helm upgrade aws-for-fluent-bit eks/aws-for-fluent-bit \
  -n amazon-cloudwatch -f ~/values.yaml

kubectl rollout status daemonset/aws-for-fluent-bit -n amazon-cloudwatch --timeout=120s
```

Fluent Bit が再起動した後にのみ、Python の Traceback を模擬して 4 行を連続で出力しま
す:

```bash
kubectl run stacktrace-app -n eks-115 --image=busybox:1.36 --restart=Never \
  -- sh -c 'printf "Traceback (most recent call last):\n  File \"app.py\", line 10, in <module>\n    raise ValueError(\"CRASH_TRACE_LAB115\")\nValueError: CRASH_TRACE_LAB115\n"; sleep 3600'

sleep 60
```

4 行すべてが 4 件ではなく 1 件の CloudWatch レコードとして届いたことを確認します:

```bash
aws logs filter-log-events --log-group-name "$LOG_GROUP" \
  --filter-pattern "CRASH_TRACE_LAB115" \
  --query 'events[*].message' --output text | tee /tmp/multiline_msg.txt
```

出力では、1 つのメッセージが `Traceback` と `CRASH_TRACE_LAB115` の両方を含んでいます -
`python` パーサーが 4 つのログ行を 1 つのレコードに結合したのです。これがなければ、
CloudWatch は 4 件の別々のイベントを受け取り、Logs Insights はそれを 4 つの異なる「クラ
ッシュ」として数えてしまいます。これを記録します:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== merged CloudWatch event ==="
  cat /tmp/multiline_msg.txt
  echo ""
  echo "FILTER multiline with the built-in python type merged 4 Traceback lines into"
  echo "one CloudWatch record instead of splitting them into 4 separate events."
} > /var/work/tests/artifacts/7/multiline.txt
cat /var/work/tests/artifacts/7/multiline.txt
```

## クイックチェック

```bash
check_result
```
