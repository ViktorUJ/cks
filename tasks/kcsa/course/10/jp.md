[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md)

# 第10章. 認証と認可

> **この先。** 第07-09章では、クラスターコンポーネント、ワーカーノード、`Pod`、ネットワーク境界を保護しました。ここからは Kubernetes API へのリクエスト経路を扱います。まずクラスターがアイデンティティを確立し、次にその操作を許可するかを決定します。これは比重22%の KCSA ドメイン **Kubernetes Security Fundamentals** です。

## 10.1 API にアクセスするのは誰か: ユーザーと `ServiceAccount`

Kubernetes API へのすべてのリクエストは認証、すなわち authentication を通過します。その役割は「これは誰か」という問いに答えることです。認証に成功すると、API Server はユーザー名とグループを次の段階である認可に渡します。

エンジニアやクラスター外部の CI システムなどの通常のユーザーは、Kubernetes の `User` オブジェクトではありません。Kubernetes は設定済みの認証メカニズムからそのアイデンティティを取得します。`ServiceAccount` は、主に `Pod` 内のプロセスのための Kubernetes API オブジェクトです。その完全名には namespace が含まれます: `system:serviceaccount:shop:catalog`。

| 方法 | 使用する場面 | 重要な制約 |
|---|---|---|
| TLS クライアント証明書 | 管理者、クラスターコンポーネント、または自動化 | 秘密鍵と証明書の有効期限を保護する必要がある。 |
| Bearer token | 自動化または統合 | トークンは保有者の権限を委譲するため、コードやログに含めてはならない。 |
| `ServiceAccount` トークン | `Pod` 内のプロセスが API にアクセスする | 権限はトークンを持つ事実ではなく、RBAC によって決まる。 |
| OIDC | 企業 SSO などの外部アイデンティティプロバイダー | API Server は issuer を信頼し、トークンの claims を検証する必要がある。 |
| Authentication webhook | 外部サービスがクライアントの credential を確認する | これは authentication integration であり、admission webhook や authorizer ではない。 |
| Bootstrap token | ノードの初期参加用に用途が限定された token | bootstrap/TLS bootstrap 用であり、長期的な application identity として使わない。 |

匿名認証が有効な場合の匿名リクエストは、ユーザー `system:anonymous` およびグループ `system:unauthenticated` になります。これは通常の API アクセスに便利なモードではありません。保護された構成では匿名アクセスを無効にするか、意図的に公開した安全なエンドポイントだけを許可します。

認証そのものはアクセスを付与しません。証明書、トークン、OIDC アイデンティティは主体を特定するだけです。その主体が何を実行できるかは認可が決定します。

## 10.2 `ServiceAccount` トークンと `default` アカウントのリスク

各 `Namespace` には `default` という名前の `ServiceAccount` があります。`Pod` の仕様で `serviceAccountName` を指定しない場合、Kubernetes はこれを割り当てます。これは `default` が自動的に広範な権限を持つことを意味しません。利便性のために `RoleBinding` または `ClusterRoleBinding` が付与されたときにリスクが生じます。

v1.36 を含む現代の Kubernetes では、通常 TokenRequest メカニズムを通じて投影された bound token が `Pod` に発行されます。このトークンは `ServiceAccount` と特定の `Pod` に結び付けられ、有効期間が限られ、kubelet によって自動更新されます。正当な理由なしに `ServiceAccount` トークンを含む長期的な Secret を作成すべきではありません。

アプリケーションに Kubernetes API が不要なら、トークンも不要です。`Pod` または `ServiceAccount` 自体でそのマウントを無効にします:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

コンテナが侵害されると、マウント済みトークンは読み取られ、有効である間はクラスター外部から利用される可能性があります。そのため各 `Pod` には最小権限の個別 `ServiceAccount` を選び、`default` をアプリケーション共通のアカウントとして使用しません。automount を無効にしても RBAC は取り消されませんが、API が不要な Pod のファイルシステムからシークレットを除去できます。

## 10.3 認可: RBAC とその他の authorizer

認可は「すでに認証された主体がこの操作を実行できるか」という問いに答えます。API Server は、ユーザーまたはグループ、`verb`、リソース、namespace、場合によってはオブジェクト名と API パスの組み合わせを評価します。

Kubernetes では複数の authorizer を有効にできます。設定された順序で確認され、最初に `Allow` または `Deny` を返したものが即座に決定を終了します。すべてが `NoOpinion` を返した場合だけ、リクエストはデフォルトで拒否されます。ほとんどのクラスターで基本かつ推奨されるメカニズムは RBAC です。

