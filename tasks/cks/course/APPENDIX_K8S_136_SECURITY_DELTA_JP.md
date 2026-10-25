[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [繁體中文版](APPENDIX_K8S_136_SECURITY_DELTA_TW.md)

# 付録。 Kubernetes v1.36 セキュリティ デルタ

> マーカー: PRODUCTION / VERSION-SENSITIVE。この付録に含まれていることは、トピックが現在の CKS 試験プールに属していることを意味するものではありません。コースの公式試験スナップショット ([`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml) を参照) は Kubernetes v1.35 を使用しますが、コース トレーニング ベースラインは v1.36 です。試験事実として扱う前に、各項目を確認してください。一部の変更は本番環境では重要ですが、カリキュラムはマイナー リリースより遅れる可能性があります。

この付録は、コースの主要な章を補完するものです。セキュリティ関連の Kubernetes v1.36 の変更を 33 章すべてに分散したり、本番環境の最新性と試験の忠実性を混同したりするのではなく、1 か所にまとめています。

## 1. User Namespaces GA

**CKS 関連性:** Deep Dive / プロダクション。

- `spec.hostUsers: false` は、Pod をユーザー名前空間に配置します。コンテナー内の root は、ホスト上の特権のない UID にマップされます。
- これは追加の多層防御境界であり、既存の制御 (capabilities、seccomp、AppArmor、RBAC) に代わるものではありません。 [第 03 章](03/jp.md) を参照してください。
- Linux のみ。特定の制限事項 (raw ブロック ボリューム、NFS) については、第 03 章を参照してください。

## 2. Fine-Grained Kubelet API Authorization GA

**CKS 関連性:** コア ([第 05 章](05/jp.md) で使用)。

- 以前は、`nodes/proxy` は、一見安全な `/metrics` と危険な `/exec` を含む、ほぼすべての kubelet API パスの唯一のサブリソースでした。
- GA では、別のサブリソース: `nodes/stats`、`nodes/metrics`、`nodes/log`、`nodes/pods`、`nodes/healthz`、`nodes/configz`、`nodes/spec`、`nodes/checkpoint` が導入されました。
- `/pods`、`/runningPods/`、`/healthz`、および `/configz` の場合、kubelet は最初に詳細なサブリソースをチェックし、下位互換性のために拒否された場合は `nodes/proxy` にフォールバックします。
- **これがセキュリティ レビューにとって重要な理由:** `nodes/proxy GET` を持つモニタリング エージェントは、ノード上の任意のコンテナーで RCE の kubelet API WebSocket セマンティクスを介して悪用される可能性があります。 `GET` は RBAC `get` にマップされますが、`kubelet` は後続の書き込み操作について `create` を個別にチェックしません。第 05 章とその「攻撃者の視点」ブロックを参照してください。
- 出典: [Kubernetes v1.36 ブログ - Fine-Grained Kubelet API Authorization 卒業生から GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/)。

## 3. アドミッションポリシー GA および Manifest-Based Admission Control (アルファ) の変更/検証

**CKS 関連性:** VAP のコア ([第 20 章](20/jp.md) で使用); Manifest-Based Admission Control は Deep Dive (アルファ、デフォルトでは無効) です。

- ネイティブ CEL ベースのポリシー層により、多くの一般的なルールに対する追加のアドミッション Webhook の必要性が軽減されます。 Kyverno/Gatekeeper の生成、複雑なオブジェクトの変更、またはサプライ チェーン イメージの検証を置き換えるものではありません (第 20 章および第 26 章を参照)。
- Manifest-Based Admission Control (v1.36、アルファ) は静的アドミッション オブジェクトをサポートします。すべてのオブジェクトには `.static.k8s.io` 名前サフィックスが必要です。バインディング内の `paramRef` は禁止されています。静的 Webhook では、`clientConfig.url` のみが許可され、`clientConfig.service` は許可されません。無効な静的マニフェストにより、API サーバーの準備ができなくなる可能性があります。

## 4. Service.spec.externalIPs は正式に非推奨になりました

**CKS 関連性:** プロダクション/Deep Dive。

- `externalIPs` は、Kubernetes v1.36 で正式に非推奨になりました。将来のマイナー リリースでは、kube-proxy の動作とそのサポート要件が適合基準から削除される予定です。
- **セキュリティ上の理由:** このフィールドは長い間危険でした。Services を作成/編集できる権限のないユーザーは、所有権の検証なしに任意の IP を要求できる可能性があります。これは、マルチテナント クラスターで MITM リスクを生み出し、**CVE-2020-8554** (LoadBalancer または外部 IP を使用する中間者) に直接関係します。
- **現在の代替案:** `externalIPs` を直接使用する代わりに、クラウド/オンプレミス コントローラーまたはゲートウェイ API を介した LoadBalancer Service。
- 出典: [Kubernetes v1.36 ブログ - Service 外部 IP の非推奨と削除](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/)、[CVE-2020-8554 アドバイザリー](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003)。

## 5. gitRepo ボリュームが永続的に無効になる

**CKS 関連性:** 生産/Deep Dive (サプライ チェーン/可変ソースのレッスン)。

- `gitRepo` ボリューム タイプは、Kubernetes v1.36 では**永続的に無効**になっており、機能ゲートによって再度有効にすることはできません。 Kubernetes API は、`gitRepo` ボリュームを持つ Pod を引き続き受け入れますが、kubelet は開始を拒否し、エラーを返します。
- **セキュリティ上の理由:** `gitRepo` ボリューム ドライバーは、十分な分離が行われずに、ノード上の kubelet によって管理されるプロセス内で `git clone` を実行しました。したがって、特別に細工された Git リポジトリにより、`git clone` 中に書き込みフックを通じて RCE が発生する可能性があります。
- **サプライ チェーンの教訓:** プロビジョニング中に任意の外部コードを実行するボリューム タイプ (「単なる」`git clone` であっても) には、ダイジェスト ピニングのない変更可能なイメージ タグと同じクラスのリスクがあります。信頼は、事前に検証されるのではなく、実行時に外部の不完全に制御されたソースに転送されます。
- 出典: [AWS EKS リリースノート - gitRepo ボリュームの削除](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)、[kubernetes/kubernetes#125983 - gitRepo ボリューム タイプの削除](https://github.com/kubernetes/kubernetes/issues/125983)。

## 6. SELinux ボリューム ラベルの変更 (マウント時の再ラベル付け)

**CKS 関連性:** Deep Dive ([第 18 章](18/jp.md) で使用)。

- kubelet ではなく、コンテナー ランタイムが再帰的な SELinux 再ラベル付けを実行します。
- `ReadWriteOncePod` 以外のアクセス モードを持つ PVC の場合、マウント ベースの再ラベル付け (`-o context=`) には、特定の CSI ドライバーで `SELinuxMount` 機能ゲート (v1.36 ではデフォルトで無効になっています) と `CSIDriver.spec.seLinuxMount: true` が必要です。それ以外の場合は、低速の再帰的再ラベル付けが使用されます。
- 再帰的再ラベル付けと `MountOption` の違いについては、第 18 章を参照してください。

## この付録の使用方法

講義や試験の準備で「現在の事実」として項目を引用する前に、次のことを行ってください。

1. [`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml)と[`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)の`checked_at`を確認してください。
2. 特定の機能が現在のカリキュラムに含まれているかどうかを確認してください (`CKS_Curriculum` PDF)。現在の運用環境が自動的に試験関連を意味するとは考えないでください。
3. 項目がラボまたは章の *コア* 資料として使用されている場合 ([`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml) を参照)、こことその章の文言を同期させてください。

---
[目次](README_JP.md)
