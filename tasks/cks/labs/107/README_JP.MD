[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 107 - Pod Security Admission: restricted、audit/warn、read-only root filesystem

## 目的

この CKS 実習では、namespace の labels を通じて、組み込みの **Pod Security Admission (PSA)** を設定します。
production の namespace では、`restricted` を `enforce` モードで有効にし、
安全でない Pod が拒否されることを確認して、通過する hardened な Pod をデプロイします。
別の namespace では、`baseline` レベルの観察モード `audit` と `warn` を有効にします。
最後に、コンテナの root filesystem を read-only にし、唯一必要な書き込みを
`emptyDir` に許可します。

課題にあるオブジェクトだけを扱ってください。クラスターには、空の namespace
`psa-restricted-107`、`psa-observe-107`、`psa-controller-107` があらかじめ作成されています；PSA-labels と workload はそこにはありません。

## 開始前のセルフチェック

<details>
<summary>1. Pod Security Admission の `enforce` は `audit`/`warn` と何が違うか？</summary>

`enforce` は、選択された PSS レベルに違反する Pod の作成を実際にブロックします - admission request はエラーで終了します。`audit`/`warn` はリクエストをブロック「しません」：Pod はそれでも作成されますが、`audit` は kube-apiserver の audit log に annotation を追加し、`warn` は `kubectl apply` のときにユーザーにテキストの警告を表示します。これらは責任のレベルが異なります：`audit`/`warn` は実際のブロックを有効にする前の観察用で、`enforce` が本来の防御です。
</details>

<details>
<summary>2. namespace に、PSS レベルとともに `*-version` label を固定する必要があるのはなぜか？</summary>

固定されたバージョン (`enforce-version`) がないと、PSA は確認のたびに Kubernetes の現在のバージョンを使用します - クラスターがアップデートされると、`restricted`/`baseline` のルールセットは気づかないうちに変わる可能性があり、昨日通った Pod が、あなたが何もしないまま今日拒否され始めることがあります。バージョンを固定すると、将来のクラスターのアップデートに関係なく、挙動が予測可能で再現可能になります。
</details>

<details>
<summary>3. 課題 6 の `ValidatingAdmissionPolicy` が PSA を重複させるのではなく補完するのはなぜか？</summary>

PSS の `restricted` は、security フィールド (non-root、capabilities、seccomp、escalation) の固定された標準化された集合を定義します。`automountServiceAccountToken` はこの集合に含まれず - PSA はこれをまったく確認しません。つまり、Pod は `restricted` に完全に適合していながら、不要なマウントされた API-token を黙って受け取る可能性があります。Custom の `ValidatingAdmissionPolicy` は、PSA がすでに行っていることを置き換えたり重複させたりすることなく、まさにこの隙間を埋めます。
</details>

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます：

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | マシンへアクセスするための SSH キー |
| `k8s-1` | シングルノードの kubeadm クラスター Kubernetes `1.36.0`、containerd、**Calico** |
| `worker` | `kubectl`、コンテキスト `cluster1-admin@cluster1`、`check_result` を備えた作業マシン |

Control-plane は通常の Pod を受け付けるため、別の Kubernetes の worker ノードは
不要です。すべての課題は作業マシンで行います。

## デプロイ

```bash
TASK=107 make run_cks_task
```

作業マシンに SSH で接続し、クラスターへのアクセスを確認します：

```bash
time_left
kubectl get nodes
check_result
```

## 課題

---
| **1** | **固定されたバージョンでの Enforce restricted** |
| :---: | :--- |
| やること | namespace `psa-restricted-107` に、`pod-security.kubernetes.io/enforce=restricted` と `pod-security.kubernetes.io/enforce-version=v1.36` を設定します。PSA が安全でない Pod を実際に拒否することを確認します：この namespace で `hostNetwork: true` を持つ Pod の server-side dry-run は、`violates PodSecurity` を含むエラーで終了する必要があります。システムの namespace の labels を変更しないでください。 |
| 受け入れ基準 | 両方の enforce-label が正確な値を持つ；安全でない Pod が `psa-restricted-107` の admission を通らない；システムの namespace `kube-system`、`kube-public`、`kube-node-lease` が、この実習の範囲で `pod-security.kubernetes.io/*` labels を受け取らない。 |

<details>
<summary>💡 課題 1 のヒント</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - 両方の label は即座に適用され、PSA は何かの再起動を必要としません。`hostNetwork: true` での `kubectl apply --dry-run=server` で自己確認してください - `client` ではなく、まさに `--dry-run=server` です。PSA を含む admission controllers は server-side でのみ動作するためです。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

まず baseline - labels を設定する前に、同じ安全でない manifest が通ることを確認します
(そうでないと、denial が自分の enforce label によるものか、他の何かによるものか分かりません)：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

両方の label を設定してから、同じ manifest をもう一度実行します - 今度は
`violates PodSecurity` というテキストを含む admission エラーになるはずです：

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **restricted を通過する Hardened Pod** |
| :---: | :--- |
| やること | `psa-restricted-107` に、`busybox:1.36` の Pod `restricted-app` を作成します。root で動作せず、すぐには終了しないものにしてください。pod-level の `runAsNonRoot: true`、`runAsUser: 1000`、`seccompProfile: RuntimeDefault` を設定します。container の securityContext で、privilege escalation を禁止し、capability `ALL` を drop し、`privileged: false` を明示的に残し、`seccompProfile: RuntimeDefault` を設定します。 |
| 受け入れ基準 | Pod が PSA に受け入れられて起動している；UID 1000/non-root として動作し、container/init/ephemeral container のいずれも pod-level の `runAsUser: 1000` を上書きしていない；seccomp が `RuntimeDefault` である；escalation と privileged が禁止されている；capabilities `ALL` が drop されている。 |

<details>
<summary>💡 課題 2 のヒント</summary>

Pod が admission rejection を受けた場合は、エラーメッセージを注意深く読んでください。通常、不足している正確なフィールド (たとえば "container has no capabilities.drop") が名指しされています。Kubernetes 1.36 の PSS `restricted` のセマンティクスについての重要な詳細：それが要求するのは、実効的な (文字どおり重複している必要はない) 許容される `seccompProfile` です - pod-level のプロファイル (`spec.securityContext.seccompProfile.type`) は、自分のフィールドが設定されていないコンテナに継承されることがあり、逆に、container-level のフィールドは、pod-level のプロファイルがなくても、すべてのコンテナで明示されていれば十分です。つまり、PSS 自体は文字どおり両方のレベルを同時に要求しません。**この実習では、意図的に Pod とコンテナの両方で `RuntimeDefault` を明示的に設定するよう求めています** - PSS がそれを要求するからではなく、両方のレベルの設定を練習するためです。同様に、`runAsUser: 1000` は、まさにこの実習の explicit な hardening の決定です：PSS `restricted` は UID `0` を禁止しますが、具体的に `1000` を要求しません (ゼロ以外の任意の値、またはフィールドの完全な不在は、PSS 自体にとっては許容されます)。
</details>

---
| **3** | **baseline の観察モード** |
| :---: | :--- |
| やること | namespace `psa-observe-107` で、PSA の両方のモードを有効にします：`pod-security.kubernetes.io/audit=baseline`、`pod-security.kubernetes.io/audit-version=v1.36`、`pod-security.kubernetes.io/warn=baseline`、`pod-security.kubernetes.io/warn-version=v1.36`。`enforce` は追加しないでください：これは、ブロックの前に段階的に観察するための namespace です。 |
| 受け入れ基準 | レベル `baseline` とバージョン `v1.36` の 4 つの audit/warn labels が存在する；enforce-label が存在しない。 |

<details>
<summary>💡 課題 3 のヒント</summary>

4 つの個別の label があり - そのうちの 1 つ (特に、いずれかのモードの `-version`) を忘れやすいです。4 つすべてを一度に確認します：`kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

Baseline - labels を設定する前は、違反する manifest は PSA の警告なしで通るはずです
(namespace はまだ観察されていません)：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

4 つの label をすべて設定してから、同じ manifest をもう一度実行します - 今度は `kubectl apply` が
`Warning: ... would violate PodSecurity "baseline:v1.36"` を出力するはずですが、コマンドは
それでもエラーではなく成功 (exit 0) で終了するはずです：

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit は legacy workload をブロックしない** |
| :---: | :--- |
| やること | `psa-observe-107` に、`busybox:1.36` の Pod `baseline-audit-sample` を作成します。これは `hostNetwork: true` で動作し、`sleep 3600` を実行します。`kubectl apply` のときに、baseline 違反についての PSA の警告を記録してください：Pod は作成される必要があります。`warn` と `audit` だけではリクエストが禁止されないからです。 |
| 受け入れ基準 | `baseline-audit-sample` が存在し、`hostNetwork: true` を持ち、API に受け入れられた；namespace には依然として enforce モードがない。 |

<details>
<summary>💡 課題 4 のヒント</summary>

Pod が作成されなかった場合は、課題 3 で `audit`/`warn` だけではなく、誤って `enforce` label を設定していないか確認してください。PSA の warning は `kubectl apply` の出力にそのまま現れます (`Warning: would violate PodSecurity "baseline:v1.36"`)。別のログで探す必要はありません。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

この課題は、実質的に課題 3 の self-check を、永続的な Pod で繰り返すものです。
`baseline-audit-sample` を作成した後、それが実際に存在し、`Running`/`Pending` (拒否されていない) であることを確認します：

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

namespace `psa-restricted-107` (課題 1) と比較します：同じ安全でない manifest は、そこでは
拒否される「べき」で、ここでは受け入れられます。違いはまさに `enforce` label にあり、
一方の namespace にはあり、もう一方にはありません：

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **writable な emptyDir を持つ Read-only root filesystem** |
| :---: | :--- |
| やること | `restricted-app` を改良します：コンテナで `readOnlyRootFilesystem: true` を有効にします。タイプ `emptyDir` の volume `writable-tmp` を作成し (一時ファイルがノードのディスクに入らないよう `medium: Memory` を推奨)、`readOnly: true` なしで `/tmp` にマウントします。コンテナはこの一時的な volume にのみ書き込めます；`hostPath` は使用しないでください。Pod 内での実際の呼び出しで、両方の結果を実証します：コンテナのルートへの書き込みの試行 (たとえば `touch /root-write-test.txt`) は `Read-only file system` エラーで終了する必要があり、`/tmp/test.txt` への書き込みは成功する必要があります。Pod の変更不可のフィールドを変更するときは、`restricted-app` を削除して同じ名前で作り直してください。 |
| 受け入れ基準 | コンテナの root filesystem が read-only である；名前 `writable-tmp` の `emptyDir` が `/tmp` に writable でマウントされている；regular containers にとって、これは唯一の writable な宣言的 `volumeMount` であり、追加の `volumeMounts` はすべて read-only である；課題 2 の hardened な設定が維持されている；コンテナのルートへの実際の書き込みの試行が `Read-only file system` を返し、`/tmp/test.txt` への書き込みが成功して、読み取り可能な内容になる。 |

<details>
<summary>💡 課題 5 のヒント</summary>

`readOnlyRootFilesystem` は、すでに存在する Pod では変更できないフィールド (immutable field) に属します - securityContext を変更した `kubectl apply` はエラーを返します。Pod を削除し (`kubectl delete pod restricted-app`)、同じ名前で作り直してください。既存のものをその場で更新しようとしないでください。
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: `automountServiceAccountToken: false` を要求する** |
| :---: | :--- |
| やること | • PSA `restricted` は、すでに `allowPrivilegeEscalation: false`、`ALL` を含む `capabilities.drop`、non-root、seccomp を要求しています - 課題 2 がまさにそれを示しています。<br/>• しかし PSS `restricted` は `automountServiceAccountToken` を**確認しません**：Kubernetes API を必要としない Pod が、マウントされた ServiceAccount token を黙って受け取り、PSA を完全に通過する可能性があります。これは PSS がカバーしない独立した control であり、そのため、組み込みの PSA を重複させるのではなく、まさに custom の `ValidatingAdmissionPolicy` がここでは適切です。<br/>• Pod レベルで `automountServiceAccountToken == false` を要求する CEL 式を持つ `ValidatingAdmissionPolicy` `require-no-automount-token` を作成します。<br/>• `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding` を、`psa-restricted-107` に対する `matchResources.namespaceSelector` で限定し、`validationActions: [Deny]` で適用します。<br/>• 3 つの状態すべてを server-side dry-run で実証します：PSA に完全に適合した Pod (課題 2 のすべてのフィールド - non-root、seccomp、drop ALL、escalation false を持つ) でフィールドがないものは、policy+binding の正確なペアから DENY を受け取る必要があります；`automountServiceAccountToken: false` は ALLOW を受け取る必要があります；`automountServiceAccountToken: true` は同じペアから再び DENY を受け取る必要があります。<br/>• policy の作成後、`psa-restricted-107` の新しい Pod (再作成する `restricted-app` を含む) は、自分自身に `automountServiceAccountToken: false` を含む必要があります。そうでなければ policy がそれらを拒否します。 |
| 受け入れ基準 | • **オブジェクト：** `ValidatingAdmissionPolicy require-no-automount-token` とその `ValidatingAdmissionPolicyBinding` が存在し、`validationActions` に `Deny` が含まれ、Binding が `psa-restricted-107` のみにマッチする。実習には、この policy に対する Binding がちょうど 1 つ - `require-no-automount-token-binding` - 存在する；この policy の他の namespace 用の追加の Binding は作成されない。<br/>• **3 つの状態：** `automountServiceAccountToken: false` のない PSA 適合 Pod の server-side dry-run が、まさに `ValidatingAdmissionPolicy 'require-no-automount-token'` と `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` のペアによって拒否される (PSA のメッセージ `violates PodSecurity` でも、他の policy でもない)；`automountServiceAccountToken: false` の Pod は受け入れられ、`automountServiceAccountToken: true` の Pod は同じ正確なペアによって拒否される。<br/>• **すべての Pod のカバー：** policy が、`psa-restricted-107` 内で、その `resourceRules` で選択されるすべての Pod をカバーする。`ValidatingAdmissionPolicy` に `spec.matchConditions`、`matchConstraints.objectSelector`、`matchConstraints.namespaceSelector` を追加しないでください。また Binding の `matchResources` に `objectSelector` も追加しないでください - これらはカバレッジを一部の Pod に狭め、workload が label やリクエストの条件によって確認から漏れる可能性があります。<br/>• **Namespace の scope:** Binding の `matchResources.namespaceSelector` のみで設定され、これは `psa-restricted-107` に正確に結びつけられている；selector には他の namespace-label のキーに関する条件が含まれず、それ自体でスコープをこの namespace に一意に限定する。<br/>• **CEL:** validation には、Pod の名前/labels/annotations、user/request、`namespaceObject`、`params`、`variables`、その他のフィールドによる例外が含まれない：判断は `object.spec.automountServiceAccountToken` のみに依存する (正しい CEL の形式なら何でも許容され、optional 構文 `object.spec.?automountServiceAccountToken.orValue(true) == false` も含まれる)。`spec.auditAnnotations` が存在しないか空である：その個別の CEL expressions が `failurePolicy` を通じて admission に影響しうるため、admission control は `spec.validations` のみで設定される。`variables` と `paramKind` は使用されない。<br/>• **Resource の scope:** `matchConstraints.resourceRules` が、policy をちょうど `core/v1 pods` の操作 `CREATE` と `UPDATE` に限定し、`resourceNames` はない；`scope` が存在しないか、`*` か `Namespaced` であり、`Cluster` ではない；`excludeResourceRules` は使用されない。Binding は、自身の `resourceRules`/`excludeResourceRules` で resource/operation の scope を狭めない。<br/>• これにより、いくつかの選ばれた workload の例ではなく、`missing / false / true` の 3 つの状態で完全な boolean contract を実証できる。 |

<details>
<summary>💡 課題 6 のヒント</summary>

この課題のテスト Pod は、`automountServiceAccountToken: false` が欠けていることを除いて、PSA に完全に適合している必要があります (課題 2 のすべてのフィールド) - テスト Pod が PSS と新しい policy の両方に同時に違反していると、組み込みの PSA ではなく、まさに「あなたの」policy が作動したことを実証できません。`matchResources.namespaceSelector` のない `ValidatingAdmissionPolicyBinding` はクラスター全体に適用されます - スコープを必ず正確に 1 つの namespace `psa-restricted-107` に限定してください (たとえば `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}` で)。`psa-restricted-107` が複数の一致する namespace の 1 つにすぎないような、複数の値を持つ `matchExpressions` ではいけません：selector が誤って `psa-observe-107` にもマッチすると、同じルールがそこでも予期せず作用し始めます。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

Baseline - VAP/Binding を作成する前は、同じ PSA 適合だが automount の opt-out のない
Pod は通るはずです (PSA 自体はそれを拒否しません。`automountServiceAccountToken` は PSS に
含まれません)：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

VAP + Binding を作成し、フィールドのない manifest を繰り返します - 今度はリクエストが、PSA ではなく、
まさに binding `require-no-automount-token-binding` を通じた `ValidatingAdmissionPolicy 'require-no-automount-token'` から
DENY を受け取るはずです。続いて、両方の明示的な値を確認します：
`false` は通り、`true` は同じ正確なペアから DENY を受け取るはずです。

```bash
kubectl apply -f require-no-automount-token.yaml   # あなたの VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 期待される結果: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

