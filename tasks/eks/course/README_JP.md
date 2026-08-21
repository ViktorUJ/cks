[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md)

# Amazon EKS: 本番運用を実践的に学ぶ自習ガイド

`tasks/eks/labs` のラボに連動した Amazon EKS の実践コースです。このコースは、**すでに CKA を修了している**、または Kubernetes 管理者レベルの知識に自信があり、AWS のマネージドクラスターの運用へ移行するエンジニア向けです。

EKS 専用の認定資格はないため、このコースは試験対策ではなく実際の運用を中心に構成されています。control plane は AWS が管理する一方で、ノード、ネットワーク、アクセス、コスト、アップグレードは利用者が担うという現実に焦点を当てます。

> **前提知識。** Pod、Deployment、Service、Ingress、RBAC、PV/PVC、probe、`kubectl`、ワークロードのデバッグは CKA コースの基礎であり、ここでは繰り返しません。これらのトピックをまだ学んでいない場合は、まず [CKA + CKAD コース](../../cka/course/README_JP.md)から始めてください。

> **バージョン。** このコースは最新の EKS バージョン（Kubernetes `1.33` - `1.36`）を対象としています。EKS には独自のバージョンライフサイクルがあり、standard support は 14 か月、extended support は 12 か月で、1 つのマイナーバージョンは合計 26 か月サポートされます。そのためアップグレードの章は特定のバージョン番号ではなくプロセスに結び付けています。コースラボは、各ラボの `env.hcl` に指定されたバージョンでデプロイされます。

## コースの構成

各トピックは番号付きのフォルダーです。その中にはローカライズされたファイルがあります。主言語はロシア語（`ru.md`）で、そこから翻訳されます（CKA および Istio コースと同様です）。最初の翻訳後、各ファイルの先頭行に言語切替が表示されます。

このコースには**自分の AWS アカウント**が必要です。ほぼすべてのトピックは実際のクラスターでしか確認できず、一部の内容（spot interruption、NAT とトラフィック、アップグレード、コスト）はローカルの kind では再現できません。ラボは Terragrunt を通じてデプロイし、費用を無駄にしないよう単一のコマンドで削除できます。

章とラボに加えて、コースには実務用のリファレンスがあります。順番に読むものではなく、必要に応じて参照してください。

- [コース用語集](GLOSSARY_JP.md) - 各章の用語とリンク
- [診断リファレンス](RUNBOOK_JP.md) - 症状、原因、確認方法。要約では第 8 部
- [アーキテクチャ決定記録（ADR）](ADR_JP.md) - コース内の分岐に対する決定テンプレート
- [EKS 成熟度マトリクス](SCORECARD_JP.md) - 8 つのドメインによるクラスター準備度の質問票
- [コストモデル](COST_MODEL_JP.md) - コスト項目と計算式の一覧。単価は自分の値を入力します

## 目次

### 第 0 部. AWS の基礎（任意）

Kubernetes には強いが AWS の経験が浅い人のための準備編です。IAM、VPC、EC2 が日常的なツールであれば、すぐに第 1 部へ進んでください。この部には個別のラボはありません。他の章を知識の抜けなく読めるようにするためのものです。

- 0.1. [Kubernetes エンジニアのための AWS: アカウント、リージョン、AZ、クォータ、タグ、請求](00-1-aws/jp.md)
- 0.2. [ゼロから始める IAM: ポリシー、ロール、信頼、STS、一時キー](00-2-iam/jp.md)
- 0.3. [ゼロから始める VPC: サブネット、ルーティング、IGW と NAT、security group、VPC endpoint](00-3-vpc/jp.md)
- 0.4. [EC2 と料金モデル: インスタンスタイプ、AMI、on-demand、spot、Savings Plans](00-4-ec2/jp.md)
- 0.5. [ツール: aws cli、eksctl、terraform と terragrunt、helm、便利なプラグイン](00-5-tools/jp.md)

### 第 1 部. アーキテクチャとクラスター作成

