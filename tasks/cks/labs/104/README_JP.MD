[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 104 - Kubernetes API へのアクセス制限：RBAC、ServiceAccount、anonymous-auth

## 目的

この CKS 実習では、最小権限の原則に従って Kubernetes API へのアクセスを制限します。実習は、最小限の namespaced RBAC、現代的な短命の ServiceAccount token、API token を持たない Pod、古くなった過剰な権限の削除、そして API server への匿名アクセスの無効化を扱います。

課題で指定されたオブジェクトだけを扱ってください。Namespace `security-104` と、意図的に危険な `legacy-operator-admin` の紐づけは、課題 10-12 用の fixtures と同様に、起動スクリプトによってすでに用意されています：Secret `legacy-config`、namespace `rbac-a`/`rbac-b`、そして namespace `development`。これは学習用の構成であり、production の例ではありません。

## Threat model

攻撃者がすでに Pod 内でコードを実行しており、workload の identity、または authentication の欠如を利用して Kubernetes API へ進もうとしていると仮定します。この場合、重要なのは最初のアクセスだけでなく、compromise の後の blast radius です。

課題 1 は過剰な RBAC scope を、課題 2 は長命な token を、課題 3 は Pod からの不要な API アクセスを塞ぎます。これにより、compromise の後に workload の identity を悪用できる余地が減ります。

課題 4 は wildcard の cluster-wide 権限を、課題 5 は anonymous access を排除します。これらの経路はそれぞれ単独でも、blast radius を Kubernetes API にまで広げる可能性があります。

課題 6 は、別の漏洩経路を塞ぎます：environment variable で渡された secret はプロセスの環境の一部となり、コンテナへの `exec` 権限を持つ任意のプロセスが `/proc/1/environ` から読み取れます。また、プログラム自体や診断ツールが環境を出力する場合には、application logs、crash dump、その他の診断出力に含まれる可能性もあります。`secretKeyRef` を持つ `env` に対する `kubectl describe pod` は、Secret とそのキーへの参照 (`<set to the key ... in secret ...>`) だけを表示し、`secretRef` を持つ `envFrom` に対しては Secret の名前だけを表示します。resolved な値は表示しません - この参照を、値そのものの漏洩と混同しないでください。`defaultMode: 0400` を持つ Volume mount は、権限のあるコンテナプロセスが値にアクセスすることを防ぎませんが、secret をプロセスの環境から取り除き、ファイルの読み取り権限を所有者のみに制限します。

課題 7 は、RBAC の privilege escalation の隠れた経路を塞ぎます：`impersonate`、`bind`/`escalate`、CSR approval は、利用可能なリソースのリストを直接は広げませんが、他者の名前で行動したり、自分自身により広い権限を付与したりすることを可能にします - これは課題 4 の wildcard `*` とは別のリスクのカテゴリです。課題 8 は、個別的ではなく体系的な防御を扱います：namespace/default SA レベルの automount は、開発者が token を明示的に無効化し忘れた Pod に対しても機能します。

課題 9 は、予防 (課題 1-8) と検出が、別個の、互いに補完し合うレイヤーであることを示します。課題 7 で特定の escalation 経路を塞いだとしても、将来のインシデントのためには、常時手動で `kubectl get` を行うことなく**危険な RBAC の変更** (たとえば、誰かへの誤った、または悪意のある `cluster-admin` の付与) を確認する方法が必要です：audit log は、RBAC の状態の現在のスナップショットだけでなく、変更を実際に開始したのが誰かについての、再現可能な forensic evidence を提供します。

ATT&CK T1528 (Steal Application Access Token) と T1613 は、このシナリオの文脈を与えます：課題は個別の攻撃をモデル化するのではなく、すでに compromise された workload の影響を制限します。

課題 10-12 は、試験でよく出る 3 つの基本的なワークフローを扱うもので、新しい脅威ではありません：課題 10 - manifest に値をケースバイケースでハードコードすることなく、既存の secret を安全に再利用すること；課題 11 - 過剰な Role の個別の修復と、scope を間違えやすい cross-namespace の RBAC の紐づけ；課題 12 - すでに用意された kubeconfig を読み解くだけではなく、private key から検証可能なアクセスまでの、証明書による新規ユーザーの完全な onboarding。

## 開始前のセルフチェック

`check_result` を開く前に、次の質問に自信を持って答えられることを確認してください。そうでなければ、[第 10 章](../../course/10/jp.md) (RBAC)、[第 11 章](../../course/11/jp.md) (ServiceAccounts)、[第 12 章](../../course/12/jp.md) (API へのアクセス制限) に戻ってください。

<details>
<summary>1. 課題 1 の文脈で、`Role`+`RoleBinding` は `ClusterRole`+`ClusterRoleBinding` と何が違うか？</summary>

`Role` は 1 つの namespace でのみ有効ですが、その `RoleBinding` は、他の任意の namespace の subject (たとえば ServiceAccount) を参照できます - Kubernetes は、`RoleBinding` 自身の namespace とは異なる `subjects[].namespace` を公式にサポートしています。固定されたままなのは、付与される権限の scope です：subject がどこから来たかに関係なく、権限は `RoleBinding` が作成された namespace でのみ有効です。`RoleBinding` は (`Role` だけでなく) `ClusterRole` も参照できます - その場合、cluster-wide なテンプレートから権限が得られますが、特定の `RoleBinding` の namespace でのみ付与されます。`ClusterRole`+`ClusterRoleBinding` はクラスター全体へのアクセスを与えます。課題 1 は最小限の **namespaced** アクセスを求めているため、`ClusterRole` ではなく `Role` を使います - そうしないと scope が必要以上に広くなります。
</details>

<details>
<summary>2. bound projected token (課題 2) が、legacy の Secret ベースの token より安全とされるのはなぜか？</summary>

Bound projected token は短命 (`expirationSeconds` で設定) で、自動的に失効して kubelet によりローテーションされ、特定の Pod に紐づいています - Pod が削除されると token は無効になります。Legacy の Secret-token には expiration がなく、通常の `Secret` として etcd に保存され、Pod がもう存在しなくても無期限に有効なままです。
</details>

<details>
<summary>3. `automountServiceAccountToken: false` が、Pod レベルと ServiceAccount レベルで与えるものの違いは何か？</summary>

ServiceAccount レベルでは baseline です：Pod が明示的にオーバーライドしない限り、その SA を使用するすべての Pod に値が適用されます。Pod レベルでは override です：Pod spec の明示的なフィールドが SA の値より優先されます。課題 8 は SA/namespace レベルの baseline を特に確認し、課題 2-3 は個別の Pod レベルの明示的な設定を確認します。
</details>

<details>
<summary>4. `impersonate`/`bind`/`escalate` (課題 7) が、wildcard `*` (課題 4) と同じリスクの分類に入らないのはなぜか？</summary>

`resources`/`verbs` の wildcard `*` は、**利用可能な操作とリソースのリスト**を直接広げます。`impersonate`/`bind`/`escalate` は、それ自体では新しいリソースへのアクセスを与えません - **他者の名前で行動する** (`impersonate`) こと、または**もともと持っていなかった権限を自分自身に付与する** (`bind`/`escalate`) ことを可能にします。これは privilege escalation の別のカテゴリで、`verbs`/`resources` だけを見てこれら 3 つの特別な verb を考慮しないと、RBAC の監査で見落としやすいものです。
</details>

## インフラ

環境は Terragrunt により AWS `eu-central-1` に展開されます：

| コンポーネント | 用途 |
|---|---|
| `vpc` | パブリックサブネットを持つ VPC `10.10.0.0/16` |
| `ssh-keys` | ノードへアクセスするためのキー |
| `k8s-1` | シングルノードの kubeadm クラスター Kubernetes `1.36.0`、containerd、**Calico** |
| `worker` | 設定済みの `kubectl` と `check_result` を備えた作業マシン |

Control-plane は通常の Pod の実行を許可しているため、別の worker ノードは不要です。
課題 5 では control-plane への SSH アクセスが必要です：API server の
static Pod の manifest はそこにあります。

## デプロイ

```bash
TASK=104 make run_cks_task
```

作業マシンに SSH で接続します。コンテキスト `cluster1-admin@cluster1` はすでに設定されています。

```bash
time_left
check_result
```

## 課題

---
| **1** | **Pod の読み取り用の最小限の RBAC** |
| :---: | :--- |
| やること | namespace `security-104` に、ServiceAccount `auditor`、Role `pod-observer`、RoleBinding `auditor-pod-observer` を作成します。Role は core API のリソース `pods` に対する `get`、`list`、`watch` **のみ**を許可する必要があります。これを ServiceAccount `auditor` にのみ紐づけます。 |
| 受け入れ基準 | Role に、`pods` に対する verbs `get`、`list`、`watch` のルールがちょうど 1 つだけある；RoleBinding がこの Role と ServiceAccount `auditor` を参照している；`auditor` として `secrets` を削除できない。 |

<details>
<summary>💡 課題 1 のヒント</summary>

よくある間違いは、余分な verbs を追加すること (たとえば「念のため」の `create`) や、`Role` の代わりに `ClusterRole` を使うことです。自己確認します：`kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` は `yes` を返し、`kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` は `no` を返す必要があります。Role と RoleBinding が異なる namespace にあると、紐づけは機能しません - `RoleBinding` は `Role` と同じ namespace にある必要があり、その中の subject は `name`/`namespace` が正確に一致している必要があります。
</details>

---
| **2** | **短命の projected ServiceAccount token** |
| :---: | :--- |
| やること | `security-104` に ServiceAccount `api-client` と Pod `token-client` を作成します。legacy の Secret-token は使用しないでください。通常の token の自動マウントを無効にし、必要な token は、**ちょうど 1 つの** projected `serviceAccountToken` source によって、`/var/run/secrets/tokens/api-token` に、`path: api-token` と `600` 以上 `3600` 以下の `expirationSeconds` でマウントします - 同じ (または別の) projected volume に、追加の `serviceAccountToken` source を一切追加しないでください。**`audience` は指定しないでください**。そうすると kubelet が API server のデフォルトの identifier を要求します。アプリケーションが別の audience を必要とする場合は、まず API server の `--api-audiences` (または `--service-account-issuer` のデフォルト) と照合し、その後でのみ明示的に指定してください。 |
| 受け入れ基準 | Pod が `api-client` を使用し、`automountServiceAccountToken: false` を持ち、Pod の spec 全体に projected `serviceAccountToken` source を**ちょうど 1 つ**含む - ハードコードされた audience はなく、指定された path と、`600`-`3600` の範囲 (両端を含む) の `expirationSeconds` を持つ。admin コンテキストから、マウントされた token に対して実行した TokenReview が `authenticated: true` と名前 `system:serviceaccount:security-104:api-client` を返す；別の RBAC チェックで、この ServiceAccount が `secrets` を削除できないことが確認される。 |

<details>
<summary>💡 課題 2 のヒント</summary>

`projected.sources[].serviceAccountToken` の正確な構文を暗記する必要はありません - `kubernetes.io/docs` に用意された例があります：Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/)、セクション **"serviceAccountToken projected volumes"**。最もよくある間違いは、それが標準の値だと思い込んで `audience: kubernetes.default.svc` を明示的に指定することです。kubeadm クラスターでは、これはデフォルトとして**保証されていません** - API server が `--api-audiences` で受け付けない audience を指定すると、TokenReview は `authenticated: false` を返します。`audience` フィールドをまったく指定しないでください - そうすると kubelet が API server のデフォルトの identifier を要求し、サーバーはそれを確実に受け付けます。また、Pod 自体に `automountServiceAccountToken: false` を指定するのを忘れないでください - そうしないと Kubernetes は、あなたの projected volume に加えて、通常の (legacy スタイルの) token volume も追加します。もう 1 つのよくある間違いは、`expirationSeconds` を小さすぎる値 (たとえば `300`) にすることです：Kubernetes API は `serviceAccountToken` projected volume に最小 `600` 秒を要求します - それより小さい値は、`kubectl apply` の時点で API server が invalid として拒否します (`must be at least 10 minutes`)。
</details>

