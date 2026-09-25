[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md)

# KCSA コース用語集

英語の用語は、KCSA の設問と選択肢を読むために必要なため原文のまま残しています。説明は意味を日本語で示しますが、英語の MCQ（multiple choice question、選択式問題）の用語学習に代わるものではありません。

| 用語 | 説明 | よくある混同 | 章 |
|---|---|---|---|
| `4C model` | cloud native の防御を分析するための Cloud、Cluster、Container、Code の階層モデル。 | クラウドインフラだけに限定されない。 | [03](03/jp.md) |
| `ABAC` | リクエストと主体の属性に基づく認可。 | ロールを使う RBAC ではない。 | [10](10/jp.md) |
| `Access control` | ルールと identity によりリソースへのアクセスを制限すること。 | authentication だけより広い概念。 | [10](10/jp.md) |
| `admission` | authentication と authorization の後に API リクエストを検証または変更する段階。 | 文脈で用語を確認し、近い概念で置き換えない。 | [07](07/jp.md) |
| `Admission control` | authentication と authorization の後にオブジェクトを許可または変更する API 段階。 | identity を確認したり権限を与えたりするものではない。 | [11](11/jp.md), [17](17/jp.md) |
| `Admission policy` | admission 時にオブジェクトを検証する宣言的ルール。 | audit policy と同じではない。 | [17](17/jp.md) |
| `Admission webhook` | mutating または validating admission に参加する外部 webhook。 | アプリケーションのネットワーク webhook ではない。 | [17](17/jp.md) |
| `Alert` | ルールにより注意または対応を要することを示すシグナル。 | 元となるログやメトリクスの代わりにはならない。 | [18](18/jp.md) |
| `Allowlist` | 許可する送信元、操作、またはオブジェクトの明示的な一覧。 | deny ルールがないことと同じではない。 | [09](09/jp.md), [17](17/jp.md) |
| `Anomaly detection` | 想定される挙動からの逸脱を検出すること。 | 異常だけでは攻撃の証明にならない。 | [18](18/jp.md) |
| `API server` | Kubernetes API リクエストを受け取り、状態へのアクセスを調整するコンポーネント。 | etcd の代わりに状態を保存するものではない。 | [07](07/jp.md) |
| `Artifact` | image、パッケージ、SBOM などの開発またはビルドの成果物。 | 必ずしも container image ではない。 | [06](06/jp.md), [17](17/jp.md) |
| `Attack surface` | システムを攻撃できる入口の総体。 | 見つかった単一の脆弱性ではない。 | [02](02/jp.md), [16](16/jp.md) |
| `Attack vector` | 攻撃を実行する具体的な経路または手法。 | attack surface より狭い。 | [15](15/jp.md), [16](16/jp.md) |
| `audit` | リクエストを拒否せず、違反を監査に記録する PSA モード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `Audit backend` | API Server の audit イベントを保存または送信する設定済みの場所。 | API Server がイベントを作成し、backend が保存または受信する。 | [14](14/jp.md) |
| `audit event` | Kubernetes API リクエストの処理に関する `kube-apiserver` の記録。 | 文脈で用語を確認し、近い概念で置き換えない。 | [14](14/jp.md) |
| `audit level` | `Metadata` や `RequestResponse` など、Kubernetes audit イベントの詳細度。 | 文脈で用語を確認し、近い概念で置き換えない。 | [20](20/jp.md) |
| `Audit logging` | Kubernetes API へのリクエストイベントを記録すること。 | プロセスの runtime detection の代わりにはならない。 | [14](14/jp.md) |
| `Audit policy` | 記録する API イベントとその詳細度を定義する設定。 | admission policy ではない。 | [14](14/jp.md) |
| `auditID` | 同一リクエストの異なる段階のイベントを結び付ける識別子。 | 文脈で用語を確認し、近い概念で置き換えない。 | [14](14/jp.md) |
| `Authentication` | リクエストを行った者を確立すること。 | 操作が許可されるかには答えない。 | [10](10/jp.md) |
| `Authorization` | 既知の主体が操作を実行できるかを確認すること。 | identity を確立するものではない。 | [10](10/jp.md) |
| `Authorization mode` | API 権限の決定に使う設定済みメカニズム。 | authentication の方法とは異なる。 | [10](10/jp.md) |
| `Availability` | 権限を持つ利用者がデータまたはサービスを利用できる性質。 | confidentiality や integrity と同じではない。 | [02](02/jp.md), [16](16/jp.md) |
| `Backup` | 消失または破損後に復元するためのデータのコピー。 | backup も元のデータと同様に保護する必要がある。 | [07](07/jp.md), [12](12/jp.md) |
| `Base64` | バイト列をテキストとして表現する可逆的なエンコード。 | encryption ではない。 | [12](12/jp.md) |
| `baseline` | 一般的な権限昇格経路をブロックするプロファイル。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `Baseline profile` | 互換性を保ちながら既知の危険な設定をブロックする PSS レベル。 | 最も厳しい restricted profile と同じではない。 | [11](11/jp.md) |
| `Bearer token` | 提示した者にその token の権限を与える token。 | コード内に安全に置けるパスワードではない。 | [10](10/jp.md) |
| `bind` | 呼び出し元が対象ロールのすべての permissions を持たなくても Role/ClusterRole をバインドできる特別な RBAC 権限。 | 文脈で用語を確認し、近い概念で置き換えない。 | [10](10/jp.md) |
| `blast radius` | 1 つのコンポーネントが侵害された場合の影響範囲。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `Bound ServiceAccount token` | ServiceAccount と Pod に紐付く短命の token。 | 旧来の長寿命な Secret token とは異なる。 | [10](10/jp.md) |
| `Build provenance` | artifact のビルドに関するデータを含む provenance。 | signature や SBOM と同じではない。 | [17](17/jp.md), [19](19/jp.md) |
| `CA` | 証明書の発行または検証で信頼される認証局。 | private key ではない。 | [18](18/jp.md) |
| `capability` | UID 0 とは独立して付与または取り消しできる個別の Linux 権限。 | 文脈で用語を確認し、近い概念で置き換えない。 | [09](09/jp.md) |
| `CEL` | Common Expression Language。任意コードを実行せず条件とルールに使える Kubernetes API 組み込みの式言語。 | 任意コードのための汎用言語ではない。 | [17](17/jp.md) |
| `Certificate` | 信頼された CA が署名した、公開鍵と identity を含む文書。 | private key は含まない。 | [18](18/jp.md) |
| `Certificate authority` | PKI で信頼される主体としての CA の正式名称。 | 任意の TLS 証明書ではない。 | [18](18/jp.md) |
| `CIA triad` | confidentiality、integrity、availability という 3 つのセキュリティ目標。 | 脅威モデルや control ではない。 | [02](02/jp.md), [15](15/jp.md) |
| `Cilium` | NetworkPolicy を適用できる CNI とネットワークツール群。 | NetworkPolicy API リソース自体ではない。 | [13](13/jp.md) |
| `CIS Kubernetes Benchmark` | Kubernetes のセキュアな設定に関する推奨事項の集合。 | 推奨事項の framework であり、完成した control ではない。 | [05](05/jp.md), [19](19/jp.md) |
| `CKS` | Certified Kubernetes Security Specialist。Kubernetes セキュリティの実践的な performance-based 認定資格。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `Cloud` | 4C model の外部層。インフラ、IAM、プロバイダーサービス。 | Kubernetes cluster と同義ではない。 | [03](03/jp.md), [04](04/jp.md) |
| `Cloud IAM` | クラウドリソースに対する identity と権限の管理。 | Kubernetes RBAC の代わりにはならない。 | [04](04/jp.md) |
| `Cluster-admin` | クラスターの全リソースに無制限の権限を持つ組み込み ClusterRole。 | 日常的な identity として使うべきではない。 | [10](10/jp.md), [16](16/jp.md) |
| `ClusterRole` | namespace の境界がない、クラスターリソースまたは全 namespace 用の許可済み API 操作の集合。 | 1 つの namespace に限定される Role とは異なる。 | [10](10/jp.md) |
| `ClusterRoleBinding` | クラスター全体で subject を ClusterRole に結び付けるもの。 | 1 つの namespace だけで有効な RoleBinding とは異なる。 | [10](10/jp.md) |
| `CNI` | コンテナを Kubernetes ネットワークへ接続するための標準と plugin。 | 文脈で用語を確認し、近い概念で置き換えない。 | [09](09/jp.md), [13](13/jp.md) |
| `Code` | ソースコード、依存関係、開発プラクティスからなる 4C の層。 | すでにビルドされた image と同じではない。 | [03](03/jp.md), [06](06/jp.md) |
| `Compliance` | 証明可能な evidence を伴う、適用される要求事項への適合。 | すべてのリスクがないことを保証しない。 | [19](19/jp.md) |
| `Confidentiality` | 許可されていない主体へのデータ開示から保護すること。 | integrity や availability と同じではない。 | [02](02/jp.md), [12](12/jp.md) |
| `Container` | image と runtime 制限を持つ隔離されたプロセス。 | 複数の container を含められる Pod と同じではない。 | [03](03/jp.md), [09](09/jp.md) |
| `container escape` | コンテナの隔離から worker node のリソースへプロセスが脱出すること。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `Container image` | コンテナの実行に使う不変のファイルと metadata のテンプレート。 | 実行中の container と同じではない。 | [06](06/jp.md), [17](17/jp.md) |
| `Container registry` | container images を保存・配布するサービス。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `Container runtime` | CRI を介して node 上でコンテナを起動するソフトウェア層。 | kubelet とは異なる。 | [08](08/jp.md) |
| `context` | `kubectl` が使用する cluster、user、namespace の選択。 | 文脈で用語を確認し、近い概念で置き換えない。 | [09](09/jp.md) |
| `Control` | リスクの可能性または影響を軽減する具体的な対策。 | 対策を構造化する framework と同じではない。 | [05](05/jp.md), [19](19/jp.md) |
| `Control plane` | Kubernetes の状態を管理するコンポーネントの論理的な集合。 | worker node と同じではない。 | [07](07/jp.md) |
| `Controller Manager` | 状態を望ましい状態へ近づける controller を実行するコンポーネント。 | Pod の node を選択するものではない。 | [07](07/jp.md) |
| `CRI` | kubelet と container runtime 間の Kubernetes インターフェース。 | CNI や CSI ではない。 | [08](08/jp.md) |
| `CronJob` | スケジュールに従って Job を作成する Kubernetes リソース。 | 本来の用途だけでなく、攻撃者がクラスター内に永続化するために使用できる。 | [16](16/jp.md) |
| `CVE` | 公開済みの既知の脆弱性の識別子。 | CVE は悪用が証明されたことを意味しない。 | [06](06/jp.md), [16](16/jp.md) |
| `Data flow` | システム参加者間でデータが移動する経路。 | trust boundary と同じではないが、それを横断する。 | [15](15/jp.md) |
| `Default deny` | 明示的に許可されていないトラフィックを初期状態で拒否する policy。 | すべての API アクセスを拒否することとは異なる。 | [13](13/jp.md) |
| `default-deny` | 明示的な policy が許可するまで、選択した方向のトラフィックを拒否するアプローチ。 | 文脈で用語を確認し、近い概念で置き換えない。 | [13](13/jp.md) |
| `Defense in depth` | 独立した複数の防御層を組み合わせること。 | 同一の control を重複させることではない。 | [02](02/jp.md), [05](05/jp.md) |
| `Denial of Service` | リソース枯渇または過負荷による availability の侵害。 | 単なるシステムの低速化とは異なる。 | [16](16/jp.md) |
| `Deployment` | ReplicaSet と Pod の更新を管理する Kubernetes リソース。 | 単独のセキュリティ境界ではない。 | [02](02/jp.md), [09](09/jp.md) |
| `Detection` | すでに観測されたイベントまたは逸脱を検出すること。 | 作成前のオブジェクトを防止するものではない。 | [14](14/jp.md), [18](18/jp.md) |
| `Digest` | artifact の特定の内容を示す暗号学的識別子。 | 作成者、安全性、由来を証明するものではない。 | [06](06/jp.md), [17](17/jp.md) |
| `distractor` | もっともらしいが誤った回答選択肢。 | 文脈で用語を確認し、近い概念で置き換えない。 | [20](20/jp.md) |
| `Distroless` | 通常の shell と package manager を持たない最小限の runtime image。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `DNS` | Service と外部アドレスの名前解決サービス。 | network segmentation のメカニズムではない。 | [09](09/jp.md) |
| `DoS` | リソース枯渇または過負荷によるサービス拒否。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `Egress` | 選択した Pod から出ていくネットワークトラフィック。 | Pod への ingress トラフィックとは異なる。 | [13](13/jp.md), [18](18/jp.md) |
| `Encryption` | キーを用いるデータの暗号学的保護。 | 可逆的な encoding と同じではない。 | [04](04/jp.md), [12](12/jp.md) |
| `Encryption at rest` | たとえば etcd 内の保存済みデータを暗号化すること。 | 権限を持つ主体による API 読み取りは保護しない。 | [07](07/jp.md), [12](12/jp.md) |
| `Encryption in transit` | ネットワーク上の転送中データを暗号化すること。 | authorization や segmentation の代わりにはならない。 | [04](04/jp.md), [18](18/jp.md) |
| `EncryptionConfiguration` | etcd 内の API リソースを暗号化する API Server の設定。 | RBAC policy ではない。 | [12](12/jp.md) |
| `Endpoint` | Service またはコンポーネントへのネットワークアクセスのアドレスまたは地点。 | すべての文脈で Kubernetes EndpointSlice と同じではない。 | [04](04/jp.md), [09](09/jp.md) |
| `enforce` | ルール違反の `Pod` を拒否する PSA モード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `envelope encryption` | データキーでデータを暗号化し、そのキーを KMS キーで保護するアプローチ。 | 文脈で用語を確認し、近い概念で置き換えない。 | [12](12/jp.md) |
| `escalate` | 呼び出し元自身の permissions を超える Role/ClusterRole を作成・変更する特別な RBAC 権限。 | 文脈で用語を確認し、近い概念で置き換えない。 | [10](10/jp.md) |
| `Etcd` | Kubernetes control plane の状態ストア。 | API Server ではない。 | [07](07/jp.md), [12](12/jp.md) |
| `Evidence` | control またはプロセスが機能していることの検証可能な証拠。 | compliance 要求そのものではない。 | [14](14/jp.md), [19](19/jp.md) |
| `Exploit` | 脆弱性を利用するコードまたは技法。 | すべての vulnerability に既知の exploit があるわけではない。 | [16](16/jp.md) |
| `External Secrets Operator` | 外部ストアから Secret を同期する operator。 | 同期後も Kubernetes Secret のリスクは残る。 | [12](12/jp.md) |
| `Falco` | コンテナと node の挙動を検出する runtime detection ツール。 | API リクエストの audit logging の代わりにはならない。 | [16](16/jp.md), [18](18/jp.md) |
| `Firewall` | 指定された境界でトラフィックをフィルタリングする network control。 | Kubernetes 内部の NetworkPolicy と同じではない。 | [04](04/jp.md) |
| `FQDN` | ネットワーク宛先の完全修飾ドメイン名。 | IP アドレスや identity ではない。 | [09](09/jp.md), [18](18/jp.md) |
| `Framework` | リスク、要求事項、または controls の網羅性を評価するための枠組み。 | それ自体は技術的 control ではない。 | [05](05/jp.md), [19](19/jp.md) |
| `Grafana` | observability データに基づくダッシュボードと alert の可視化ツール。 | 文脈で用語を確認し、近い概念で置き換えない。 | [18](18/jp.md) |
| `gVisor` | workload と node のカーネルの間に隔離を追加する sandbox runtime。 | PSS、RBAC、NetworkPolicy の代わりにはならない。 | [05](05/jp.md) |
| `hard multi-tenancy` | 強力で多くの場合インフラレベルの境界によるテナント隔離。 | 文脈で用語を確認し、近い概念で置き換えない。 | [05](05/jp.md) |
| `Hash` | データの同一性確認に使う hash 関数の結果。 | 作成者を確認する signature ではない。 | [06](06/jp.md), [17](17/jp.md) |
| `HIPAA` | 米国の医療情報保護制度。 | Kubernetes リソースではない。 | [19](19/jp.md) |
| `hostPath` | worker node のファイルシステムパスを `Pod` にマウントする volume。 | 文脈で用語を確認し、近い概念で置き換えない。 | [09](09/jp.md) |
| `Hubble` | Cilium のネットワークフロー監視ツール。 | 文脈で用語を確認し、近い概念で置き換えない。 | [18](18/jp.md) |
| `Identity` | 操作を実行する主体を表すもの。 | 権限の集合とは異なる。 | [10](10/jp.md), [18](18/jp.md) |
| `Image digest` | 特定の image 内容を固定する Digest。 | mutable な tag とは異なる。 | [06](06/jp.md), [17](17/jp.md) |
| `Image policy` | image の送信元、signature、または属性に基づく admission ルール。 | scanner レポートではない。 | [17](17/jp.md) |
| `image registry` | container images と関連 metadata の保管場所。 | 文脈で用語を確認し、近い概念で置き換えない。 | [17](17/jp.md) |
| `Image tag` | 変更される可能性のある、人が読める image のラベル。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `impersonate` | 別の identity を impersonation する従来の Kubernetes permission。v1.36 では、より限定的な verbs を持つ beta ConstrainedImpersonation もある。 | 文脈で用語を確認し、近い概念で置き換えない。 | [10](10/jp.md) |
| `Incident response` | インシデント後の検出、封じ込め、復旧のための準備と行動。 | ログ収集だけに限定されない。 | [14](14/jp.md), [16](16/jp.md) |
| `Ingress` | 選択した Pod へ入るネットワークトラフィック。 | HTTP ルーティング用の Ingress オブジェクトと同じではない。 | [13](13/jp.md), [18](18/jp.md) |
| `Integrity` | データが正確で、許可なく変更されない性質。 | confidentiality と同じではない。 | [02](02/jp.md), [19](19/jp.md) |
| `iptables` | `kube-proxy` で `Service` トラフィックのリダイレクトを実装するモード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [08](08/jp.md) |
| `IPVS` | Kubernetes v1.35 以降では非推奨化が進む、`kube-proxy` の `Service` 負荷分散モード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [08](08/jp.md) |
| `Isolation` | ある主体または workload が他に及ぼす影響を制限すること。 | 単一の network segmentation より広い概念。 | [05](05/jp.md), [13](13/jp.md) |
| `KCNA` | Kubernetes and Cloud Native Associate。cloud native の広範な入門認定資格。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate。cloud native と Kubernetes セキュリティの概念的な認定資格。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `kill chain` | 初期アクセスから影響発生までの攻撃段階の連続を表すモデル。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md), [19](19/jp.md) |
| `KMS` | 暗号化キーを管理するサービスまたは plugin。 | データを暗号化する provider 自体ではない。 | [12](12/jp.md) |
| `KMS v2` | API Server と KMS を統合する現在推奨の API。KMS v1 は v1.28 から deprecated で、v1.29 からデフォルト無効。 | 文脈で用語を確認し、近い概念で置き換えない。 | [12](12/jp.md) |
| `kube-apiserver` | control plane コンポーネントとしての API Server プロセスの正式名称。 | kubelet API や kube-proxy と同じではない。 | [07](07/jp.md) |
| `kube-bench` | Kubernetes コンポーネントの設定を CIS Benchmark のチェックと照合するツール。 | アプリケーションのビジネスロジックを評価せず、完全な監査の代わりにもならない。 | [05](05/jp.md), [19](19/jp.md) |
| `Kube-proxy` | `Service` へのルーティングのためにカーネル規則（`iptables`、`nftables`、IPVS）を設定する node コンポーネント。userspace traffic proxy 自体ではない。 | NetworkPolicy を適用せず、パケット自体はカーネルが転送する。 | [08](08/jp.md) |
| `Kubeconfig` | cluster のアドレス、信頼する CA、クライアント認証情報を含むファイル。 | secrets を含まない無害な設定ではない。 | [09](09/jp.md) |
| `Kubelet` | container runtime を介して Pod を起動する node agent。 | scheduler ではない。 | [08](08/jp.md) |
| `Kubelet API` | node 上の操作と診断に使う Kubelet の HTTPS インターフェース。 | 文脈で用語を確認し、近い概念で置き換えない。 | [08](08/jp.md) |
| `Kubernetes API` | API Server 経由で cluster リソースを管理するインターフェース。 | kubelet API と同じではない。 | [07](07/jp.md), [10](10/jp.md) |
| `L3/L4/L7` | IP ネットワーク、転送ポート、アプリケーションプロトコルという control の層。 | 文脈で用語を確認し、近い概念で置き換えない。 | [13](13/jp.md) |
| `lateral movement` | 攻撃者が侵害済みリソースから別のリソースへ移動すること。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md), [16](16/jp.md) |
| `Least privilege` | 必要最小限の権限だけを付与すること。 | 全員に権限を一切与えないことではない。 | [02](02/jp.md), [10](10/jp.md) |
| `level` | イベントに含まれるデータ量。`None`、`Metadata`、`Request`、`RequestResponse`。 | 文脈で用語を確認し、近い概念で置き換えない。 | [14](14/jp.md) |
| `LimitRange` | namespace 内のコンテナの制限とデフォルト値。 | ResourceQuota のように namespace 全体の予算を定めるものではない。 | [11](11/jp.md), [16](16/jp.md) |
| `Log backend` | ログの受信先または保存先。 | それ自体がすべてのイベントの発生元ではない。 | [14](14/jp.md), [18](18/jp.md) |
| `Logging` | イベントについての離散的な記録を収集すること。 | monitoring や完全な observability と同じではない。 | [14](14/jp.md), [18](18/jp.md) |
| `MCQ` | Multiple choice question。KCSA 試験の選択式問題形式。 | CKS の hands-on 課題とは異なる。 | [01](01/jp.md), [20](20/jp.md) |
| `Metric` | 時間とともに変化する状態または挙動の数値測定。 | ログの完全な文脈は含まない。 | [18](18/jp.md) |
| `MITM` | man-in-the-middle。ネットワーク通信の傍受または改ざん。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `MITRE ATT&CK` | 攻撃者の戦術と技法の知識ベース。 | preventive control ではない。 | [15](15/jp.md), [19](19/jp.md) |
| `MITRE ATT&CK for Containers` | コンテナ環境における攻撃者の挙動を記述する戦術と技法の知識ベース。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md) |
| `mock exam` | 試験形式と時間制限を模した練習試験。 | 文脈で用語を確認し、近い概念で置き換えない。 | [20](20/jp.md) |
| `Monitoring` | システムの既知の指標と閾値を監視すること。 | observability より狭い。 | [18](18/jp.md) |
| `most appropriate` | 意味として許容される選択肢の中から、最も直接的で適切な回答を選ぶという指示。 | 文脈で用語を確認し、近い概念で置き換えない。 | [20](20/jp.md) |
| `mTLS` | 接続両端を相互検証する TLS。 | ネットワークフローの allowlist を定義するものではない。 | [18](18/jp.md) |
| `Multi-stage build` | builder stage と最小の final stage を分離したビルド。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `multi-tenancy` | アクセスとリソースを分離しつつ、複数のチームまたは組織が同一プラットフォームを利用すること。 | 文脈で用語を確認し、近い概念で置き換えない。 | [13](13/jp.md) |
| `multiple choice` | 複数の回答選択肢から最も正しいものを選ぶ問題。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `Mutating admission webhook` | 保存前にオブジェクトを変更できる Webhook。 | 許可または拒否だけを行う validating webhook とは異なる。 | [17](17/jp.md) |
| `MutatingAdmissionPolicy` | 別の webhook なしで対象 API オブジェクトを変更する、CEL を使う組み込みの宣言的 admission policy。 | 外部の mutating admission webhook と同じではない。 | [17](17/jp.md) |
| `Namespace` | リソース、権限、quota のための Kubernetes の論理的な領域。 | それ自体はネットワークの壁ではない。 | [05](05/jp.md), [13](13/jp.md) |
| `Network segmentation` | ゾーンまたは workload 間のネットワーク経路を分離すること。 | 一般的な isolation と同義ではない。 | [13](13/jp.md), [18](18/jp.md) |
| `NetworkPolicy` | Pod の許可された ingress と egress を記述する API リソース。 | kube-proxy、RBAC、TLS の代わりにはならない。 | [13](13/jp.md) |
| `nftables` | `kube-proxy` のモード。サポートされる Linux では deprecated な IPVS の代替として推奨される。 | 文脈で用語を確認し、近い概念で置き換えない。 | [08](08/jp.md) |
| `Node` | Kubernetes の worker または control-plane マシン。 | Pod と同じではない。 | [07](07/jp.md), [08](08/jp.md) |
| `Node authorization` | kubelet からの API リクエストの authorization メカニズム。 | Node object ではない。 | [08](08/jp.md), [10](10/jp.md) |
| `Observability` | ログ、メトリクス、trace からシステムの状態を理解できる能力。 | 1 つの monitoring ダッシュボードに還元されない。 | [18](18/jp.md) |
| `OIDC` | API Server が外部 issuer を信頼するための識別プロトコル。 | Kubernetes の汎用 OAuth authorization ではない。 | [10](10/jp.md) |
| `OPA` | 多目的 policy engine。多くの場合 Gatekeeper を通じて使われる。 | 組み込みの ValidatingAdmissionPolicy ではない。 | [17](17/jp.md) |
| `OpenID Connect` | OAuth 2.0 上の識別レイヤーとしての OIDC の正式名称。 | RBAC の判断を置き換えるものではない。 | [10](10/jp.md) |
| `OWASP Kubernetes Top 10` | OWASP（Open Worldwide Application Security Project、オープンな Web アプリケーションセキュリティプロジェクト）による Kubernetes の一般的なリスク分類カタログ。 | 必須 YAML フィールドの一覧ではない。 | [05](05/jp.md) |
| `PeerAuthentication` | service mesh またはその一部が受け入れる mTLS モードを設定する Istio リソース。 | `STRICT` は mTLS を要求するが、authorization と NetworkPolicy の代わりにはならない。 | [18](18/jp.md) |
| `performance-based` | 回答の選択だけでなく、環境内で実行した実践的な操作を評価する形式。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `persistence` | 最初の侵入点を削除した後も攻撃者がアクセスを維持する能力。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `PKI` | キー、証明書、信頼チェーンのインフラストラクチャ。 | 文脈で用語を確認し、近い概念で置き換えない。 | [18](18/jp.md) |
| `Pod` | 1 つ以上のコンテナを含む Kubernetes の最小デプロイ可能単位。 | 単一の container と同じではない。 | [09](09/jp.md), [11](11/jp.md) |
| `Pod Security Admission` | Pod Security Standards を適用する組み込み admission メカニズム。 | 廃止された PSP ではない。 | [11](11/jp.md) |
| `Pod Security Standards` | Pod 設定用の privileged、baseline、restricted のレベル集合。 | 特定の admission plugin と同じではない。 | [11](11/jp.md) |
| `Policy` | 望ましいまたは許容可能な挙動を定めるルール。 | すべての policy が技術的に自動 enforce されるわけではない。 | [13](13/jp.md), [17](17/jp.md) |
| `policy engine` | API オブジェクトにルールを適用するメカニズム。多くは admission path で動作する。 | 文脈で用語を確認し、近い概念で置き換えない。 | [05](05/jp.md) |
| `Private key` | 署名または認証に使う秘密の暗号鍵。 | certificate と一緒に公開してはならない。 | [09](09/jp.md), [18](18/jp.md) |
| `privileged` | host に対して非常に広い権限を持つコンテナモード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [09](09/jp.md), [11](11/jp.md) |
| `proctored` | 試験監督者が規則順守を監督する試験。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `proctoring` | プロバイダーの規則に従って監督下で行う試験手続き。 | 文脈で用語を確認し、近い概念で置き換えない。 | [20](20/jp.md) |
| `Prometheus` | メトリクスを収集・保存するシステム。 | 文脈で用語を確認し、近い概念で置き換えない。 | [18](18/jp.md) |
| `Provenance` | artifact の由来、ソース、作成プロセスに関する記録。 | digest、signature、SBOM と同じではない。 | [17](17/jp.md), [19](19/jp.md) |
| `PSA` | Pod Security Admission。PSS を適用する組み込み admission controller。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `PSP` | Kubernetes v1.25 で削除された PodSecurityPolicy メカニズム。 | 現行の PSA の代替ではない。 | [11](11/jp.md) |
| `PSS` | Pod Security Standards。`Pod` の 3 つの標準セキュリティプロファイル。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `Public key` | 署名検証または暗号化に使う鍵ペアの公開部分。 | private key として保管すべきではない。 | [18](18/jp.md) |
| `RBAC` | ロールと主体を権限に結び付けることによる authorization。 | authentication ではない。 | [10](10/jp.md) |
| `RCE` | remote code execution。脆弱性を通じたリモートでのコード実行。 | 文脈で用語を確認し、近い概念で置き換えない。 | [16](16/jp.md) |
| `Registry` | container images を保存・提供するレジストリ。 | 自動的に image の安全性を確認するものではない。 | [06](06/jp.md), [17](17/jp.md) |
| `ResourceQuota` | namespace 内のリソース消費総量の制限。 | LimitRange のように container の境界を定めるものではない。 | [13](13/jp.md), [16](16/jp.md) |
| `restricted` | アプリケーション workload 用の厳格な least privilege プロファイル。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `Risk` | 望ましくないイベントの可能性と結果の組み合わせ。 | threat や vulnerability と同じではない。 | [15](15/jp.md), [19](19/jp.md) |
| `Role` | namespace 内の許可された API 操作の集合。 | RoleBinding なしに権限を付与するものではない。 | [10](10/jp.md) |
| `Role / ClusterRole` | 1 つの namespace 内 / クラスター全体におけるルールの集合。 | 文脈で用語を確認し、近い概念で置き換えない。 | [10](10/jp.md) |
| `RoleBinding` | namespace 内で subject を Role または ClusterRole に結び付けるもの。 | authentication 自体ではない。 | [10](10/jp.md) |
| `RoleBinding / ClusterRoleBinding` | user、group、または `ServiceAccount` へのロールのバインド。 | 文脈で用語を確認し、近い概念で置き換えない。 | [10](10/jp.md) |
| `Runtime class` | Pod の実行に用いる runtime class の選択。 | runtime detection ではない。 | [05](05/jp.md), [09](09/jp.md) |
| `Runtime detection` | workload 起動後のプロセス挙動を検出すること。 | API リクエストの audit logging の代わりにはならない。 | [16](16/jp.md), [18](18/jp.md) |
| `runtime socket` | クライアントが container runtime を管理する Unix socket。 | 文脈で用語を確認し、近い概念で置き換えない。 | [08](08/jp.md) |
| `Sandbox` | 信頼できない workload のための強化された実行境界。 | least privilege の代わりにはならない。 | [05](05/jp.md) |
| `SAST` | アプリケーションを実行せずに行う静的コード解析。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `SBOM` | ソフトウェア artifact のコンポーネントと依存関係のインベントリ。 | signature や provenance と同じではない。 | [06](06/jp.md), [17](17/jp.md) |
| `SCA` | 依存関係とその既知リスクの分析。 | runtime scanner と同じではない。 | [06](06/jp.md) |
| `Scheduler` | 新しい Pod の node を選ぶコンポーネント。 | node 上でコンテナを起動するものではない。 | [07](07/jp.md) |
| `Secret` | 機密性のある小さなデータのための Kubernetes API オブジェクト。 | `data` の Base64 は encryption ではない。 | [12](12/jp.md) |
| `Secret scanning` | コード、履歴、artifact 内の credentials や他の secrets を探すこと。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `SecurityContext` | プロセスまたは Pod の権限と制限の設定。 | PSS、RBAC、NetworkPolicy の代わりにはならない。 | [09](09/jp.md), [11](11/jp.md) |
| `Segmentation` | 制限された相互作用を持つゾーンにシステムを分割すること。 | isolation を実現する方法の 1 つであり、完全な同義語ではない。 | [13](13/jp.md), [15](15/jp.md) |
| `Service identity` | API にアクセスするコンポーネントまたは workload のサービス用 identity。 | 人間の operator の identity ではない。 | [07](07/jp.md) |
| `Service mesh` | Service の connectivity、identity、多くの場合 mTLS を提供するインフラ層。 | NetworkPolicy の代わりにはならない。 | [18](18/jp.md) |
| `ServiceAccount` | Pod 内プロセスの Kubernetes identity。 | RBAC なしに権限を与えるものではない。 | [10](10/jp.md), [12](12/jp.md) |
| `Shared responsibility` | 防御の責任をプロバイダーと顧客の間で分担すること。 | プロバイダーが顧客の workload を保護するという意味ではない。 | [04](04/jp.md) |
| `SIEM` | セキュリティイベントを集約・相関するシステム。 | API Server audit イベントの発生元ではない。 | [14](14/jp.md), [18](18/jp.md) |
| `Signature` | データを署名キーに結び付ける暗号学的証明。 | digest、SBOM、provenance と同じではない。 | [06](06/jp.md), [17](17/jp.md) |
| `SLSA` | Build と Source の独立した tracks を持つ software supply chain 要求の framework。 | reproducible build の万能名称ではない。 | [17](17/jp.md), [19](19/jp.md) |
| `SLSA v1.2` | Build と Source の独立した tracks を持つ要求の枠組み。レベルは track と共に示す。 | 文脈で用語を確認し、近い概念で置き換えない。 | [17](17/jp.md), [19](19/jp.md) |
| `snapshot` | 特定時点の `etcd` 状態の整合性のある backup。 | 文脈で用語を確認し、近い概念で置き換えない。 | [07](07/jp.md) |
| `SOC 2` | Trust Services Criteria に基づくサービス組織の controls の評価。 | Kubernetes security standard ではない。 | [19](19/jp.md) |
| `soft multi-tenancy` | 論理的 controls により、共有 cluster 内で信頼するチームを分離すること。 | 文脈で用語を確認し、近い概念で置き換えない。 | [05](05/jp.md) |
| `Software supply chain` | コード、依存関係、ビルド、配布から runtime に至る経路。 | container registry だけに限定されない。 | [06](06/jp.md), [17](17/jp.md) |
| `SPIFFE` | 分散システムの workload identity 標準。 | それ自体は TLS 証明書ではない。 | [18](18/jp.md) |
| `stage` | リクエスト処理の時点。`RequestReceived`、`ResponseStarted`、`ResponseComplete`、`Panic`。 | 文脈で用語を確認し、近い概念で置き換えない。 | [14](14/jp.md) |
| `STRIDE` | 6 つの分類による脅威モデリング framework。 | 実際の攻撃のログではない。 | [15](15/jp.md), [19](19/jp.md) |
| `Subject` | リクエストの主体となる user、group、または ServiceAccount。 | Role や permission と同じではない。 | [10](10/jp.md) |
| `Supply chain` | ソフトウェア artifact の作成・供給の連鎖。 | 単一のビルド段階と同じではない。 | [17](17/jp.md), [19](19/jp.md) |
| `Syscall` | プロセスから OS カーネルへのシステムコール。 | Kubernetes API コールではない。 | [16](16/jp.md), [18](18/jp.md) |
| `Tag` | image バージョンを示す人が読める参照。 | mutable である可能性があり digest と同じではない。 | [06](06/jp.md) |
| `Threat` | 望ましくないイベントの潜在的な原因またはシナリオ。 | vulnerability や評価済みの risk と同じではない。 | [15](15/jp.md), [16](16/jp.md) |
| `Threat model` | システムの asset、境界、flow、threat を記述するもの。 | CVE の一覧ではない。 | [15](15/jp.md), [19](19/jp.md) |
| `TLS` | 接続を暗号化し認証するプロトコル。 | NetworkPolicy や authorization の代わりにはならない。 | [07](07/jp.md), [18](18/jp.md) |
| `TLS termination` | コンポーネントが TLS を終端して接続を復号する地点。 | 文脈で用語を確認し、近い概念で置き換えない。 | [18](18/jp.md) |
| `Token` | authentication のために提示する認証情報。 | 自動的に RBAC アクセスを制限するものではない。 | [10](10/jp.md) |
| `Trace` | 分散 Service を通過するリクエストの関連付けられた経路。 | 単一の log 記録と同じではない。 | [18](18/jp.md) |
| `Trust boundary` | 信頼、権限、またはデータ control が変化する場所。 | 必ずしも namespace と一致しない。 | [15](15/jp.md) |
| `Trusted image` | 検証可能な由来と一連の信頼 controls を持つ image。 | 文脈で用語を確認し、近い概念で置き換えない。 | [06](06/jp.md) |
| `Trusted registry` | policy が images の提供元として許可する Registry。 | image に CVE がないことを証明するものではない。 | [06](06/jp.md), [17](17/jp.md) |
| `ValidatingAdmissionPolicy` | API オブジェクトを validation するための CEL を用いた組み込みの宣言的 admission policy。cluster-scoped で、別の `ValidatingAdmissionPolicyBinding` により適用される。 | 「namespace 内」に存在するものではない。namespace scope は binding/`matchResources` で指定する。 | [17](17/jp.md) |
| `version-light` | 1 つの Kubernetes バージョンへの結び付きではなく、主要概念を問う試験の特性。 | 文脈で用語を確認し、近い概念で置き換えない。 | [01](01/jp.md) |
| `Vulnerability` | threat または exploit が利用できる弱点。 | threat や risk と同じではない。 | [06](06/jp.md), [16](16/jp.md) |
| `Vulnerability scanner` | コンポーネント情報に基づき既知の脆弱性を探すツール。 | runtime の挙動を防止するものではない。 | [06](06/jp.md), [17](17/jp.md) |
| `warn` | リクエストを拒否せず、クライアントに警告を示す PSA モード。 | 文脈で用語を確認し、近い概念で置き換えない。 | [11](11/jp.md) |
| `Webhook` | Kubernetes または別コンポーネントから呼び出される HTTP handler。 | すべての webhook が admission に関係するわけではない。 | [10](10/jp.md), [17](17/jp.md) |
| `webhook backend` | audit イベントを HTTPS collector または SIEM に送る backend。 | 文脈で用語を確認し、近い概念で置き換えない。 | [14](14/jp.md) |
| `Workload` | 実行されるアプリケーションと、それを管理する Kubernetes リソース。 | 単一の container image と同じではない。 | [03](03/jp.md), [09](09/jp.md) |
| `Zero trust` | ネットワーク、identity、場所を暗黙に信頼しないアプローチ。 | すべての相互作用を禁止することではない。 | [02](02/jp.md), [18](18/jp.md) |
| `信頼境界` | 信頼レベルの異なる参加者またはコンテキスト間の移行点。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md) |
| `脅威モデル` | システムの asset、参加者、flow、trust boundary、threat、control の記述。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md) |
| `データフロー` | コンポーネント間でのリクエスト、状態、またはデータの転送。 | 文脈で用語を確認し、近い概念で置き換えない。 | [15](15/jp.md) |
| `サービスアイデンティティ (service identity)` | Kubernetes API にアクセスするコンポーネントのアカウント。 | 文脈で用語を確認し、近い概念で置き換えない。 | [07](07/jp.md) |
## 用語上の注意点

