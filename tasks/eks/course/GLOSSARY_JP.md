[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [繁體中文版](GLOSSARY_TW.md)

# EKS コース用語集

[コース目次](README_JP.md)

コースで使う用語の統合アルファベット順リファレンスです。AWS と Kubernetes で英語の用語は英語のままとし、説明は日本語です。「章」列には用語を扱う章へのリンクを示します。ページ内検索は Ctrl+F を使用してください。

| 用語 | 説明 | 章 |
|--------|----------|-------|
| **ABAC / RBAC** | `aws:PrincipalTag` によるタグベースのアクセスと、特定のアクションおよびリソースを指定するロール・ポリシーベースのアクセス。 | [0.2](00-2-iam/jp.md) |
| **Access entry** | 1 つの IAM principal を `username` と `kubernetesGroups` に結び付けるクラスタアクセス設定のエントリ。人・サービスには `STANDARD`、ノードには `EC2_LINUX`、`EC2_WINDOWS`、`FARGATE_LINUX`、`HYBRID_LINUX`、`EC2` を使う。 | [01](01/jp.md), [05](05/jp.md), [47](47/jp.md) |
| **access entry 型 `EC2_LINUX`** | クラスタ内でノードロールの ARN を認可するエントリ。 | [45](45/jp.md) |
| **access point** | 独自の権限と POSIX identity を持つ EFS サブディレクトリへの入口。動的プロビジョニングとディレクトリ分離の基礎。 | [24](24/jp.md) |
| **Access policy** | access entry に関連付ける AWS 管理の Kubernetes レベル権限ポリシー。IAM 権限ではなく verbs と resources を含み、編集不可。 | [05](05/jp.md), [47](47/jp.md) |
| **Access scope** | access policy の適用範囲。`cluster` または namespace のリスト。 | [05](05/jp.md) |
| **ACM (AWS Certificate Manager)** | ロードバランサー上に存在する証明書。キーはエクスポートされず、更新は自動。 | [27](27/jp.md), [29](29/jp.md) |
| **actions / conditions** | カスタムアクション（redirect、fixed-response、weighted forward）と追加ルーティング条件（header、method、query、source IP）のアノテーション。 | [27](27/jp.md) |
| **Admission webhook** | apiserver がオブジェクトを etcd に書き込む前に呼ぶ外部ハンドラー。mutating はオブジェクトを変更し、validating は許可または拒否だけを行う。 | [22](22/jp.md) |
| **ADOT** | AWS Distro for OpenTelemetry。AWS による OTel ディストリビューション（SDK、agent、Collector）。 | [36](36/jp.md) |
| **ALIAS** | AWS リソース（例: ELB）への Route 53 レコード。CNAME を使えないドメイン apex で動作し、個別クエリとして課金されない。 | [29](29/jp.md) |
| **Allocatable** | `kube-reserved`、`system-reserved`、eviction threshold 後に Pod が使える残り。scheduler はこれを見る。 | [14](14/jp.md) |
| **`allowVolumeExpansion`** | PVC の拡張によるボリューム増量を許可する StorageClass フラグ。 | [23](23/jp.md) |
| **Amazon EKS** | AWS のマネージド Kubernetes。control plane は AWS が運用し、ノードと周辺設定は利用者が担当する。 | [01](01/jp.md) |
| **Amazon Managed Grafana (AMG)** | マネージド Grafana。AMP を data source として接続し、ユーザーアクセスは IAM Identity Center 経由。 | [33](33/jp.md) |
| **Amazon Managed Service for Prometheus (AMP)** | マネージド Prometheus 互換バックエンド。workspace、remote-write、PromQL、retention を AWS 側で提供する。 | [33](33/jp.md) |
| **amazon-cloudwatch-observability** | CloudWatch agent を導入し、Container Insights with enhanced observability を有効化する EKS managed addon。 | [33](33/jp.md) |
| **AMI (Amazon Machine Image)** | インスタンスディスクのテンプレート。kernel、FS、ソフトウェアを含む。ノードには `kubelet`、`containerd`、bootstrap ロジックが整合済みの EKS 最適化イメージを使用する。 | [0.4](00-4-ec2/jp.md), [10](10/jp.md) |
| **API Priority and Fairness** | リクエスト種別に同時リクエスト枠を配分する Kubernetes 機構。枠を使い切るとクライアントは `429` を受ける。 | [02](02/jp.md) |
| **app-of-apps** | 子 `Application` の集合をデプロイする親 Application。 | [44](44/jp.md) |
| **Application** | Argo CD CRD。Git のソースと対象クラスタ・namespace の結合。 | [44](44/jp.md) |
| **Application Load Balancer (ALB)** | host・path ルーティング、TLS termination、WAF、認証を備える L7（HTTP/HTTPS）ロードバランサー。EKS では LBC が Ingress から作成する。 | [27](27/jp.md) |
| **ApplicationSet** | テンプレートから `Application` を生成する Argo CD controller。cluster generator は接続済みクラスタごと、git generator は Git のディレクトリ・ファイルごと、matrix generator は 2 つの generator を組み合わせて生成する。 | [44](44/jp.md) |
| **ARN** | `arn:partition:service:region:account-id:resource` 形式のリソースアドレス。 | [0.1](00-1-aws/jp.md) |
| **`AssumeRoleWithWebIdentity`** | web identity token を IAM role の一時 credentials に交換する STS 操作。 | [16](16/jp.md) |
| **auditID** | audit log の一意なリクエスト ID。同じ操作の全 stage で共通。CloudTrail と共通 ID はなく、principal、IP、時刻で突合する。 | [21](21/jp.md) |
| **`authenticationMode`** | クラスタ認証モード。`CONFIG_MAP`、`API_AND_CONFIG_MAP`、`API`。移行は `API` 方向にのみ可能。 | [04](04/jp.md), [05](05/jp.md), [47](47/jp.md) |
| **`authenticationSource`** | ボリューム認証情報のソース。`driver`（共通 driver role）または `pod`（Pod の service account role）。 | [25](25/jp.md) |
| **Availability Zone (AZ)** | リージョン内の分離されたデータセンター群。レプリカを分散する基本的な障害ドメイン。 | [0.1](00-1-aws/jp.md), [40](40/jp.md) |
| **AWS Backup** | AWS の集中バックアップサービス。共通の計画と保管庫で EKS、EBS、EFS、S3 などをバックアップする。 | [41](41/jp.md) |
| **aws cli v2** | AWS の主要 CLI。設定は `~/.aws/config`、アクセスは `--profile` または `AWS_PROFILE` で選択する。 | [0.5](00-5-tools/jp.md) |
| **AWS Control Tower** | AWS の事前構成済み landing zone。controls（preventive、detective、proactive）、drift 検出、account factory を提供する。 | [0.1](00-1-aws/jp.md) |
| **`aws eks get-token`** | クラスタへのログイン用 presigned STS token を作る kubeconfig の `exec` plugin。 | [47](47/jp.md) |
| **AWS Gateway API Controller** | `aws-application-networking-k8s` controller。GatewayClass `amazon-vpc-lattice` を Gateway API から VPC Lattice オブジェクトへ変換する。 | [28](28/jp.md) |
| **AWS Load Balancer Controller (Gateway API)** | `controllerName` が `gateway.k8s.aws/alb`（ALB、L7）および `gateway.k8s.aws/nlb`（NLB、L4）の実装。 | [28](28/jp.md) |
| **AWS Load Balancer Controller (LBC)** | クラスタ内 controller。LoadBalancer type Service には NLB、Ingress には ALB を作成する。Helm で導入し IAM role が必要。 | [26](26/jp.md) |
| **AWS Organizations** | 複数アカウント管理サービス。OU 階層、共通ポリシー（SCP）、統合請求を提供する。 | [0.1](00-1-aws/jp.md), [32](32/jp.md) |
| **AWS PrivateLink** | interface endpoint により AWS サービスや他アカウントのサービスへプライベート接続する仕組み。 | [31](31/jp.md) |
| **AWS RAM (Resource Access Manager)** | subnets、Transit Gateway、VPC Lattice service network、Route 53 Resolver rules を他アカウントや組織と共有するサービス。 | [0.1](00-1-aws/jp.md), [32](32/jp.md) |
| **`aws sts get-caller-identity`** | 「自分は誰か」を表示するコマンド。account、ARN、userId を返す。 | [0.5](00-5-tools/jp.md) |
| **AWS X-Ray** | マネージド trace バックエンド。保存、service map、レイテンシ内訳、trace 検索を提供する。 | [36](36/jp.md) |
| **`aws-auth` ConfigMap** | `kube-system` 内の `mapRoles` と `mapUsers` による legacy マッピング機構。 | [05](05/jp.md), [45](45/jp.md), [47](47/jp.md) |
| **aws-for-fluent-bit** | AWS サービス向け出力 plugin を内蔵する AWS ビルドの Fluent Bit イメージ。 | [34](34/jp.md) |
| **`aws-vault`** | credentials を keychain に格納し、一時セッションでコマンドを実行する。 | [0.5](00-5-tools/jp.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | Pod egress のノード SNAT を `true` で無効化し、外部側から実際の Pod アドレスを見えるようにする。この場合、インターネットへの出口は NAT gateway のみとなる。 | [07](07/jp.md) |
| **`AWSTraceHeader`** | X-Ray trace header 用の SQS system message attribute。header がない非同期境界を越えて context を運ぶ。 | [36](36/jp.md) |
| **backend-protocol-version** | target group の application protocol。`HTTP1`、`HTTP2`、`GRPC`。ALB が Pod へ HTTP/1.1 でなく gRPC・HTTP/2 を proxy するために必要。 | [27](27/jp.md) |
| **backup plan** | backup の schedule、retention、lifecycle（cold storage への移行）、リソース関連付け。 | [41](41/jp.md) |
| **backup vault** | KMS key と access policy を持つ recovery point の保管庫。Vault Lock はここで有効化する。 | [41](41/jp.md) |
| **BackupStorageLocation (BSL)** | Velero backup の保存先（S3 bucket）。 | [42](42/jp.md) |
| **bake period** | control plane upgrade とノード upgrade の間の待機。ノードを N-1 のままにし、ノードを戻さず rollback できる。 | [39](39/jp.md) |
| **Basic / Enhanced scanning** | ECR の CVE スキャンモード。basic は OS package をネイティブに、enhanced は Amazon Inspector により OS と言語 package を継続的に検査する。 | [20](20/jp.md) |
| **behavior / stabilizationWindowSeconds** | stabilization window と policies で scaling の速度と揺れを平滑化する HPA セクション。 | [35](35/jp.md) |
| **bin packing** | requests に基づいて Pod をノードへ詰めること。 | [14](14/jp.md) |
| **blue/green クラスタ** | 旧クラスタの横に対象バージョンの新クラスタを用意し、workload を移行して traffic を切り替える方式。 | [03](03/jp.md), [38](38/jp.md) |
| **bootstrap.sh** | user data から AL2 の kubelet を設定するスクリプト。 | [45](45/jp.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | 作成時のアクセス設定。`true`（既定）ならクラスタ作成者に admin 権限を与える。 | [04](04/jp.md), [05](05/jp.md) |
| **Bottlerocket** | container 向け最小 OS。read-only root、イメージ単位の更新、API 管理、開放 SSH の代わりの control・admin container を備える。 | [10](10/jp.md) |
| **Burstable (T シリーズ)** | ベース CPU 割合と CPU credits。production ノードには不向き。 | [0.4](00-4-ec2/jp.md) |
| **Capacity** | CPU、メモリ、Pod に対するインスタンスの総容量。 | [14](14/jp.md) |
| **Capacity Blocks** | training 用 GPU/Trainium capacity の予約。 | [0.4](00-4-ec2/jp.md) |
| **capacity type** | ノード capacity 種別（`spot`/`on-demand`）。ラベルは `karpenter.sh/capacity-type` と `eks.amazonaws.com/capacityType`。 | [13](13/jp.md) |
| **CapacityProvisioned** | 丸め後に実際に割り当てられた vCPU・メモリの組み合わせを示す Pod annotation。これが料金を決める。 | [15](15/jp.md) |
| **cert-manager** | クラスタ内で証明書を `Secret` として発行する controller。ソースは ClusterIssuer または Issuer で指定する。 | [29](29/jp.md) |
| **CFS throttling** | CPU limit を超えた container のスロットリング。 | [14](14/jp.md) |
| **chargeback** | 実際の費用をチームの予算に計上すること。 | [43](43/jp.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | L7・FQDN ルールとクラスタ全体スコープを持つ Cilium CRD。 | [08](08/jp.md), [30](30/jp.md) |
| **CloudTrail** | AWS API 呼び出しの監査ログ。EKS では AWS リソースとしてのクラスタ操作（management events）を記録し、Kubernetes 内部イベントは記録しない。 | [21](21/jp.md) |
| **CloudWatch Application Signals** | OTel 上の APM（SLO、レイテンシ、エラー）。`amazon-cloudwatch-observability` addon で有効化する。 | [36](36/jp.md) |
| **CloudWatch Logs** | AWS のログ保管サービス。log groups、log streams、Logs Insights によるクエリを提供し、ingestion と storage に課金する。 | [34](34/jp.md) |
| **CloudWatch Logs Insights** | ログクエリ言語（`fields`、`filter`、`sort`、`stats`）。audit log 分析の主要ツール。 | [21](21/jp.md) |
| **Cluster Autoscaler (CA)** | Auto Scaling group 上で動く node autoscaler。配置不能 Pod と低利用率に応じて group の `desiredSize` を変更する。インスタンスタイプは group の launch template で固定。 | [11](11/jp.md) |
| **cluster creator admin** | クラスタを作成した IAM principal に自動付与される admin access。 | [47](47/jp.md) |
| **Cluster endpoint** | クラスタ Kubernetes API のアドレス。public endpoint はインターネットから CIDR リストで制限され、private endpoint は VPC から cluster security group で制限される。 | [01](01/jp.md), [02](02/jp.md) |
| **Cluster insights** | EKS の自動クラスタチェック。`UPGRADE_READINESS` は upgrade 準備、`ROLLBACK_READINESS` は rollback 可否を示し、7 日間利用可能。 | [03](03/jp.md), [38](38/jp.md) |
| **Cluster security group** | クラスタ用に自動作成される security group。これらの interface と managed node groups のノードに適用される。 | [02](02/jp.md), [45](45/jp.md) |
| **cluster version rollback** | in-place upgrade 後 7 日の期間に、etcd、workload、volume を保持して EKS control plane を前の minor へ戻すこと。 | [03](03/jp.md), [39](39/jp.md) |
| **ClusterIssuer / Issuer** | クラスタ全体または namespace の証明書ソースを記述する cert-manager オブジェクト。 | [29](29/jp.md) |
| **ClusterMesh** | `clustermesh-apiserver` で複数 Cilium クラスタの Pod Network を接続する機能。一意な `cluster-id` と重複しない PodCIDR が必要。 | [08](08/jp.md) |
| **CMK (customer managed key)** | 利用者管理の KMS key。デフォルト AWS owned key と異なり key policy を制御でき、復号を CloudTrail で監査できる。 | [18](18/jp.md) |
| **CNI chaining** | VPC CNI がアドレス割り当てと interface 設定を行い、Cilium が policy と observability を重ねるモード。`aws-node` は残る。 | [08](08/jp.md), [30](30/jp.md) |
| **`cni-metrics-helper`** | `aws-node` Pod から `awscni_*` を scrape し、集計値を CloudWatch へ送るコンポーネント。 | [06](06/jp.md) |
| **composite recovery point** | クラスタ状態と volume backup を 1 単位としてまとめる EKS 用 recovery point。 | [41](41/jp.md) |
| **Compute Savings Plans** | 1-3 年の時間単位支出コミットメントと引き換えの割引。instance family、region、Fargate/Lambda を横断できる。時間間で繰り越せず Spot には適用されず、Cost Explorer の utilization と coverage report で確認する。 | [43](43/jp.md) |
| **Compute SP / EC2 Instance SP** | 柔軟なプラン（EC2、Fargate、Lambda）/ 1 region の 1 family に対するより深い割引。 | [0.4](00-4-ec2/jp.md) |
| **configurationValues** | manifest を手で変更せず宣言的に設定する addon のフィールド。 | [37](37/jp.md) |
| **connection draining** | target deregistration 時にアクティブ接続を排出すること。`deregistration_delay.timeout_seconds` は既定で 300。 | [40](40/jp.md) |
| **conntrack** | ノード kernel の connection table。満杯になると新規接続が drop される。 | [46](46/jp.md) |
| **Consolidated billing** | 組織の共通請求書。volume discount と Savings Plans は全 account に適用される。 | [0.1](00-1-aws/jp.md) |
| **Consolidation** | コストのための自発的な集約。`WhenEmpty`、`WhenEmptyOrUnderutilized`、empty/single/multi-node 手法、`consolidateAfter` を含む。 | [11](11/jp.md), [12](12/jp.md) |
| **Container Insights** | CloudWatch による EKS monitoring。agent が node・Pod metrics を収集し、CloudWatch の dashboard と alarm を提供する。 | [33](33/jp.md) |
| **ContainerResource** | Pod 全体ではなく 1 container の utilization を計算する HPA metric type。sidecar が application metric を薄める場合に使う。 | [35](35/jp.md) |
| **context propagation** | trace が途切れないよう W3C Trace Context などの header を通じてサービス間に `trace id` を渡すこと。 | [36](36/jp.md) |
| **continuous profiling** | コード内の CPU・memory hotspot を継続収集すること。AWS では Amazon CodeGuru Profiler、eBPF profiler では Pyroscope と Parca がある。 | [36](36/jp.md) |
| **Control plane** | API server、scheduler、controller manager、etcd。EKS では AWS account 内・利用者 VPC 外で動き、`kubectl get pods -n kube-system` には表示されない。 | [01](01/jp.md) |
| **control plane logging** | EKS control plane の `api`、`audit`、`authenticator`、`controllerManager`、`scheduler` log を CloudWatch Logs へ送る機能。 | [34](34/jp.md) |
| **core addon** | `vpc-cni`、`kube-proxy`、`coredns`。各クラスタに導入される必須コア。 | [37](37/jp.md) |
| **cost allocation（配賦）** | 消費量または requests に基づき AWS resource cost を Kubernetes オブジェクト（namespace、Deployment、label）へ配分すること。 | [43](43/jp.md) |
| **cost allocation tags** | 請求を分解する AWS tags。user-defined tag は Billing console で有効化が必要。 | [43](43/jp.md) |
| **Cost and Usage Report** | S3 に出力する詳細 AWS billing。Athena で読むと OpenCost/Kubecost の allocation を割引後の実請求と照合できる。 | [43](43/jp.md) |
| **Cost Anomaly Detection** | 異常な支出増加を ML で検出し、email または SNS（AWS Chatbot 経由の Slack/Teams）へ alert する AWS service。 | [43](43/jp.md) |
| **crash-consistent / application-consistent** | 書き込み停止なしの snapshot / application レベルで整合させた snapshot。AWS Backup の EKS で使えるのは前者だけ。 | [41](41/jp.md) |
| **Cross-account ENI** | control plane と node、kubelet API、webhook、OIDC の通信のため、EKS が利用者 subnet に作る network interface。 | [02](02/jp.md) |
| **cross-AZ traffic** | availability zone 間のデータ転送。通常は両方向で転送料金がかかる。 | [31](31/jp.md) |
| **cross-zone load balancing** | 全 AZ の target に traffic を振り分ける load balancer モード。負荷は均等だが cross-AZ traffic は増える。 | [31](31/jp.md) |
| **Custom networking** | secondary ENI と Pod address を `ENIConfig` の subnet・security groups から得るモード。AZ ごとに 1 つ作成し、`ENI_CONFIG_LABEL_DEF` の label で選ぶ。 | [07](07/jp.md) |
| **custom.metrics.k8s.io** | HPA 用のクラスタオブジェクト custom metrics API（Pods、Object）。 | [35](35/jp.md) |
| **Data Firehose** | S3、OpenSearch などへ stream を送るマネージド buffer・router。 | [34](34/jp.md) |
| **Data plane** | 利用者のノードと、その上で実行されるすべて。 | [01](01/jp.md) |
| **Delegated administrator** | 組織全体の GuardDuty/Security Hub を管理し、全 member の findings を見られる account。region ごとに指定する。 | [0.1](00-1-aws/jp.md), [21](21/jp.md) |
| **`deletionProtection`** | クラスタ削除を禁止するフラグ。 | [04](04/jp.md) |
| **deprecated / removed API** | `apiVersion` はまず非推奨となり、その後削除される。削除後、その manifest は適用できない。 | [38](38/jp.md) |
| **describe-addon-versions** | EKS API 操作。addon version、Kubernetes minor との互換性、`defaultVersion` を表示する。 | [37](37/jp.md) |
| **`describe-target-health`** | target group の target 状態と理由を示すコマンド。 | [46](46/jp.md) |
| **Digest** | image content の `sha256` hash である不変 identifier。tag と違い digest deploy はビルドした artifact そのものの実行を保証する。 | [20](20/jp.md) |
| **Disruption budget** | 自発的 disruption 速度の上限。node の割合・数、`schedule` と `duration` の window、`reasons` への関連付け。 | [12](12/jp.md) |
| **DNS-01** | TXT record で domain ownership を ACME 検証する方法。Route 53 では cert-manager が作成する。 | [29](29/jp.md) |
| **Drift** | node と desired state の差異（新 AMI、変更した selector や `requirements`）。consolidation より先に実行される。 | [12](12/jp.md) |
| **Dual-stack** | IPv4・IPv6（`/56` と `/64`）を持つ VPC と subnet。IPv6 mode は Pod address 不足を解消する。 | [0.3](00-3-vpc/jp.md) |
| **EBS / instance store** | 1 AZ の network volume / ephemeral なローカル NVMe。 | [0.4](00-4-ec2/jp.md) |
| **EBS CSI driver** | `aws-ebs-csi-driver`。provisioner `ebs.csi.aws.com` を含む managed addon で、EBS volume lifecycle を管理する。 | [23](23/jp.md) |
| **EC2NodeClass** | AWS 設定（AMI、IAM role、subnet・SG、disk、IMDS）を定義する CRD（`karpenter.k8s.aws/v1`）。 | [12](12/jp.md) |
| **ECR** | AWS のマネージド OCI image registry。private registry は account-region ごとに `<account-id>.dkr.ecr.<region>.amazonaws.com`、public は `public.ecr.aws`。 | [20](20/jp.md) |
| **EFS** | Amazon Elastic File System。elastic capacity と ReadWriteMany mode を持つマネージド regional NFS。 | [24](24/jp.md) |
| **EFS CSI driver** | `aws-efs-csi-driver`。provisioner `efs.csi.aws.com` を含む managed addon で、あらかじめ作成した filesystem 上で動く。 | [24](24/jp.md) |
| **EKS audit log** | control plane log type の `audit`。誰が、どの verb で、どの resource に、どこから、どの結果で操作したかを示す Kubernetes audit JSON event を CloudWatch Logs に書く。 | [21](21/jp.md) |
| **EKS authenticator** | presigned STS token を検証し、IAM identity を Kubernetes subject に対応付ける control plane の webhook。 | [47](47/jp.md) |
| **EKS Auto Mode** | AWS が appliance node（Bottlerocket、read-only root、SSH・SSM なし、寿命 21 日）、Karpenter による scaling、組み込み network・DNS・EBS CSI・ELB を管理する mode。 | [01](01/jp.md), [09](09/jp.md) |
| **EKS Cluster State** | Kubernetes object manifest（Secret、ConfigMap、StatefulSet、PVC、RBAC、CRD など）とクラスタ設定。 | [41](41/jp.md) |
| **EKS Pod Identity** | node agent と EKS API で Pod に IAM role を発行する仕組み。cluster OIDC provider や特定クラスタに結び付く trust policy は不要。 | [17](17/jp.md), [47](47/jp.md) |
| **EKS Pod Identity Agent** | node 上で `DaemonSet` として動き、local endpoint 経由で Pod に temporary credentials を配る `eks-pod-identity-agent` addon。 | [17](17/jp.md) |
| **EKS 最適化 AMI** | 必要な version の node component を含む AWS image。AL2023、Bottlerocket、Windows、廃止予定の AL2 family がある。 | [10](10/jp.md) |
| **eksctl** | CloudFormation を通じて動作する公式 EKS CLI。imperative である。 | [0.5](00-5-tools/jp.md) |
| **enableNetworkPolicy** | 標準 NetworkPolicy enforcement を有効にする VPC CNI managed addon parameter。 | [30](30/jp.md) |
| **Encryption at rest** | ECR layer の暗号化。既定は SSE-S3（AES-256）、任意で `aws/ecr` または customer managed key の SSE-KMS。作成時に指定し変更不可。 | [20](20/jp.md) |
| **endpoint service** | 自身のサービス（NLB 配下）を、他 VPC・account の consumer 向け PrivateLink target として公開するもの。 | [31](31/jp.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | endpoint access mode の boolean flag。既定は `true` と `false`。 | [02](02/jp.md) |
| **enforcer** | NetworkPolicy を実際の traffic filter に変換する CNI component。EKS では有効化するまで既定で存在しない。 | [30](30/jp.md) |
| **Enhanced subnet discovery** | `ENIConfig` なしで tag `kubernetes.io/role/cni=1` を持つ subnet。 | [07](07/jp.md) |
| **ENI** | elastic network interface。instance あたりの ENI 数と ENI あたりの IPv4 数は instance type に依存する。 | [0.3](00-3-vpc/jp.md), [06](06/jp.md) |
| **Envelope encryption** | 2 キーの暗号化。DEK が data を、KEK（KMS key）が DEK を暗号化する。EKS は Kubernetes KMS provider v2 で etcd secret に使用する。 | [18](18/jp.md) |
| **ephemeral ports** | 戻り traffic が使う高位 range `1024-65535`。NACL では手動で許可する。 | [46](46/jp.md) |
| **eviction threshold** | kubelet が Pod を eviction する memory buffer の閾値。 | [14](14/jp.md) |
| **exec plugin kubeconfig** | `aws eks get-token` を呼ぶ `exec` section。長期 token は file に置かず、取得 credentials を `client-go` が `status.expirationTimestamp` まで cache する。 | [0.5](00-5-tools/jp.md) |
| **Expander** | Pod が複数 node group に適合する時の Cluster Autoscaler 選択戦略。`least-waste`（既定）、`priority`、`most-pods`、`random`。 | [11](11/jp.md) |
| **Extended support** | standard support（約 12 か月）後の phase。version は引き続きサポートされるが cluster hour の追加料金がかかり、既定で有効。 | [03](03/jp.md), [38](38/jp.md) |
| **External Secrets Operator (ESO)** | AWS から secret を読み native `Secret` を作る controller。`SecretStore`/`ClusterSecretStore` と `ExternalSecret` を使用する。 | [18](18/jp.md) |
| **external-dns** | Kubernetes object（Ingress、Service）と provider の DNS record を同期する controller。AWS では Route 53 を使う。 | [29](29/jp.md) |
| **external.metrics.k8s.io** | HPA の External type 用 external metrics API（queue、topic）。 | [35](35/jp.md) |
| **externalTrafficPolicy** | Service policy。`Cluster`（任意 node へ転送し SNAT）または `Local`（local Pod のみ、client IP 保持）。 | [26](26/jp.md) |
| **`failed to assign an IP address to container`** | VPC CNI が Pod へ IP を割り当てられなかったエラー。node または subnet の address が枯渇している。 | [46](46/jp.md) |
| **failurePolicy** | webhook unavailable 時の動作。`Fail` は admission を停止し、`Ignore` は検証せず object を通す。 | [22](22/jp.md) |
| **Fargate** | node なしで専用 micro-VM 上に Pod を実行する方式。DaemonSet、privilege、`HostNetwork`、GPU、node access は使えない。Pod の vCPU・memory に課金。 | [09](09/jp.md) |
| **fargate-scheduler** | kube-scheduler と並行して動き、profile に合う Pod を Fargate へ送る EKS scheduler。 | [15](15/jp.md) |
| **Fargate profile** | selector（namespace と optional labels）、pod execution role、private subnet を持つ cluster level object。Fargate に送る Pod を決め、変更はできず再作成が必要。 | [15](15/jp.md) |
| **Finding** | GuardDuty の検出結果。Security Hub と EventBridge に送られ alert・response に使う。 | [21](21/jp.md) |
| **Fluent Bit** | C 製の軽量 log forwarder。各 node で DaemonSet として動き、log file を読み、enrich して送信する。 | [34](34/jp.md) |
| **Forbidden (403)** | authorization failure。RBAC が action の権限を許可していない。 | [47](47/jp.md) |
| **game day** | DR と incident scenario を実地検証する演習。 | [48](48/jp.md) |
| **Gatekeeper** | OPA 上の policy engine。Rego rule、`ConstraintTemplate`（template と schema）、`Constraint`（instance）モデルを使う。 | [22](22/jp.md) |
| **Gateway** | listener（protocol、port、TLS）を持つ entry point。platform team が所有し、VPC Lattice では Service Network に対応する。 | [28](28/jp.md) |
| **Gateway API** | traffic 管理用 Kubernetes 標準。Ingress の後継で、役割を分離した型付き resource 群。 | [28](28/jp.md) |
| **gateway endpoint** | route table entry を使う S3・DynamoDB 用 VPC endpoint type。無料。 | [25](25/jp.md), [31](31/jp.md) |
| **GatewayClass** | `controllerName` field を持つ実装 template。どの controller が Gateway を処理するかを決める（IngressClass 相当）。 | [28](28/jp.md) |
| **GitOps** | desired state を Git に記述し、agent が継続的にクラスタをその状態へ収束させるモデル。原則は CNCF project の OpenGitOps が定義する。 | [44](44/jp.md) |
| **GitOps Toolkit** | Flux controller 群（source、kustomize、helm、image など）。 | [44](44/jp.md) |
| **Golden image** | image builder で最適化 AMI の上に構築する再現可能な custom image。 | [10](10/jp.md) |
| **graceful node shutdown** | OS shutdown 時に grace period を使って Pod を終了する kubelet 機能。 | [40](40/jp.md) |
| **Grafana Loki** | stream label のみを index する log store。log は object store に compressed chunk として保存し LogQL で query する。label は低 cardinality にし、高 cardinality には structured metadata を使う。native agent は Grafana Alloy（Promtail は統合済み）。 | [34](34/jp.md) |
| **`granted` (`assume`)** | SSO profile の高速切替と console login。 | [0.5](00-5-tools/jp.md) |
| **Graviton** | arm64 の AWS processor（suffix `g`）。multi-arch image が必要。 | [0.4](00-4-ec2/jp.md) |
| **GuardDuty EKS Protection** | control plane logging を必須にせず、GuardDuty 独自の独立 stream で EKS audit logs の脅威を分析する。 | [21](21/jp.md) |
| **GuardDuty Runtime Monitoring** | `aws-guardduty-agent`（eBPF）による node behavior monitoring。process、network、file を監視し、Fargate と Hybrid Nodes は非対応。 | [21](21/jp.md) |
| **Hard multi-tenancy** | tenant を別々の cluster/account に置く方式。複雑さと引き換えに強い境界を提供する。 | [22](22/jp.md) |
| **HashiCorp Vault** | AWS 以外の外部 secret store で Secrets Manager と同じ位置付け。Pod は Kubernetes、JWT/OIDC、AWS IAM auth で認証し、Vault Agent Injector、Vault Secrets Operator、ESO、Vault provider の CSI Driver で配布する。 | [18](18/jp.md) |
| **head-based と tail-based sampling** | request 結果の前に入口で記録を決める方式 / trace を組み立てた後に gateway で決める方式（error・latency policy）。tail-based では 1 trace の全 span が同じ collector instance に届く必要がある。 | [36](36/jp.md) |
| **helmfile** | version と values を 1 file にまとめた helm release 集合の宣言的記述。 | [0.5](00-5-tools/jp.md) |
| **hop limit (`httpPutResponseHopLimit`)** | IMDS response の network hop 数。1 なら Pod は IMDS に届かず node は動作する。 | [19](19/jp.md) |
| **hosted zone** | Route 53 の domain DNS record container。public（internet）と private（VPC に関連付け）がある。 | [29](29/jp.md) |
| **HPA (HorizontalPodAutoscaler)** | metric に応じて Deployment replica 数を変更する controller。 | [35](35/jp.md) |
| **HTTPRoute** | host、path、header から backend へルーティングする rule。`parentRefs` で Gateway を参照し、VPC Lattice では VPC Lattice Service に対応する。 | [28](28/jp.md) |
| **hub-and-spoke** | central Transit Gateway（hub）に team の VPC（spokes）を接続する topology。 | [32](32/jp.md) |
| **Hubble** | Cilium observability subsystem。flow map と per-flow verdict を提供し、VPC CNI network policy にはない。 | [08](08/jp.md), [30](30/jp.md) |
| **IAM Access Analyzer** | resource-based policy と trust policy の external access で外部 trusted entity を検出する。 | [0.2](00-2-iam/jp.md) |
| **IAM auth policy** | service 間 traffic 認可用 IAM format policy。controller では `IAMAuthPolicy` resource。 | [28](28/jp.md) |
| **IAM database authentication** | password ではなく temporary token（`aws rds generate-db-auth-token`、既定 15 分）で RDS または Aurora に login する方式。rotation は不要。 | [18](18/jp.md) |
| **IAM Identity Center** | permission set によりアクセスを付与する single sign-on。 | [0.1](00-1-aws/jp.md) |
| **IAM OIDC identity provider** | cluster issuer URL を登録する IAM object。role trust policy が参照し、cluster ごとに一度作る。 | [16](16/jp.md) |
| **IAM role** | 永続 key を持たず、一時的に assume する identity。 | [0.2](00-2-iam/jp.md) |
| **IAM user / group** | 長期的な identity とその集合。production では避ける。 | [0.2](00-2-iam/jp.md) |
| **idle capacity** | 支払い済み node capacity と実消費の差。過大な requests と不十分な bin-packing の指標。 | [43](43/jp.md) |
| **image automation** | 新しい image tag を Git に commit し戻す Flux controller。 | [44](44/jp.md) |
| **IMDS** | `169.254.169.254` の Instance Metadata Service。node role の metadata と credentials のソース。IMDSv1 は token なし、IMDSv2 は session-based（`PUT`+token）。 | [0.2](00-2-iam/jp.md), [0.4](00-4-ec2/jp.md), [19](19/jp.md) |
| **Immutable parameter** | 作成後に変更できない cluster parameter。`ipFamily`、custom `serviceIpv4Cidr`、VPC、name、cluster IAM role。 | [04](04/jp.md) |
| **In-place upgrade** | 同じ cluster を次の minor へ upgrade すること。control plane、addon、node の順に行う。 | [03](03/jp.md), [38](38/jp.md) |
| **in-tree cloud provider** | Kubernetes component 内蔵の AWS code。既定では LoadBalancer type Service に Classic Load Balancer を作る。 | [26](26/jp.md) |
| **in-tree provisioner** | 内蔵 `kubernetes.io/aws-ebs`。deprecated で `gp3` と snapshot を扱えない。EKS の default `gp2` は依然これを使う。 | [23](23/jp.md) |
| **IngressClass alb** | controller `ingress.k8s.aws/alb` の class。`ingressClassName: alb` の Ingress は AWS Load Balancer Controller が処理する。 | [27](27/jp.md) |
| **IngressGroup** | `group.name` により複数 Ingress を 1 つの共通 ALB に統合する。`group.order` は rule priority を指定する。 | [27](27/jp.md) |
| **INPUT / FILTER / OUTPUT** | Fluent Bit pipeline section の 3 種。read、process、send。 | [34](34/jp.md) |
| **`InsufficientCidrBlocks`** | address が形式上空いていても連続 block がないことを示す EC2 API error。 | [07](07/jp.md) |
| **Interface endpoint** | PrivateLink 基盤の VPC endpoint type。subnet に ENI を作り、時間料金と data 料金がかかる。 | [31](31/jp.md) |
| **Internet Gateway** | public address 用の無料 internet gateway。 | [0.3](00-3-vpc/jp.md) |
| **involuntary disruption** | node/AZ failure、OOM、spot interruption など制御できない disruption。PDB でなく分散配置で守る。 | [40](40/jp.md) |
| **ipamd** | `aws-node` 内の daemon。node address pool を管理し、secondary address を関連付け、EC2 API で ENI を作る。 | [06](06/jp.md) |
| **`ipFamily`** | cluster の address family。作成時のみ設定できる。 | [07](07/jp.md) |
| **IRSA** | IAM Roles for Service Accounts。OIDC federation に基づき関連付けた `ServiceAccount` を通じて Pod に IAM role を与える。 | [0.2](00-2-iam/jp.md), [16](16/jp.md), [47](47/jp.md) |
| **Karpenter** | 特定の unschedulable Pod 向けに直接 EC2 instance を作る node autoscaler。許可範囲から instance type を自ら選ぶ。 | [11](11/jp.md) |
| **KEDA** | event-driven autoscaling の拡張。HPA に metric を供給し管理する。 | [35](35/jp.md) |
| **`kms:CreateGrant`** | ない場合 driver は自身の CMK で volume を作れても mount できない権限。EBS encryption は grant を使うため key policy にも許可が必要。 | [23](23/jp.md) |
| **krew** | plugin manager。index、`search`、`install`、`upgrade` を備え、独自 index も使える。 | [0.5](00-5-tools/jp.md) |
| **kube-prometheus-stack** | Prometheus Operator、Prometheus、Grafana、Alertmanager、node-exporter、kube-state-metrics を含む Helm chart。 | [33](33/jp.md) |
| **`kube-reserved` / `system-reserved`** | Kubernetes と OS のため kubelet が予約する resources。 | [14](14/jp.md) |
| **kube-state-metrics** | Kubernetes object state（Pending、replica、restart）を metrics として公開する component。 | [33](33/jp.md) |
| **Kubecost** | OpenCost ベースの UI、report、recommendation 製品。EKS には EKS-optimized bundle（addon または Helm）がある。 | [43](43/jp.md) |
| **`kubectl plugin list`** | kubectl が `PATH` 内に見つけた plugin。 | [0.5](00-5-tools/jp.md) |
| **`kubeProxyReplacement`** | kube-proxy の代わりに eBPF で Service/NodePort を balance する Cilium mode。`true` で置換を有効化する。新しい kernel と load balancing の管理が必要。 | [08](08/jp.md) |
| **Kustomization / HelmRelease** | Flux CRD。source の何をどこへ適用するかを記述する。 | [44](44/jp.md) |
| **Kyverno** | policy を YAML resource（`ClusterPolicy`/`Policy`）として記述する policy engine。validate/mutate/generate/verifyImages rule と `Enforce`/`Audit` response を持つ。 | [22](22/jp.md) |
| **Landing zone** | 事前構成済み multi-account structure（management、shared services、environment、team）。AWS Control Tower などで展開する。 | [0.1](00-1-aws/jp.md), [32](32/jp.md) |
| **Launch template** | version 管理可能な instance template（AMI、type、disk、SG、user data、IMDS）。managed node group は常にこれで展開する。 | [10](10/jp.md) |
| **Launch template / Auto Scaling group** | version 管理可能な launch template / AZ subnet にまたがる `min`、`desired`、`max` を持つ instance group。 | [0.4](00-4-ec2/jp.md) |
| **Lifecycle policy** | image を age または count により自動削除する rule。 | [20](20/jp.md) |
| **limits** | container 消費量の上限。 | [14](14/jp.md) |
| **log group / log stream** | CloudWatch Logs における group（通常 application 単位）とその内部 stream（通常 Pod 単位）。 | [34](34/jp.md) |
| **Managed / inline policy** | 再利用可能で version 管理される policy / role に埋め込む policy。 | [0.2](00-2-iam/jp.md) |
| **Managed addon (EKS managed addon)** | AWS が管理する cluster component（VPC CNI、CoreDNS、kube-proxy、CSI）。version は EKS が API を通じて管理する。 | [0.5](00-5-tools/jp.md), [01](01/jp.md), [37](37/jp.md) |
| **managed collector (scraper)** | EKS metrics を agentless で scrape し、remote-write により AMP workspace へ送るマネージド collector。 | [33](33/jp.md) |
| **managed fields / server-side apply** | addon が自身の field を宣言・適用する仕組み。conflict resolution の基盤。 | [37](37/jp.md) |
| **Managed node group** | EKS 管理の EC2 group。AWS が ASG と launch template を管理し、指定により drain して更新するが、OS と node 内容は利用者が担当する。 | [01](01/jp.md), [09](09/jp.md) |
| **Management account** | root payer account。workload はここに置かない。 | [0.1](00-1-aws/jp.md) |
| **`matchLabelKeys`** | scheduling constraint の `labelSelector` に加える Pod label key。`pod-template-hash` と併用すると skew は Deployment の 1 revision 内で計算される。 | [40](40/jp.md) |
| **max-pods** | node あたり Pod 上限。`ENI * (IP per ENI - 1) + 2`。managed node groups は上限 110 または 250。 | [0.4](00-4-ec2/jp.md), [06](06/jp.md), [46](46/jp.md) |
| **maxSkew** | 最も多い domain と最も少ない domain の Pod 数に許される差。 | [40](40/jp.md) |
| **`memory_limiter`** | memory 消費を制限する Collector processor。閾値で `OOMKilled` になる代わりに data の受信を拒否する。最初に置く。 | [36](36/jp.md) |
| **metric_relabel_configs** | scrape config の section（ServiceMonitor では `metricRelabelings`）。保存・remote-write 前に high-cardinality metric（`__name__` の `drop`）と label（`labeldrop`）を捨て、volume と cost を制御する。 | [33](33/jp.md) |
| **Metrics API (`metrics.k8s.io`)** | 現在の resource metrics を返す Kubernetes API。`kubectl top` と resource metrics による HPA の source。 | [33](33/jp.md), [35](35/jp.md) |
| **metrics-server** | kubelet から CPU・memory を収集し、`kubectl top` と HPA 向け Metrics API で返す component。履歴や保存は行わない。 | [33](33/jp.md) |
| **mount target** | 特定 AZ の subnet 内にある EFS network interface。その zone の node に対する入口で、AZ ごとに 1 つ。 | [24](24/jp.md) |
| **Mountpoint for Amazon S3** | bucket object を filesystem interface で公開する client。CSI driver の基盤。 | [25](25/jp.md) |
| **Mountpoint S3 CSI driver** | `aws-mountpoint-s3-csi-driver`。provisioner `s3.csi.aws.com` を含む managed addon。static provisioning のみ。 | [25](25/jp.md) |
| **must have** | これなしでは production への投入が危険で、block すべき項目。 | [48](48/jp.md) |
| **NACL** | subnet level の stateless filter。inbound と outbound rule は独立している。 | [46](46/jp.md) |
| **namespace restore** | cluster-scoped resource（関連 PV を除く）なしで、既存 cluster の最大 5 namespace を個別に restore すること。 | [42](42/jp.md) |
| **NAT Gateway** | private subnet に internet への outbound access を与える AWS managed address translation service。時間料金と処理 GB 料金がかかる。 | [0.3](00-3-vpc/jp.md), [31](31/jp.md) |
| **`ndots:5`** | Pod resolv.conf の設定。name に対し search domain を試行する。 | [46](46/jp.md) |
| **nested (child) recovery point** | composite 内の子 recovery point。cluster state または個別 volume。 | [41](41/jp.md) |
| **Network ACL** | subnet の stateless filter。rule number で allow と deny を定義する。 | [0.3](00-3-vpc/jp.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | Pod 起動時 policy enforcement mode。`standard`（default allow、policy のない window あり）または `strict`（default deny）。 | [08](08/jp.md), [30](30/jp.md) |
| **NetworkPolicy** | Pod に許可する ingress・egress を宣言する標準 Kubernetes object。enforcer なしでは何も block しない。 | [30](30/jp.md) |
| **nice to have** | 成熟度を高める項目。production 運用開始後に対応してもよい。 | [48](48/jp.md) |
| **NLB (Network Load Balancer)** | 高性能、static IP を持つ L4（TCP/UDP）load balancer。LBC が LoadBalancer type Service から作る。 | [26](26/jp.md) |
| **node instance role** | EC2 node が assume する IAM role。kubelet はこれで AWS API を呼ぶ。 | [45](45/jp.md) |
| **Node Termination Handler (NTH)** | Karpenter なしの managed/self-managed node で interruption を処理する AWS component。IMDS と Queue Processor mode がある。 | [13](13/jp.md) |
| **nodeadm** | AL2023 と Bottlerocket の node initializer。入力は YAML `NodeConfig` manifest（`apiVersion: node.eks.aws/v1alpha1`）で、`bootstrap.sh` の後継。 | [10](10/jp.md), [45](45/jp.md) |
| **NodeClaim** | 特定 node に対する Karpenter claim。`NodePool` と実際の `Node` を結び付ける。 | [12](12/jp.md) |
| **NodeCreationFailure** | managed node group health issue。起動後 15 分以内に node が cluster へ join しなかった。 | [45](45/jp.md) |
| **NodeLocal DNSCache** | node 上の local caching DNS。CoreDNS の負荷と ENI ごとの throttling を軽減する。 | [46](46/jp.md) |
| **NodePool** | node 境界を定義する CRD（`karpenter.sh/v1`）。`requirements`、`limits`、`weight`、labels/taints、disruption policy を指定する。 | [12](12/jp.md) |
| **NodePool と NodeClass** | どの node をどう起動するかを記述する object。Auto Mode の default は変更不可だが独自のものは追加可能。 | [09](09/jp.md) |
| **non-destructive restore** | 既存 object を上書きせず skip する restore mode。skip は SNS で確認できる。 | [42](42/jp.md) |
| **kubelet は生きているのに NotReady** | 通常は CNI が ready でなく、Pod に IP が発行されない。 | [45](45/jp.md) |
| **OIDC issuer URL** | projected token の public signing key を公開する cluster public OIDC endpoint（`oidc.eks.<region>.amazonaws.com/id/`）。 | [16](16/jp.md) |
| **On-demand / Spot** | 従量課金 / 割引価格で 2 分前通知による中断がある capacity。 | [0.4](00-4-ec2/jp.md) |
| **OOMKilled** | memory limit 超過時に kernel が container を kill した状態。 | [14](14/jp.md) |
| **OpenCost** | vendor-neutral なオープンな cost allocation standard・engine で CNCF project。Prometheus の消費量と AWS resource price を使う。 | [43](43/jp.md) |
| **OpenSearch Service** | full-text search と dashboard 用のマネージド OpenSearch。cluster（node）に課金する。 | [34](34/jp.md) |
| **OpenTelemetry (OTel)** | 共通 API、SDK、protocol を定める CNCF standard。instrumentation と backend を分離する。 | [36](36/jp.md) |
| **OpenTelemetry Collector** | telemetry collector。receivers が受信し、processors が処理し、exporters が backend へ出力する。 | [36](36/jp.md) |
| **OpenTelemetry Operator** | agent injection により Pod の auto-instrumentation を行う operator。 | [36](36/jp.md) |
| **OpenTofu** | コース module と互換の open source terraform fork。`terraform_binary = "tofu"` attribute で選択する。 | [0.5](00-5-tools/jp.md) |
| **OTLP** | application から collector、および collector 間で telemetry を送る protocol。 | [36](36/jp.md) |
| **OU** | policy を適用する account の group。 | [0.1](00-1-aws/jp.md) |
| **ownership** | domain または checklist item に対する明確な責任。 | [48](48/jp.md) |
| **Permissions boundary** | role または user の権限上限。権限自体は付与しない。 | [0.2](00-2-iam/jp.md) |
| **Placement group** | instance placement 制御。`cluster`（近接、最低 latency、1 AZ）、`partition`（partition ごとの別 rack、AZ あたり最大 7）、`spread`（別 hardware、AZ あたり稼働最大 7）。 | [0.4](00-4-ec2/jp.md) |
| **`placementGroupSelector`** | 独自 `NodeClass` で name または id により placement group を選ぶ field。group は事前作成し、Pod は `eks.amazonaws.com/placement-group-id` label の `nodeSelector` で所属を指定する。 | [09](09/jp.md), [12](12/jp.md) |
| **Platform version** | Kubernetes minor 内の EKS control plane の patch level と feature set。`eks.<n>` 形式で AWS が自動更新する。 | [01](01/jp.md), [02](02/jp.md) |
| **pluto / kube-no-trouble (kubent)** | deprecated API を探すツール。pluto は Git・Helm、kubent は稼働中 cluster を調べる。 | [38](38/jp.md) |
| **Pod execution role** | Fargate 基盤の `kubelet` が cluster に登録し ECR から image を pull する IAM role。profile 作成時に指定する。組み込み log router の送信権限もこの role に必要。 | [15](15/jp.md) |
| **Pod Identity association** | `cluster + namespace + ServiceAccount` を IAM role に結び付ける EKS API record。`aws eks create-pod-identity-association` で作成する。 | [17](17/jp.md), [37](37/jp.md) |
| **pod readiness gate** | Pod の追加 readiness 条件。AWS Load Balancer Controller は target が `healthy` になるまで `target-health.elbv2.k8s.aws` を false に保つ。 | [40](40/jp.md) |
| **Pod Security Admission (PSA)** | namespace label を通じ Pod Security Standards を適用する組み込み admission controller。Pod Security Policies の後継。 | [19](19/jp.md) |
| **Pod Security Standards** | privileged、baseline、restricted（厳格、production 用）の profile。 | [19](19/jp.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | source NAT なしの `strict` と、VPC 外 traffic が primary ENI・node SG rule を使う `standard`。 | [46](46/jp.md) |
| **PodDisruptionBudget (PDB)** | 自発的 disruption 時に同時 eviction 可能な Pod 数を制限する object（`minAvailable`/`maxUnavailable`）。 | [40](40/jp.md) |
| **`pods.eks.amazonaws.com`** | Pod Identity role trust policy の service principal。全 cluster・account に共通。EKS Auth API が `AssumeRoleForPodIdentity` で role credentials を発行する。 | [17](17/jp.md) |
| **Policy** | `Version`、`Statement`、`Effect`、`Action`、`Resource`、`Condition` を持つ JSON。identity-based（principal 上）と resource-based（resource 自体）がある。 | [0.2](00-2-iam/jp.md) |
| **Policy engine** | 独自 rule を持つ admission webhook（Kyverno、Gatekeeper）。etcd への書き込み前に rule により object を検査し必要なら変更する。 | [22](22/jp.md) |
| **`pollingInterval` と `cooldownPeriod`** | KEDA source の polling period（既定 30 秒）と zero へ戻すまでの待機（既定 300 秒）。後者は scale-to-zero のみに効く。 | [35](35/jp.md) |
| **Prefix delegation** | ENI slot を `/28` prefix（16 address）で使う mode。`ENABLE_PREFIX_DELEGATION` で有効化し Nitro が必要。 | [07](07/jp.md), [46](46/jp.md) |
| **preserve_client_ip** | `ip` mode で source client IP を保持するかを制御する NLB target group attribute。 | [26](26/jp.md) |
| **preStop** | SIGTERM 前に実行する hook。停止前の待機に使う。 | [40](40/jp.md) |
| **Principal** | request を実行する主体。user、role、AWS service。 | [0.2](00-2-iam/jp.md) |
| **private / public endpoint** | cluster API server への access mode。 | [45](45/jp.md) |
| **Private hosted zone** | endpoint name を private address へ解決するため EKS が作成し利用者 VPC に関連付ける Route 53 zone。 | [02](02/jp.md) |
| **Projected service account token** | SA identity、audience `sts.amazonaws.com`、lifetime を持つ OIDC 互換 JWT。Pod に mount され STS で credentials と交換する。 | [16](16/jp.md) |
| **prometheus-adapter** | Prometheus metric を custom/external API に公開する adapter。 | [35](35/jp.md) |
| **provisioningMode: efs-ap** | driver が PVC ごとに access point を作る StorageClass mode。 | [24](24/jp.md) |
| **`publicAccessCidrs`** | public endpoint を許可する CIDR list。既定は `0.0.0.0/0`。 | [02](02/jp.md) |
| **Pull through cache** | 外部 registry（Docker Hub、Quay、`registry.k8s.io` など）の image を demand 時に private ECR へ cache する ECR rule。 | [20](20/jp.md) |
| **pull model** | cluster 内 agent 自身が Git から pull する model。push は外部 pipeline。 | [44](44/jp.md) |
| **QoS class** | `Guaranteed`、`Burstable`、`BestEffort`。memory 不足時の eviction 順序を定める。 | [14](14/jp.md) |
| **ReadWriteMany (RWX)** | access mode。volume を複数 node 上の複数 Pod が同時に read/write mount できる。 | [24](24/jp.md) |
| **Rebalance recommendation** | 2 分の notice より早く届く、reclaim risk 上昇の早期 signal。あらかじめ workload を退避する時間を与える。 | [13](13/jp.md) |
| **recovery point** | 成功した backup job の結果である復旧ポイント。 | [41](41/jp.md) |
| **ReferenceGrant** | target resource namespace に置く Gateway API resource。列挙した namespace からの cross-namespace reference（`backendRefs`、`certificateRefs`）を許可する。 | [28](28/jp.md) |
| **Replication configuration** | image を他 region・account へ複製する ECR rule。cross-account では受信 account が registry policy で source に `ecr:CreateRepository` と `ecr:ReplicateImage` を許可する。 | [20](20/jp.md) |
| **Repository creation template** | prefix により pull through cache 用 repository を ECR が自動作成する時の設定 template（encryption、lifecycle、immutability、policy）。なければ `MUTABLE`、SSE-S3、policy なしが既定。 | [20](20/jp.md) |
| **Repository policy / registry policy** | 個別 repository / account 全体 registry の resource-based policy。`aws:PrincipalOrgID` が使えるため、組織全体へ一度に pull を許可できる。 | [20](20/jp.md), [32](32/jp.md) |
| **requests** | packing と autoscaler 判断に使う resource 量。Pod の予約。 | [14](14/jp.md) |
| **resolveConflicts** | field conflict 時の addon 動作。`NONE`、`OVERWRITE`、`PRESERVE`。 | [37](37/jp.md) |
| **Resource Modifiers** | restore 時に object へ JSON patch を当てる Velero ConfigMap（`--resource-modifier-configmap`）。target cluster と非互換の field を除去する。 | [42](42/jp.md) |
| **ResourceQuota / LimitRange** | namespace の合計消費上限 / 個別 container の default・境界。 | [22](22/jp.md) |
| **restore hook** | Pod restore 時に Velero が実行する init container または exec command。 | [42](42/jp.md) |
| **restore job** | AWS Backup の復元 job。`start-restore-job` で起動し、`list-restore-jobs`/`describe-restore-job` で追跡する。 | [42](42/jp.md) |
| **retention policy** | log group の log 保持期間。経過後に record を削除する。既定で log は期限切れにならない。 | [34](34/jp.md) |
| **right-sizing** | node を効率化するため requests/limits を実消費に合わせること。 | [14](14/jp.md), [43](43/jp.md) |
| **rollback readiness** | version rollback の準備状態。window と順序が分かっている。 | [48](48/jp.md) |
| **rollback readiness insights** | `ROLLBACK_READINESS` category の cluster insights type。rollback 準備を確認し、PASSING/WARNING/ERROR/UNKNOWN status を返す。 | [39](39/jp.md) |
| **Root user** | 無制限権限の account owner。初期設定時だけ使う。 | [0.1](00-1-aws/jp.md) |
| **Route 53 Resolver** | 「CIDR + 2」アドレスにある VPC 組み込み DNS。CoreDNS の upstream。 | [0.3](00-3-vpc/jp.md) |
| **Route table** | subnet の routing table。public と private subnet の違いは default route だけ。 | [0.3](00-3-vpc/jp.md) |
| **RPO** | 許容する data loss 量。backup frequency で決まる。 | [42](42/jp.md) |
| **RTO** | 障害後に service を復旧する目標時間。 | [42](42/jp.md) |
| **S3 Express One Zone** | 1 AZ 内の低 latency・高 IOPS storage class（directory buckets）。general purpose bucket と異なり `append` をサポートする。 | [25](25/jp.md) |
| **S3 Object Lock** | S3 bucket の WORM protection。retention 中の object version を不変にする（Governance/Compliance）。Velero backup を削除・暗号化から保護する。 | [42](42/jp.md) |
| **sampling** | volume と cost を制御するため全 trace ではなく一部だけを記録すること。 | [36](36/jp.md) |
| **sampling rules** | reservoir と fixed rate で記録する request の割合を定める X-Ray rule。 | [36](36/jp.md) |
| **Savings Plans / RI** | 1 または 3 年の commitment に対する 30-70% の割引。 | [0.4](00-4-ec2/jp.md) |
| **scale-to-zero** | idle 時に Deployment を 0 replica へ下げること。KEDA は可能だが HPA は不可。 | [35](35/jp.md) |
| **ScaledJob** | work batch に合わせて parallel Job 数を scaling する KEDA CRD。 | [35](35/jp.md) |
| **ScaledObject** | Deployment の scaling target と trigger を記述する KEDA CRD。 | [35](35/jp.md) |
| **scaler** | KEDA metric source。`aws-sqs-queue`、`aws-cloudwatch`、`prometheus`、`kafka`、`cron` など多数。 | [35](35/jp.md) |
| **Schedule** | cron による定期 backup の Velero object。RPO を定める。 | [42](42/jp.md) |
| **SCP (Service Control Policy)** | OU または account に対する制限 policy。最大権限を定めるが権限自体は許可しない。 | [0.1](00-1-aws/jp.md), [0.2](00-2-iam/jp.md) |
| **Secondary CIDR** | VPC の追加 IPv4 block。EKS では通常 `100.64.0.0/10`（RFC 6598）から取る。 | [07](07/jp.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | AWS secret を node 上の volume に file として mount する driver。`SecretProviderClass` object と、optional な `Secret` sync を使う。 | [18](18/jp.md) |
| **Security group** | ENI の stateful firewall。allow のみで、別の SG を source にできる。 | [0.3](00-3-vpc/jp.md), [46](46/jp.md) |
| **`SecurityGroupPolicy`** | selector で Pod に SG を関連付ける resource（security groups for pods）。branch ENI の Pod は node SG rule を継承しない。 | [46](46/jp.md) |
| **self-heal** | Git の状態へ drift を自動的に戻すこと。 | [44](44/jp.md) |
| **self-managed addon** | Helm または manifest で導入する component。lifecycle と互換性はすべて engineer が担う。 | [37](37/jp.md) |
| **Self-managed node** | 自身で起動・join する EC2 instance（`EC2_LINUX` type access entry）。node の全 lifecycle を利用者が管理する。 | [09](09/jp.md) |
| **service map** | service と接続の map。edge ごとに latency と error rate を示す。 | [36](36/jp.md) |
| **Service Network** | service 集合の VPC Lattice boundary。client VPC を関連付けて service へアクセスさせる。 | [28](28/jp.md) |
| **Service Quotas** | account・region ごとの service limit。request により増量できる。 | [0.1](00-1-aws/jp.md) |
| **`serviceIpv4Cidr`** | VPC と無関係な virtual Service address range。 | [06](06/jp.md) |
| **ServiceMonitor, PodMonitor** | scrape する endpoint を宣言的に記述する Prometheus Operator CRD。 | [33](33/jp.md) |
| **Session tags** | Pod Identity が STS request に付ける session tag（cluster、namespace、SA）。ABAC の基盤となり、policy では `aws:PrincipalTag/kubernetes-namespace` と `aws:PrincipalTag/eks-cluster-name` を使う。trust policy に `sts:TagSession` が必要。 | [17](17/jp.md) |
| **shared costs** | cluster の共有費用（control plane、system namespace、idle）。rule によって team に配賦するか、別表示する。 | [43](43/jp.md) |
| **Shared responsibility** | AWS は cloud の security を、利用者は cloud 内の security を担当する。 | [0.1](00-1-aws/jp.md), [01](01/jp.md) |
| **shared services account** | 他 account が使う共有 resource（ECR、private DNS zone、observability）を置く account。 | [32](32/jp.md) |
| **shared VPC** | owner が RAM で subnet を共有し、他 account がそこに EKS node を含む自分の resource を起動する model。 | [32](32/jp.md) |
| **showback** | 金銭移動をせず team に費用を見せること。 | [43](43/jp.md) |
| **SNAT** | Pod outbound traffic の source address を node address に置き換えること。`AWS_VPC_K8S_CNI_EXTERNALSNAT` で無効化する。 | [06](06/jp.md) |
| **Soft multi-tenancy** | 同一 cluster の tenant を namespace、RBAC、ResourceQuota、LimitRange、NetworkPolicy、policy で分離する方式。control plane と core は共有。 | [22](22/jp.md) |
| **span** | trace 内の個別操作（処理、call、database request）。time と attribute を持ち、span で trace tree を構成する。 | [36](36/jp.md) |
| **split-horizon DNS** | public/private zone の組み合わせにより、同じ name に VPC 外と内で異なる応答を返す DNS。 | [29](29/jp.md) |
| **Spot interruption notice** | instance stop・terminate の 2 分前に届く interruption notice。正常終了に使える時間は限られる。 | [13](13/jp.md) |
| **Spot instance** | on-demand demand に必要になれば AWS がいつでも回収できる、割引された未使用 EC2 capacity。 | [13](13/jp.md) |
| **Spot pool** | 「instance type + availability zone」の組み合わせ。capacity は pool 単位で回収される。 | [13](13/jp.md) |
| **ssl-redirect** | 指定 listener port への HTTP から HTTPS redirect を有効にする annotation。 | [27](27/jp.md) |
| **SSM Session Manager** | SSM agent を使い SSH なしで instance にアクセスする仕組み。 | [45](45/jp.md) |
| **Staging labels** | Secrets Manager の secret version label。既定で `AWSCURRENT` を読み、`AWSPENDING` は rotation 中の検証値、`AWSPREVIOUS` は前の値。 | [18](18/jp.md) |
| **Stakater Reloader** | mount した `Secret` または `ConfigMap` の変更時、annotation に応じて Deployment を rolling restart し、新しい値を Pod に反映する controller。 | [18](18/jp.md) |
| **Standard support** | EKS の minor version support phase（約 14 か月）。version 追加料金なしの通常運用。 | [03](03/jp.md), [38](38/jp.md), [48](48/jp.md) |
| **State** | Terraform code と実 resource の対応を記録する file。versioning と write lock を有効にした S3 に保存する。 | [0.5](00-5-tools/jp.md), [04](04/jp.md) |
| **stdout/stderr** | container の standard output stream。Kubernetes の慣例では application は container 内 file でなくここへ log を出す。 | [34](34/jp.md) |
| **STS** | temporary key の service。`sts:AssumeRole`、`sts:AssumeRoleWithWebIdentity`。 | [0.2](00-2-iam/jp.md) |
| **Subnet CIDR reservation** | prefix 用に subnet 内の連続 block を予約すること。 | [07](07/jp.md) |
| **subnet IP exhaustion** | subnet の ENI・Pod 用 free address が尽きた状態。 | [46](46/jp.md) |
| **sync waves** | Argo CD の sync phase 内で resource を適用する wave の順序。 | [44](44/jp.md) |
| **Tag immutability** | `IMMUTABLE` repository mode。別 image による tag 上書きを禁止する。`MUTABLE`（既定）は上書きを許可する。 | [20](20/jp.md) |
| **target EKS cluster** | restore を行う既存 cluster。または AWS Backup が restore 時に作成する cluster（`newCluster=true`）。 | [42](42/jp.md) |
| **target-type** | NLB target type。`instance`（node の `NodePort` 経由）または `ip`（直接 Pod IP、VPC CNI が必要で Fargate では必須）。 | [26](26/jp.md), [27](27/jp.md) |
| **`terminationGracePeriod`** | node drain の上限。この指定があれば block する PDB と `do-not-disrupt` があっても drift が実行される。 | [12](12/jp.md) |
| **terminationGracePeriodSeconds** | Pod 終了における SIGTERM と SIGKILL の間隔（既定 30）。 | [40](40/jp.md) |
| **terragrunt** | terraform wrapper。共通 backend、`env.hcl`、`dependency`、`run-all`、copy-paste しない DRY module を提供する。 | [0.5](00-5-tools/jp.md) |
| **Thanos** | Prometheus に object store の長期保存を加える component 群。`sidecar` は S3 に block を出し、`store gateway` は読み戻し、`compactor` は compact・downsampling・retention を行い、`querier` は単一 PromQL と HA pair deduplication、`ruler` は履歴に対する rule を実行する。 | [33](33/jp.md) |
| **throughput mode** | EFS throughput mode。Elastic、Bursting、Provisioned。 | [24](24/jp.md) |
| **topology aware routing** | client と同じ zone の endpoint を優先する routing。Service の `trafficDistribution: PreferClose` で有効化する。 | [31](31/jp.md) |
| **topologySpreadConstraints** | domain 間の replica 均等配置を定める Pod field（`maxSkew`、`topologyKey`、`whenUnsatisfiable`、`minDomains`）。 | [40](40/jp.md) |
| **trace** | 共通 `trace id` を持つ、複数 service を通る 1 request の全経路。 | [36](36/jp.md) |
| **Transit Gateway** | 接続した VPC、VPN、Direct Connect 間を transitive routing する regional router hub。RAM で共有できる。 | [32](32/jp.md) |
| **TriggerAuthentication** | trigger access parameter を持つ KEDA CRD。AWS には IRSA または Pod Identity を通じる `aws` provider がある。 | [35](35/jp.md) |
| **Trust policy** | role trust policy。`Federated` principal（OIDC provider ARN）、`sts:AssumeRoleWithWebIdentity` の `Action`、`sub` と `aud` の `StringEquals` condition を持つ。 | [0.2](00-2-iam/jp.md), [16](16/jp.md), [47](47/jp.md) |
| **TXT registry** | external-dns が自身の record に TXT marker を付ける仕組み。owner は `--txt-owner-id` で指定する。 | [29](29/jp.md) |
| **Unauthorized (401)** | authentication failure。identity が証明されていないか mapping されていない。 | [47](47/jp.md) |
| **`unhealthyPodEvictionPolicy`** | PDB field。`IfHealthyBudget`（既定）は application がすでに壊れている場合に unhealthy Pod の eviction を防ぎ、`AlwaysAllow` は常に許可する。 | [40](40/jp.md) |
| **upgrade insights** | upgrade readiness と removed API を示す insights type。 | [38](38/jp.md) |
| **Upgrade policy (`supportType`)** | `STANDARD` と `EXTENDED` を持つ cluster config field。standard support 終了時の動作を定める。extended support は既定で有効で、policy 切替では抜けられず upgrade が必要。 | [03](03/jp.md) |
| **`useCachedMetrics` と `fallback`** | polling interval 内の値の caching と、source unavailable 時の replica 数。API throttling と `TARGETS` の `<unknown>` のリスクを下げる。 | [35](35/jp.md) |
| **User data** | instance の初回起動時に実行する script または config。bootstrap を開始し `kubelet` を設定する。 | [0.4](00-4-ec2/jp.md), [10](10/jp.md) |
| **ValidatingAdmissionPolicy** | external webhook なしで CEL により validation する apiserver 組み込み機能（Kubernetes 1.30+）。`ValidatingAdmissionPolicyBinding` と組にし、適用先と `Deny`/`Warn`/`Audit` response を定める。 | [22](22/jp.md) |
| **Vault Lock** | backup 削除を防ぐ vault の WORM protection。governance mode（IAM で解除可能）と、grace time 後に不変の compliance mode がある。 | [41](41/jp.md) |
| **Velero** | Kubernetes-native backup/restore。object は S3（BackupStorageLocation）、volume は CSI snapshot または File System Backup で扱う。 | [42](42/jp.md) |
| **velero-plugin-for-aws** | AWS 向け公式 Velero plugin。S3 の object store（BSL）と EBS snapshot の volume snapshotter を提供する。 | [42](42/jp.md) |
| **Version skew** | upstream policy が許す kubelet と API server の version 差。「control plane を先に、node を後に」の順になる理由。 | [03](03/jp.md), [37](37/jp.md) |
| **version skew policy** | Kubernetes rule。node は control plane より新しくできず、rollback 順序は node を先に、control plane を後にする。 | [38](38/jp.md), [39](39/jp.md) |
| **VersionRollback** | rollback 時の `update-cluster-version` response にある update type。 | [39](39/jp.md) |
| **VictoriaLogs** | dependency のない schema-less log database。disk 上の columnar storage、LogsQL query、Elasticsearch bulk・Loki push・OTLP・syslog protocol による受信を提供する。cluster variant は `vlinsert`、`vlstorage`、`vlselect`。 | [34](34/jp.md) |
| **VictoriaMetrics** | metric store の置換であり拡張ではない。収集は `vmagent`、保存は `vmsingle` または `vminsert`/`vmstorage`/`vmselect` cluster、rule は `vmalert`、retention は `-retentionPeriod`、言語は PromQL 拡張の MetricsQL。 | [33](33/jp.md) |
| **volume node affinity conflict** | volume の `nodeAffinity` が適合 node のない zone を指す scheduler event。 | [23](23/jp.md) |
| **`volumeBindingMode`** | volume の provision 時期。`Immediate`（PVC 作成時）または `WaitForFirstConsumer`（Pod scheduling 時）。 | [23](23/jp.md) |
| **VolumeSnapshot / Content / Class** | CSI snapshot object。request、AWS snapshot、class。 | [23](23/jp.md) |
| **voluntary disruption** | drain、node upgrade、consolidation など意図的な Pod eviction。PDB で保護する。 | [40](40/jp.md) |
| **VPC** | region 内の隔離 network。primary CIDR（`/16` ... `/28`）は不変で、secondary CIDR でのみ拡張できる。 | [0.3](00-3-vpc/jp.md) |
| **VPC CNI** | VPC subnet から実際の private address を Pod に割り当てる AWS network plugin。`kube-system` の `aws-node` DaemonSet。 | [06](06/jp.md) |
| **VPC CNI network policy** | eBPF による組み込み `NetworkPolicy` 実装。control plane controller と `aws-node` 内の `aws-network-policy-agent` からなり、addon parameter `enableNetworkPolicy` で有効化する。 | [08](08/jp.md), [30](30/jp.md) |
| **VPC endpoint** | AWS service への private access。gateway（S3、DynamoDB）または interface（PrivateLink）。 | [0.3](00-3-vpc/jp.md), [31](31/jp.md) |
| **VPC endpoint (PrivateLink)** | VPC 内の AWS service への private entry point。private data plane では ECR、S3、STS、EKS などに必須。 | [19](19/jp.md) |
| **VPC Flow Logs** | accepted/rejected flow の記録。CloudWatch Logs Insights の `action = REJECT` filter は SecOps と診断に使う。 | [0.3](00-3-vpc/jp.md) |
| **VPC Lattice** | sidecar・peering なしで VPC・account 間の east-west communication を提供するマネージド application networking service。 | [28](28/jp.md) |
| **VPC peering** | 2 VPC を 1 対 1 で直接接続するもの。transitive ではなく、CIDR の重複は不可。 | [32](32/jp.md) |
| **wafv2-acl-arn** | request filter 用 AWS WAF v2 Web ACL を ALB に結び付ける annotation。 | [27](27/jp.md) |
| **warm pool** | Pod を高速起動するため node にあらかじめ割り当てた予備 IPv4 address。 | [06](06/jp.md) |
| **`WARM_PREFIX_TARGET`** | node の prefix 予備数。`WARM_IP_TARGET` と `MINIMUM_IP_TARGET` がこれより優先される。 | [07](07/jp.md) |
| **workspace** | 独自 remote-write endpoint と Prometheus 互換 API を持つ、AMP 内の隔離 metric store。 | [33](33/jp.md) |
| **X-Amzn-Trace-Id** | `Root`、`Parent`、`Sampled` field を持つ X-Ray header。ADOT X-Ray propagator は W3C `traceparent` に対応付け、end-to-end の `trace id` を維持する。 | [36](36/jp.md) |
| **ZoneId (`euc1-az1`)** | 全 account で同じ stable な availability zone name。 | [0.1](00-1-aws/jp.md) |
| **addon `adot`** | collector 管理用 ADOT Operator を展開する EKS managed addon。 | [36](36/jp.md) |
| **アカウント** | 隔離された resource 空間であり billing unit。12 桁番号は ARN と trust policy に使われる。 | [0.1](00-1-aws/jp.md) |
| **secondary private address** | node ENI 上の追加 IPv4 address。Pod に割り当てる。 | [06](06/jp.md) |
| **多様化** | 複数 AZ の多くの instance type を使い、1 pool の回収で critical node の大部分を失わないようにすること。 | [13](13/jp.md) |
| **準備ドメイン** | control plane、node、security、network、storage、observability、operations、incident という、個別に確認する 1 つの運用軸。 | [48](48/jp.md) |
| **drift（差異）** | 実際の状態と code または Git に記述した状態の不一致。 | [04](04/jp.md), [44](44/jp.md) |
| **stack 間依存関係** | 1 stack の output を別 stack の input に渡すこと（Terragrunt の `dependency` block）。 | [04](04/jp.md) |
| **EC2 instance** | virtual machine。EKS では containerd と kubelet を持つ node。 | [0.4](00-4-ec2/jp.md) |
| **local cache** | node volume の Mountpoint data cache（`cache: emptyDir`/`ephemeral`）。繰り返し read を高速化する。metadata cache は `metadata-ttl` で設定する。 | [25](25/jp.md) |
| **node scaling と Pod scaling** | 別の層。node は CA と Karpenter、Pod は HPA、VPA、KEDA が scale する。 | [11](11/jp.md) |
| **micro-VM** | 専用 kernel、CPU、memory、network interface を持つ 1 Pod 用 virtual machine。Fargate の isolation boundary。 | [15](15/jp.md) |
| **object storage** | key-value model。byte と metadata の object を string key に置き、不変で、`PutObject` により全体置換する。 | [25](25/jp.md) |
| **rollback window（7 日）** | upgrade 後に rollback が可能な期間。期限後は rollback とその insights を利用できない。 | [39](39/jp.md) |
| **kubectl plugin** | `PATH` にある `kubectl-<name>` file。`kubectl <name>` として使える。 | [0.5](00-5-tools/jp.md) |
| **subnet** | 1 AZ 内の VPC CIDR の一部。 | [0.3](00-3-vpc/jp.md) |
| **完全置換** | `aws-node` を削除し、Cilium を独自 IPAM の唯一の CNI にすること。ENI IPAM（実 VPC address）または cluster-pool（overlay/VXLAN、virtual address）を使う。 | [08](08/jp.md) |
| **prefix** | Mountpoint が directory をエミュレートする `/` より前の key 部分。S3 に本物の directory はない。 | [25](25/jp.md) |
| **強制 upgrade** | extended support 終了時の自動 version upgrade。この cluster は rollback できない。 | [38](38/jp.md) |
| **provider** | terraform plugin（`aws`、`kubernetes`、`helm`）。 | [0.5](00-5-tools/jp.md) |
| **progressive delivery** | application の canary/blue-green deploy（Argo Rollouts、Flagger）。 | [44](44/jp.md) |
| **production checklist** | domain ごとの readiness を体系的に検証する一覧。各項目を完了するか既知リスクとして記録する。 | [48](48/jp.md) |
| **profile** | region、role、SSO の名前付き parameter set。 | [0.5](00-5-tools/jp.md) |
| **region** | resource が属する地理的拠点（`eu-central-1`）。 | [0.1](00-1-aws/jp.md) |
| **external mode** | `aws-load-balancer-type` annotation の値。Service reconciliation を in-tree provider でなく外部 LBC controller に委ねる。 | [26](26/jp.md) |
| **EBS access modes** | `ReadWriteOnce`（1 node）と `ReadWriteOncePod`（厳密に 1 Pod）。`ReadWriteMany` は 1 AZ の `volumeMode: Block` で filesystem なしの `io2` Multi-Attach のみ可能。共有 filesystem access には EFS または FSx を使う。 | [23](23/jp.md) |
| **reconciliation** | desired state（Git）と actual state（cluster）を継続的に照合する loop。 | [44](44/jp.md) |
| **static provisioning** | PV を `bucketName` で手動記述すること。driver は dynamic provisioning と bucket 作成を行わない。 | [25](25/jp.md) |
| **stack** | 独自 state を持ち、独立して適用する infrastructure unit。 | [0.5](00-5-tools/jp.md), [04](04/jp.md) |
| **rotation strategy** | `single user`（1 user の password を変更。短い failure risk window は遅延付き retry で補う）または `alternating users`（2 user を交互に使い常に valid credentials を保つ。superuser 権限の secret が必要）。 | [18](18/jp.md) |
| **Spot strategy** | pool の選択方法。`capacity-optimized(-prioritized)` または `lowest-price`。capacity 重視は interruption が少ない。 | [0.4](00-4-ec2/jp.md) |
| **tag** | key/value pair。EKS controller は tag で resource を探し、有効化した cost allocation tag は billing の内訳に使う。 | [0.1](00-1-aws/jp.md) |
| **instance type** | `family + generation + suffix . size`。例: `m7g.xlarge`。 | [0.4](00-4-ec2/jp.md) |
| **control plane log types** | `api`、`audit`、`authenticator`、`controllerManager`、`scheduler`。有効化後にのみ CloudWatch Logs へ書かれる。 | [02](02/jp.md) |
| **Argo CD 向け EKS managed capability** | EKS Capability としての Argo CD。controller は AWS control plane 内、target は ARN による EKS cluster のみで、それらへの access は EKS access entries 経由。 | [44](44/jp.md) |
| **kubernetes filter** | namespace、Pod、container、labels、annotations を record に追加する Fluent Bit FILTER。 | [34](34/jp.md) |
| **Argo CD sharding** | 接続済み cluster を application-controller replica に分配すること。 | [44](44/jp.md) |
| **`--force`** | insights の check（ERROR/WARNING/UNKNOWN）を迂回する flag。ただし前提条件（window、1 minor、created-on-version、feature compatibility）は迂回しない。 | [39](39/jp.md) |
| **/var/log/containers** | container log file への link がある node directory。collector はここから log を取得する。 | [34](34/jp.md) |