| メカニズム | 目的 | 実務上の意味 |
|---|---|---|
| RBAC | `Role`、`ClusterRole`、およびバインディングのルール | 管理可能で監査可能なアクセスにおける通常の選択。 |
| Node | ノードの代理として kubelet が行う操作を制限する | ノードアイデンティティに使用し、ユーザー RBAC の代替ではない。 |
| Webhook | 外部の認可サービスに問い合わせる | 決定が外部システムに依存する場合に適する。 |
| ABAC | リクエストを静的ポリシーファイルと照合する | 新規プロジェクトには古く、監査と保守が困難なアプローチ。 |

RBAC を authentication と混同しないでください。`RoleBinding` はアイデンティティを確認したりトークンを作成したりしません。すでに判明している主体を権限セットに関連付けるものです。同様に、`NetworkPolicy` はネットワーク接続を制限しますが、リソースに対する権限の API Server による決定を置き換えません。

### Node authorizer と `NodeRestriction`: 隣接するが異なるレイヤー

**Node authorizer** は、グループ `system:nodes` に属する kubelet/node identity `system:node:<nodeName>` 用の特別な authorizer です。必要な `Secret`、`ConfigMap`、ボリューム情報を含め、kubelet が自ノードとそこに割り当てられた `Pod` に対して実行できる API 操作を制限します。これは **authorization** です。

**`NodeRestriction`** は validating admission plugin です。さらに、kubelet が変更できる `Node` オブジェクトと関連する `Pod` を制限します。正しく識別された kubelet でも、他の Node/Pod を変更したり保護された labels を勝手に設定したりしてはなりません。これは authorizer ではなく **admission** です。

> **混同しないこと。** Node authorizer は「node identity にこの API 操作が許可されているか」を回答します。`NodeRestriction` は「認可後であっても、このオブジェクト変更は許容されるか」を回答します。どちらのメカニズムも kubelet の least privilege に重要ですが、ユーザーの RBAC、TLS、ノード保護を置き換えるものではありません。

## 10.4 RBAC: ロール、バインディング、最小権限

`Role` は一つの `Namespace` 内だけのルールを記述します。`ClusterRole` はクラスター全体のスコープのルールを記述するか、`RoleBinding` を介して一つの namespace にバインドできます。`RoleBinding` はその namespace 内で有効であり、`ClusterRoleBinding` はクラスター全体で有効です。

RBAC の権限は加算的です。複数のバインディングは合算され、個別の「拒否」ルールはありません。したがって最小権限の原則は、必要な `apiGroups`、`resources`、`verbs` だけを付与し、最小のスコープを選ぶことを意味します。

以下の `Role` は、namespace `shop` 内でアプリケーションが一つの `ConfigMap` だけを読み取ることを許可します。これは狭いルールの例であり、すべてのタスク向けのテンプレートではありません。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

期待する権限は `kubectl auth can-i` コマンドで確認できます。例えば、管理者は特定のアカウントに対する操作を確認できます:

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

このコマンドは確認に役立ちますが、マニフェストと実際のバインディングのレビューに代わるものではありません。`secrets` に対する `get`、`list`、`watch` の権限、およびワークロードに対する `create`、`update`、`patch`、`delete` には特別な注意が必要です。RBAC リソース、`bind`、`escalate`、`impersonate` へのアクセスは、追加の権限を付与または利用できるようにする可能性があります。`cluster-admin`、`verbs: ["*"]`、`resources: ["*"]` は安全な出発点ではありません。

これらの特別な authorization checks は異なる課題を解決します:

- `bind` は `RoleBinding` / `ClusterRoleBinding` の作成または変更に関係します。通常 caller は、バインドされる `Role`/`ClusterRole` に含まれる permissions を、該当スコープで既に持っている必要があります。特定のロールへの明示的な `bind` 権限により、それらすべての permissions を自身が持たなくても binding を実行できます。

- `escalate` は binding ではなく、`Role` / `ClusterRole` の作成または変更に関係します。通常 caller は、自身が持たない permissions をロールに書き込めません。明示的な `escalate` 権限はこの保護の例外です。

- classic `impersonate` は、指定の user/group/ServiceAccount、または他のサポート対象 identity attribute としてリクエストを送信することを許可します。これは独立した能力であり、`bind` や `escalate` と混同してはいけません。

Kubernetes v1.36 では、デフォルトで有効な beta メカニズム `ConstrainedImpersonation` も利用できます。これはより狭い `impersonate:*` および `impersonate-on:*` 系の verbs を追加し、identity だけでなくその名前で実行される操作も制限します。classic `impersonate` を持つ既存の RBAC rules は引き続き動作します。API Server は constrained checks を使用し、必要に応じて classic `impersonate` に fallback できます。