同じ PSA 適合の manifest で `automountServiceAccountToken: false` を設定します - リクエストは
通るはずです：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 期待される結果: pod/self-check-automount-false created (または server-side dry-run success)
```

次に `automountServiceAccountToken: true` を設定します - リクエストは再び、まさに同じ
policy と binding によって拒否されるはずです：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 期待される結果: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

最後に、最も重要なこと - denial の事実だけでなく、scope の境界を確認してください：同じ
manifest (automount の opt-out なし) を namespace `psa-observe-107` で実行すると、「通る」はずです -
そこでも拒否される場合、`namespaceSelector` が 1 つの namespace より多くにマッチしているということです：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# 期待される結果: 0 (denied ではない) - そうでなければ binding の scope が広すぎます
```
</details>

---

| **7** | **Controller-driven な admission denial: ReplicaSet events による診断** |
| :---: | :--- |
| やること | 空の namespace `psa-controller-107` に、hardening のない単純な Pod template (たとえば `busybox:1.36`、`sleep 3600`、`securityContext` なし) を持つ Deployment `controller-app` (label `app=controller-app`、replicas=1) を作成します - 正常に起動するはずで、PSA はまだ邪魔をしません。次に、この namespace で `pod-security.kubernetes.io/enforce=restricted` と `enforce-version=v1.36` を有効にします (すでに存在する Pod は動作し続けます - PSA はすでに作成されたオブジェクトには触れません)。現在の Pod を削除します：ReplicaSet が代わりの Pod を作成しようとし、今度は admission がそれを拒否します。原因を `kubectl -n psa-controller-107 describe rs` と `kubectl -n psa-controller-107 get events` で確認します - そこには、テキスト `violates PodSecurity "restricted:v1.36"` を伴う `FailedCreate` があります。Deployment の Pod template を修正し (課題 2 と同じ hardening フィールドを追加します：non-root、`seccompProfile: RuntimeDefault`、`capabilities.drop: [ALL]`、`allowPrivilegeEscalation: false`)、ReplicaSet が、通過する新しい Pod を正常に作成するまで待ちます。 |
| 受け入れ基準 | namespace で `restricted:v1.36` が enforce されている；Deployment の Pod template が PSS `restricted` に完全に適合している；現在の Pod を削除した後、ReplicaSet が現在の enforce モードの下で新しい Ready な Pod を実際に作成する (単に「オブジェクトが存在する」だけではない - 実際の削除と再作成で確認される)。 |