---
| **3** | **Kubernetes API token を持たない Pod** |
| :---: | :--- |
| やること | `automountServiceAccountToken: false` を持つ ServiceAccount `no-token-sa` と、この ServiceAccount を使う Pod `no-token` を `security-104` に作成します。Pod 自体にも、明示的に `automountServiceAccountToken: false` を設定します。安全で長時間動作する任意のイメージ (たとえば `busybox:1.36` と `sleep 3600`) を使用します。ServiceAccount の token を持つ Secret を手動で別途マウントしないでください - Pod には、automount 経由でも、明示的にマウントされた legacy Secret 経由でも、API token が一切あってはなりません。 |
| 受け入れ基準 | ServiceAccount と Pod の両方で automount が無効になっている；Pod が `no-token-sa` を使用している；その spec に、自動的に追加された ServiceAccount token volume も、手動でマウントされたタイプ `kubernetes.io/service-account-token` の Secret もない；コンテナ内で `/var/run/secrets/kubernetes.io/serviceaccount/token` を読み取ろうとするとエラーで終了し (ファイルが存在しない)、その際 `kubectl exec` 自体は成功する必要がある。 |

<details>
<summary>💡 課題 3 のヒント</summary>

課題 8 との違い：技術的には、SA か Pod のどちらか一方のレベルで automount を無効にするだけでも足りますが、この課題は**両方**のレベルを同時に (defence in depth) 求めています。自己確認します：`kubectl get pod no-token -o jsonpath='{.spec.volumes}'` に `kube-api-access-*` に似たものが含まれていてはなりません。それでも volume が現れた場合は、Pod を作成した後ではなく、作成する前に automount を無効にしたことを確認してください (SA の変更は、すでに作成された Pod には影響しません)。automount を無効にしても、`volumes[].secret` を通じて古い (legacy の) `type: kubernetes.io/service-account-token` の `Secret` を手動でマウントすることは妨げられません - そうすると、Pod には形式上 automounted な volume がなくても、実際には有効な API token が得られてしまいます。この課題が求めているのは token の完全な不在であり、automount の不在だけではありません。
</details>