`pods` に対する `create` 権限には特別な注意が必要です。対象データに直接アクセスできない主体であっても、`Pod` を作成できること自体が、その主体の影響力を高める一段階になり得ます。推論の連鎖は次のとおりです: 主体に `Pod` 作成権限がある → 新しい `Pod` は、個別の明示的な禁止が設定されていなければ namespace 内で利用可能な任意の `ServiceAccount` を `serviceAccountName` として指定できる → 選択した `ServiceAccount`、またはマウントされた `Secret`/`ConfigMap`/ボリュームを通じて、この `Pod` は元の主体が直接は持っていなかったデータまたは API 権限にアクセスできる可能性がある。最終的な範囲は、namespace 内で実際に利用可能な `ServiceAccount` とボリューム、および個別の制限 controls（例: `automountServiceAccountToken: false`、PSA/PSS、既存 `ServiceAccount` 向けの制限された RBAC バインディング）に依存します。ワークロード作成権限を、クラスター内の任意の `Secret` または任意の `ServiceAccount` への無条件の経路と解釈してはいけません。影響可能性は namespace の残りの構成が許す範囲に正確に拡大するだけです。

## 10.5 実務での適用方法

プラットフォームチームは、人間と機械のアイデンティティを分離します。従業員は企業 OIDC でログインし、自動化には個別の認証情報を与え、各 `Namespace` のコンポーネントは個別の `ServiceAccount` を使用します。

Kubernetes API を呼び出さないアプリケーション HTTP サービスには、`automountServiceAccountToken: false` を設定します。API を必要とするコントローラーには、個別の `ServiceAccount` と、特定のリソースおよび verb を持つ `Role` を与えます。変更をリリースする前に `kubectl auth can-i` を確認し、その後 `RoleBinding` と `ClusterRoleBinding` のレビューを行います。

`default` へのバインディングと広範な `ClusterRoleBinding` を定期的に探します。従業員の退職、トークンの漏洩、証明書キーの喪失が発生した場合は、認証情報を取り消すか置き換え、関連する権限を見直します。こうして一つのトークンの漏洩がクラスター全体への恒久的なアクセスになることを防ぎます。

## 10.6 Exam vocabulary / ミニ用語集

| 用語 | 意味 |
|---|---|
| authentication | API にリクエストを送る送信者のアイデンティティを確立すること。 |
| authorization | そのアイデンティティに特定の操作が許可されるかの決定。 |
| `ServiceAccount` | 通常 `Pod` で実行されるプロセスの Kubernetes アイデンティティ。 |
| bearer token | 提示者が関連する権限を取得するトークン。 |
| OIDC | Kubernetes を外部アイデンティティプロバイダーに接続するプロトコル。 |
| RBAC | ロールとロールバインディングを介したアクセス制御。 |
| `Role` / `ClusterRole` | 一つの namespace / クラスター全体のスコープにおけるルールセット。 |
| `RoleBinding` / `ClusterRoleBinding` | ユーザー、グループ、または `ServiceAccount` へのロールのバインディング。 |
| `bind` | バインドするロールのすべての permissions を自ら持たなくても Role/ClusterRole をバインドできる、特別な RBAC 権限。 |
| `escalate` | caller 自身の permissions を超える permissions で Role/ClusterRole を作成・変更できる、特別な RBAC 権限。 |
| `impersonate` | 別の identity を impersonation する classic Kubernetes permission。v1.36 ではより狭い verbs を持つ beta ConstrainedImpersonation も存在する。 |

## 10.7 Exam Essentials / 章の要点

- 通常のユーザーは外部メカニズムで認証され、`ServiceAccount` は `Pod` 内プロセスのための Kubernetes オブジェクトです。
- クライアント証明書、bearer tokens、`ServiceAccount` トークン、OIDC はアイデンティティを確立しますが、認可なしに権限を付与することはありません。
- `default` は自動的に広範な権限を持つわけではありませんが、これにバインディングを付与すると、暗黙に使用するすべての Pod がその権限を持つ可能性があります。
- アプリケーションに不要な `ServiceAccount` トークンは、`automountServiceAccountToken: false` でマウントしません。
- RBAC は基本的な authorizer です。`Role` と `RoleBinding` は通常、クラスター全体の代替手段よりアクセススコープを縮小します。
- 権限は合算されるため、危険な verb と広範な wildcard ルールは侵害時の影響を増大させます。

## 10.8 混同しやすい点と試験での出題