<details>
<summary>💡 課題 7 のヒント</summary>

順序が重要です：まず hardening のない Deployment (PSA はまだ enforce ではないので通ります)、次に
namespace への enforce=restricted の label (既存の Pod は影響を受けません)、その後 `kubectl
delete pod -l app=controller-app` - ここで初めて ReplicaSet が admission の deny に遭遇します。
Pod を手動で削除しないと、何らかの reschedule が自然に起こるまで、拒否はまったく見えません。
修正すべきは、namespace の label ではなく、まさに Deployment の `spec.template` です (`kubectl
edit deployment controller-app` または修正した manifest での `kubectl apply`)；enforce を元に戻すことは、この課題の解決ではありません。
</details>

---

## 検証

作業マシンで次を実行します：

```bash
check_result
```

チェックには Init と 7 個の独立した課題が含まれます。さらに、安全でない Pod の
server-side dry-run も実行するため、restricted namespace に永続的な「悪い」Pod がないことは
期待どおりの正しい結果です。課題 7 では、checker が現在の Pod `controller-app` を自分で削除し、
ReplicaSet が Ready な Pod を実際に再作成することを確認します -
events のテキストを証拠としては受け入れません。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 削除

```bash
TASK=107 make delete_cks_task
```

## PSA のバージョンと audit の可観測性についての注記

この実習は、学習用クラスター自体が Kubernetes 1.36.0 で動作しているため、PSA の labels を `v1.36` に意図的に固定しています。2026-09-06 時点で、公式の CKS blueprint は Kubernetes
`v1.35` を対象としています；そのため、これは **forward-looking** な学習用の構成であり、試験のバージョンについての主張ではありません。
現在の試験の準備には、`*-version` のサフィックスを `v1.35` に置き換え、
そのバージョンのドキュメントと挙動を照合してください。

`audit` モードは、違反した Pod について、**kube-apiserver の audit event** に annotation
`pod-security.kubernetes.io/audit-violations` を追加します。学習用のインフラは
audit-log の sink を設定も提供もしないため、ここでは `kubectl` でこの annotation を
読み取ることはできません。課題 4 で観察可能な証拠となるのは、server-side admission での PSA の警告
(`Warning: ... would violate PodSecurity "baseline"`) と、`enforce` なしでの Pod の
作成の成功です；audit mode は説明されていますが、その log annotation はこの実習では
確認されません。