---
| **4** | **過剰な cluster-wide 権限を削除する** |
| :---: | :--- |
| やること | クラスターには、wildcard 権限を持つ ClusterRole `legacy-operator-admin` と、`security-104` の ServiceAccount `legacy-operator` に対する同名の ClusterRoleBinding が意図的に残されています。**両方の**オブジェクトを削除してください。wildcard アクセスを別の広い ClusterRole に置き換えないでください。 |
| 受け入れ基準 | `legacy-operator-admin` が、ClusterRole としても ClusterRoleBinding としても存在しない；ServiceAccount `legacy-operator` が、`security-104` の `secrets` をもう読み取れない。 |

<details>
<summary>💡 課題 4 のヒント</summary>

`ClusterRole` を削除せずに `ClusterRoleBinding` だけを削除すると、危険なテンプレートがクラスターに残ります - 誰かが後でそれに対する新しい紐づけを作成できます。両方のオブジェクトを削除してください。2 つの別々のコマンドで自己確認します：`kubectl get clusterrole legacy-operator-admin` と `kubectl get clusterrolebinding legacy-operator-admin` - どちらも `NotFound` を返す必要があります。
</details>

---
| **5** | **API server への anonymous access を無効にする** |
| :---: | :--- |
| やること | • control-plane 上に、`/livez`、`/readyz`、`/healthz` を除くすべての endpoint への anonymous access を無効にする `AuthenticationConfiguration` を含むファイル `/etc/kubernetes/authentication-config.yaml` を作成します - kubeadm が static Pod API server の HTTPS liveness/readiness/startup probes に使うのはまさにこれらの path であり、完全な `--anonymous-auth=false` は、攻撃者のアクセスだけでなく probes 自体も壊します。<br/>• `hostPath` volume と引数 `--authentication-config=<コンテナ内のパス>` を通じて、`/etc/kubernetes/manifests/kube-apiserver.yaml` にファイルを接続し、既存の `--anonymous-auth=true` を**削除**します - anonymous access の 2 つの設定方法は互いに排他的であり、両方が指定されると kube-apiserver は起動しません。Kubelet が static Pod を自動的に再起動します。<br/>• API server の準備ができるまで待ち (Pod が Running/Ready のままであること)、認証なしの `/version` へのリクエストが `401` を受け取り、`/livez` と `/readyz` へのリクエストが `200` を受け取ることを確認します。<br/>• さらに、effective な `--authorization-mode` が `Node,RBAC` を含み、`AlwaysAllow` を**含まない**ことを確認します (制限的な authorization のない authentication は無意味です)。<br/>• subjects が `system:anonymous`/グループ `system:unauthenticated` である ClusterRoleBinding を監査します：クラスターには、そのような危険な (lab-owned) 紐づけ `lab104-unintended-anonymous-access` が 1 つ意図的に残されています。その ClusterRole とともに削除してください。標準の kubeadm の binding `system:public-info-viewer` には**触れないでください** - これも `system:unauthenticated` に紐づいていますが、アクセスを与えるのは non-resource URL `/livez`、`/readyz`、`/healthz`、`/version`、`/version/` のみであり、これは bootstrap の通常の一部 (default Kubernetes RBAC) であって、この課題の発見事項ではありません。<br/>• これは、同じ課題の `AuthenticationConfiguration` とは別のレイヤーです：そこでは `anonymous.conditions` が、匿名 identity を `/livez`/`/readyz`/`/healthz` のみに意図的に許可しています - `/version` に匿名でアクセスできないのは、そのリクエストが authentication の段階でそもそも anonymous identity を受け取らないためであり、より広い non-resource URL のリストを持つ `system:public-info-viewer` による authorization には、そこまで到達しません。 |
| 受け入れ基準 | • Static Pod API server が `--authentication-config` を使用し、それが `anonymous.enabled: true` と、ちょうど `/livez`、`/readyz`、`/healthz` を含む `conditions` を持つ `AuthenticationConfiguration` を参照している。<br/>• 引数 `--anonymous-auth` が存在しない。<br/>• kube-apiserver Pod が再起動後も `Running`/`Ready` のままである。<br/>• 認証なしの `GET /version` が `401` を返す。<br/>• 認証なしの `GET /livez` と `GET /readyz` が `200` を返す。<br/>• 認証された `/readyz` へのリクエスト (有効な credentials で) も動作する。<br/>• Effective な `--authorization-mode` が `Node,RBAC` を含み、`AlwaysAllow` を含まない。<br/>• ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` が削除されている。<br/>• 標準の `system:public-info-viewer` が手つかずのままである。<br/>• グループ `system:unauthenticated` が、どの namespace でも `pods`/`secrets`/`configmaps` を読み取れない。 |

<details>
<summary>💡 課題 5 のヒント</summary>

Pod オブジェクトを `kubectl edit pod` で編集しないでください - kubelet は manifest ファイルを監視しており、API 経由で行われた変更をすべて元の状態に上書きします。ノードのディスク上のファイル `/etc/kubernetes/manifests/kube-apiserver.yaml` を編集してください。保存した後は待ってください：kubelet がファイルの変更を検出するのは瞬時ではなく、static Pod の再起動中は API server が数秒間利用できなくなります - ファイルを保存した直後に `curl` が何も返さなくても、慌てないでください。

単純な `--anonymous-auth=false` はここでは**適していません**：kubeadm `release-1.36` は、kube-apiserver の static Pod を、まさに `/livez` と `/readyz` への HTTPS liveness/readiness/startup probes とともに生成し、kubelet の HTTP probes は client credentials を渡しません - anonymous access を完全に無効にすると、これらのリクエストは `401` を受け取り、kubelet はコンテナを異常と見なして kube-apiserver をループで再起動する可能性があり、この課題だけでなく、後続の課題 9 も壊れます。正しい方法は、`anonymous.enabled: true` と、anonymous access を必要な health の path のみに制限する `anonymous.conditions` を持つ `AuthenticationConfiguration` です：

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` と `--anonymous-auth` は同時に指定できません - manifest に両方の引数があると kube-apiserver は起動しません。`--anonymous-auth=true` を、値を `false` に置き換えるだけではなく、完全に削除したことを確認してください。