MCQ（multiple choice question、選択問題）では通常、authentication と authorization を区別し、最も狭い安全なアクセスを選ぶ必要があります。よくある落とし穴:

- `ServiceAccount` またはトークン自体が権限を付与すると考えること。権限を決めるのは RBAC バインディングです。
- `RoleBinding` と `ClusterRoleBinding` を混同すること。前者は自身の namespace に限定されます。
- `default` を無条件に危険とみなすこと。リスクは付与された権限とトークンのマウントに依存します。
- OIDC を認可の方式とみなすこと。OIDC は外部アイデンティティを確認し、アクセス決定は authorizer が行います。
- リソースと verb が正確に限定された個別ロールではなく、`cluster-admin` または wildcard を選ぶこと。

まず、質問が何に関するものかを見極めます。誰がリクエストを行うのか、どの方法でアイデンティティが確立されたのか、またはどの操作が許可されるのかです。次にスコープを確認します。一つの namespace か、クラスター全体かです。

## 10.9 自己確認問題

### 1. `ServiceAccount` について正しい説明はどれですか?

   - a. 自身の namespace で自動的に `cluster-admin` を取得する。

   - b. これは `Pod` 内プロセスのための Kubernetes アイデンティティであり、その権限は RBAC バインディングで決まる。

   - c. ネットワークアクセスに対して `NetworkPolicy` を置き換える。

   - d. 常に OIDC で認証される外部ユーザーである。

<details>
<summary>回答と解説</summary>

**正解: b.** `ServiceAccount` は通常 Pod 内のプロセスに使用され、その能力はロールとバインディングによって決まります。OIDC、`cluster-admin`、ネットワークルールは、`ServiceAccount` を作成しただけでは得られません。

</details>

### 2. Kubernetes API を必要としない `Pod` のリスクを低減するのはどれですか?

   - a. API Server の匿名認証を有効にする。

   - b. `ClusterRole` に `verbs: ["*"]` を追加する。

   - c. `cluster-admin` を持つ `default` `ServiceAccount` を割り当てる。

   - d. `automountServiceAccountToken: false` を設定する。

<details>
<summary>回答と解説</summary>

**正解: d.** これにより Kubernetes は `ServiceAccount` トークンを Pod にマウントしません。他の選択肢はアクセスを拡張するか、不要な攻撃対象領域を作ります。

</details>

### 3. 一つの `Namespace` に限定された権限を定義するオブジェクトはどれですか?

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>回答と解説</summary>

**正解: a.** `Role` は namespace に限定されたルール（どのリソースにどの verbs を許可するか）を定義しますが、それ自体で主体に権限を付与することはありません。実際に権限を付与するには、同じ namespace 内で `Role` を特定の subjects に関連付ける `RoleBinding` を使用します。

</details>

### 4. ユーザーおよび `ServiceAccount` の権限管理における Kubernetes の基本的な選択肢はどれですか?

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>回答と解説</summary>

**正解: c.** RBAC はロールとバインディングを通じて監査可能なアクセスルールを定義します。OIDC は認証に関するものであり、Node authorizer はノードアイデンティティを扱い、ABAC は静的ポリシーに基づきます。

</details>

### 5. `secrets` に対する `get` 権限に特別な注意が必要なのはなぜですか?

   - a. Kubernetes または外部システムへのアクセスを後に可能にする credentials、キー、トークンを公開する可能性がある。
   - b. Secret の metadata だけを返すため、API クライアントが保存された値を取得できることはない。
   - c. RBAC に対応する権限がなくても、主体に `Pod` 作成権限を自動的に付与する。
   - d. 読み取りのたびに API Server に Secret の再暗号化を強制するため、クライアントの権限を増やす。

<details>
<summary>回答と解説</summary>

**正解: a.** `Secret` には他のリソースへのアクセスを開くデータが含まれることがよくあります。そのため `get`、特により広範な `list/watch` は least privilege に従って付与する必要があります。Secret を読んでも、他の RBAC 権限が自動的に作成されることはありません。

</details>

> **この先。** 第10章 CKS で RBAC とアクセスの最小化、第11章 CKS で ServiceAccounts とトークン、第12章 CKS で Kubernetes API へのアクセス制限に関する実践的なスキルを深めてください。ロールの基本構文は第38章 CKA: RBAC にもあり、`ServiceAccount` と admission の連鎖は第21章 CKA にあります。KCSA では、Pod Security Standards と Pod Security Admission を扱う[第11章](../11/jp.md)へ進みます。

[目次](../README_JP.md) · [第09章](../09/jp.md) · [第11章](../11/jp.md)
