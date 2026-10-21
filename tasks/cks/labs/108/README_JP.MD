[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 108 - Kyverno による Admission policies

## 目的

この CKS 実習では、Kyverno をインストールし、namespace `policy-108` を policy-as-code の
ルールで保護します。実習は validating admission を扱います：タグ `latest` の禁止、必須の
`runAsNonRoot`、registry の allowlist；最後のオプションの段階では、admission 時の Pod の mutation を扱います。
課題 6 では、このアプローチを別の仕組み - 組み込みの
`ImagePolicyWebhook` と比較します。そこでは image の判断を、クラスター内の CEL 式ではなく、`ImageReview` API を通じて外部の HTTP(S)-backend が行います。
最後の課題 7 は、3 つ目の独立した admission engine：**Gatekeeper (OPA/Rego)** で、Kyverno 内で CEL を書くのではなく、すでにデプロイされているが
不完全な policy を修正します。課題に記載されたオブジェクトと名前だけを扱ってください。

## 開始前のセルフチェック

<details>
<summary>1. 明示的なタグ `:latest` だけを禁止しても、mutable-tag のリスク全体を塞げないのはなぜか?</summary>

image がタグなしで指定された場合 (たとえば `nginx`)、Docker/OCI はデフォルトでそれを `nginx:latest` として解決します - implicit latest です。文字列 `:latest` の文字どおりの一致だけを確認する policy は、そのような image を通してしまいますが、意味的には明示的な `:latest` と同じものです。正しい policy は、明示的な latest と implicit latest の両方を拒否する - あるいは明示的な versioned tag/digest を要求する必要があります。
</details>

<details>
<summary>2. validating policy が `ephemeralContainers` を `containers`/`initContainers` とは別に確認する必要があるのはなぜか?</summary>

`kubectl debug` は、通常の Pod の CREATE/UPDATE ではなく、別の subresource API (`pods/ephemeralcontainers`) を通じて、すでに存在する Pod に ephemeral container を追加します。policy がこの subresource を明示的に含めずにリソース `pods` だけにマッチしている場合、未検証/untrusted な ephemeral container を追加しようとする試みは、通常の containers 向けに書かれたすべての validating policies をすり抜ける可能性があります。
</details>

<details>
<summary>3. Kyverno の `ValidatingPolicy` と `MutatingPolicy` の原理的な違いは何か?</summary>

`ValidatingPolicy` はリクエストを確認して許可または拒否 (Allow/Deny) するだけで - オブジェクトは変更されません。`MutatingPolicy` は、保存する前にオブジェクトを変更します (フィールドを追加/変更します。たとえば label) - リクエストはそれでも通りますが、内容は変更されています。課題 5 が mutation を使うのは、まさに目的が Pod の拒否ではなく、label を自動的に追加することだからです。
</details>

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます：

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | ノードへアクセスするためのキー |
| `k8s-1` | シングルノードの kubeadm クラスター Kubernetes `1.36.0`、containerd、**Calico** |
| `worker` | `kubectl`、Helm、`/usr/local/bin/install-kyverno` を備えた作業マシン |

Control-plane は通常の Pod を許可しているため、別の Kubernetes worker は作成されません。
Kyverno は初期状態では意図的に**インストールされていません**：これは課題 1 の一部です。作業マシンには、
chart を手動で選ぶ必要のない、固定された installer が用意されています。
この実習は Kyverno `1.19` (Helm chart `3.9.0`) を固定し、安定した CEL ベースの API
`policies.kyverno.io/v1` を使用します。`kyverno.io/v1` の Legacy `Policy`/`ClusterPolicy` は、このバージョンから
deprecated であり、移行用の資料としてのみ扱われます。

Kyverno とは異なり、課題 7 用の **Gatekeeper (OPA) はすでに** クラスターの bootstrap によって**インストールされており**、
初期の (意図的に不完全な) `ConstraintTemplate` と `Constraint` も含まれています。
これは意図的なものです：課題 7 は、admission engine をゼロからインストールすることではなく、すでに存在する
`ConstraintTemplate` の Rego を見つけて書き足す能力を確認します - その部分は
Kyverno の課題 1 ですでに練習されています。課題 7 は、Kyverno の課題 1-5 (`policy-108`) から分離された
別の namespace `gatekeeper-108` で動作し、Pod が
2 つの異なる admission engine に同時に拒否されることがないようにしています。

## デプロイ

```bash
TASK=108 make run_cks_task
```

作業マシンに SSH で接続します。コンテキスト `cluster1-admin@cluster1` はすでに設定されています。

```bash
time_left
check_result
```

## 課題

---
| **1** | **Kyverno をインストールする** |
| :---: | :--- |
| やること | • namespace `kyverno` に Kyverno をインストールします。<br/>• worker に用意されたコマンド `/usr/local/bin/install-kyverno` を使用します；これは固定された Helm chart を適用します。<br/>• admission controller が利用可能になるまで待ちます。 |
| 受け入れ基準 | • クラスターに CRD `validatingpolicies.policies.kyverno.io` がある<br/>• Kyverno のバージョンが `1.19.x` である<br/>• namespace `kyverno` の少なくとも 1 つの Deployment に利用可能な replica がある |

<details>
<summary>💡 課題 1 のヒント</summary>

`/usr/local/bin/install-kyverno` はすでに固定されたバージョンに設定されています - 別の chart を使って `helm install` で Kyverno を手動でインストールしようとしないでください。CRD のバージョンが非互換になる可能性があります。インストールの後は待ってください：admission controller の Pod が `Available` になる必要があり、それは瞬時には起こりません。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

最初のコマンドは CRD 自体を返す必要があります (エラー `NotFound` ではなく)；image のバージョンには
`v1.19.` が含まれる必要があります；少なくとも 1 つの Deployment の `AVAILABLE` が `0` より大きい必要があります。
</details>

---
| **2** | **タグ `latest` の image を禁止する** |
| :---: | :--- |
| やること | • `validationActions: [Deny]` を持つ、CEL ベースの `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) を作成します。<br/>• namespace `policy-108` の Pod と subresource `pods/ephemeralcontainers` に適用される必要があります。<br/>• `containers`、`initContainers`、`ephemeralContainers` の中の、明示的な `:latest` または implicit latest (タグも digest もまったくない image) である任意の image を拒否する必要があります。 |
| 受け入れ基準 | • Policy が存在し、Deny モードで動作する<br/>• Admission が、3 つのコンテナリストそれぞれで、明示的な `:latest` と implicit latest (タグなし) の両方を拒否する。タグのない registry-ポート付きの image (`registry.example:5000/app`) も含む。また、各リストで versioned な trusted images と digest で固定された images を受け入れる<br/>• 既存の Pod の UPDATE で `spec.containers[*].image` または `spec.initContainers[*].image` を `:latest` に変更した場合も、この policy によって拒否される (通常の Pod の image フィールドは in-place UPDATE を許可する) |

<details>
<summary>💡 課題 2 のヒント</summary>

`matchConstraints.resourceRules` は、`pods` と subresource
`pods/ephemeralcontainers` の両方を別々にカバーする必要があります - そうでないと `kubectl debug` は policy をすり抜けます。
CEL ロジック自体については：image の文字列を、最後の `/` の後にある最後の `:` で `registry/path` と `tag` に分解してください
(最後の `/` の前にある `:` は、タグではなく registry のポートの一部である可能性があります)；
分解した後にタグがまったくなければ - それは implicit latest です；タグがあっても
`latest` に等しければ - それも禁止されるケースです；digest (`@sha256:...`) は別の、常に
許可されるケースで、タグには該当しません。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

policy を適用する前に、違反する Pod がそもそも admission を通ること (baseline) を確認してください -
そうでないと、denial があなたの policy によるものか他の何かによるものか分かりません：

```bash
# baseline: policy を適用する前 - 通るはずです (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

policy を適用してから、同じ manifest をもう一度実行します - 今度は admission エラー
(exit が 0 以外) で終了し、メッセージがあなたの policy を参照しているはずです：

```bash
kubectl apply -f deny-latest-tag.yaml   # あなたの policy のファイル
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

次のものについて、同じ baseline→apply→probe→compare のサイクルを繰り返してください：タグがまったくない image
(`registry.k8s.io/pause`)、`registry.example:5000/app` (最後の `/` の前のコロンは registry のポートであり、タグではありません)、`initContainers` の `:latest`、そして、すでに起動している許可された Pod に対する
`kubectl debug --image=...` での `:latest`/タグなし (`pods/ephemeralcontainers`
subresource)。最後に positive control を確認します - versioned タグは、policy の適用前だけでなく
適用後も通る必要があります。
</details>

---
| **3** | **root 以外での実行を要求する** |
| :---: | :--- |
| やること | • Deny モードの CEL ベースの `ValidatingPolicy` `require-run-as-non-root` を作成します。<br/>• `policy-108` のすべての Pod で、フィールド `spec.securityContext.runAsNonRoot` が明示的に `true` に等しい必要があります。<br/>• Pod レベルとすべてのコンテナで、`runAsUser: 0` と container-level の `runAsNonRoot: false` が禁止されます：コンテナの設定は Pod-level の securityContext を上書きできるためです。 |
| 受け入れ基準 | • Policy が存在し、Deny である<br/>• `runAsNonRoot: false` の Pod、またはこのフィールドのない Pod、Pod-level の `runAsUser: 0`、また `containers`、`initContainers`、`ephemeralContainers` 内の `runAsNonRoot: false` / `runAsUser: 0` のコンテナが、まさにこの policy によって拒否される<br/>• 安全な明示的な container-level の `runAsNonRoot: true`、`runAsUser: 1000` は受け入れられる |

<details>
<summary>💡 課題 3 のヒント</summary>

「`false` がないこと」ではなく、明示的な値 `true` を確認してください - `object.spec.securityContext.runAsNonRoot == true` のような CEL 式は、フィールドがまったく設定されていない場合に通りません (`null != true`)。そしてここではそれが必要です：課題は、明示的な `false` と、フィールドの欠如の両方を拒否します - 明示的な `false` だけではなく、両方のケースが denied になる必要があります。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

```bash
# baseline: policy を適用する前、両方のパターンが通るはずです
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

policy を適用して、両方の manifest をもう一度実行します - 今度は両方が admission エラーで
終了するはずです。続いて positive control を確認します：同じ Pod で、
`runAsNonRoot: true` を明示したものは、policy の適用後も通る必要があります。
</details>

---
| **4** | **Container registry の allowlist** |
| :---: | :--- |
| やること | • Deny モードの CEL ベースの `ValidatingPolicy` `allow-approved-registries` を作成します。<br/>• すべてのコンテナ (`containers`、`initContainers`、`ephemeralContainers`) で、`registry.k8s.io/*` または `ghcr.io/cks-lab/*` のみを許可します。<br/>• その他の image registry は禁止します。 |
| 受け入れ基準 | • Policy が存在し、Deny である<br/>• Untrusted な image が 3 つのリストすべてで拒否される<br/>• 承認された 2 つの prefix (`registry.k8s.io/` と `ghcr.io/cks-lab/`) が、3 つのリストそれぞれで許可される<br/>• image を未承認の registry に変更する通常の Pod UPDATE が、policy 自体によって拒否される<br/>• 他の未承認の registry と、init/ephemeral リストでの host/path に似た偽装も確認される |

<details>
<summary>💡 課題 4 のヒント</summary>

`startsWith('registry.k8s.io/')` は最も確実な prefix の確認ですが、許可された 2 つの registry が OR (どちらか一方で良い) で確認され、AND (両方同時、1 つの image には不可能) ではないことを確認してください。確認するのは allowlist (image は 2 つの prefix のどちらかに一致した場合にのみ許可される) であり、具体的に `docker.io` の denylist ではありません - 「`docker.io` なら deny、それ以外は allow」と書かれた policy は、`quay.io`、unqualified な images、その他あらゆるサードパーティの registry を通してしまいます。また、prefix が末尾の `/` 付きで比較されていること (`registry.k8s.io/` であり、単なる `registry.k8s.io` ではない) も確認してください。そうでないと、綴りの似た host (`registry.k8s.io.evil.example`) が、大文字小文字を区別しない、または不完全な一致で通る可能性があります。課題 2 と同様に、`ephemeralContainers` を忘れないでください - これは 3 つのコンテナリストを確認する同じパターンです。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

```bash
# baseline: policy を適用する前 - untrusted registry が通るはずです
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

policy を適用して同じ manifest を繰り返します - 今度は denied になるはずです。これは 1 つの
具体的な untrusted の値 (`docker.io`) にすぎず、完全な
allowlist の証明ではありません - 文字どおり `docker.io` を禁止するだけで、たとえば
unqualified な image (明示的な host のない implicit Docker Hub)、`quay.io`、または
綴りの似た host (`registry.k8s.io.evil.example`) を通してしまう policy も、この 1 つの
確認は通ります。同じ baseline→apply→probe→compare を、少なくとも次について繰り返してください：unqualified な
image (host がまったくない `busybox:1.36`)、別の明示的なサードパーティの registry
(`quay.io/...`)、綴りの似た host/path (`registry.k8s.io.evil.example/...`、
`ghcr.io/cks-lab.evil/...`)、`initContainers` の untrusted な image、そして、すでに起動している許可された Pod に対する
`kubectl debug` での untrusted/trusted な image。最後に positive control：両方のコンテナ (main + init) が
`registry.k8s.io`/`ghcr.io/cks-lab` の Pod は通る必要があります；`ghcr.io/cks-lab/*` も、`containers` だけでなく
init と ephemeral コンテナで確認してください。
</details>

---
| **5** | **オプション: Kyverno で label を mutate する** |
| :---: | :--- |
| やること | • namespace `policy-108` の Pod に、label `security.cks.io/managed-by: kyverno` が存在しない場合に追加する、CEL ベースの `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`) を作成します。<br/>• validation ではなく mutation を使用します。<br/>• 他の namespace の Pod は mutate しないでください。 |
| 受け入れ基準 | • 許可された registry と `runAsNonRoot: true` を持ち、この label がまだない Pod の server-side dry-run が、mutation の後に値 `kyverno` でそれを受け取る<br/>• label がすでに別の値で設定されている Pod は、元の値を保持する<br/>• `default` の Pod にはこの label が付かないままである<br/>• この段階は `check_result` に表示されるが、スキップしても構わない |

<details>
<summary>💡 課題 5 のヒント</summary>

この段階はオプションです - 時間がなくなった場合は、実習の他の部分にリスクなくスキップできます。mutation を確認するテスト Pod は、すでに課題 2-4 の policies (trusted registry、non-root) を通る必要があります - 前の policy のいずれかにそれ自体が拒否されると、mutation の結果がまったく見えません。課題の「存在しない場合」は単なる希望ではありません：mutation は label の有無を明示的に確認し、すでにある場合はオブジェクトに触れてはいけません。そうでなければ、label のない Pod が正しい値を受け取ったとしても、課題は達成されていません。
</details>

---
| **6** | **ImagePolicyWebhook: CEL policy の代わりに外部 backend** |
| :---: | :--- |
| やること | • 作業マシンには、すでに `/opt/image-policy-backend/server.py` が用意されています - `ImageReview` API を実装する最小限の HTTPS サーバーで (タグ `:latest` またはタグがまったくない image を拒否します)。<br/>• これを namespace `image-policy` に Deployment としてデプロイし、ポート `8443` の Service `image-policy-backend` の背後に置きます。Backend は TLS で接続を受け付ける必要があります (upstream の `ImagePolicyWebhook` の契約は HTTPS を要求し、plain HTTP はサポートされません)。<br/>• `control-plane` (`ssh`、その後 `sudo -i`) で、plugin `ImagePolicyWebhook` 用の `AdmissionConfiguration` (`defaultAllow: false`) と、あなたの backend を指す kubeconfig を設定します。<br/>• static manifest `kube-apiserver.yaml` で、`ImagePolicyWebhook` を既存の `--enable-admission-plugins` のリストに**追加**し (リスト全体を置き換えないでください - すでに有効な plugins を無効にするリスクがあります)、`--runtime-config=imagepolicy.k8s.io/v1alpha1=true` を有効にします。<br/>• API の復旧後、`:latest` の Pod を作成します - 拒否される必要があります；次に、固定されたタグの Pod - 作成される必要があります。 |
| 受け入れ基準 | • `image-policy-backend` が Available である<br/>• Kube-apiserver が healthy で、plugin が追加されており (置き換えられておらず)、`--runtime-config` がある<br/>• backend の kubeconfig が HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy` を使用している<br/>• `:latest` と implicit latest (タグなしの registry-port を含む) の Pod が、namespace `default` で、まさに ImagePolicyWebhook によって拒否される — 通常の Pod でも、init/ephemeral container でも同様<br/>• ユーザー定義のアノテーション `alpha.image-policy.k8s.io/break-glass: "true"` は例外にならない<br/>• Namespace `policy-108` は、Tasks 2-4 の Kyverno 用に割り当てられており、2 つの独立した admission の仕組みが互いの拒否を隠さないようにしている<br/>• そのため backend は、`ImageReview.spec.namespace == policy-108` の場合は判断を Kyverno に委譲し、それ以外のすべての namespace では ImagePolicyWebhook が引き続き動作する<br/>• 固定されたタグの Pod が作成され Running である<br/>• backend の outage の間に Service が実際に Endpoints を失い、この endpoint の利用不能により API が拒否する (`defaultAllow: false`)。その後、Service の selector と admission が正確に元の状態に復元される |

<details>
<summary>💡 課題 6 のヒント</summary>

`ImagePolicyWebhook` は、課題 1-5 の Kyverno とは原理的に異なる仕組みです：判断を行うのは、クラスター内の CEL 式ではなく、`ImageReview` API を通じた外部の HTTPS-backend です。用意された `/opt/image-policy-backend/server.py` を `control-plane` にコピーしてください (たとえば SSH 経由で `scp`/`cat`) - この課題が確認するのは、admission plugin の wiring、TLS の契約、ImageReview API の理解であり、HTTP サーバーをゼロから書く能力ではありません。TLS については：まず Service を作成し (`ClusterIP` を知るため)、次にその IP を SAN に含む自己署名証明書を作成し (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`)、続いてコードと証明書の両方をマウントする Deployment を作成します。既存の `--enable-admission-plugins` を新しい値で全体的に置き換えないでください - すでに有効な plugins にカンマ区切りで `ImagePolicyWebhook` を追記してください (通常は `NodeRestriction` がすでにあります)。また `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` も忘れないでください - この API を明示的に有効にしないと、backend はまったく呼び出されません。Namespace `image-policy` は事前に作成されていません - Deployment/Service の前に自分で作成してください。リソース/パス/フラグの詳細な手順で行き詰まった場合は、参考となる手順が解答に示されています。
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: Rego の blocklist を書き足す** |
| :---: | :--- |
| やること | • クラスターには、すでに **Gatekeeper** (OPA) と、`ConstraintTemplate` `k8sblockedregistries`、および Constraint `K8sBlockedRegistries/deny-bad-registries` がインストールされており、これは別の namespace `gatekeeper-108` に限定されています (`policy-108` ではありません - これは Kyverno の課題 1-5 とは別の演習場であり、Kyverno と Gatekeeper が同じ Pod を同時に拒否しないようにしています)。<br/>• `ConstraintTemplate` 内の Rego には、すでにいくつかのブロックされた registry (`untrusted-registry.example`、`docker-fake.test`) が含まれていますが、`very-bad-registry.test` は**意図的に含まれていません**。<br/>• `ConstraintTemplate.spec.targets[].rego` を見つけ、そこに `very-bad-registry.test` 用のルールを書き足します - `Constraint` のパラメータではなく、Rego の中にです。<br/>• `deny-bad-registries` はすでに完全に正しく、`spec.parameters` をまったく使用していません - 触れる必要はありません。 |
| 受け入れ基準 | • `ConstraintTemplate k8sblockedregistries` と元の Constraint `K8sBlockedRegistries/deny-bad-registries` が存在する<br/>• Rego が元の 2 つの有効なルール (`untrusted-registry.example`、`docker-fake.test`) を保持し、`very-bad-registry.test` 用の新しい有効なルールを含む<br/>• これら 3 つの registry それぞれの Pod が、`gatekeeper-108` で、まさに Constraint `deny-bad-registries` によって拒否される<br/>• 信頼された `registry.k8s.io` の image を持つ Pod は通る<br/>• Constraint が Pod のみで、`gatekeeper-108` に限定され、parameters/selectors/exclusions がないままである<br/>• この種類の追加の Constraint は作成されない |

<details>
<summary>💡 課題 7 のヒント</summary>

ConstraintTemplate は `kubectl get constrainttemplate k8sblockedregistries -o yaml` で見つけてください。Rego は `spec.targets[].rego` に複数行の文字列として入っています - 編集すべきはまさにそれです (`kubectl edit constrainttemplate k8sblockedregistries`、または `get -o yaml` → 修正 → `apply`)。既存の Rego は、ブロックされた registry を `blocked_registry("untrusted-registry.example")` の形式の個別のファクトとして宣言しています - 既存のものを削除したり置き換えたりせずに、`very-bad-registry.test` 用にもう 1 行そのような行を書き足してください。これを `Constraint.spec.parameters` と混同しないでください - この policy のバージョンでは、Constraint は parameters をまったく使用しないため、そこには編集するものがありません。
</details>

<details>
<summary>🔍 `check_result` の前の自己確認</summary>

Baseline - 修正の前：`very-bad-registry.test` の Pod は通る (Rego はまだそれをカバーしていない) はずで、すでに
ブロックされている `untrusted-registry.example` は拒否されるはずです：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

Rego を書き足して、同じ manifest をもう一度実行します (新しい名前で。古い Pod は dry-run ですでに
「作成」されており、保存されていません) - 今度は、両方の registry について、
まさに `k8sblockedregistries` を参照する Gatekeeper からの admission エラーが期待されます：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

positive control を確認します - 信頼された registry は、修正の後も通る必要があります：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## 検証

作業マシンで次を実行します：

```bash
check_result
```

チェックには Init と 7 個のテストが含まれます。最初の 4 つ、6 番目、7 番目は必須です。5 番目の
テストは mutation の確認を実行しますが、オプションの policy が作成されていなくても、実習は失敗になりません。
課題 2-4 と 7 は `--dry-run=server` を使用するため、image はダウンロードされず、Pod も namespace に
残りません；課題 6 は ImagePolicyWebhook を通じた実際の (dry-run ではない)
admission を確認するため、Pod `webhook-pinned-ok` は実際に作成されます。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 削除

```bash
TASK=108 make delete_cks_task
```

## 互換性と image 禁止の正確なセマンティクス

この実習は、新しい `policies.kyverno.io/v1` API を知るために Kubernetes 1.36.0 と Kyverno 1.19 を固定しています。
これは **forward-looking / unsupported combination** です：Kyverno
1.19 は、公式には Kubernetes 1.33-1.35 でテストされており、1.36 ではありません。実習の外で適用する前に、
サポートされているバージョンのマトリックスを選び、release notes と照合してください。

課題 2 における「`latest` の禁止」には、暗黙的な `latest` の禁止も含まれます：タグも digest もない `nginx` は、
`nginx:latest` と同様に許可されません。許可されるのは、`latest` 以外の明示的なタグ、または
digest (`@sha256:...`) を持つ image のみです。この基準に対する正確な CEL ロジックは、課題では
用意されていません - 追加の手がかりが必要であれば、課題 2 のヒントを参照してください。