匿名の ClusterRoleBinding を監査するには：`kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`。少なくとも 2 つの
紐づけが見つかります - 標準の `system:public-info-viewer` (触れないでください) と、lab-owned の
`lab104-unintended-anonymous-access` (その ClusterRole
`lab104-anonymous-debug-access` とともに削除してください) です。これらは、参照している ClusterRole の名前で見分けられます：
`kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` は `system:public-info-viewer` を表示します - これは通常の resources ではなく、
non-resource URL に限定された ClusterRole です。
</details>

---
| **6** | **env 経由の Secret の `/proc/1/environ` への漏洩：volume への移行** |
| :---: | :--- |
| やること | • `security-104` の Pod `app-vulnerable` は、`envFrom.secretRef` を通じて `db-creds` を受け取っています - 値は、コンテナへ `kubectl exec` できる人 (`cat /proc/1/environ`)、または env が誤って出力されたときに logs/describe を読み取れる人なら誰でも見られます。<br/>• この漏洩を確認します：`kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` を実行し、出力 (`DB_PASSWORD` を含む) を `/var/work/tests/artifacts/6/env-leak-before.txt` に保存します。<br/>• 同じ名前 `app-vulnerable` で Pod を再作成します：この secret を使う `envFrom`/`env` を削除し、`db-creds` を volume `db-creds-vol` として `/etc/secrets` に、**read-only** かつ `defaultMode: 0400` でマウントします。<br/>• 新しい `/proc/1/environ` に変数 `DB_PASSWORD` がないことを確認し、マウントされたファイルの `stat -L -c '%a'` を `/var/work/tests/artifacts/6/secret-file-mode.txt` に保存します (フラグ `-L` は必須です - secret は `..data` のシンボリックリンクのチェーン経由でマウントされるため、`-L` がないと `stat` は実際のファイルではなくシンボリックリンク自体のモードを表示します)。 |
| 受け入れ基準 | `env-leak-before.txt` に、Secret `db-creds` の `DB_PASSWORD` の実際の値が含まれている (単なる単語 `DB_PASSWORD` ではない)；最終的な Pod `app-vulnerable` に `db-creds` を参照する `env`/`envFrom` がなく、同じ Secret を別の方法でマウントしていない；volume `db-creds-vol` が `/etc/secrets` に `readOnly: true` と `defaultMode: 0400` (10 進数では `256`) でマウントされている - checker はコンテナ内で `stat -L -c %a` を自分で確認し、ちょうど `400` を要求する；最終的な Pod の `/proc/1/environ` に `DB_PASSWORD` がない (`exec` が正常に実行された場合 - 失敗した `exec` は証拠とみなされない)；その際、アプリケーションのプロセスは、`/etc/secrets/DB_PASSWORD` から secret の値を実際に読み取ることができる (positive control)。 |

