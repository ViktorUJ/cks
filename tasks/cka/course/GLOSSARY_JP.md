[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md)

# CKA + CKAD コースの用語集

[← コース目次](README_JP.md) · [CKA](CKA_JP.md) · [CKAD](CKAD_JP.md)

コースの用語をアルファベット順にまとめた統一リファレンス。用語は英語（Kubernetes
と同じ表記）、説明は日本語、「章」の列にはその用語を扱っている場所（章へのリンク
付き）を示します。ページ内検索は Ctrl+F。

| 用語 | 説明 | 章 |
|--------|----------|-------|
| **A レコード / AAAA レコード** | DNS レコード：名前 → IPv4 / 名前 → IPv6。 | [0.2](00-2-dns/jp.md) |
| **accessModes** | アクセスモード：RWO、ROX、RWX、RWOP。 | [25](25/jp.md) |
| **activeDeadlineSeconds** | タスクの最大実行時間。 | [10](10/jp.md) |
| **Adapter** | アプリの出力を必要な形式に変換するコンテナ。 | [22](22/jp.md) |
| **admin.conf** | init 後の管理者用 kubeconfig。 | [35](35/jp.md) |
| **Admission control** | authn+authz の後にリクエストを検証/変更する仕組み。 | [21](21/jp.md) |
| **aggregation layer** | 独自の extension-apiserver で API を拡張する仕組み（例：metrics-server）。 | [41](41/jp.md) |
| **APIService** | 集約された API を登録するオブジェクト（`metrics.k8s.io` など）。 | [41](41/jp.md) |
| **allow ロジック** | ポリシーは許可するだけ；拒否を表す独立したルールは存在しない。 | [34](34/jp.md) |
| **allowPrivilegeEscalation** | 権限昇格の許可/禁止。 | [20](20/jp.md) |
| **allowVolumeExpansion** | ボリュームの拡張が許可されているか。 | [25](25/jp.md), [26](26/jp.md) |
| **Ambassador** | アプリの外向き接続を仲介するコンテナ。 | [22](22/jp.md) |
| **Annotation** | 補助データ用のキー・バリュー；選別（セレクタ）には使わない。 | [06](06/jp.md) |
| **API deprecation** | API バージョンを非推奨と宣言し、後に削除すること。 | [29](29/jp.md) |
| **apiVersion** | オブジェクトの API グループのバージョン（alpha/beta/安定版）。 | [29](29/jp.md) |
| **Application container** | 実処理を担う Pod のメインコンテナ。 | [04](04/jp.md) |
| **apply** | マニフェストからオブジェクトを作成または更新する（冪等、3-way merge）。 | [03](03/jp.md) |
| **args** | イメージの CMD を上書きする（引数）。 | [17](17/jp.md) |
| **Authn** | リクエストの送信者が誰かを確定すること。 | [21](21/jp.md) |
| **Authz** | 送信者に許可があるかの検証（RBAC）。 | [21](21/jp.md) |
| **automountServiceAccountToken** | SA のトークンを Pod にマウントするか。 | [21](21/jp.md) |
| **averageUtilization** | リソース使用率の目標平均値（%）。 | [16](16/jp.md) |
| **backendRefs** | 転送先の Service（canary 用の重み付きも可）。 | [33](33/jp.md) |
| **backoffLimit** | 失敗時の再試行回数。 | [10](10/jp.md) |
| **Bare pod** | コントローラを介さず直接作られた Pod；復旧されない。 | [04](04/jp.md) |
| **base** | 共通の元マニフェスト。 | [43](43/jp.md) |
| **Base image** | ビルドの出発点となるベースイメージ（`FROM`）。 | [23](23/jp.md) |
| **base64** | Secret の値のエンコード方式；暗号化では**ない**。 | [19](19/jp.md) |
| **behavior** | scale up/down の速度の細かい調整。 | [16](16/jp.md) |
| **Binding** | 条件に合う PV と PVC を結び付けること（1 対 1）。 | [25](25/jp.md) |
| **Blue** | 現在稼働中のバージョン；**Green** - 切り替えを控えた新しいバージョン。 | [09](09/jp.md) |
| **Blue/Green** | 完全な 2 つの環境（現行と新規）を用意し、トラフィックを一気に切り替える方式。 | [09](09/jp.md) |
| **bootstrap トークン** | ノードの join 用の一時トークン（有効期間はおよそ 24 時間）。 | [35](35/jp.md) |
| **bridge (cni0)** | ノード上の Pod をつなぐソフトウェアスイッチ。 | [0.7](00-7-netns/jp.md), [30](30/jp.md) |
| **CA** | 認証局；信頼の起点であり、証明書に署名する。 | [0.3](00-3-tls/jp.md), [39](39/jp.md) |
| **Calico / Cilium / Flannel** | 代表的な CNI プラグイン。 | [30](30/jp.md), [40](40/jp.md) |
| **Canary** | 新しいバージョンを少量のトラフィックに出し、徐々に比率を上げる方式。 | [09](09/jp.md) |
| **CIDR** | `アドレス/N` という表記。`N` はネットワーク部のビット数；N が大きいほどネットワークは小さい。 | [0.1](00-1-net/jp.md), [30](30/jp.md) |
| **CNAME** | DNS レコード：別の名前を指す別名。 | [0.2](00-2-dns/jp.md) |
| **capabilities** | root の「万能さ」を分割した個別の権限（drop/add）。 | [20](20/jp.md) |
| **cgroups** | コンテナのリソースを制限するカーネルのコントローラ（cpu、memory、pids、io）；requests/limits の土台。 | [0.4](00-4-containers/jp.md), [14](14/jp.md) |
| **cgroup v1 / v2** | 旧版（コントローラごとの階層）/ 現行版（単一階層）の cgroups；v2 は Fedora 31、Ubuntu 22.04、Debian 11、RHEL 9 から既定（K8s の cgroup v2 は 1.25 で GA）。 | [0.4](00-4-containers/jp.md) |
| **cgroup ドライバ** | cgroups を設定する主体（`systemd` または `cgroupfs`）；kubelet と runtime で一致させる（`SystemdCgroup=true`）。 | [0.4](00-4-containers/jp.md), [35](35/jp.md) |
| **cert-manager** | 証明書の発行と更新を自動化するオペレータ。 | [32](32/jp.md) |
| **cert-manager / Prometheus Operator** | 代表的なオペレータ。 | [41](41/jp.md) |
| **change-cause** | 履歴用に変更理由を残すアノテーション。 | [08](08/jp.md) |
| **Chart** | パッケージ：マニフェストのテンプレート + values + メタデータ。 | [42](42/jp.md) |
| **CKA** | Certified Kubernetes Administrator、クラスタ運用の試験。 | [01](01/jp.md) |
| **CKAD** | Certified Kubernetes Application Developer、アプリ実行の試験。 | [01](01/jp.md) |
| **Client certificate** | ユーザーの身分証明；CN → 名前、O → グループ。 | [39](39/jp.md) |
| **Cluster Autoscaler** | クラスタのノード数を変える。 | [16](16/jp.md) |
| **Karpenter** | Pending の Pod に合わせて必要な種類のノードを選び起動する（Cluster Autoscaler より柔軟）。 | [16](16/jp.md) |
| **Cluster API** | クラスタのライフサイクルを宣言的に管理する仕組み。 | [35](35/jp.md), [35B](35-3-design/jp.md) |
| **managed / self-managed** | control plane をプロバイダ（EKS/GKE/AKS）が運用する / 自分で運用する。 | [35B](35-3-design/jp.md) |
| **node pool** | 同種のノードのグループ（プロファイル、ゾーン、spot/on-demand）。 | [35B](35-3-design/jp.md) |
| **IaC** | コードとしてのインフラ（Terraform/OpenTofu、Ansible）。 | [35B](35-3-design/jp.md) |
| **GitOps** | クラスタの状態の正解を git に置く方式（Argo CD/Flux）。 | [35B](35-3-design/jp.md) |
| **cluster-admin / admin / edit / view** | 組み込みの ClusterRole。 | [38](38/jp.md) |
| **Cluster-scoped オブジェクト** | クラスタ単位のオブジェクト（Node、PV、StorageClass、ClusterRole）。 | [06](06/jp.md) |
| **ClusterIP** | 既定のタイプ：内部の仮想 IP で、クラスタ内からのみ届く。 | [07](07/jp.md) |
| **ClusterRole** | クラスタ全体 / cluster-scoped リソースへの権限 / 再利用のための定義。 | [38](38/jp.md) |
| **ClusterRoleBinding** | ロールをクラスタ全体でサブジェクトに結び付ける。 | [38](38/jp.md) |
| **CNCF** | Cloud Native Computing Foundation、Kubernetes とこれらの認定を支える組織。 | [01](01/jp.md) |
| **CNI** | Pod ネットワークのインターフェースとプラグイン（Calico、Cilium など）。 | [02](02/jp.md), [30](30/jp.md), [40](40/jp.md) |
| **command** | イメージの ENTRYPOINT を上書きする（何を起動するか）。 | [17](17/jp.md) |
| **completions** | 必要な成功完了の回数。 | [10](10/jp.md) |
| **componentstatuses** | コンポーネントの概況（非推奨化が進行中）。 | [45](45/jp.md) |
| **concurrencyPolicy** | CronJob の実行が重なったときの方針（Allow/Forbid/Replace）。 | [10](10/jp.md) |
| **Conditions** | ノードの状態（Ready、MemoryPressure、DiskPressure、PIDPressure）。 | [45](45/jp.md) |
| **ConfigMap** | 機密でない設定を持つオブジェクト（キー・バリューまたはファイル）。 | [18](18/jp.md) |
| **configMapGenerator / secretGenerator** | ConfigMap/Secret の生成（名前にハッシュが付く）。 | [43](43/jp.md) |
| **configMapKeyRef** | ConfigMap の 1 つのキーを環境変数に取り込む。 | [18](18/jp.md) |
| **container runtime** | コンテナの実行環境（containerd）、CRI 経由でやり取りする。 | [02](02/jp.md) |
| **containerd / CRI-O** | CRI の実装（ランタイム）。 | [40](40/jp.md) |
| **context** | cluster + user + namespace の組。 | [39](39/jp.md) |
| **Context (kubeconfig)** | クラスタ + ユーザー + namespace の組；`use-context` で切り替える。 | [03](03/jp.md) |
| **Control plane** | クラスタの管理層（頭脳）：apiserver、etcd、scheduler、controller-manager。 | [02](02/jp.md) |
| **Controller** | 調整ループを持つプログラム（現実を spec に近づける）。 | [41](41/jp.md) |
| **cordon** | ノードを unschedulable にする（新しい Pod はここに来なくなる）。 | [36](36/jp.md) |
| **cordon / drain** | ノードを unschedulable にする / ノードから Pod を退避させる（第 36 章）。 | [13](13/jp.md), [36](36/jp.md) |
| **CoreDNS** | クラスタの DNS サーバー（kube-system の Deployment、Service kube-dns の背後）。 | [31](31/jp.md) |
| **Corefile** | CoreDNS の設定（ConfigMap `coredns` の中）。 | [31](31/jp.md) |
| **CrashLoopBackOff** | コンテナが繰り返し落ちて再起動する状態。 | [04](04/jp.md), [44](44/jp.md) |
| **containerd / CRI-O** | kubelet が対話する高レベルの container runtime。 | [0.4](00-4-containers/jp.md), [40](40/jp.md) |
| **CRD** | API に新しいオブジェクト型を定義するもの。 | [41](41/jp.md) |
| **CreateContainerConfigError** | Pod が参照している ConfigMap/Secret が存在しない。 | [44](44/jp.md) |
| **CRI** | kubelet ↔ 実行環境のインターフェース。 | [0.4](00-4-containers/jp.md), [40](40/jp.md) |
| **crictl** | ノード上で CRI 経由でコンテナを扱う CLI。 | [40](40/jp.md), [45](45/jp.md) |
| **CronJob** | cron のスケジュールで Job を作成する。 | [10](10/jp.md) |
| **CSI** | Kubernetes にストレージを接続する標準。 | [26](26/jp.md), [40](40/jp.md) |
| **CSI ドライバ** | CSI の実装（StorageClass の provisioner）。 | [40](40/jp.md) |
| **CSR** | クラスタの API 経由での証明書署名要求。 | [39](39/jp.md) |
| **certSANs** | apiserver 証明書に追加する名前/アドレス（例：HA 用ロードバランサの DNS）。 | [35](35/jp.md) |
| **certificatesDir** | クラスタの PKI のディレクトリ（既定は `/etc/kubernetes/pki`）。 | [35](35/jp.md) |
| **Custom Resource** | CRD で定義した型のインスタンス。 | [41](41/jp.md) |
| **custom-columns** | 独自の出力テーブル。 | [47](47/jp.md) |
| **DaemonSet** | 条件に合う各ノードに Pod を 1 つずつ保つコントローラ。 | [11](11/jp.md) |
| **data / binaryData** | ConfigMap のテキストデータ / バイナリデータ。 | [18](18/jp.md) |
| **Declarative approach** | マニフェストによる管理（`kubectl apply -f`）。 | [01](01/jp.md), [03](03/jp.md) |
| **default / kube-system / kube-public / kube-node-lease** | システムの namespace。 | [06](06/jp.md) |
| **default deny** | ある方向の通信をすべて遮断するポリシー（許可ルールが無い状態）。 | [34](34/jp.md) |
| **default SA** | 各 namespace にある既定の ServiceAccount。 | [21](21/jp.md) |
| **Default StorageClass** | クラスを明示しない PVC に使われる既定のクラス。 | [26](26/jp.md) |
| **default-deny + DNS** | 落とし穴：egress ポリシーが名前解決を切ってしまう（第 34 章）。 | [34](34/jp.md), [46](46/jp.md) |
| **Deployment** | ReplicaSet の上位のコントローラ：レプリカ + 更新 + ロールバック + 履歴。 | [05](05/jp.md) |
| **Desired state** | マニフェストに記述した状態。 | [01](01/jp.md) |
| **Destructive operations** | etcd restore、drain：とくに慎重に確認する操作。 | [48](48/jp.md) |
| **distroless / scratch** | 余計なものを含まない / 空の、最小のベースイメージ。 | [23](23/jp.md) |
| **dnsConfig** | Pod の DNS を細かく設定する（`options ndots` も含む）、どの dnsPolicy でも効く。 | [31](31/jp.md) |
| **dnsPolicy** | Pod が DNS をどう受け取るか（ClusterFirst など）。 | [31](31/jp.md) |
| **Dockerfile** | イメージのビルド手順。 | [0.4](00-4-containers/jp.md), [23](23/jp.md) |
| **Downward API** | Pod が自分自身の情報にアクセスする仕組み（`fieldRef`、`resourceFieldRef`）。 | [17](17/jp.md) |
| **drain** | ノードから Pod を（穏やかに）退避させ、他へ移す。 | [36](36/jp.md) |
| **Dynamic provisioning** | PVC の要求に応じて PV を自動作成すること。 | [26](26/jp.md) |
| **eBPF** | Cilium の土台になっている Linux カーネルの技術。 | [30](30/jp.md) |
| **EmptyDir** | コンテナ間でファイルを受け渡すための Pod のボリューム。 | [22](22/jp.md), [24](24/jp.md) |
| **encryption at rest** | etcd 内の Secret の暗号化。 | [19](19/jp.md) |
| **External CA mode** | `pki/` に鍵無しの `ca.crt` だけがある状態：kubeadm は CSR を作り、署名と更新は利用者の責任。 | [35](35/jp.md) |
| **endpoint 2379** | etcd のクライアント用ポート。 | [37](37/jp.md) |
| **Endpoints** | Service の背後にある Pod のアドレス一覧；空なら未紐付け（第 7 章）。 | [07](07/jp.md), [46](46/jp.md) |
| **Endpoints / EndpointSlice** | Service の背後にある準備完了 Pod の IP 一覧。 | [07](07/jp.md) |
| **ENTRYPOINT/CMD** | イメージ側で定義された、何をどの引数で起動するか。 | [17](17/jp.md) |
| **env** | コンテナの環境変数。 | [17](17/jp.md) |
| **envFrom + configMapRef** | ConfigMap の全キーを環境変数として渡す。 | [18](18/jp.md) |
| **Ephemeral volume** | Pod と同じ寿命のボリューム（コンテナの再起動は越えるが、Pod の削除は越えない）。 | [24](24/jp.md) |
| **ephemeral コンテナ** | 稼働中の Pod をデバッグするための一時コンテナ（`kubectl debug`）。 | [04](04/jp.md), [29](29/jp.md) |
| **etcd** | クラスタの全状態を保持する分散 key-value ストア。 | [02](02/jp.md), [37](37/jp.md) |
| **etcdctl** | etcd を操作する CLI；スナップショットには `ETCDCTL_API=3` が必要。 | [37](37/jp.md) |
| **Events** | `describe`/`get events` の出力に現れるオブジェクトの操作履歴。 | [29](29/jp.md), [44](44/jp.md) |
| **eviction** | ノードのリソース不足時に kubelet が Pod を追い出すこと。 | [14](14/jp.md) |
| **exec** | コンテナ内でコマンド/シェルを実行する。 | [29](29/jp.md) |
| **exec 形式** | コマンドをリストで書く形式、シェルを介さない（シグナルの扱いが正しい）。 | [17](17/jp.md) |
| **expandtab** | YAML 用の vim 設定（タブの代わりにスペース）。 | [0.8](00-8-vim/jp.md), [47](47/jp.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | 秘密情報を実際に保護するためのツール。 | [19](19/jp.md) |
| **ExternalName** | 外部ドメインへの DNS 別名（CNAME）。 | [07](07/jp.md) |
| **FailedScheduling** | Pending のときに出るスケジューラのイベント。 | [44](44/jp.md) |
| **failureThreshold / successThreshold** | 状態を切り替えるまでの失敗/成功の回数。 | [27](27/jp.md) |
| **filters** | 変換処理（rewrite、redirect、ヘッダー操作）。 | [33](33/jp.md) |
| **Flat network** | どの Pod も他の Pod に IP で直接、NAT 無しで届くネットワーク。 | [30](30/jp.md) |
| **Fluent Bit/Fluentd** | ログ収集のエージェント（通常は DaemonSet）。 | [28](28/jp.md) |
| **Service の FQDN** | `<service>.<namespace>.svc.cluster.local`。 | [31](31/jp.md) |
| **fsGroup** | マウントしたボリュームの所有グループ（Pod レベル）。 | [20](20/jp.md) |
| **Gateway** | 入口となる存在：リスナー（ポート、プロトコル、TLS）を持つ；クラスタ運用者が所有する。 | [33](33/jp.md) |
| **Gateway API** | Kubernetes における現代的なトラフィックルーティングの標準。 | [33](33/jp.md) |
| **FQDN** | すべての階層を含む完全修飾ドメイン名（例：`backend.default.svc.cluster.local`）。 | [0.2](00-2-dns/jp.md), [31](31/jp.md) |
| **GatewayClass** | Gateway API の実装（コントローラ）、StorageClass に相当する概念。 | [33](33/jp.md) |
| **globalDefault** | 明示的な優先度を持たない Pod に適用される PriorityClass。 | [15](15/jp.md) |
| **HA (high availability)** | control plane の耐障害性：ノードを複数持ち、1 台の障害で管理機能が止まらないこと。 | [35A](35-2-ha/jp.md) |
| **--control-plane-endpoint** | HA 用の control plane の安定したアドレス（ロードバランサ）；`kubeadm init` で指定する。 | [35A](35-2-ha/jp.md), [35](35/jp.md) |
| **stacked / external etcd** | etcd を control plane ノード上に置く（既定）/ 別のノードに置く。 | [35A](35-2-ha/jp.md) |
| **クォーラム (etcd)** | 書き込みに必要な etcd ノードの過半数（raft）；だから台数は奇数（3/5）。 | [35A](35-2-ha/jp.md), [37](37/jp.md) |
| **leader election** | HA 環境で scheduler/controller-manager の稼働インスタンスを選ぶ仕組み（残りは待機）。 | [35A](35-2-ha/jp.md) |
| **SPOF** | 単一障害点；HA はこれを取り除く。 | [35A](35-2-ha/jp.md) |
| **--upload-certs / certificate-key** | HA ノードの join 時に control plane の証明書を受け渡す仕組み。 | [35A](35-2-ha/jp.md) |
| **Handshake (TLS)** | TLS 接続を確立する手順（証明書の検証、鍵の合意）。 | [0.3](00-3-tls/jp.md) |
| **Headless Service** | `clusterIP: None`、DNS が Pod の IP をそのまま返す。 | [07](07/jp.md), [11](11/jp.md) |
| **Helm** | Kubernetes のパッケージマネージャ。 | [42](42/jp.md) |
| **helm install/upgrade/rollback/uninstall** | リリースのライフサイクル。 | [42](42/jp.md) |
| **helm template** | チャートをローカルでマニフェストにレンダリングする（確認用）。 | [42](42/jp.md) |
| **hostPath** | ノードのディレクトリを Pod にマウントする（危険、システム用途向け）。 | [24](24/jp.md) |
| **HPA** | レプリカ数をメトリクスに応じて変える。 | [16](16/jp.md) |
| **httpGet / tcpSocket / exec / grpc** | プローブの実施方法。 | [27](27/jp.md) |
| **HTTPRoute** | Service への HTTP ルーティング規則；開発者が所有する。 | [33](33/jp.md) |
| **IgnoredDuringExecution** | ルールはスケジューリング時に評価されるが、既に動いている Pod は追い出さない。 | [12](12/jp.md) |
| **Image** | アプリのファイルシステム + 依存 + 起動メタデータをまとめたもの。 | [23](23/jp.md) |
| **ImagePullBackOff/ErrImagePull** | イメージを取得できない。 | [44](44/jp.md) |
| **imagePullPolicy** | イメージをいつ取得するか（IfNotPresent/Always/Never）。 | [23](23/jp.md) |
| **imagePullSecrets** | プライベートなイメージレジストリにアクセスするための Secret。 | [19](19/jp.md) |
| **immutable** | 変更不可の ConfigMap（作り直しのみ）。 | [18](18/jp.md) |
| **Imperative approach** | コマンドでオブジェクトを操作する方式（`kubectl run`、`create`）。 | [01](01/jp.md), [03](03/jp.md) |
| **Ingress コントローラ** | Ingress の規則を実行するアプリ（nginx、Traefik、ALB）。 | [32](32/jp.md) |
| **Ingress リソース** | L7 ルーティング規則の宣言（ホスト、パス、TLS）。 | [32](32/jp.md) |
| **ingress2gateway** | Ingress を Gateway API のリソースへ自動変換するツール（下書きが得られる、レビューは必要）。 | [33](33/jp.md) |
| **IngressClass** | その Ingress をどのコントローラが処理するか（`ingressClassName`）。 | [32](32/jp.md) |
| **Init コンテナ** | メインコンテナより前に実行され、必ず完了しなければならないコンテナ。 | [22](22/jp.md) |
| **initialDelaySeconds** | 最初のプローブまでの待ち時間。 | [27](27/jp.md) |
| **IP アドレス** | ネットワーク上の機器を表す数値のアドレス（IPv4 は 32 ビット、4 つのオクテット）。 | [0.1](00-1-net/jp.md) |
| **ipBlock** | IP 範囲による許可（外部トラフィック）。 | [34](34/jp.md) |
| **iptables / IPVS モード** | Service を実装する方式；IPVS の方がスケールしやすい。 | [31](31/jp.md) |
| **Job** | 一度きりのタスクのコントローラ；Pod が正常終了するまで面倒を見る。 | [10](10/jp.md) |
| **journalctl -u kubelet** | kubelet のログ、NotReady の原因を探る第一の情報源。 | [45](45/jp.md) |
| **JSONPath** | API の応答からフィールドを取り出す記法（`-o jsonpath=...`）。 | [03](03/jp.md), [47](47/jp.md) |
| **KEDA** | 外部イベントに基づくイベント駆動オートスケーリング（ゼロまで縮小も可能）。 | [16](16/jp.md) |
| **kube-apiserver** | すべてのリクエストが通る唯一の入口；etcd に書き込むのはこれだけ。 | [02](02/jp.md) |
| **list-watch** | 変更の追跡：LIST + WATCH ストリーム（API のポーリングをしない）。 | [02](02/jp.md) |
| **informer** | watch で同期されるコントローラのローカルなオブジェクトキャッシュ。 | [02](02/jp.md) |
| **resourceVersion** | オブジェクトのバージョン；watch の再開位置であり、楽観的ロックの基礎。 | [02](02/jp.md) |
| **楽観的ロック** | 古いバージョンでの書き込みは拒否される（409 Conflict）→ 再試行。 | [02](02/jp.md) |
| **kube-controller-manager** | 各種コントローラ（調整ループ）の集まり。 | [02](02/jp.md) |
| **kube-proxy** | ノード上で iptables/IPVS を使って Service を実現する。 | [02](02/jp.md), [07](07/jp.md), [31](31/jp.md) |
| **kube-scheduler** | Pod をノードに割り当てる。 | [02](02/jp.md), [12](12/jp.md) |
| **kubeadm** | クラスタ構築の公式ツール（init/join/upgrade）。 | [35](35/jp.md) |
| **kubeadm certs renew** | クラスタの証明書を更新する。 | [39](39/jp.md) |
| **kubeadm init** | control plane の初期化。 | [35](35/jp.md) |
| **kubeadm join** | ノードをクラスタに参加させる。 | [35](35/jp.md) |
| **kubeadm reset** | ノード上の kubeadm の状態を消去する。 | [36](36/jp.md) |
| **kubeadm upgrade plan / apply / node** | 計画 / 適用（最初の CP）/ ノードの更新。 | [36](36/jp.md) |
| **kubeconfig** | クラスタ、ユーザー、コンテキストを記述したファイル（`~/.kube/config`）。 | [03](03/jp.md), [39](39/jp.md) |
| **kubectl** | クラスタを操作する主要なコマンドラインツール。 | [01](01/jp.md), [03](03/jp.md) |
| **kubectl apply -k** | Kustomize のディレクトリを適用する。 | [43](43/jp.md) |
| **kubectl certificate approve** | CSR を承認する（CA が署名する）。 | [39](39/jp.md) |
| **kubectl debug** | デバッグ用コンテナの差し込み / Pod の複製 / ノードのデバッグ。 | [29](29/jp.md) |
| **kubectl explain** | オブジェクトのフィールドの組み込みドキュメント。 | [03](03/jp.md) |
| **kubectl kustomize / kustomize build** | 適用せずにレンダリングする。 | [43](43/jp.md) |
| **kubectl logs** | Pod/コンテナのログを見る。 | [28](28/jp.md) |
| **kubectl top** | リソース消費を表示する（metrics-server が必要）。 | [28](28/jp.md) |
| **kubelet** | ノードのエージェント、Pod を起動し監視する；システムサービス。 | [02](02/jp.md) |
| **Kubernetes** | コンテナオーケストレーションのシステム：クラスタの実際の状態を望ましい状態へ近づける。 | [01](01/jp.md) |
| **kustomization.yaml** | リソースと変換内容を記述するファイル。 | [43](43/jp.md) |
| **Kustomize** | テンプレートを使わず、パッチの重ね合わせでマニフェストを適応させるツール。 | [43](43/jp.md) |
| **Label** | オブジェクトの選別と結び付けのためのキー・バリュー。 | [06](06/jp.md) |
| **Labels** | オブジェクトに付けるキー・バリュー、セレクタはこれで働く。 | [05](05/jp.md) |
| **Layer** | ファイルシステムの変更のまとまり；レイヤーはキャッシュされ再利用される。 | [23](23/jp.md) |
| **Layered troubleshooting** | ネットワークを下から上へ切り分ける：CNI → DNS → Endpoints → ポリシー → 入口。 | [46](46/jp.md) |
| **LimitRange** | namespace 内の個々のオブジェクトに対する既定値とリソースの上下限。 | [14](14/jp.md) |
| **limits** | 消費の上限；実行中に監視される。 | [14](14/jp.md) |
| **liveness** | コンテナが生きているか；失敗 → 再起動。 | [27](27/jp.md) |
| **LoadBalancer** | Service の前段に置く外部のクラウドロードバランサ。 | [07](07/jp.md) |
| **localhost** | Pod 内の共有ネットワーク、コンテナ同士はこれで通じる。 | [22](22/jp.md) |
| **Manifest** | Kubernetes オブジェクトを記述した YAML ファイル。 | [01](01/jp.md) |
| **matchLabels / matchExpressions** | セレクタの 2 つの書き方。 | [06](06/jp.md) |
| **maxSurge** | ロールアウト中に希望数を超えて作れる Pod の数。 | [08](08/jp.md) |
| **maxUnavailable** | ロールアウト中に一時的に失ってよい Pod の数。 | [08](08/jp.md) |
| **medium: Memory** | emptyDir を RAM 上に置く（tmpfs）。 | [24](24/jp.md) |
| **metrics-server** | Pod の CPU/メモリを収集する；HPA と `kubectl top` に必要。 | [16](16/jp.md), [28](28/jp.md) |
| **Mi/Gi vs M/G** | 2 進（1024）と 10 進（1000）のメモリ単位。 | [14](14/jp.md) |
| **Microsegmentation** | Pod/Service 間の通信をきめ細かく分離すること。 | [34](34/jp.md) |
| **milli-CPU** | コアの 1000 分の 1（`500m` は半コア）。 | [14](14/jp.md) |
| **minReplicas/maxReplicas** | レプリカ数の下限と上限。 | [16](16/jp.md) |
| **Mirror Pod** | static pod の API 上の写し；見えるが kubectl では削除できない。 | [15](15/jp.md) |
| **Mock exam** | 自動採点付きの時間制限リハーサル。 | [48](48/jp.md) |
| **mTLS** | 相互 TLS：双方が証明書を提示する。 | [0.3](00-3-tls/jp.md), [39](39/jp.md) |
| **Multi-stage build** | 1 つのイメージ内でビルドし、最終成果物だけを残す方式。 | [23](23/jp.md) |
| **Mutating / Validating admission** | 変更する / 検証するアドミッションコントローラ。 | [21](21/jp.md) |
| **Namespace** | クラスタの区画；オブジェクト名はその中で一意。 | [06](06/jp.md) |
| **Namespaced オブジェクト** | namespace の中に存在する（Pod、Deployment、Service、...）。 | [06](06/jp.md) |
| **namespaceSelector** | namespace のラベルで Pod を選ぶ。 | [34](34/jp.md) |
| **NAT** | プライベートなトラフィックを外に出すため、ゲートウェイでアドレスを書き換えること。 | [0.1](00-1-net/jp.md) |
| **netshoot** | デバッグ用のネットワークツールを詰めたイメージ。 | [46](46/jp.md) |
| **NetworkPolicy** | どの Pod がどの Pod と通信できるかの規則（Pod レベルのファイアウォール）。 | [34](34/jp.md) |
| **Node** | クラスタを構成するマシン（VM または物理）。 | [02](02/jp.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl（CKA 固有の作業）。 | [48](48/jp.md) |
| **nodeAffinity** | 柔軟なノード選択；`required`（厳格）と `preferred`（緩やか）。 | [12](12/jp.md) |
| **NodeLocal DNSCache** | 各ノード上のローカル DNS キャッシュ。 | [31](31/jp.md) |
| **nodeName** | スケジューラを介さずノードを直接指定すること。 | [12](12/jp.md) |
| **NodePort** | 外部アクセス用に全ノードでポート（30000-32767）を開く。 | [07](07/jp.md) |
| **nodeSelector** | ノードのラベルによる単純で厳格な選択。 | [12](12/jp.md) |
| **NoExecute** | toleration の無い Pod はスケジュールせず、既に動いているものも追い出す。 | [13](13/jp.md) |
| **NoSchedule** | toleration の無い新しい Pod をスケジュールしない（既存の Pod は残る）。 | [13](13/jp.md) |
| **NotReady** | kubelet が準備完了を報告していないときのノードの状態。 | [45](45/jp.md) |
| **ndots** | 名前に含まれるドット数のしきい値：これより少ない名前は先に search サフィックスを付けて試される（既定 `ndots:5` → 外部名で余分な問い合わせが発生）。 | [31](31/jp.md) |
| **namespaces (Linux)** | プロセスが見えるものの分離：PID、NET、MNT、UTS、IPC、USER（Kubernetes の namespace とは別物）。 | [0.4](00-4-containers/jp.md) |
| **network namespace** | プロセス/コンテナの独立したネットワークスタック（自分のインターフェース、IP、経路）。 | [0.7](00-7-netns/jp.md), [40](40/jp.md) |
| **nslookup/dig** | Pod の中から DNS 解決を確認する。 | [46](46/jp.md) |
| **OCI** | イメージとコンテナのフォーマットの公開標準（Docker ↔ containerd の互換性）。 | [0.4](00-4-containers/jp.md) |
| **OLM** | Operator Lifecycle Manager、オペレータのインストール/更新の仕組み。 | [41](41/jp.md) |
| **OOMKilled** | メモリ制限の超過でコンテナが強制終了された。 | [04](04/jp.md), [14](14/jp.md), [44](44/jp.md) |
| **Operator** | コントローラ + アプリ運用のドメイン知識。 | [41](41/jp.md) |
| **operator Equal/Exists** | 値まで一致 / キーの存在だけで一致。 | [13](13/jp.md) |
| **Orchestration** | コンテナのライフサイクルの自動管理（起動、再起動、スケーリング、配置）。 | [01](01/jp.md) |
| **overlay** | 特定の環境向けに base の上に重ねる変更のまとまり。 | [43](43/jp.md) |
| **Overlay network** | ノード間でパケットをカプセル化するネットワーク（VXLAN）。 | [30](30/jp.md) |
| **parallelism** | Job が同時に起動する Pod の数。 | [10](10/jp.md) |
| **parentRefs** | Route を Gateway に結び付ける指定。 | [33](33/jp.md) |
| **Partial credit** | 部分的にできていれば部分点が入る。 | [47](47/jp.md) |
| **patches** | フィールド単位の変更（strategic merge / JSON6902）。 | [43](43/jp.md) |
| **pathType** | パスの照合方式：Prefix / Exact / ImplementationSpecific。 | [32](32/jp.md) |
| **pause コンテナ** | Pod のネットワーク namespace を保持する裏方のコンテナ。 | [40](40/jp.md) |
| **Pending** | Pod がスケジュールされていない（リソース/taints/affinity/PVC）。 | [44](44/jp.md) |
| **periodSeconds** | プローブの間隔。 | [27](27/jp.md) |
| **PersistentVolume** | クラスタ内の「ストレージの一片」を表すオブジェクト。 | [25](25/jp.md) |
| **PersistentVolumeClaim** | アプリからのストレージ要求（サイズ、モード）。 | [25](25/jp.md) |
| **Phase** | Pod の大まかな段階：Pending、Running、Succeeded、Failed、Unknown。 | [04](04/jp.md) |
| **クラスタの PKI** | `/etc/kubernetes/pki/` にある CA と証明書の一式、`kubeadm init` で作られる。 | [35](35/jp.md), [39](39/jp.md) |
| **front-proxy-ca** | aggregation layer（API サーバーの拡張）用の CA。 | [35](35/jp.md) |
| **sa.key / sa.pub** | ServiceAccount のトークンに署名するための鍵ペア。 | [35](35/jp.md), [21](21/jp.md) |
| **pluto / kubent** | マニフェスト/クラスタ内の非推奨 API を探すツール。 | [29](29/jp.md), [36](36/jp.md) |
| **kubepug (kubectl deprecations)** | 目標の K8s バージョンに対する API のチェック（クラスタとファイルの両方）。 | [29](29/jp.md) |
| **kubeconform** | 目標の K8s バージョンのスキーマでマニフェストを検証するツール（CI 向け）。 | [29](29/jp.md) |
| **Popeye** | クラスタのサニタイザ；非推奨 API も見つけてくれる。 | [29](29/jp.md) |
| **Pod** | 実行の最小単位：共通のネットワークとボリュームを持つ 1 つ以上のコンテナのラッパー。 | [04](04/jp.md) |
| **Pod CIDR / Service CIDR** | Pod のアドレス範囲 / Service の仮想 IP の範囲；重ねてはいけない。 | [0.1](00-1-net/jp.md), [30](30/jp.md) |
| **Pod connectivity** | Pod 同士が IP で通信できるか（CNI のレイヤー、第 30 章）。 | [30](30/jp.md), [46](46/jp.md) |
| **Pod Security Admission** | privileged/baseline/restricted の各レベルを持つ組み込みポリシー。 | [20](20/jp.md) |
| **podAffinity** | ラベルで指定した Pod の近くに配置する。 | [12](12/jp.md) |
| **podAntiAffinity** | ラベルで指定した Pod から離して配置する。 | [12](12/jp.md) |
| **PodDisruptionBudget** | 自発的な退避のときに保つべき利用可能 Pod の最小数。 | [36](36/jp.md) |
| **podSelector** | ポリシーを適用する対象の Pod / 許可する相手の Pod。 | [34](34/jp.md) |
| **policyTypes** | 方向：Ingress（受信）および/または Egress（送信）。 | [34](34/jp.md) |
| **port / targetPort / nodePort** | Service のポート / Pod 側のポート / ノード上のポート。 | [07](07/jp.md) |
| **port-forward** | Pod/Service のポートをローカルマシンへ転送する。 | [29](29/jp.md), [46](46/jp.md) |
| **Preemption** | 優先度の高い Pod を置くために、低い Pod を削除すること。 | [15](15/jp.md) |
| **PreferNoSchedule** | ここへの配置を緩やかに避ける。 | [13](13/jp.md) |
| **pressure-taints** | ノードのリソース不足時に自動で付く taints（第 13 章）。 | [13](13/jp.md), [45](45/jp.md) |
| **PriorityClass** | Pod の優先度を数値で表すオブジェクト。 | [15](15/jp.md) |
| **privileged** | 特権コンテナ（ノード上の root に近い）；危険。 | [20](20/jp.md) |
| **Probe** | kubelet が実行するコンテナのヘルスチェック。 | [27](27/jp.md) |
| **Progressive delivery** | メトリクスに基づく canary/blue-green の自動化（Argo Rollouts、Flagger）。 | [09](09/jp.md) |
| **projected** | 複数のソースを 1 つにまとめるボリューム（secret/configMap/downwardAPI）。 | [24](24/jp.md) |
| **Prometheus / Grafana** | メトリクスの収集・保存と可視化（本格的な監視）。 | [28](28/jp.md) |
| **provisioner** | 実際のボリュームを作成する CSI ドライバ。 | [26](26/jp.md) |
| **PTR** | 逆引き DNS レコード：IP → 名前。 | [0.2](00-2-dns/jp.md) |
| **QoS クラス** | Guaranteed / Burstable / BestEffort；メモリ不足時の退避の順序。 | [14](14/jp.md) |
| **Quorum** | 動作に必要な etcd ノードの過半数（HA）。 | [37](37/jp.md) |
| **raft** | etcd のノード同士が合意するためのコンセンサスプロトコル。 | [02](02/jp.md) |
| **RBAC** | ロールベースのアクセス制御（第 38 章）。 | [21](21/jp.md), [38](38/jp.md) |
| **readiness** | トラフィックを受けられるか；失敗 → Endpoints から外れる（再起動はしない）。 | [27](27/jp.md) |
| **readOnlyRootFilesystem** | ルートファイルシステムを読み取り専用にする。 | [20](20/jp.md) |
| **ReadWriteMany** | 複数ノードからの読み書き（ネットワークファイルシステムが必要）。 | [25](25/jp.md) |
| **ReadWriteOnce** | 1 つのノードからの読み書き（1 つの Pod ではない！）。 | [25](25/jp.md) |
| **reclaimPolicy** | PVC 削除後の PV の扱い：Retain / Delete。 | [25](25/jp.md) |
| **Reconciliation loop** | コントローラが望ましい状態と実際の状態の差を埋め続ける連続的なループ。 | [01](01/jp.md) |
| **Recreate** | 「全部消してから作る」戦略；ダウンタイムあり。 | [08](08/jp.md) |
| **Registry** | イメージの保管場所（既定は Docker Hub）；プライベートなら imagePullSecret が必要。 | [0.4](00-4-containers/jp.md), [23](23/jp.md) |
| **Release** | インストールされたチャートのインスタンス（リビジョンの履歴を持つ）。 | [42](42/jp.md) |
| **replicas** | 望ましい Pod の数。 | [05](05/jp.md) |
| **ReplicaSet** | セレクタで指定した Pod を所定の数だけ維持するコントローラ。 | [05](05/jp.md) |
| **ReplicationController** | ReplicaSet の古い前身。 | [05](05/jp.md) |
| **Repository** | チャートの保管場所。 | [42](42/jp.md) |
| **requests** | 保証される最小のリソース；スケジューリングで使われる。 | [14](14/jp.md) |
| **required vs preferred** | affinity における厳格な（必須の）ルールと緩やかな（できれば）ルール。 | [12](12/jp.md) |
| **ResourceQuota** | namespace 単位のリソース合計とオブジェクト数の上限。 | [14](14/jp.md) |
| **restartPolicy** | コンテナの再起動方針：Always、OnFailure、Never。 | [04](04/jp.md) |
| **Return to context** | ノード上での作業を終えたら元のマシンに戻って続けること。 | [48](48/jp.md) |
| **Revision** | 履歴に記録された Deployment のテンプレートのバージョン。 | [08](08/jp.md) |
| **revisionHistoryLimit** | ロールバック用に保持する古い ReplicaSet の数。 | [08](08/jp.md) |
| **Role** | 1 つの namespace 内での権限。 | [38](38/jp.md) |
| **RoleBinding** | namespace 内でロールをサブジェクトに結び付ける。 | [38](38/jp.md) |
| **roleRef** | binding が参照するロール。 | [38](38/jp.md) |
| **rollback** | 前のリビジョンへ戻すこと（`rollout undo`）。 | [08](08/jp.md) |
| **RollingUpdate** | ダウンタイム無しで Pod を順次入れ替える戦略（既定）。 | [08](08/jp.md) |
| **rollout** | Deployment の新しいバージョンを展開する処理。 | [08](08/jp.md) |
| **Routed network** | Pod への経路を直接知っているネットワーク（BGP）。 | [30](30/jp.md) |
| **rules** | 何に対して何が許可されるか。 | [38](38/jp.md) |
| **runAsNonRoot** | root での起動を禁止する。 | [20](20/jp.md) |
| **runAsUser / runAsGroup** | コンテナのプロセスの UID/GID。 | [20](20/jp.md) |
| **runc** | カーネルを使ってコンテナを起動する低レベルのツール。 | [0.4](00-4-containers/jp.md), [40](40/jp.md) |
| **Scheduler Profiles** | 1 つのスケジューラの中に複数の設定を持つ仕組み。 | [15](15/jp.md) |
| **schedulerName** | その Pod をどのスケジューラが配置するか。 | [15](15/jp.md) |
| **scope** | CRD の適用範囲：namespace 内かクラスタ全体か。 | [41](41/jp.md) |
| **search ドメイン** | resolv.conf にあるサフィックス、短い名前を補完する。 | [0.2](00-2-dns/jp.md), [31](31/jp.md) |
| **Secret** | 機密データ（パスワード、トークン、鍵、証明書）用のオブジェクト。 | [19](19/jp.md) |
| **secretKeyRef / secretRef** | Secret の 1 キー / 全体を env に取り込む。 | [19](19/jp.md) |
| **SecurityContext** | Pod/コンテナレベルのセキュリティ設定。 | [20](20/jp.md) |
| **selector** | コントローラが「自分の」Pod を見つける方法（ラベルによる）。 | [05](05/jp.md), [06](06/jp.md) |
| **Selector switch** | Service の `selector` を差し替えてトラフィックを別バージョンへ一気に移すこと（blue/green の基礎）。 | [09](09/jp.md) |
| **SSH** | ネットワーク越しにノードへ安全にログインする；`exit` で戻る。 | [0.5](00-5-linux/jp.md) |
| **sudo** | root としてコマンドを実行する；`sudo -i` はセッションの間 root になる。 | [0.5](00-5-linux/jp.md) |
| **systemd / systemctl** | サービス（kubelet、containerd）の管理システムとその操作コマンド。 | [0.5](00-5-linux/jp.md), [45](45/jp.md) |
| **Service** | セレクタで選ばれた Pod 群の前に置く安定したアドレスと負荷分散。 | [07](07/jp.md) |
| **ServiceAccount** | API にアクセスする Pod/プロセスのアイデンティティ。 | [21](21/jp.md) |
| **shell 形式** | `sh -c` を介したコマンド（変数やパイプが必要なとき）。 | [17](17/jp.md) |
| **Sidecar** | 同じ Pod 内の補助コンテナ（第 22 章）。 | [04](04/jp.md), [22](22/jp.md) |
| **snapshot restore** | スナップショットを新しいデータディレクトリに展開すること。 | [37](37/jp.md) |
| **snapshot save** | etcd のバックアップをファイルに作成すること。 | [37](37/jp.md) |
| **stabilization window** | レプリカを減らす前の待機ウィンドウ。 | [16](16/jp.md) |
| **Stable identity** | 再作成後も変わらない予測可能な Pod 名（`db-0`、`db-1`）。 | [11](11/jp.md) |
| **startup** | 起動が完了したか；通るまで他のプローブを止める。 | [27](27/jp.md) |
| **Stateful** | 状態を持つアプリ；アイデンティティと専用のストレージが必要。 | [05](05/jp.md) |
| **StatefulSet** | 状態を持つアプリ向けのコントローラ：安定した名前、順序、Pod ごとのストレージ。 | [11](11/jp.md) |
| **Stateless** | 固有の状態を持たないアプリ；Pod は互換で入れ替え可能。 | [05](05/jp.md) |
| **Static Pod** | スケジューラを介さず、`/etc/kubernetes/manifests/` のマニフェストから kubelet が直接起動する Pod。 | [02](02/jp.md), [15](15/jp.md), [45](45/jp.md) |
| **staticPodPath** | kubelet が監視するディレクトリ（通常は `/etc/kubernetes/manifests/`）。 | [15](15/jp.md) |
| **stdout/stderr** | コンテナの標準出力、Kubernetes はここからログを取る。 | [28](28/jp.md) |
| **StorageClass** | ボリューム作成のひな型：プロビジョナ、パラメータ、reclaim ポリシー。 | [26](26/jp.md) |
| **stringData** | 値を平文で書くフィールド（自動でエンコードされる）。 | [19](19/jp.md) |
| **subjects** | 権限を与える相手：User、Group、ServiceAccount。 | [38](38/jp.md) |
| **suspend** | CronJob の一時停止。 | [10](10/jp.md) |
| **swapoff** | swap の無効化（Kubernetes の要件）。 | [35](35/jp.md) |
| **Taint** | ノードに付ける制約のマーク（`キー=値:効果`）、Pod を退ける。 | [13](13/jp.md) |
| **Task weight** | 配点の比率、優先順位の手がかり。 | [47](47/jp.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | 他のプロトコル向けのルーティング。 | [33](33/jp.md) |
| **template** | レプリカを作る元になる Pod のテンプレート。 | [05](05/jp.md) |
| **Three pillars of observability** | ログ、メトリクス、トレース。 | [28](28/jp.md) |
| **Three-pass strategy** | 時間配分の戦略：簡単なもの → 難しいもの → 見直し。 | [47](47/jp.md), [48](48/jp.md) |
| **throttling** | CPU の上限を超えたときにコンテナの実行を絞ること。 | [14](14/jp.md) |
| **TLS** | トラフィックを暗号化・認証するプロトコル（HTTPS の「S」）。 | [0.3](00-3-tls/jp.md) |
| **TLS termination** | Ingress で HTTPS を復号すること；証明書は tls タイプの Secret から。 | [0.3](00-3-tls/jp.md), [32](32/jp.md) |
| **Toleration** | taint の付いたノードに居られるようにする Pod の「通行証」。 | [13](13/jp.md) |
| **tolerationSeconds** | NoExecute のノードに Pod が退避されるまで留まる時間。 | [13](13/jp.md) |
| **topologyKey** | 「近さの範囲」を決めるノードのラベル（hostname、zone）。 | [12](12/jp.md) |
| **topologySpreadConstraints** | トポロジー全体に Pod を均等に分散させる（`maxSkew`）。 | [12](12/jp.md) |
| **troubleshooting 領域** | CKA の 30%、最も比重が大きい；アプリ/クラスタ/ネットワークを直す。 | [48](48/jp.md) |
| **TTL** | DNS レコードのキャッシュ内での寿命（秒）。 | [0.2](00-2-dns/jp.md) |
| **ttlSecondsAfterFinished** | 完了した Job を指定時間後に自動削除する。 | [10](10/jp.md) |
| **type** | Secret の用途（Opaque、tls、dockerconfigjson など）。 | [19](19/jp.md) |
| **uncordon** | ノードをスケジューリング対象に戻す。 | [36](36/jp.md) |
| **updateStrategy** | DaemonSet/StatefulSet の更新戦略（rolling）。 | [11](11/jp.md) |
| **valueFrom** | 変数の値をソースから取る（Pod のフィールド、リソース、CM/Secret）。 | [17](17/jp.md) |
| **Values** | テンプレートに差し込むパラメータ。 | [42](42/jp.md) |
| **VAR** | マニフェスト内で先に宣言した変数への参照。 | [17](17/jp.md) |
| **veth ペア** | 連結された 2 つの仮想インターフェース - Pod とノードの network namespace をつなぐ「ケーブル」。 | [0.7](00-7-netns/jp.md), [30](30/jp.md) |
| **Version skew** | 許容されるコンポーネント間のバージョン差；kubelet は apiserver より新しくしない。 | [36](36/jp.md) |
| **Volume** | Pod のレベルで宣言し、コンテナにマウントするストレージ。 | [24](24/jp.md) |
| **Volume mount** | ConfigMap のキーがディレクトリ内のファイルになる方式。 | [18](18/jp.md) |
| **volumeBindingMode** | ボリュームを作成/バインドするタイミング（Immediate / WaitForFirstConsumer）。 | [26](26/jp.md) |
| **volumeClaimTemplates** | Pod ごとに PVC を作る StatefulSet のテンプレート。 | [11](11/jp.md), [26](26/jp.md) |
| **volumes / volumeMounts** | ボリュームの宣言 / コンテナへのマウント。 | [24](24/jp.md) |
| **VPA** | Pod の requests/limits を変える。 | [16](16/jp.md) |
| **webhook** | オブジェクトの外部での検証/変更（Kyverno、OPA、mesh）。 | [21](21/jp.md) |
| **YAML** | 人が読めるマニフェストの形式；入れ子はインデントで表す（スペースのみ）。 | [0.6](00-6-yaml/jp.md), [03](03/jp.md) |
| **whenUnsatisfiable** | topologySpread のモード：`DoNotSchedule`（厳格、→ Pending）または `ScheduleAnyway`（緩やか、偏りを許容）。 | [12](12/jp.md) |
| **Worker ノード** | アプリの Pod が動く作業ノード。 | [02](02/jp.md) |
| **Ingress のアノテーション** | コントローラ固有の設定（rewrite、timeout など）。 | [32](32/jp.md) |
| **非対称暗号** | 対になった 2 つの鍵：秘密鍵（秘密にする）と公開鍵（公開する）。 | [0.3](00-3-tls/jp.md) |
| **サブネットマスク** | アドレスのどこまでがネットワーク部で、どこからがホスト部かを示すもの。 | [0.1](00-1-net/jp.md) |
| **オクテット** | IPv4 アドレスを構成する 4 つの数のひとつ（8 ビット、0-255）。 | [0.1](00-1-net/jp.md) |
| **ポート** | 機器上のアプリを指す 0-65535 の数値；「IP + ポート」の組でサービスになる。 | [0.1](00-1-net/jp.md) |
| **秘密鍵 / 公開鍵** | 所有者だけが持つ鍵（渡さない）/ 誰にでも配る鍵。 | [0.3](00-3-tls/jp.md) |
| **リゾルバ** | アプリの代わりに DNS 問い合わせを行うコンポーネント（クラスタ内では CoreDNS）。 | [0.2](00-2-dns/jp.md), [31](31/jp.md) |
| **証明書** | 公開鍵 + 所有者の情報 + CA の署名。 | [0.3](00-3-tls/jp.md), [39](39/jp.md) |
| **Ingress → Gateway API への移行** | 1 つの Ingress を Gateway（入口）と HTTPRoute（規則）に分割すること。 | [33](33/jp.md) |
| **ネイティブ sidecar** | `restartPolicy: Always` を持つ init コンテナ。 | [22](22/jp.md) |
| **etcd の証明書** | `/etc/kubernetes/pki/etcd/` にある CA/cert/key。 | [37](37/jp.md) |
| **Kubernetes のネットワークモデル** | ネットワークへの要件：Pod ごとに IP、NAT 無しの通信、フラットなネットワーク。 | [30](30/jp.md) |
| **PV/PVC のステータス** | Available、Bound、Pending、Released。 | [25](25/jp.md) |
| **タグ / digest** | イメージのバージョン / 内容の不変なハッシュ。 | [23](23/jp.md) |

## パラメータ、フラグ、コード

コマンドのフラグ、ヘルパーのエイリアス、応答コードは、アルファベット順の用語の
本体リストとは分けてここにまとめます。

| パラメータ / コード | 説明 | 章 |
|----------------|----------|-------|
| **$do / $now** | `--dry-run=client -o yaml` のヘルパー / すばやい削除。 | [47](47/jp.md) |
| **--control-plane-endpoint** | control plane の共通アドレス（HA 用）。 | [35](35/jp.md) |
| **--data-dir** | etcd のデータディレクトリ（restore のときは新しいものにする）。 | [37](37/jp.md) |
| **--from-file / --from-env-file** | ファイル全体を 1 つのキーに / 行ごとにキーへ。 | [18](18/jp.md) |
| **--ignore-daemonsets** | drain のとき DaemonSet の Pod は対象にしない（ノードに紐づくため）。 | [36](36/jp.md) |
| **--pod-network-cidr** | Pod のアドレス範囲（CNI と整合させる）。 | [35](35/jp.md) |
| **--previous** | 直前の（落ちた）コンテナのログ。 | [28](28/jp.md) |
| **--set / -f** | values の上書き：CLI で / ファイルで。 | [42](42/jp.md) |
| **401 vs 403** | 認証されていない（証明書）vs 権限が無い（RBAC）。 | [39](39/jp.md) |
| **`--dry-run=client -o yaml`** | 何も作らずに YAML を生成する。 | [03](03/jp.md) |