1. [導入: EKS が担うことと利用者に残ること](01/jp.md)
2. [EKS control plane: public と private endpoint、platform version、SLA、ログ](02/jp.md)
3. [バージョンライフサイクル: standard と extended support、アップグレード戦略](03/jp.md)
4. [クラスター作成: eksctl、Terraform と Terragrunt、CloudFormation](04/jp.md) 🧪
5. [クラスターへのアクセス: IAM と RBAC、access entry、aws-auth からの移行](05/jp.md)
6. [クラスターのネットワーク: VPC CNI、ENI と IP アドレス、CIDR 計画](06/jp.md) 🧪
7. [アドレス計画の拡張: prefix delegation、secondary CIDR、custom networking](07/jp.md)
8. [VPC CNI の代替: Cilium、ネットワークモード、CNI を変更すべき場合](08/jp.md) 🧪

### 第 2 部. ノードとコンピューティングリソース

9. [コンピューティングタイプ: managed node group、self-managed、Fargate、Auto Mode](09/jp.md) 🧪
10. [AMI と bootstrap: AL2023、Bottlerocket、launch template、kubelet、user data](10/jp.md) 🧪
11. [Cluster Autoscaler と Karpenter: ノードスケーリングの 2 つのアプローチ](11/jp.md)
12. [Karpenter: NodePool、EC2NodeClass、disruption、consolidation、drift](12/jp.md)
13. [Spot インスタンス: 中断、分散、イベント処理](13/jp.md)
14. [密度とサイジング: pods per node、ENI 制限、クラウドでの requests と limits](14/jp.md)
15. [Fargate: プロファイル、制約、コスト、ユースケース](15/jp.md)

### 第 3 部. アイデンティティとセキュリティ

16. [IRSA: OIDC provider、trust policy、ServiceAccount アノテーション](16/jp.md)
17. [EKS Pod Identity: エージェント、関連付け、IRSA からの移行](17/jp.md)
18. [シークレット: KMS 暗号化、External Secrets と CSI 経由の Secrets Manager および SSM](18/jp.md)
19. [ハードニング: IMDSv2 と hop limit、Pod Security Admission、プライベートクラスター](19/jp.md)
20. [イメージと supply chain: ECR、スキャン、署名、pull through cache](20/jp.md) 🧪
21. [監査と検出: control plane ログ、CloudTrail、GuardDuty、runtime monitoring](21/jp.md)
22. [ポリシーとマルチテナンシー: Kyverno と Gatekeeper、チームの分離](22/jp.md) 🧪

### 第 4 部. データストレージ

23. [EBS CSI: gp3、StorageClass、拡張、スナップショット、AZ へのバインド](23/jp.md)
24. [EFS と FSx: AZ をまたぐワークロード用の共有ストレージ](24/jp.md)
25. [アプリケーションでの S3: Mountpoint for Amazon S3 CSI とアクセスパターン](25/jp.md) 🧪

### 第 5 部. ネットワークとトラフィック

26. [AWS Load Balancer Controller と LoadBalancer 型 Service: NLB](26/jp.md)
27. [ALB 経由の Ingress: target-type、アノテーション、TLS と ACM、WAF](27/jp.md)
28. [AWS の Gateway API: ALB Gateway API と VPC Lattice](28/jp.md) 🧪
29. [DNS と証明書: external-dns、Route 53、cert-manager](29/jp.md)
30. [EKS の NetworkPolicy: VPC CNI network policy と Cilium](30/jp.md)
31. [Egress とトラフィックコスト: NAT、VPC endpoint、PrivateLink](31/jp.md)
32. [マルチクラスターとマルチアカウント: 接続性、共有リソース、パターン](32/jp.md)

### 第 6 部. オブザーバビリティ