<details>
<summary>💡 課題 6 のヒント</summary>

漏洩を確認する手順の `/proc/1/environ` は、値を見る唯一の方法ではありません
(`kubectl exec ... -- env` や `echo $DB_PASSWORD` でも同じ結果が得られます。
container runtime はデフォルトで、exec されたプロセスに PID 1 と同じ環境を与えるためです)。
`/proc/1/environ` は、あなたの特定の exec-shell が継承したものに頼らず、
`/proc` を通じて PID 1 の環境を直接読み取ります - これは、自分のプロセスだけでなく
任意のプロセスの環境を見るために、security 分析で実際に使われる手法と同じです。

Volume mount は、すでに `kubectl exec` できる人からアクセスを**奪うものではありません** - 修正後の `cat
/etc/secrets/DB_PASSWORD` は、修正前に `cat
/proc/1/environ` が値を読み取っていたのと同じくらい簡単に値を読み取り、それは想定どおりです (課題の positive control が
まさにそれを確認します)。この課題は exec アクセスを塞ぐことではありません - プロセスに値を読み取る権限がある以上、
それはファイルでも変数でも不可能です。実際の違いは、明示的な `exec` なしで
機能する漏洩経路にあります：
- 環境変数は**あらゆる**子プロセスに自動的に継承されます (`fork()` は env 全体を
  コピーします) - アプリケーション内のサードパーティのライブラリ、プラグイン、偶発的な subprocess は、
  開発者が考えていなくても `DB_PASSWORD` を受け取ります；ファイルはそのようには
  渡されません - 子プロセスはパスを明示的に知り、それを開く必要があります；
- crash handler や error-logger は、クラッシュ時にプロセスの `environ` 全体を出力することがよくあります。
  それは自動的に logs に流れます；ファイルの内容は、コードが明示的にそれを読み取って
  ログに記録しない限り、それ自体では logs に入りません；
- 環境変数にはアクセス権限のモデルがありません - コンテナの namespace 内の任意のプロセスから見えます；
  `defaultMode: 0400` を持つファイルにはあります - 適切な UID を持つプロセスだけが読み取れます。

```text
[FAIL] Secret Volume の defaultMode の指定が正しくありません。
💡 defaultMode: 400 (10 進数の 400) を指定しました。
   YAML は先頭にゼロを付けた 8 進数リテラル (0400) をサポートしており、Kubernetes はそれを
   通常の Unix のパーミッションとして解釈します；先頭のゼロがない 400 は、パーミッション 0400 ではなく
   10 進数の 400 として読み取られます (パーミッション 0400 は 10 進数では 256 です)。
```

