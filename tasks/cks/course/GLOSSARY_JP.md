[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md)

# CKSコース用語集

[← コース内容](README_JP.md) · [チートシート](CHEATSHEET_JP.md) · [トラブルシューティングインデックス(RU)](TROUBLESHOOTING_INDEX_RU.md)

CKS 用語をアルファベット順にまとめたリファレンスです。用語は英語、説明は日本語で記載しています。「章」は詳しい説明へのリンク、「ラボ/課題」は確認済みの実践例を示し、理論のみの用語では空欄にしています。すぐに使えるコード例は[チートシート](CHEATSHEET_JP.md)を参照してください。

| 用語 | 説明 | 章 | ラボ/課題 |
|--------|----------|-------|--------------|
| **4C** | Kubernetes セキュリティを評価するためのクラウド、クラスター、コンテナー、コード レイヤーのモデル。 | [02](02/jp.md) | |
| **Admission control** | 認証と認可の後、オブジェクトが etcd に保存される前の、API サーバー要求処理段階。 | [01](01/jp.md), [20](20/jp.md) | labs/107 (課題 6) |
| **Admission policy** | Kubernetes API リクエストを許可、変更、または拒否するルール。 | [01](01/jp.md), [20](20/jp.md) | labs/107 (課題 6), labs/108 |
| **Admission scan** | スキャン結果または関連する証明書を使用するワークロード作成時のチェック。 | [28](28/jp.md) | |
| **Admission verification** | API サーバーが Pod を永続化する前に、イメージの発信元または署名の必須検証。 | [26](26/jp.md) | labs/111 (課題 9a) |
| **aescbc** | Kubernetes PKCS#7 パディングを含む AES-CBC を使用する API データ暗号化プロバイダー。そのキーは保護された構成に保存されます。これには暗号文認証が組み込まれておらず (HMAC/AEAD はありません)、CBC はパディング オラクル攻撃に対して脆弱であるため、`aesgcm` や KMS v2 と比較して弱い/レガシーなオプションとみなされます。 | [21](21/jp.md) | labs/109 (課題 2) |
| **aesgcm** | API データ暗号化用の AES-GCM AEAD プロバイダー。キーにはスケジュールされたローテーションが必要です。 | [21](21/jp.md) | |
| **allow-list / allowlist** | 許可されたアクション、ソース、または宛先の明示的なリスト。記載されていないものは拒否されます。 | [12](12/jp.md), [15](15/jp.md), [17](17/jp.md) | labs/112 (課題 9) |
| **anonymous authentication** | 資格情報のないリクエストを `system:anonymous` にマッピングします。通常、API および kubelet では無効になります。 | [12](12/jp.md) | labs/104 (課題 5) |
| **AppArmor** | プロセス操作をプロファイルで許可されたものに制限するパスベースの Linux MAC。 | [03](03/jp.md), [16](16/jp.md) | labs/106 (課題 1-2) |
| **apparmor_parser** | AppArmor プロファイルをチェック、ロード、置換、アンロードするためのユーティリティ。 | [16](16/jp.md) | labs/106 (課題 1) |
| **Artifact** | OCI イメージ、SBOM、チャート、来歴などのビルド出力。 | [25](25/jp.md) | labs/111 |
| **Artifact repository** | 制御されたアーティファクト ストア: レジストリ、パッケージ リポジトリ、またはチャート リポジトリ。 | [25](25/jp.md) | |
| **attack surface** | 攻撃や構成ミスの可能性があるすべてのインターフェイス、コンポーネント、およびエントリ ポイント。 | [02](02/jp.md), [14](14/jp.md), [24](24/jp.md) | labs/105 |
| **Attribution** | イベントをプロセス、コンテナー、Pod、ID、ノード、および時間に関連付けます。 | [30](30/jp.md) | labs/112 (課題 6) |
| **audience** | ServiceAccount トークンの受信者。サービスは、独自の対象ユーザーのトークンのみを受け入れる必要があります。 | [11](11/jp.md) | labs/104 (課題 2) |
| **audit / enforce / warn** | 独立した PSA モード: 違反を記録する、Pod を拒否する、または警告を返す。 | [19](19/jp.md), [31](31/jp.md) | labs/107 (課題 1, 3-4) |
| **audit backend** | 監査ポリシーによって選択されたイベントを受信するローカル ファイル バックエンドまたは Webhook バックエンド。 | [32](32/jp.md) | labs/112 (課題 4, 8) |
| **audit event** | 1 つの Kubernetes API リクエストの API サーバー レコード。 | [32](32/jp.md) | labs/112 (課題 4) |
| **audit policy** | 監査レベルと除外されるイベント ステージを定義する順序付きルール。 | [32](32/jp.md) | labs/112 (課題 4) |
| **auditID** | 単一の API リクエストのすべての監査ステージをリンクする識別子。 | [32](32/jp.md) | |
| **Base image** | ビルド段階の初期ファイルシステムを提供する `FROM` 命令内のイメージ。 | [24](24/jp.md) | labs/111 (課題 3) |
| **Bound ServiceAccount token** | ServiceAccount および Pod にバインドされた短期間の TokenRequest API トークン。 | [11](11/jp.md) | labs/104 (課題 2) |
| **BPF filter** | seccomp フィルター モードの syscall に対してカーネルによって実行されるフィルター プログラム。 | [17](17/jp.md) | labs/106 (課題 4-5) |
| **break-glass access** | 緊急時またはインシデント時の一時的な特権アクセスを制御します。 | [10](10/jp.md), [15](15/jp.md) | |
| **Build context** | ビルダーに送信されるファイル。 `.dockerignore` はこのセットを削減します。 | [24](24/jp.md) | |
| **CAP_SYS_ADMIN** | Linux 機能が広すぎるため、通常のワークロードにとって危険です。 | [03](03/jp.md) | labs/106 (課題 5) |
| **capability** | root 権限から得られる個別の Linux 特権。安全なベースラインは `ALL` を削除し、必要なものだけを復元します。 | [03](03/jp.md), [18](18/jp.md) | labs/107 (課題 2) |
| **CEL** | 組み込みの ValidatingAdmissionPolicy によって使用される共通式言語。 | [20](20/jp.md) | labs/107 (課題 6), labs/108, labs/111 (課題 9a), labs/112 (課題 9) |
| **cgroup** | 制限があり、CPU、メモリ、PIDs、その他のリソースを考慮したプロセス グループ。 | [03](03/jp.md) | |
| **CI gate** | ゼロ以外の終了コードで次のパイプライン ステージをブロックする必須チェック。 | [27](27/jp.md), [28](28/jp.md) | |
| **Cilium** | eBPF ベースの Kubernetes CNI およびセキュリティ プラットフォーム。 | [06](06/jp.md), [23](23/jp.md) | labs/102, labs/110 (課題 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | クラスター全体の Cilium ポリシー。その範囲は広いため、特に慎重な展開が必要です。 | [06](06/jp.md) | |
| **CiliumNetworkPolicy (CNP)** | L3/L4/L7 ルールを備えた名前空間付き Cilium ポリシー リソース。 | [06](06/jp.md) | labs/102 (課題 3) |
| **cipher suite** | 証明書およびクライアントと互換性のある TLS 暗号化アルゴリズムのセット。 | [09](09/jp.md) | labs/103 (課題 5) |
| **CIS Kubernetes Benchmark** | Kubernetes コンポーネントとノードの安全な構成のための CIS の推奨事項。 | [01](01/jp.md), [07](07/jp.md) | labs/103 (課題 1, 7) |
| **CKS** | Kubernetes セキュリティ スペシャリスト認定、実用的な Kubernetes セキュリティ認定。 | [01](01/jp.md), [33](33/jp.md) | |
| **Clair** | コンテナー イメージ用のサービスベースの脆弱性スキャナーおよびインデクサー。 | [28](28/jp.md) | |
| **complain** | ポリシー違反をブロックせずにログに記録する AppArmor モード。 | [16](16/jp.md) | |
| **condition** | ルールが適用されるかどうかを決定するイベント フィールドに対するブール Falco 式。 | [29](29/jp.md) | labs/112 (課題 3, 7, 9) |
| **Constraint** | パラメーター、一致するスコープ、およびアクションを含む Gatekeeper テンプレート インスタンス。 | [20](20/jp.md) | |
| **ConstraintTemplate** | 新しい Gatekeeper 制約タイプの Rego テンプレートとパラメーター スキーマ。 | [20](20/jp.md) | |
| **container escape** | 予想されるコンテナ分離を回避して、ノードまたは他のテナント リソースにアクセスします。 | [03](03/jp.md) | |
| **Container runtime sandbox** | ワークロードとホスト カーネルの間に分離境界を追加するランタイム。 | [22](22/jp.md) | labs/110 (課題 1-3) |
| **Confidential computing / TEE** | ハードウェア分離された CPU 領域 (Intel SGX、AMD SEV) は、ハイパーバイザーやクラウド プロバイダーからもメモリ内のデータを保護します。 Kubernetes は特別な `RuntimeClass` (機密コンテナ) を通じてそれを公開しますが、ハードウェア保証は Kubernetes API の外側にあります。 | [30](30/jp.md) | |
| **context** | kubeconfig 内のクラスター、ユーザー、名前空間の名前付きの組み合わせ。 | [33](33/jp.md) | |
| **Correlation** | さまざまなソースからのイベントを単一のインシデント タイムラインにリンクします。 | [30](30/jp.md) | labs/112 (課題 6) |
| **Cosign** | OCI アーティファクトに署名および検証するための Sigstore ツール。 | [26](26/jp.md) | labs/111 (課題 7, 9a, 9c) |
| **CRI** | コンテナランタイムインターフェイス。 `crictl` は、CRI ソケットを通じてランタイムにアクセスします。 | [14](14/jp.md), [30](30/jp.md) | labs/112 (課題 6) |
| **CRI socket** | kubelet - ランタイム通信エンドポイント (`/run/containerd/containerd.sock` など)。 | [14](14/jp.md) | |
| **CVE** | 公に知られている脆弱性の識別子。 | [13](13/jp.md), [28](28/jp.md) | labs/111 (課題 1) |
| **CycloneDX** | SBOM のコンポーネント インベントリとセキュリティ分析用の OWASP 形式。 | [25](25/jp.md), [28](28/jp.md) | labs/111 (課題 7) |
| **daemon.json** | Docker デーモン構成ファイル (通常は `/etc/docker/daemon.json`)。 | [14](14/jp.md) | |
| **DaemonSet** | 選択されたすべてのノードでエージェント Pod を維持する Kubernetes ワークロード。 | [29](29/jp.md) | |
| **defense in depth** | 1 つの制御障害による影響を軽減する独立した保護層。 | [01](01/jp.md), [02](02/jp.md) | labs/104 (課題 3) |
| **deny-list** | デフォルトのアクションで syscall が許可される一方で、特定の syscall が拒否されるポリシー。 | [17](17/jp.md) | |
| **Digest** | 可変タグとは異なり、特定のイメージ マニフェストまたはアーティファクトの不変 SHA-256 識別子。 | [09](09/jp.md), [24](24/jp.md), [25](25/jp.md), [26](26/jp.md) | labs/111 (課題 3-5, 9c) |
| **distroless** | パッケージ マネージャーや通常はシェルを含まない最小限のランタイム イメージ。 | [24](24/jp.md), [31](31/jp.md) | labs/111 (課題 7) |
| **docker group** | Docker ソケット アクセスを持つグループ。ルート同等として扱われる必要があります。 | [14](14/jp.md) | labs/105 (課題 6) |
| **Docker socket** | `/var/run/docker.sock`、ローカル Docker デーモン API。アクセスはホスト上の root とほぼ同等です。 | [14](14/jp.md) | labs/105 (課題 6) |
| **drop-in** | 基本構成を拡張する別の構成ファイル (systemd または SSH など)。 | [15](15/jp.md) | |
| **eBPF** | 制限付きプログラム用の Linux カーネル メカニズム。 Cilium はデータパスに使用し、Falco はイベントに使用します。 | [06](06/jp.md), [29](29/jp.md) | labs/112 (課題 1) |
| **egress policy** | 許可されるアウトバウンド Pod 接続を指定する NetworkPolicy。 | [04](04/jp.md), [05](05/jp.md) | labs/101 (課題 2, 4, 6) |
| **encryption at rest** | etcd、ディスク、スナップショット、バックアップに保存されているデータの暗号化。 | [21](21/jp.md) | labs/109 |
| **EncryptionConfiguration** | kube-apiserver によって読み取られた暗号化プロバイダー構成。 | [21](21/jp.md) | labs/109 (課題 2) |
| **enforce** | 実際にポリシー違反をブロックする AppArmor または PSA モード。 | [16](16/jp.md), [19](19/jp.md) | labs/106 (課題 1), labs/107 (課題 1) |
| **Entity** | 事前定義された Cilium アドレス グループ (`world`、`cluster`、`host` など)。 | [06](06/jp.md) | |
| **envelope encryption** | データ暗号化キー（DEK）でオブジェクトを暗号化し、その DEK 自体を外部のキー暗号化キー（KEK）で保護する方式。 | [21](21/jp.md) | |
| **evidence** | 結果を確認する検証可能なアーティファクト: API オブジェクト、ログ、プロファイル、スキャナー レポート、またはネットワーク テスト。 | [33](33/jp.md) | |
| **exemption** | 信頼できる名前空間、ユーザー名、または RuntimeClass の狭い PSA バイパス。 RBAC 権限は付与されません。 | [19](19/jp.md) | |
| **Exfiltration** | 信頼境界を越えたデータの不正な転送。 | [02](02/jp.md), [30](30/jp.md) | |
| **failurePolicy** | Webhook/ポリシーが利用できない場合、またはエラーが発生した場合の API サーバー アクション: 通常は `Fail` または `Ignore`。 | [20](20/jp.md) | labs/107 (課題 6) |
| **Falco** | カーネル イベントとコンテナ/Kubernetes メタデータを使用するランタイム セキュリティ イベント ルール エンジン。 | [29](29/jp.md), [30](30/jp.md) | labs/112 (課題 1-3, 6-7, 9) |
| **Falco rule override** | ベンダー ルールセットを編集せずに、Falco ルール条件または例外をローカルで変更します。 | [29](29/jp.md), [30](30/jp.md) | labs/112 (課題 7) |
| **falco_rules.local.yaml** | ローカル オーバーライドおよびカスタム Falco ルールに優先されるファイル。 | [29](29/jp.md), [30](30/jp.md) | labs/112 (課題 3, 7, 9) |
| **False positive** | 特定のリソースには当てはまらない発見。それには文書化された狭い例外が必要です。 | [27](27/jp.md) | |
| **fixed version** | ベンダーが CVE を修正したコンポーネントのバージョン。 | [13](13/jp.md), [28](28/jp.md) | |
| **footprint** | ノードの攻撃対象領域を増やすパッケージ、プロセス、ポート、ソケット、および構成。 | [14](14/jp.md) | labs/105 (課題 1-2) |
| **Gatekeeper** | `ConstraintTemplate` および `Constraint` モデルを備えた OPA ベースの Kubernetes ポリシー エンジン。 | [20](20/jp.md), [26](26/jp.md) | |
| **Grype** | コンテナー イメージと SBOM 用の Anchore エコシステム スキャナー。 | [28](28/jp.md) | |
| **gVisor** | ユーザー空間カーネルを備えたサンドボックス ランタイム。 OCI ランタイムと CRI ハンドラーは、`runsc` と呼ばれることがよくあります。 | [03](03/jp.md), [22](22/jp.md) | labs/110 (課題 1-3) |
| **handler** | CRI 構成のランタイム名。 `RuntimeClass.spec.handler` と一致する必要があります。 | [22](22/jp.md) | labs/110 (課題 1) |
| **Hardware root of trust** | 物理デバイス (TPM/vTPM) にルートされた暗号化信頼チェーン。ノードのブートチェーンの整合性 (BIOS/UEFI → ブートローダー → カーネル → ランタイム) を検証するために使用されます。検証は Kubernetes API の外側にあります。 | [30](30/jp.md) | |
| **host endpoint** | CNI データプレーン内の通常の Pod ではなく、ノード ネットワーク エンドポイント。 | [05](05/jp.md) | |
| **host firewall** | ノード自体でのトラフィック フィルタリング (たとえば、`ufw`、`iptables`、または `nftables`)。 | [15](15/jp.md) | labs/105 (課題 3) |
| **host namespace** | Pod から `hostPID`、`hostNetwork`、または `hostIPC` によって共有されるノード名前空間。 | [18](18/jp.md) | labs/101 (課題 7) |
| **Host PID** | ノード PID 名前空間内のコンテナー プロセス PID。 `/proc` および `strace` に必要です。 | [30](30/jp.md) | labs/112 (課題 6) |
| **HSM (Hardware Security Module)** | ソフトウェアによる秘密キーの抽出を防止する物理暗号キー ストレージ デバイス (たとえば、kube-apiserver CA 秘密キーまたは KMS マスター キー用)。 | [21](21/jp.md), [30](30/jp.md) | |
| **Hubble** | Cilium ネットワーク フローの可観測性。 | [06](06/jp.md) | labs/102 (課題 5) |
| **identity** | ラベルから派生した Cilium エンドポイント識別子。 `identity` プロバイダーとは異なります。 | [06](06/jp.md), [21](21/jp.md) | labs/102 |
| **ImagePolicyWebhook** | `ImageReview` を通じてイメージの決定を外部バックエンドに委任するアドミッション プラグイン。 | [26](26/jp.md) | |
| **IMDS** | インスタンス メタデータ Service、クラウド プロバイダーのインスタンス メタデータ エンドポイント。 | [05](05/jp.md) | labs/101 (課題 5) |
| **IMDSv2** | メタデータリクエストに一時トークンを必要とする AWS IMDS バリアント。 | [05](05/jp.md) | |
| **Immutable infrastructure** | 実稼働アーティファクトを実行時に変更するのではなく、新しい検証済みバージョンに置き換えるアプローチ。 | [02](02/jp.md), [31](31/jp.md) | |
| **include** | 外部ファイルをロードするディレクティブ: SSH `Include`、AppArmor `#include`、またはチェック構成の `include:`。 | [15](15/jp.md), [16](16/jp.md), [27](27/jp.md) | labs/105 (課題 5) |
| **Ingress** | Pod に入るトラフィック、または外部 HTTP/HTTPS を Service にルーティングする Kubernetes API オブジェクト。文脈が意味を決定します。 | [04](04/jp.md), [08](08/jp.md) | labs/101 (課題 2), labs/103 (課題 4) |
| **IngressClass** | NGINX Ingress コントローラーなどの Ingress 実装の選択。 | [08](08/jp.md) | |
| **Inner packet** | 暗号化前または復号化後に表示される元の Pod から Pod フロー。 | [23](23/jp.md) | labs/110 (課題 5) |
| **ipBlock** | CIDR または個々の IP のイングレス/エグレス ルール。 `except` はアドレスとサブネットを除外します。 | [04](04/jp.md), [05](05/jp.md) | labs/101 (課題 6) |
| **IPsec ESP** | IP レベルで保護されたペイロードは、セキュリティ アソシエーション間の機密性と整合性を提供します。 | [23](23/jp.md) | |
| **Kata Containers** | ゲスト カーネルを備えた軽量 VM で Pod サンドボックスを起動するランタイム。 | [03](03/jp.md), [22](22/jp.md) | |
| **KEK/DEK** | エンベロープ暗号化におけるキー暗号化キーとデータ暗号化キー。 | [21](21/jp.md) | |
| **kernel module** | ロード可能なカーネル モジュール。一方向 Falco がイベントをキャプチャします。 | [29](29/jp.md) | labs/105 (課題 7) |
| **Keyless signing** | OIDC 認証後の永続的なローカル署名キーの代わりに、有効期間の短い証明書を使用して署名します。 | [26](26/jp.md) | labs/111 (課題 7) |
| **Kill chain** | 流出など、最初のアクセスから目的への一連の攻撃フェーズ。 | [02](02/jp.md), [30](30/jp.md) | labs/112 (課題 6) |
| **kube-bench** | CIS Kubernetes ベンチマーク プロファイルを使用した構成チェック ツール。 | [07](07/jp.md), [33](33/jp.md) | labs/103 (課題 1, 7) |
| **kube-linter** | ベスト プラクティス チェックを備えた Kubernetes YAML および Helm チャート リンター。 | [27](27/jp.md) | labs/111 (課題 2) |
| **kubelet** | Kubernetes ノード エージェント。その保護されたエンドポイントは通常、ポート `10250` をリッスンします。 | [05](05/jp.md), [07](07/jp.md) | labs/103 (課題 2), labs/105 (課題 8) |
| **kubesec** | セキュリティ スコアとコントロールをレポートする Kubernetes マニフェスト スキャナー。 | [27](27/jp.md) | labs/111 (課題 2, 4) |
| **Kyverno** | YAML ルールを備えた Kubernetes ネイティブ ポリシー エンジン: `validate`、`mutate`、`generate`、および `verifyImages`。 | [20](20/jp.md), [26](26/jp.md), [31](31/jp.md) | labs/108, labs/111 (課題 9a), labs/112 (課題 9) |
| **L3/L4** | Cilium ポリシーのネットワーク層とトランスポート プロトコル/ポート。 | [06](06/jp.md) | labs/102 (課題 2) |
| **L7** | HTTP メソッド/パスや DNS (Cilium Kafka フィルタリングは非推奨です) などのプロトコル層。 | [06](06/jp.md) | labs/102 (課題 3) |
| **lateral movement** | 侵害されたワークロードから他のシステム、データ、または ID に移動する攻撃者。 | [02](02/jp.md), [04](04/jp.md) | |
| **least privilege** | ID に必要最小限の権限、範囲、期間のみを付与します。 | [02](02/jp.md), [10](10/jp.md), [15](15/jp.md) | labs/104 (課題 1) |
| **legacy annotation** | 廃止された AppArmor ベータ アノテーション。移行のために読み取られますが、新しい Pods には使用されません。 | [16](16/jp.md) | |
| **level** | 監査イベントのデータ詳細: `None`、`Metadata`、`Request`、または `RequestResponse`。 | [32](32/jp.md) | labs/112 (課題 4) |
| **Linkerd identity** | Linkerd mTLS ID。通常は ServiceAccount から派生します。 | [23](23/jp.md) | |
| **live-restore** | デーモンの再起動時にコンテナーを実行し続ける Docker モード。 | [14](14/jp.md) | |
| **Localhost** | ノードにプリロードされた AppArmor/seccomp プロファイルの Kubernetes タイプ。 | [16](16/jp.md), [17](17/jp.md) | labs/106 (課題 2, 4) |
| **localhostProfile** | kubelet seccomp ルートに対する相対的な JSON プロファイル パス。 | [17](17/jp.md) | labs/106 (課題 4) |
| **MAC** | 必須アクセス制御。UID/GID およびモード ビットに加えて強制されるアクセス ポリシー。 | [03](03/jp.md), [16](16/jp.md) | |
| **macro** | Falco 条件の再利用可能な名前付きフラグメント。 | [29](29/jp.md) | labs/112 (課題 7) |
| **mTLS** | TLS では、クライアントとサーバーの両方が証明書を提示します。 | [23](23/jp.md) | labs/110 (課題 6) |
| **Multi-stage build** | `COPY --from=` によって接続された個別のビルド ステージとランタイム ステージを含む Dockerfile。 | [24](24/jp.md) | |
| **Mutating admission webhook** | 検証前にオブジェクトを追加または変更する Webhook。 | [20](20/jp.md) | labs/108 (課題 5) |
| **namespace** | プロセス グループのカーネル リソースの分離されたビュー。 Kubernetes 名前空間とは異なります。 | [03](03/jp.md) | labs/106 (課題 6) |
| **namespaceSelector** | クロスネームスペース NetworkPolicy ルールのラベルによる Kubernetes ネームスペースの選択。 | [04](04/jp.md) | labs/101 (課題 6) |
| **network namespace** | プロセスのインターフェイス、ルート、ネットワーク スタックの分離。 | [03](03/jp.md) | |
| **no_new_privs** | `exec` による追加の権限を防止するカーネル フラグ。 `allowPrivilegeEscalation: false` によって有効になります。 | [18](18/jp.md) | |
| **Node authorizer** | 必要な Node および Pod オブジェクトに対する kubelet アイデンティティ アクションの承認者。 | [12](12/jp.md) | |
| **Node encryption** | ノード間トラフィックの保護。特定のワークロードの ID と同等ではありません。 | [23](23/jp.md) | labs/110 (課題 4-5) |
| **NodeRestriction** | kubelet をそのノードとそれに割り当てられた Pods にさらに制限するアドミッション プラグイン。 | [12](12/jp.md) | |
| **Notary Project / Notation** | X.509 信頼ポリシーを備えた OCI 署名エコシステム。 Kubernetes の施行にはアドミッションの統合が必要です。 | [26](26/jp.md) | |
| **OCI** | レジストリや署名ツールで使用されるコンテナイメージとアーティファクト形式のオープンスタンダード。 | [25](25/jp.md), [26](26/jp.md) | labs/111 |
| **OPA** | オープン ポリシー エージェント。宣言型 Rego ルールを実行するポリシー エンジンです。 | [20](20/jp.md), [27](27/jp.md) | |
| **Outer packet** | 物理ネットワーク上のノード IP 間の暗号化されたパケット。 | [23](23/jp.md) | labs/110 (課題 5) |
| **partial credit** | タスクの独立して正しく完了した部分に対する功績です。 | [33](33/jp.md) | |
| **PeerAuthentication** | Istio インバウンド mTLS ポリシー。 `STRICT` は平文を拒否します。 | [23](23/jp.md) | labs/110 (課題 6) |
| **Performance-based** | 試験解答を選択するのではなく、作業環境での結果を求める試験形式です。 | [01](01/jp.md), [33](33/jp.md) | |
| **PID namespace** | プロセス リストとプロセス PIDs の分離。 | [03](03/jp.md) | |
| **Pod UID** | 特定の Pod インスタンスの不変 UID。相関関係ではその名前よりも信頼性が高くなります。 | [30](30/jp.md) | |
| **podSelector** | NetworkPolicy 名前空間内のラベルによって Pods を選択します。 | [04](04/jp.md) | labs/101 (課題 2, 6) |
| **PolicyReport** | ポリシー エンジンがこの API をインストールするときのポリシー チェック結果のレポート。 | [31](31/jp.md) | |
| **private key** | 非対称鍵ペアの秘密部分。 TLS ID (第 07 章から第 08 章) または Cosign 署名鍵 (ラボ 111) のプロトコル/ツールに従って使用されます。どちらも制限されたアクセス (通常は `0600`) を必要とします。 | [07](07/jp.md), [08](08/jp.md) | labs/111 (課題 9a) |
| **profiling** | プロセスのパフォーマンス診断エンドポイント。必要な場合を除き、`--profiling=false` で無効にします。 | [07](07/jp.md), [12](12/jp.md) | labs/103 (課題 3) |
| **projected volume** | トークン、ConfigMaps、下向き API、およびその他のソースを Pod ファイルに結合するボリューム。 | [11](11/jp.md) | labs/104 (課題 2) |
| **provenance** | アーティファクトのソース、入力、ビルダー、およびビルド プロセス (構成証明) に関するメタデータ。検証可能なオリジンは、単純な署名検証とは別のものです。`cosign sign`/`verify` は、ビルド履歴全体ではなく、署名/アイデンティティを証明します。 Sigstore は、出所として `cosign attest`/`verify-attestation` を提供します。 | [09](09/jp.md), [25](25/jp.md), [26](26/jp.md) | |
| **provider** | 指定された API リソースを暗号化および復号化するメカニズム。 | [21](21/jp.md) | labs/109 (課題 2) |
| **PSA** | Pod セキュリティ アドミッション、PSS の組み込み検証アドミッション コントローラー。 | [19](19/jp.md), [31](31/jp.md) | labs/107 (課題 1, 3-4) |
| **PSP** | PodSecurityPolicy、PSA の前身は Kubernetes 1.25 で削除されました。 | [19](19/jp.md) | |
| **PSS** | Pod セキュリティ標準: 事前定義された `privileged`、`baseline`、および `restricted` プロファイル。 | [19](19/jp.md) | labs/107 |
| **purl** | パッケージ URL、そのエコシステムとバージョンを含むパッケージ識別子。 | [25](25/jp.md) | |
| **re-encryption** | 新しい暗号化プロバイダーまたはキーを使用して古い API オブジェクトを書き換えます。 | [21](21/jp.md) | labs/109 (課題 2) |
| **read-only kubelet port** | `0` で無効にする必要があるレガシーの未認証 kubelet ポート。 | [07](07/jp.md), [09](09/jp.md), [12](12/jp.md) | labs/103 (課題 2) |
| **read-only root filesystem** | 画像レイヤーの変更を禁止するモード。許可された書き込みはボリュームに行われます。 | [18](18/jp.md), [31](31/jp.md), [33](33/jp.md) | labs/107 (課題 5), labs/112 (課題 5) |
| **Registry allowlist** | 明示したレジストリ/リポジトリのイメージだけを許可するポリシー。完全一致か接頭辞一致かを明確に指定する必要があります。ラボ112では、接頭辞/`startsWith` による比較だと `library/busybox-evil` が許可リストの `library/busybox` に一致してしまう例を示し、完全一致を使用しています。 | [26](26/jp.md) | labs/112 (課題 9) |
| **release cadence** | マイナー リリースとパッチ リリースの頻度。 | [13](13/jp.md) | |
| **remediation** | アーティファクト、依存関係、または基本イメージを更新し、結果を検証することでリスクを除去します。 | [28](28/jp.md) | |
| **Rendered manifest** | `helm template` または `kustomize build` の後の最後の YAML。展開前に分析されます。 | [27](27/jp.md) | |
| **RoleBinding** | ServiceAccount など、サブジェクトへのロールまたは ClusterRole の名前空間バインディング。 | [10](10/jp.md), [11](11/jp.md) | labs/104 (課題 1) |
| **Rootless Podman** | ルート デーモンではなく、通常のユーザーがビルド/実行を実行する Podman モード。 | [24](24/jp.md) | |
| **rotation** | サイズ、数、または経過時間に基づいて古いログ ファイルの名前を変更し、削除します。 | [21](21/jp.md), [32](32/jp.md) | labs/112 (課題 4) |
| **rule** | 条件、出力、優先順位を備えた名前付き Falco 検出器。 | [29](29/jp.md) | labs/112 (課題 3, 7, 9) |
| **runtime detection** | syscalls/eBPF およびランタイム メタデータを使用して、実行中のプロセスの不審な動作を検出します。 | [01](01/jp.md), [29](29/jp.md), [30](30/jp.md) | labs/112 |
| **Runtime mutation** | 実行中のコンテナのファイルシステムまたは構成を変更する。 | [31](31/jp.md) | labs/112 (課題 5) |
| **runtime overhead** | 選択された RuntimeClass の Pods のスケジューラーによって考慮される追加の CPU/メモリを修正しました。 | [22](22/jp.md) | |
| **RuntimeClass** | CRI ハンドラーとオプションのオーバーヘッド/スケジューリング制約を選択するクラスター スコープの Kubernetes リソース。 | [19](19/jp.md), [22](22/jp.md) | labs/110 (課題 1) |
| **RuntimeDefault** | AppArmor または seccomp の選択されたコンテナー ランタイムによって提供されるプロファイル。 | [16](16/jp.md), [17](17/jp.md), [18](18/jp.md) | labs/106 (課題 3), labs/107 (課題 2) |
| **sandbox pool** | 準備されたランタイム、ラベル、テイント、および容量を備えた専用ノード。 | [22](22/jp.md) | labs/110 |
| **sandboxed runtime** | gVisor や Kata Containers など、より強力な分離境界を持つランタイム。 | [03](03/jp.md), [22](22/jp.md) | labs/110 (課題 1-3) |
| **SCMP_ACT_ERRNO** | システムコールを実行せずにエラーを返す seccomp アクション。 | [17](17/jp.md) | labs/106 (課題 4) |
| **SCMP_ACT_LOG** | システムコールを許可し、カーネルログを要求する seccomp アクション。 | [17](17/jp.md) | |
| **seccomp** | プロセスのシステムコールをフィルタリングする Linux メカニズム。 | [03](03/jp.md), [17](17/jp.md), [18](18/jp.md) | labs/106 (課題 3-5, 7) |
| **SECCOMP audit record** | seccomp 関連イベントのカーネル/監査レコード。 | [17](17/jp.md) | |
| **Secret mount** | 1 つのビルド コマンドの資格情報を、最終層に書き込まずに一時的にマウントします。 | [24](24/jp.md) | |
| **security advisory** | 影響を受けるバージョン、悪用条件、軽減策、修正バージョンに関するベンダーの主要な通知。 | [13](13/jp.md) | |
| **SecurityContext** | プロセスまたは Pod の ID と制限を定義する Kubernetes フィールド。 | [18](18/jp.md), [33](33/jp.md) | labs/106, labs/107 (課題 2) |
| **self-signed certificate** | 信頼された CA ではなく独自のキーで署名された証明書。テストには適していますが、デフォルトでは信頼されません。 | [08](08/jp.md) | labs/103 (課題 4) |
| **SELinux** | タイプ強制を備えたラベルベースの MAC で、通常のアクセス許可を補完します。 | [03](03/jp.md) | |
| **ServiceAccount (SA)** | Pods および Kubernetes API のプロセスの名前空間 ID。 | [11](11/jp.md), [23](23/jp.md) | labs/104 (課題 2-3) |
| **severity** | 所見の重大度クラス: `LOW`、`MEDIUM`、`HIGH`、または `CRITICAL`。 | [28](28/jp.md) | labs/111 (課題 1) |
| **SHA-256 checksum** | 公開されたアーティファクトとバイトごとの同等性を検証する 256 ビット ファイル ダイジェスト。 | [09](09/jp.md) | labs/103 (課題 6) |
| **shim** | containerd プロセスまたは containerd を特定のランタイムに接続するバイナリ。 | [22](22/jp.md) | labs/110 (課題 1) |
| **Sidecar** | トラフィックをインターセプトまたは処理するアプリケーションと並行するプロキシまたはその他のヘルパー コンテナ。 | [23](23/jp.md) | labs/110 (課題 6) |
| **SLSA** | ソフトウェア サプライ チェーンのセキュリティ実践の成熟度モデル。 | [25](25/jp.md) | |
| **Software supply chain** | 実行中のワークロードへのソース、依存関係、ビルド システム、およびアーティファクトのパス。 | [25](25/jp.md) | labs/111 |
| **SPDX** | SBOM でパッケージ、ライセンス、およびそれらの関係を説明するオープン スタンダード。 | [25](25/jp.md), [28](28/jp.md) | labs/111 (課題 6) |
| **SSRF** | サーバー側のリクエスト フォージェリ。攻撃者が選択したアドレスをサーバーに要求させる脆弱性。 | [05](05/jp.md) | labs/101 (課題 5) |
| **stage** | 監査イベント作成ステージ: `RequestReceived`、`ResponseStarted`、`ResponseComplete`、または `Panic`。 | [32](32/jp.md) | labs/112 (課題 4) |
| **static analysis** | ワークロードを実行せずに Dockerfile、マニフェスト、ポリシーをチェックします。 | [27](27/jp.md) | labs/111 (課題 2) |
| **static Pod** | ノードローカル マニフェストからの Pod。Kubernetes API を介してスケジュールせずに、kubelet によって管理されます。 | [07](07/jp.md), [09](09/jp.md), [12](12/jp.md), [32](32/jp.md), [33](33/jp.md) | labs/103, labs/104 (課題 5), labs/112 (課題 4) |
| **sudoers** | ユーザーが別のユーザーとして実行できるコマンドのポリシー。 `visudo`で編集してください。 | [15](15/jp.md) | |
| **SUID/SGID** | 所有者の有効な UID またはグループの GID を使用してプログラムを実行する特殊ファイル ビット。 | [15](15/jp.md) | |
| **support window** | サポートされているバージョンは、セキュリティ パッチを受け取るブランチです。 | [13](13/jp.md) | |
| **Syft** | イメージ、ファイルシステム、またはアーカイブから SBOM を生成するツール。 | [25](25/jp.md) | labs/111 (課題 7) |
| **syscall** | プロセスがカーネル操作を要求するシステム コール。 | [03](03/jp.md), [17](17/jp.md), [29](29/jp.md) | labs/106 (課題 4-5) |
| **system:unauthenticated** | 匿名の被験者のグループ。バインディングには、`system:anonymous` と同じレビューが必要です。 | [12](12/jp.md) | |
| **systemd unit** | systemd によって管理されるサービス、ソケット、タイマー、またはその他のエンティティの定義。 | [14](14/jp.md) | labs/105 (課題 1) |
| **TLS minimum version** | サーバーがクライアントとネゴシエートする最小の TLS バージョン。 | [09](09/jp.md) | labs/103 (課題 5) |
| **TLS Secret** | `tls.crt` および `tls.key` を含む `kubernetes.io/tls` Secret。 | [08](08/jp.md) | labs/103 (課題 4) |
| **TLS termination** | TLS ハンドシェイクを完了し、イングレス コントローラーでトラフィックを復号化します。 | [08](08/jp.md) | labs/103 (課題 4) |
| **toFQDNs** | DNS 名と監視された DNS 応答を使用する Cilium エグレス ルール。 | [06](06/jp.md) | labs/102 (課題 4) |
| **TokenRequest API** | 有効期間の短い ServiceAccount トークンを発行する API。 | [11](11/jp.md) | labs/104 (課題 2) |
| **Transparent encryption** | アプリケーション、Service、または URL 変更を必要としないデータパス暗号化。 Cilium はそれをノードに適用します。 | [23](23/jp.md) | labs/110 (課題 4) |
| **triage** | 調査結果やイベントをソース、リスク、範囲、次のアクションごとに迅速に分類します。 | [33](33/jp.md) | |
| **Trivy** | イメージ、SBOM、ファイルシステム、シークレット、構成/IaC のスキャナー。 | [28](28/jp.md), [33](33/jp.md) | labs/111 (課題 1, 5, 8) |
| **Unconfined** | コンテナーには seccomp フィルターがありません。一時的な例外であり、ベースラインではありません。 | [17](17/jp.md) | labs/106 (課題 5) |
| **Unix socket** | ローカル ファイルシステム IPC エンドポイント。その権限によって、誰がデーモン API にアクセスできるかが決まります。 | [14](14/jp.md) | labs/105 (課題 6) |
| **userns-remap** | Docker デーモン機能 (`dockerd --userns-remap`) は、Docker 自体内のホスト上のコンテナー UID/GID を再マッピングします。ラボ 106 でテストされた Kubernetes Pod ユーザー名前空間 (`hostUsers: false`) とは別のものです。 | [14](14/jp.md) | |
| **Validating admission webhook** | オブジェクトを許可または拒否する Webhook。 | [20](20/jp.md) | |
| **ValidatingAdmissionPolicy** | 外部 Webhook を使用しない API サーバー内の組み込み CEL 検証。バインディングを通じて適用されます。 | [20](20/jp.md) | labs/107 (課題 6) |
| **version skew** | Kubernetes コンポーネント間で許可されるバージョンの違い。 kubelet は、API サーバーよりも新しいものであってはなりません。 | [13](13/jp.md) | |
| **webhook collector** | 集中ストレージと分析のための監査イベントを受信する HTTPS エンドポイント。 | [32](32/jp.md) | labs/112 (課題 8) |
| **WireGuard** | ピアキーペアを使用した VPN プロトコル。公開キーは、許可されたピアを識別します。 | [23](23/jp.md) | labs/110 (課題 4-5) |
| **Workload identity** | 暗号的に検証可能なワークロード ID。通常はメッシュ内の ServiceAccount/名前空間にリンクされます。 | [23](23/jp.md) | labs/110 (課題 6) |
| **Writable layer** | ランタイムによって読み取り専用イメージ レイヤー上に追加される可変レイヤー。 | [31](31/jp.md) | |
| **Zero trust** | ネットワーク、名前空間、または場所に基づいて暗黙的な信頼を拒否します。 | [02](02/jp.md) | |