- [Authentication](10/jp.md) は identity を確立し、[authorization](10/jp.md) は権限を確認し、[admission control](11/jp.md) は最初の 2 段階の後にオブジェクトの許容可否を評価します。
- [Audit logging](14/jp.md) は API イベントを扱い、[runtime detection](18/jp.md) は起動後のプロセス挙動を扱います。
- [Encryption](12/jp.md) はデータ保護にキーを必要とし、[Base64](12/jp.md) は可逆的な encoding にすぎません。
- [Digest](06/jp.md) は内容を固定し、[signature](17/jp.md) はデータをキーに結び付け、[SBOM](17/jp.md) はコンポーネントを列挙し、[provenance](17/jp.md) は由来を記述します。
- [Isolation](13/jp.md) は複数の境界を対象とし、[segmentation](13/jp.md) はそれらをゾーンと経路に分けます。
- [Control](05/jp.md) はリスクを低減し、[framework](19/jp.md) は controls の選択と評価を助けます。
- [Vulnerability](16/jp.md) は弱点、[threat](15/jp.md) は潜在的なシナリオ、[risk](19/jp.md) は可能性と影響の評価です。
- [Logging](18/jp.md) はイベントを保存し、[monitoring](18/jp.md) は既知の指標を追跡し、[observability](18/jp.md) は複数のシグナルから状態を説明可能にします。
- [CIA triad](02/jp.md) は [confidentiality](12/jp.md)、[integrity](19/jp.md)、[availability](16/jp.md) を統合します。

[目次と学習ロードマップ](README_JP.md)