これはこの課題で最もよくある間違いです：`defaultMode` は POSIX mode bits を持つ数値フィールドで、
Kubernetes YAML は 8 進数と 10 進数の両方の表記をサポートします - 10 進数のみが許される
JSON とは異なります。`defaultMode: 400` (先頭のゼロなし) と書くと、Kubernetes はそれを
おなじみの Unix パーミッション `0400` ではなく、**10 進数**の 400 として解釈します。正しい方法は、
`defaultMode: 0400` (先頭のゼロ付き、YAML が 8 進数リテラルとして認識します) と書くか、
10 進数の同等の値 `256` を明示することです。自己確認します：
`kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
は `256` を返し、コンテナ内の `stat -L -c '%a' /etc/secrets/DB_PASSWORD` は `400` を返す必要があります。
</details>

---
| **7** | **隠れた RBAC privilege escalation 経路 (`impersonate`、`bind`、`escalate`、CSR approval) の監査と取り消し** |
| :---: | :--- |
| やること | • ClusterRole `build-agent-hidden-privesc` には wildcard `*` は含まれません (これは課題 4 ですでに排除された別の経路です) が、`security-104` の ServiceAccount `build-agent` に、実際に悪用可能な 3 つの権限昇格経路を与えています：<br/>• `users`/`groups`/`serviceaccounts` に対する `impersonate` - 攻撃者がそのようなユーザーを知っていれば、cluster-admin を含む、なりすまし。<br/>• `clusterroles` に対する `create`/`update`/`bind`/`escalate` と、`clusterrolebindings` に対する `create`/`update` - 基本的な verbs はオブジェクト自体を作成/変更することを可能にし、`bind`/`escalate` は、そうでなければ自分自身の権限より広い権限を付与/紐づけることを禁止する組み込みの RBAC チェックを回避します (基本的な `create`/`update` がなければ、`bind`/`escalate` だけでは実際の escalation には不十分です)。<br/>• `certificatesigningrequests/approval` に対する `update` + signer `kubernetes.io/kube-apiserver-client` に対する `approve` - 任意の identity の CSR を承認できること (ただし、この ClusterRole 自体は `create certificatesigningrequests` を与えません：攻撃を証明書の発行まで進めるには、identity に CSR を作成する別の権限も必要で、たとえば別の compromise されたロールや、すでに CSR を送信できる compromise された automation を通じて得られます)。<br/>• `impersonate`、`bind`、`escalate` を許可する ClusterRole を持つ**すべての** ClusterRoleBinding を見つけ (たとえば、`rules[].verbs` に対する `kubectl get clusterrole -o json \| jq` で)、`/var/work/tests/artifacts/7/dangerous-bindings-before.txt` に書き出します。<br/>• ClusterRoleBinding `build-agent-hidden-privesc` **と** ClusterRole `build-agent-hidden-privesc` を削除します (他の意図しないものが見つかればそれらも、ただし `system:*` のシステムの ClusterRoleBinding は除きます)。<br/>• 見つかったすべての権限について、`kubectl auth can-i` で取り消しを確認します：`impersonate users`、`bind clusterroles`、`escalate clusterroles`、`update certificatesigningrequests/approval`、さらに signer `kubernetes.io/kube-apiserver-client` に対する `approve` - すべて `no` を返す必要があります。 |
| 受け入れ基準 | • `dangerous-bindings-before.txt` に、見つかった ClusterRoleBinding として `build-agent-hidden-privesc` が含まれている (名前が異なる場合は ClusterRole の名前ではない)。<br/>• 修正後、ClusterRoleBinding **と** ClusterRole `build-agent-hidden-privesc` が存在しない。<br/>• `build-agent` が `impersonate`、`bind`、`escalate`、`update certificatesigningrequests/approval` できない。<br/>• `build-agent` が signer `kubernetes.io/kube-apiserver-client` に対する `approve` を実行できない。<br/>• システムの `system:*` ClusterRoleBinding に触れていない。 |

<details>
<summary>💡 課題 7 のヒント</summary>

CSR approval は `impersonate`/`bind`/`escalate` とは別のカテゴリです：これは `verbs` に対する同じ `jq` フィルターには含まれません。リソース `certificatesigningrequests/approval` に対する verb `update` の独立したルールに、特定の `signer` に対する `approve` を加えたものだからです。`impersonate`/`bind`/`escalate` だけでフィルターすると、1 つの経路は見つかりますが CSR は見落とします - 両方を別々に探し、それぞれについて、参照している ClusterRole ではなく **ClusterRoleBinding** の名前を保存してください (この実習では名前は一致していますが、一般には保証されません)。プレフィックス `system:` を持つシステムの `ClusterRoleBinding` を削除しないでください - それらは Kubernetes の core コンポーネントが正当な `impersonate` を行うために必要です (たとえば `system:kube-controller-manager`)。
</details>

---
| **8** | **Namespace レベルの baseline: automount なしの `default` ServiceAccount** |
| :---: | :--- |
| やること | • 課題 3 では、特定の Pod とその専用の ServiceAccount の内部で、個別に automount を無効にしました。ここで必要なのは、**namespace** レベルの baseline です。<br/>• namespace `security-104-baseline` を作成し、その中に自動的に作成される ServiceAccount `default` が現れるのを待ちます (ServiceAccount の作成は、namespace 自体と同時ではなく、別の controller によって非同期に行われます)。<br/>• その後で初めて、この ServiceAccount に `automountServiceAccountToken: false` を設定します：`kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`。<br/>• この namespace に、`busybox:1.36` (`sleep 3600`) の Pod `implicit-default-sa` を、`serviceAccountName` も `automountServiceAccountToken` も明示的に**指定せずに**作成します - これは暗黙的に `default` SA を使用し、その値を継承する必要があります。<br/>• 最終的な Pod の spec にフィールド `automountServiceAccountToken` が存在しない (`false` ではない) こと、token volume がないこと、そしてコンテナ内で token ファイルを読み取ろうとすると、まさにファイルが存在しないというエラーで終了することを確認します (その際 `kubectl exec` 自体は成功する必要があります)。 |
| 受け入れ基準 | • `security-104-baseline` の ServiceAccount `default` が `automountServiceAccountToken: false` を持つ。<br/>• Pod `implicit-default-sa` が `serviceAccountName: default` を使用している (暗黙的または明示的に)。<br/>• その spec にフィールド `automountServiceAccountToken` が**存在しない** (明示的に `true` にも `false` にも設定されていない)。<br/>• 自動的に追加された ServiceAccount token の `projected`/`secret` volume も、手動でマウントされたタイプ `kubernetes.io/service-account-token` の legacy `Secret` もない。<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` が成功し (exit code `0`)、任意のエラーではなく、成功した exec を通じてファイルの不在が確認される。 |

<details>
<summary>💡 課題 8 のヒント</summary>

操作の順序が重要です：namespace の `default` SA に `patch` が適用される前に Pod を作成すると、Pod は古い (デフォルトの `true`) 値に従って token を受け取ります。また、`kubectl create namespace` の直後に確認なしですぐに `default` SA にパッチを当てないでください - ServiceAccount `default` は別の controller によって作成され、namespace の作成から最初のごくわずかな間はまだ存在しない場合があります；それが現れるのを待ち (`kubectl get serviceaccount default -n security-104-baseline`)、その後でパッチを当ててください。この課題は、Pod で `serviceAccountName` をあえて指定していません - これは、開発者が単に ServiceAccount のことを忘れていたという現実の状況をモデル化しており、baseline がデフォルトで彼らを守る必要があります。Pod 自体に明示的な `automountServiceAccountToken: false` を付けると、(課題 3 のように) 個別の設定を実証するだけになります - ここでは、SA/namespace からの継承そのものを実証するために、フィールドを完全に未指定のままにする必要があります。
</details>

