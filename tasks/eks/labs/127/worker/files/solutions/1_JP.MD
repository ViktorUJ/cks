[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ127 - 参考解答(CELによるValidatingAdmissionPolicy)

すべてのコマンドはワーカーマシン上でSSH経由で実行します。kubectlはすでにクラスタに
対して設定されています(kubeconfigはマシンの起動時に`aws eks update-kubeconfig`経由
で組み立てられます)。

## タスク1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## タスク2. AuditモードのCELポリシーは`:latest`のpodを通過させる

`validationActions: ["Audit"]`の`ValidatingAdmissionPolicy`と
`ValidatingAdmissionPolicyBinding`を作成します。ポリシーは`namespaceSelector`
(ラベル`kubernetes.io/metadata.name`、k8sがnamespaceに自動的に設定するもの)経由で
namespace `eks-127`にのみ適用されます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: ":latestタグは forbidden です、具体的なイメージバージョンを指定してください"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Audit"]
EOF
```

両方のオブジェクトが揃っていることを確認します:

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

次に`Audit`モードで`:latest`イメージのpodを作成します - これは作成されるはずです。
`Audit`は違反をaudit logに書き込むだけで、リクエストをブロックしないからです:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: latest-audit-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get pod latest-audit-pod -n eks-127
```

ルールに違反しているにもかかわらずpodは作成されます - これこそが`Audit`の意味です:
既存のワークロードを壊すリスクを取らずにポリシーを試すことができます。

## タスク3. Denyに切り替える - `:latest`のpodは拒否される

Bindingを更新し、`validationActions`だけを変更します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Deny"]
EOF
```

もう一つ`:latest`のpodを作成しようとします - 今度はapiserverがリクエストを拒否する
はずです:

```bash
mkdir -p /var/work/tests/artifacts/3
cat <<'EOF' | kubectl apply -f - 2> /var/work/tests/artifacts/3/denied.txt
apiVersion: v1
kind: Pod
metadata:
  name: latest-deny-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

cat /var/work/tests/artifacts/3/denied.txt
```

`denied.txt`ファイルには、ポリシーのテキスト(`latest`と`forbidden`という単語)を含む
apiserverのエラーメッセージが含まれているはずです。その際Pod `latest-deny-pod`は作成
されません - `kubectl get pod latest-deny-pod -n eks-127`は`NotFound`を返します。

## タスク4. 明示的なタグを持つ正当なpodはDenyでも通過する

このポリシーは`:latest`だけをチェックするため、具体的なイメージバージョンを持つpodは
問題なく通過します。タグ`53833ea`は`viktoruj/ping_pong`内の実在するコミットタグで、
amd64とarm64向けにビルドされています。実在するタグを使うことが重要です: 許可は
イメージの文字列だけを見るため、架空のタグを持つpodも作成されてしまい、
`ErrImagePull`のままになります - ポリシーは形式的には「妨げなかった」ことになります
が、その主張を確認する手立てが何も残らなくなってしまいます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tagged-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF

kubectl get pod tagged-pod -n eks-127
```

## タスク5. 2つ目のCELポリシー: 必須の`resources.requests`

もう一つ、最初から`Deny`モードの`ValidatingAdmissionPolicy`です - すべてのコンテナに
`resources.requests`が設定されていることを要求します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources-requests
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.requests))"
      message: "すべてのコンテナにresources.requestsが設定されている必要があります"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-requests-binding
spec:
  policyName: require-resources-requests
  validationActions: ["Deny"]
EOF
```

`requests`のないpodは拒否されます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-requests-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF
```

このコマンドはadmissionエラーを返し、`kubectl get pod no-requests-pod -n eks-127`は
`NotFound`を表示します。`requests`が設定されたpodは正常に通過します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-ok-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl get pod requests-ok-pod -n eks-127
```

## タスク6. `failurePolicy: Fail`と外部webhookとの違い

最初のポリシーに明示的に`failurePolicy: Fail`を設定します(これはデフォルト値です
が、明示的に固定します):

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy`はCEL式の評価エラー(たとえば、古いAPIバージョンのオブジェクトに存在し
ないフィールドへのアクセス)に反応するものであり、外部サービスの到達不能に反応するも
のではありません。組み込みの`ValidatingAdmissionPolicy`には外部webhookが一切なく、
CELはapiserverの内部で直接評価されるため、KyvernoやGatekeeperに特有の「webhookが応答
せず、admissionが止まった」というリスクがありません(そちらでは、ルールはwebhookの
背後にある別のサービスが実行し、それが到達不能になると、`failurePolicy: Fail`はリク
エストをキューに入れるかブロックします)。

説明をアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
ValidatingAdmissionPolicyのfailurePolicyは、CEL式の評価エラー(例えば、オブジェクトに
存在しないフィールドへのアクセス)にのみ反応し、外部サービスの到達不能には反応しな
い。

組み込みのValidatingAdmissionPolicyには外部webhookが一切ない: CEL式はapiserverの内部
で直接評価され、外部へのネットワーク呼び出しは一切ない。そのため、KyvernoやGatekeeper
に特有の「webhookが応答しなかった」というリスクはここには存在しな
い。KyvernoやGatekeeperでは、ルールはwebhookの背後にある別のサービスが実行し、
apiserverはその応答を待つ。
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## クイックチェック

```bash
check_result
```

ポリシーの状態を確認するのに役立つコマンド:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
