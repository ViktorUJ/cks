[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_137_SECURITY_DELTA_TW.md)

# 付録。 Kubernetes v1.37 セキュリティ デルタ

> マーカー: PRODUCTION / VERSION-SENSITIVE。この付録に含まれていることは、トピックが現在の CKS 試験プールに属していることを意味するものではありません。コースの公式試験スナップショット ([`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml) を参照) は Kubernetes v1.35 を使用しますが、コース トレーニング ベースラインは v1.36 です。最新のアップストリーム安定バージョンは Kubernetes v1.37 です。試験/カリキュラムとの関連性を別途確認することなく、この付録の機能を 🎯 CKS Core に昇格させないでください。

この付録には、セキュリティ関連の Kubernetes v1.37 の変更がまとめられています。主要な章とラボは、検証済みの試験/トレーニングのコンテキストに関連付けられたままです。この文書には、本番環境の現時点の変更点が記録されています。

## 1. Manifest-Based Admission Control: ベータ版であり、デフォルトで有効になっています

**CKS 関連性:** Deep Dive / プロダクション / バージョン依存。

v1.36 トレーニング ベースラインでは、Manifest-Based Admission Control はアルファのままで、デフォルトで無効になっています。 v1.37 ではベータ版となり、`ManifestBasedAdmissionControlConfig` 機能ゲートがデフォルトで有効になりました。 API サーバーは、Webhook と CEL ベースのアドミッション ポリシーを静的ファイルからロードします。これらは、API サーバーの起動時にアクティブになり、アドミッション設定自体の保存に etcd に依存せず、API ベースのアドミッション リソースを変更から保護できます。

これによりブートストラップと自己保護の隙間は埋まりますが、運用リスクは増えます。初回読み込み時の manifest が無効だと、API サーバーは Ready になれません。HA 構成では各 API サーバーがそれぞれのファイルを読むため、一貫した内容をアトミックに配布する必要があります。

出典: [Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/)。

## 2. SELinuxMount: 一般提供され、デフォルトで有効になります

**CKS 関連性:** Deep Dive / プロダクション / バージョン依存。

v1.36 では、`SELinuxMount` はデフォルトで無効になっていました。 v1.37 では GA となり、デフォルトで有効になります。適格な CSI PVC の場合、`CSIDriver.spec.seLinuxMount: true` およびその他すべての適格条件が満たされる場合にのみ、Kubernetes は低速な再帰的再ラベル付けの代わりに SELinux ラベル マウント オプションを使用します。これにより動作が変更されます。1 つのノード上の共有ボリュームでは、互換性のない SELinux ラベルを持つ Pod が `ContainerCreating` に残る可能性があります。

SELinux が有効なクラスターをアップグレードする前に、`SELinuxWarningController` を有効にし、検出された競合を解決し、そのメトリックを観察します。異なるラベル間でボリュームを意図的に共有するワークロードは、以下を使用して以前の動作を維持できます。

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

ソース: [Pod またはコンテナーのセキュリティ コンテキストを構成する](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)。

## 3. Pod Certificates および ClusterTrustBundles: 安定しています

**CKS 関連性:** Deep Dive / プロダクション。

ServiceAccount JWT は引き続き bearer credential です。トークンは有効期限、オブジェクトへのバインド、audience によって制限されますが、通信相手に提示されます。Pod Certificates は、秘密キーとその保有証明モデルを備えた X.509 ワークロード資格情報を追加します。Kubelet は `PodCertificateRequest` を作成し、署名者から証明書チェーンを取得して資格情報をローテーションします。証明書と信頼バンドルは投射ボリューム（projected volumes）を通じてワークロードに渡され、`ClusterTrustBundle` がトラストアンカーを提供します。

署名コンポーネントは交換可能です。 Kubernetes v1.37 には、SPIFFE またはすべてのワークロード用の、すぐに使用できる汎用のコア署名者が同梱されていません。したがって、Pod Certificates は、ServiceAccount JWT を自動的に置き換えたり、既存の Istio/SPIFFE アイデンティティ メカニズムを不要にしたりしません。

出典: [Kubernetes v1.37: Pod Certificates およびクラスター信頼バンドル](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/)。

## 4. KubeletInUserNamespace: ベータ版のルートレス ノード パス

**CKS 関連性:** Deep Dive / プロダクション。

`KubeletInUserNamespace` は v1.37 のベータ版です。有効にすると、kubelet、CRI/OCI ランタイム、CNI、および kube-proxy は、Linux ユーザー名前空間内で非 root ホスト ユーザーとして実行できます。このルートレス ノード アーキテクチャは、侵害されたノード コンポーネントの影響を軽減し、CNI および CSI の互換性チェックが必要になる場合があります。

`spec.hostUsers: false` と混同しないでください。後者は Pod 用のユーザー名前空間を作成しますが、ノードコンポーネントは引き続きホストの root として動作する場合があります。これらは異なる、併用可能なセキュリティ境界です。機能ゲートを有効にしても、既存の root 権限で動作するノードが自動的に rootless モードへ移行するわけではありません。

出典: [Kubernetes v1.37: KubeletInUserNamespace がベータ版に移行](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/)。

## 5. 読み取り不可能または破損したリソースの削除: 安全でない回復パス

**CKS との関連性:** 生産 / 回復 / 危険な操作。

v1.37 では、ベータ版のデフォルトで有効になっている機能ゲート `AllowUnsafeMalformedObjectDeletion` により、復号化の失敗またはデコードの破損によりストレージから読み取れないオブジェクトの安全でない削除が許可されます。削除リクエストでは `ignoreStoreReadErrorWithClusterBreakingPotential` が使用されます。 `delete` と `unsafe-delete-ignore-read-errors` の両方の権限が必要です。

> ⚠️ これは、クラスターを破壊する可能性がある最後の手段の回復メカニズムです。これはファイナライザーと前提条件のチェックをバイパスし、古い暗号化キーの保持やバックアップ/復元を置き換えることはなく、EncryptionConfiguration エラーを修正する通常の方法ではありません。

出典: [Kubernetes API 概念: 強制削除](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion)。

## 6. StorageVersionMigration: 一般提供され、デフォルトで有効になります

**CKS 関連性:** 本番 / Deep Dive。

v1.37 では、組み込みの `storagemigration.k8s.io/v1` API とコントローラーが GA になり、デフォルトで有効になりました。 Storage Version Migration は、永続化された API オブジェクトを現在のストレージ バージョンに宣言的に書き換えます。これは、API ストレージ バージョンの移行に役立ち、暗号化プロバイダーまたはキーの変更後の制御された再暗号化の一部を形成できます。

SVM は、暗号化プロバイダーのローテーションとは異なります。プロバイダーの順序、古いデータの復号化、バックアップ、および復元戦略は、引き続き個別のオペレーターの責任となります。

出典: [Kubernetes v1.37: Storage Version Migration はデフォルトで有効](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/)。

---
[目次](README_JP.md)