---
| **9** | **統合課題：audit log で RBAC escalation を検出し、封じ込める** |
| :---: | :--- |
| やること | • この課題は、RBAC (この実習) と audit ロギング ([第 32 章](../../course/32/jp.md) を参照) を組み合わせます - audit log がなければ、危険な RBAC の変更の事実は、再現可能な forensic evidence としてではなく、`kubectl get` による事後的なものとしてしか見えません。<br/>• control-plane で、最小限の audit backend を有効にします：`/etc/kubernetes/audit/policy.yaml` を作成し、`apiGroups: ["rbac.authorization.k8s.io"]`、リソース `clusterroles` と `clusterrolebindings` に対する `RequestResponse` ルールと、フォールバックとしての catch-all `Metadata` を含めます。<br/>• static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` に、`--audit-policy-file=/etc/kubernetes/audit/policy.yaml`、`--audit-log-path=/var/log/kubernetes/audit/audit.log`、および必要な hostPath volume/volumeMount を追加します (ディレクトリは事前に作成してください)。API が復旧するまで待ちます。<br/>• 管理者 (`cluster1-admin`) として、ClusterRole `cluster-admin` を `security-104` の ServiceAccount `build-agent` に紐づける ClusterRoleBinding `incident-simulated-escalation` を作成します - これは `build-agent` 自身による escalation の試み**ではなく** (課題 7 でそこから実際の権限昇格経路はすでに取り消されています)、管理者がモデル化した危険な RBAC の変更です：誰か (人間のオペレーター、スクリプト、compromise された CI/CD) が、誤って、または悪意を持って ServiceAccount に `cluster-admin` を付与するという現実のシナリオで、SOC/security エンジニアの仕事は、常時手動で `kubectl get` を行うのではなく、まさにそのようなイベントを audit log から検出することです。<br/>• audit log から、この名前の `clusterrolebindings` に対する `create` イベントで、`requestObject.roleRef` が `cluster-admin` を指し、`requestObject.subjects` に `system:serviceaccount:security-104:build-agent` があるものを見つけ、イベント全体 (`user.username` を含む - リクエストを実際に開始した人) を `/var/work/tests/artifacts/9/audit-escalation-event.json` に保存します。これは単に「audit ルールが機能していることを確認する」ことではありません - ここでの SOC エンジニアの実際の仕事は、forensic evidence として具体的なレコードを**抽出して保存する**ことです (checker は control-plane の `audit.log` を独立して自分で読み取り、あなたの成果物の `auditID` を実際のレコードと照合します - 似ていても作り上げた JSON は通りません)。<br/>• containment を実行します：`incident-simulated-escalation` を削除し、`kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent` でアクセスが取り消されたことを確認し、最終的な `no` を `/var/work/tests/artifacts/9/containment-result.txt` に保存します (`-n`/`-A` なしの `can-i` は、クラスター全体ではなく、kubeconfig コンテキストの現在の namespace のみを確認します - namespace を明示してください)。 |
| 受け入れ基準 | • kube-apiserver の static manifest に `--audit-policy-file` と `--audit-log-path` が含まれ、API server が healthy である。<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` が、`verb: create`、`objectRef.resource: clusterrolebindings`、`objectRef.name: incident-simulated-escalation`、`requestObject.roleRef.name: cluster-admin`、そして `requestObject.subjects` の中に `security-104` の ServiceAccount `build-agent` を持つ、有効な JSON の audit event である。<br/>• containment の後、ClusterRoleBinding `incident-simulated-escalation` が存在しない。<br/>• `containment-result.txt` に `no` が含まれている。 |

<details>
<summary>💡 課題 9 のヒント</summary>

`rbac.authorization.k8s.io` に対する `RequestResponse` ルールは、policy のルールのリストの先頭に置く必要があります - より具体的なルールは、一般的な `Metadata` の catch-all より前に置く必要があります。そうしないと catch-all がイベントを先に捕捉し、リクエストボディを持つ `RequestResponse` ではなく `Metadata` レベルしか得られません。policy 全体のレベルで `omitStages: [RequestReceived]` を追加してください - このステージにはまだ `requestObject`/`responseStatus` がなく、`Metadata` の catch-all はクラスターのすべてのリクエストに適用されるため、`omitStages` がないと `audit.log` はこの課題にとって何の追加の利点もなく 2 倍の速さで増えます。`incident-simulated-escalation` は、API server が新しい audit backend で再起動した後に作成してください - そうしないとイベントは単にログに入りません。この課題は、危険な RBAC の変更の検出それ自体を確認するものであり、`build-agent` がそれを行ったことを確認するものではありません - audit log では、フィールド `user.username` は実際の開始者 (管理者) を示し、`build-agent` ではありません；`build-agent` はこのイベントでは権限の受け取り手 (`requestObject.subjects`) としてのみ登場します。`audit-escalation-event.json` は、`/var/log/kubernetes/audit/audit.log` からコピーした**実際の**レコード (その `auditID` を含む) である必要があります - 複数の一致する行で手動で組み立てた JSON は、self-check が control-plane のログを自分で読み取って `auditID` を照合するため、確認を通りません。containment を忘れないでください：`ClusterRoleBinding` の削除自体は課題の半分にすぎず、残りの半分は、オブジェクトが単に読み取れなくなっただけではなく、アクセスが実際に取り消されたことを `kubectl auth can-i` で実証することです。
</details>

---
| **10** | **Secret のデコード、作成、マウント** |
| :---: | :--- |
| やること | • `security-104` には、2 つのキー `SERVICE_USER` と `SERVICE_TOKEN` を持つ Opaque Secret `legacy-config` がすでに存在します。API 経由で読み取り、両方の値を base64 からデコードします。<br/>• literal 値から (`kubectl create secret generic ... --from-literal=...`)、同じキー名と同じデコード済みの値を持つ新しい generic Secret `rehydrated-config` を作成します。<br/>• `rehydrated-config` を **read-only** の volume として `/etc/rehydrated` にマウントする、`busybox:1.36` (`sleep 3600`) の Pod `secret-workflow` を作成します。<br/>• コンテナ内で両方のファイルが実際に読み取れ、期待される値が含まれていることを確認します。 |
| 受け入れ基準 | • `rehydrated-config` が存在し、そのデコードされた `SERVICE_USER`/`SERVICE_TOKEN` が元の `legacy-config` と一致している。<br/>• Pod `secret-workflow` が、まさにこの Secret を `/etc/rehydrated` に `readOnly: true` でマウントしている。<br/>• コンテナ内の `kubectl exec` が、両方のファイルを正しい内容で読み取れる。 |