33. [メトリクス: Container Insights、Managed Prometheus と Grafana、kube-prometheus-stack](33/jp.md)
34. [ログ: Fluent Bit、CloudWatch Logs、OpenSearch、支出の管理](34/jp.md)
35. [アプリケーションの自動スケーリング: HPA、外部メトリクス、KEDA](35/jp.md) 🧪
36. [トレーシングとプロファイリング: ADOT と X-Ray](36/jp.md)

### 第 7 部. 運用

37. [EKS アドオン: managed addon と Helm、バージョンとアップグレード順序](37/jp.md)
38. [クラスターのアップグレード: バージョンごとの in-place、blue/green クラスター、廃止 API](38/jp.md)
39. [クラスターのバージョンロールバック: rollback readiness insight、7 日間のウィンドウ、ロールバック手順](39/jp.md)
40. [信頼性: multi-AZ、PDB、topology spread、ノードの適切な停止](40/jp.md) 🧪
41. [AWS Backup によるクラスターのバックアップ: クラスター状態、永続ボリューム、composite recovery point](41/jp.md) 🧪
42. [復元と DR: 既存および新規クラスターへの restore、namespace restore、Velero](42/jp.md) 🧪
43. [コスト: OpenCost と Kubecost、right-sizing、Savings Plans、spot の組み合わせ、トラフィック](43/jp.md)
44. [GitOps とデリバリー: Argo CD と Flux、クラスター群の管理](44/jp.md) 🧪

この部には 2 つのリファレンスがあります。[コストモデル](COST_MODEL_JP.md)は第 43 章の評価フォームで、[アーキテクチャ決定記録](ADR_JP.md)はコース全体の分岐に対応する ADR テンプレートです。

### 第 8 部. トラブルシューティング

45. [ノードがクラスターに参加しない: IAM、SG、user data、bootstrap、kubelet](45/jp.md)
46. [ネットワーク障害: ENI exhausted、SG と NACL、DNS、ロードバランサーの unhealthy target](46/jp.md) 🧪
47. [アクセスと IAM: access entry、IRSA と Pod Identity、webhook、kubeconfig](47/jp.md) 🧪

これら 3 章の「診断手順」セクションは、[診断リファレンス](RUNBOOK_JP.md)にまとめています。症状、考えられる原因、確認すべきことを収録しています。オンコールでは、3 つの章ではなくこちらを開く方が便利です。

### 第 9 部. まとめ

48. [EKS の本番チェックリストと次に読むもの](48/jp.md)

第 48 章のチェックリストは、スコアと技術的負債の一覧を含む質問票として[EKS 成熟度マトリクス](SCORECARD_JP.md)にまとめています。

## 実践

このコースには、章に対応した `101+` 番台の専用ラボがあります。ラボは AWS アカウント上で Terragrunt を通じてデプロイし、`check_result` で自動検証して、単一のコマンドで削除します。

- 🧪 [EKS ラボ](../../../docs/labs.MD#eks-labs) - ラボ一覧と起動コマンド

コースのラボセットは現在も作成中です。目次の 🧪 は、その章にすでに専用ラボがあることを示します。印のない章は、現時点では理論として進めます。

リポジトリには以前からある EKS ラボもあります（[Karpenter](../labs/02/README_JP.MD)、[KEDA と Prometheus による自動スケーリング](../labs/03/README_JP.MD)）。これらはコースには含まれず独自に管理されていますが、トピックは第 12 章および第 35 章と重なるため、追加の実践として取り組めます。

## 次に読むもの

- [Amazon EKS ドキュメント](https://docs.aws.amazon.com/eks/latest/userguide/) - バージョン、アドオン、制限に関する一次情報。
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) - ネットワーク、セキュリティ、信頼性、コストに関する公式推奨事項。
- [EKS Workshop](https://www.eksworkshop.com/) - AWS 提供の無料インタラクティブモジュール。
- [AWS Backup: EKS のバックアップと復元](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) - クラスター状態と永続ボリュームのバックアップに関するドキュメント。
- [Spot.io から Karpenter へ](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) - 本番環境におけるノード管理の移行に関する解説。