<details>
<summary>💡 課題 10 のヒント</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` で
実際の値が得られます - 新しい Secret に任意の文字列を書かないでください。checker は
元のものを自分で改めてデコードして比較します。`kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` は値を
自動的にエンコードします - `--from-literal` で作成する場合、自分で base64-encode する必要はありません。
volumeMount の `readOnly: true` を忘れないでください - マウントされていても writable な Secret は、
Pod 自体が正しく動作していても、そのフラグが原因で受け入れ基準を文字どおり通りません。
</details>

---
| **11** | **既存の Role の修復と、別の namespace の SA への紐づけ** |
| :---: | :--- |
| やること | • namespace `rbac-a` には、ServiceAccount `dev`、Role `pod-role`、RoleBinding `pod-role-binding` がすでに存在します。Role は現在 `pods` に対する `get`、`list`、`delete` を許可しています - ここでの `delete` は余分 (削除してください) で、`watch` は必要なのに欠けています (追加してください)。新しいものを作成せず、既存の Role を修正してください。<br/>• 別に、namespace `rbac-b` には ConfigMap `shared-config` がすでに存在します。`rbac-b` に、**namespace `rbac-a` の** ServiceAccount `dev` に、`rbac-b` の `configmaps` に対する `get`/`list` (のみ) のアクセスを与える、新しい Role と RoleBinding を作成します。<br/>• `rbac-a` に、`serviceAccountName: dev` を持つ Pod を作成します。 |
| 受け入れ基準 | • `rbac-a` の Role `pod-role` が、`pods` に対する `get`、`list`、`watch` のみをちょうど許可している。<br/>• `dev` が `rbac-a` で `delete pods` できない。<br/>• `dev` が `rbac-b` で `get`/`list configmaps` できるが、`delete configmaps` はできず、同じ場所の `secrets` を読み取れない。<br/>• `rbac-a` に、ServiceAccount `dev` を使用する Pod が存在する。 |

<details>
<summary>💡 課題 11 のヒント</summary>

`RoleBinding` は、他の任意の namespace の subject (`ServiceAccount`) を参照できます -
Kubernetes は `subjects[].namespace` を通じてこれを公式にサポートしています。しかし、`RoleBinding` 自体と、
それに関連する権限は、常に、それ自身が作成された namespace でのみ有効です - そのため、
新しい Role+RoleBinding は `rbac-a` ではなく `rbac-b` の中に作成する必要があります。自己確認します：
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` は
`yes` を返し、`kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` は
`no` を返す必要があります。
</details>

---
| **12** | **CSR + namespaced RBAC による Client certificate ユーザー** |
| :---: | :--- |
| やること | • クライアント証明書で認証される新しい Kubernetes ユーザー `john` を作成します：private key を生成し、次に `CN=john` の CSR (`openssl req -new`) を生成します。<br/>• それを Kubernetes `CertificateSigningRequest` `john-csr` として、`signerName: kubernetes.io/kube-apiserver-client` で送信します；CSR を承認します (`kubectl certificate approve`)。<br/>• `status.certificate` から発行された証明書を取り出し (base64-decode)、private key とともに `/var/work/tests/artifacts/12/john.crt` と `.../john.key` に保存します。<br/>• namespace `development` (すでに作成済み) に、`pods` に対する `create`/`list`/`get` を許可する Role と、subject `{kind: User, name: john}` への RoleBinding を作成します。<br/>• John 用の別の kubeconfig を組み立て (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`)、`/var/work/tests/artifacts/12/john.kubeconfig` として保存します；`kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` が実際に動作し、同じリクエストを別の namespace に対して行うと `Forbidden` を受け取ることを確認します - これは、直接の TLS リクエストと同様に動作する証明書であることを、`curl` ではなくおなじみの `kubectl` を通じて実証します。<br/>• 実際の `kubectl auth can-i --as=john` チェックで確認します：John は `development` で pods を `create`/`list`/`get` できるが、同じ場所で `delete` はできず、別の namespace では同じ権限を持たない。 |
| 受け入れ基準 | • `john-csr` が正しい signer を使用し、`Approved` である。<br/>• 発行された証明書が `CN=john` を持ち、このクラスターの CA に対して実際に検証される。<br/>• `development` の Role+RoleBinding が、John に `pods` に対する `create`/`list`/`get` のみをちょうど与えている。<br/>• John が同じ場所で pods を `delete` できず、他の namespace へのアクセスを持たない。<br/>• 保存された `john.crt`/`john.key` が、直接の TLS リクエストで API server に実際に受け入れられる (`--as=john` の impersonation だけではない)。<br/>• 組み立てた kubeconfig がパス `/var/work/tests/artifacts/12/john.kubeconfig` に存在し、`kubectl --kubeconfig=<このファイル> get pods -n development` が実際に動作し、同じリクエストを別の namespace に対して行うと `Forbidden` で終了する。 |

<details>
<summary>💡 課題 12 のヒント</summary>

この課題を Lab 114 と混同しないでください：あちらでは kubeconfig の中にすでに存在する証明書を分析しますが、
ここでは、完全に新しい、実際に機能する identity をゼロから発行する必要があります。
証明書ベースのユーザーの RBAC は、`ServiceAccount` ではなく `subjects: [{kind: User, name:
john}]` を通じて紐づけます - Kubernetes の `User` には独立した API オブジェクトがなく、その
「存在」は、クライアント証明書の CN が binding の
`name` と一致しているかどうかで完全に決まります。`kubectl auth can-i` の `--as=john` は RBAC のロジック
(impersonation) のみを確認し、証明書が実際に有効であることは実証しません - 別途、
control-plane の `/etc/kubernetes/pki/ca.crt` に対する `openssl verify` が `OK` を返すことを確認してください。
</details>

## 結果のチェック

作業マシンで次を実行します：

```bash
check_result
```

チェックには Init と 12 個の独立した課題が含まれます。API server を変更した後、
一部のテストは static Pod の再起動を短時間待つことがあります。

## 解答

参考解答：[worker/files/solutions/1_JP.MD](worker/files/solutions/1_JP.MD)

## 削除

```bash
TASK=104 make delete_cks_task
```
