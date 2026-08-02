[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md)

# CKA + CKAD：Kubernetes の実践自習ガイド

CNCF と Linux Foundation の 2 つの認定を同時に準備するための
合同の実践コースです：

- **CKA** (Certified Kubernetes Administrator) - クラスタの管理：
  インストール、運用、ネットワーク、ストレージ、セキュリティ、troubleshooting。
- **CKAD** (Certified Kubernetes Application Developer) - Kubernetes での
  アプリケーションの開発と実行：ワークロード、設定、可観測性、
  サービス。

2 つの試験は大きく重なっています（ワークロード、サービス、設定、ストレージ、
可観測性）。そのため別々に学ぶよりも一緒に学ぶほうが効率的です。共通の
コアは一度だけ通り、各試験に固有の内容はそれぞれ別のパートに分けています。
このコースは `tasks/cka/labs` のラボと結びついています。

> **Kubernetes のバージョン。** このコースは試験の現行バージョン -
> Kubernetes `v1.35` (CKA と CKAD の 2025-2026 の出題範囲) に合わせています。どちらの試験も
> 実技で、実際のクラスタをコマンドラインから操作します：CKA - 2 時間、CKAD - 2
> 時間、合格点は 66% です。

## コースの構成

各トピックは番号のついたフォルダです。中には各言語のファイルが置かれています。主な言語は
ロシア語 (`ru.md`) で、そこから翻訳が作られています：英語 (`README.md`)、スペイン語
(`es.md`)、フランス語 (`fr.md`)、ドイツ語 (`de.md`)、グルジア語 (`ge.md`)。
言語の切り替えは、各ファイルの最初の行にあります。

各章には、どの試験に属するかが示されています：

- 🟦 **CKA** - 管理者向けのみ
- 🟩 **CKAD** - 開発者向けのみ
- 🟪 **CKA + CKAD** - 両方の試験に共通するトピック

コースの最後には、特定の試験に合わせて章とラボをまとめた
2 つの独立したガイドがあります：

- [CKA のプログラムとラボ](CKA_JP.md)
- [CKAD のプログラムとラボ](CKAD_JP.md)

コースのすべての用語は、1 つのリファレンスにまとめられています：

- [コースの用語集](GLOSSARY_JP.md) - 章ごとのすべての用語とリンク

## 試験の公式プログラム

CKA (領域と重み)：

| 領域 | 重み |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD (領域と重み)：

| 領域 | 重み |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## 目次

### パート 0. 初心者のための土台 (任意) 🟪 CKA + CKAD

ネットワーク、DNS、TLS、コンテナ、Linux、YAML の確かな基礎を持たずに
入ってくる人のための準備パートです。これらのトピックに自信があるなら - すぐに
パート 1 へ進んでかまいません。このパートに専用のラボはありません：これは残りの章が
支えとする土台です (0.5-0.7 のスキルは、ノードとネットワークの
ラボでそのまま使います)。

- 0.1. [ゼロから学ぶネットワーク：IP、ポート、CIDR、NAT](00-1-net/jp.md)
- 0.2. [DNS をゼロから：名前はどのようにアドレスへ変わるのか](00-2-dns/jp.md)
- 0.3. [TLS と証明書をゼロから：HTTPS、鍵、認証局](00-3-tls/jp.md)
- 0.4. [ゼロから学ぶコンテナと Docker：イメージ、レイヤー、レジストリ、runtime](00-4-containers/jp.md)
- 0.5. [ゼロから学ぶ Linux とノードのツール：SSH、sudo、systemd、ログ、ファイル](00-5-linux/jp.md)
- 0.6. [ゼロから学ぶ YAML：インデント、リスト、辞書、マニフェスト](00-6-yaml/jp.md)
- 0.7. [Linux ネットワークの内側：network namespace、veth、ルーティング](00-7-netns/jp.md)
- 0.8. [vim を 15 分で：生き延びて YAML 向けに設定する](00-8-vim/jp.md)

### パート 1. Kubernetes の基礎 🟪 CKA + CKAD

1. [はじめに：Kubernetes、CKA と CKAD 試験、そしてコースの構成](01/jp.md)
2. [Kubernetes のアーキテクチャ：control plane と worker ノード](02/jp.md)
3. [kubectl での作業：命令的アプローチと宣言的アプローチ](03/jp.md)
4. [Pod：ライフサイクル、作成と設定](04/jp.md)
5. [ReplicaSet と Deployment](05/jp.md)
6. [Namespace、labels、selectors と annotations](06/jp.md)
7. [Services: ClusterIP、NodePort、LoadBalancer、Endpoints](07/jp.md)

### パート 2. ワークロードとスケジューリング 🟪 CKA + CKAD

8. [Deployment：rolling update と rollback](08/jp.md)
9. [デプロイ戦略：blue/green と canary](09/jp.md) 🟩 CKAD
10. [Jobs と CronJobs](10/jp.md)
11. [DaemonSet と StatefulSet](11/jp.md)
12. [Pod のスケジューリング：nodeName、nodeSelector、affinity](12/jp.md)
13. [Taints と tolerations](13/jp.md)
14. [リソース：requests、limits、LimitRange、ResourceQuota](14/jp.md)
15. [Static Pods、PriorityClass、複数のスケジューラ](15/jp.md)
16. [ワークロードの自動スケーリング：HPA](16/jp.md)

### パート 3. アプリケーションの設定とセキュリティ 🟪 CKA + CKAD

17. [コマンド、引数、環境変数](17/jp.md)
18. [ConfigMap](18/jp.md)
19. [Secret](19/jp.md)
20. [SecurityContext と capabilities](20/jp.md)
21. [ServiceAccount；認証、認可、admission](21/jp.md)

### パート 4. アプリケーションの設計とビルド 🟩 CKAD

22. [マルチコンテナ Pod：sidecar、adapter、ambassador、init](22/jp.md)
23. [コンテナイメージ：ビルド、Dockerfile、最適化](23/jp.md)
24. [アプリケーションのためのボリューム：emptyDir とエフェメラルボリューム](24/jp.md)

### パート 5. データの保存 🟪 CKA + CKAD

25. [Volumes、PersistentVolume と PersistentVolumeClaim](25/jp.md)
26. [StorageClass、動的プロビジョニング、StatefulSet におけるストレージ](26/jp.md)

### パート 6. 可観測性と運用 🟪 CKA + CKAD

27. [ヘルスチェック：liveness、readiness、startup probe](27/jp.md)
28. [ロギングとモニタリング：logs、metrics-server、kubectl top](28/jp.md)
29. [アプリケーションのデバッグと API の廃止](29/jp.md)

### パート 7. Service とネットワーク 🟪 CKA + CKAD

30. [Kubernetes のネットワークモデル、Pod のネットワーク、CNI](30/jp.md)
31. [Service の内部、DNS と CoreDNS](31/jp.md)
32. [Ingress と Ingress コントローラー](32/jp.md)
33. [Gateway API](33/jp.md)
34. [NetworkPolicy](34/jp.md)

### パート 8. クラスタのアーキテクチャ、インストールと設定 🟦 CKA

35. [kubeadm を使ったクラスタのインストール](35/jp.md)
- 35A. [高可用性 (HA)：複数の control-plane ノード、etcd のトポロジー、ロードバランサー](35-2-ha/jp.md) 🟦 CKA
- 35B. [クラスタの設計とサイジング：インフラ、トポロジー、IaC](35-3-design/jp.md) 🟦 CKA
36. [クラスタの更新 (lifecycle)](36/jp.md)
37. [etcd のバックアップとリストア](37/jp.md)
38. [RBAC：Role、ClusterRole とバインディング](38/jp.md)
39. [TLS 証明書、kubeconfig、CSR API](39/jp.md)
40. [拡張インターフェース：CNI、CSI、CRI](40/jp.md)
41. [CRD とオペレーター](41/jp.md)
42. [Helm](42/jp.md)
43. [Kustomize](43/jp.md)

### パート 9. Troubleshooting 🟦 CKA

44. [アプリケーション障害のデバッグ](44/jp.md)
45. [control plane と worker ノードのデバッグ](45/jp.md)
46. [Service とネットワークのデバッグ](46/jp.md)

### パート 10. 試験の準備

47. [CKAD 試験：形式、タイムマネジメント、JSONPath と kubectl の生産性](47/jp.md) 🟩 CKAD
48. [CKA 試験：形式、タイムマネジメント、戦略](48/jp.md) 🟦 CKA

## 演習

- 🧪 [ラボ](../labs) - 試験スタイルの 25 のラボ。自動チェック `check_result` 付き
- 🧪 [CKA モック試験](../mock) - タイマー付きの CKA モック試験（マルチクラスタ、SSH、課題の重み）
- 🧪 [CKAD モック試験](../../ckad/mock) - タイマー付きの CKAD モック試験

### どちらのラボを選ぶか

このプラットフォームのラボはコースの主要な演習であり、試験対策にはこちらのほうが適して
います。複合型で（1 つの環境に関連する複数の課題があり、実際の試験と同じ形です）、本格
的なクラスタに展開され、SSH でノードに入れます。検証は `check_result` で自動的に行われ、
モック試験はタイマー付き、課題ごとに重みがあります。これこそが CKA と CKAD の条件を再現
しています。

各章にある Killercoda のシナリオは**手早く始めるため**のものです。ブラウザで開き、
インストールは不要で、無料です。章を読んだ直後に 1 つの狭いトピックを固めるのに便利で、
クラスタが手元にないときの練習にも使えます。ただし原子的で（1 シナリオにつき 1 課題）、
英語のみで、ノード上での作業もタイマー付きのリハーサルもありません。

おすすめの組み合わせ：トピックを手早く固めるには Killercoda、試験そのものの対策には
このプラットフォームのラボとモック試験を使ってください。

## 次に読むもの

このコースは試験の準備に焦点を合わせています。各章は CKA または CKAD の領域に結びついて
います。アーキテクチャの哲学、プロジェクトの歴史、エコシステムの概観（service mesh、
GitOps、可観測性）は意図的に含めていません。これらは別のトピックであり、試験では問われ
ません。もっと広く、もっと深く知りたい場合は：

- **Kubernetes: Up and Running**（Burns、Beda、Hightower、O'Reilly） - Kubernetes が
  なぜ生まれたか、Borg からの進化、アプリケーションのアーキテクチャパターン。
- **The Kubernetes Book**（Nigel Poulton） - プラットフォーム全体の理解に重点を置いた
  概観的な入門書。毎年更新されます。
- [Kubernetes の公式ドキュメント](https://kubernetes.io/docs/) - 一次情報源。試験中に
  参照することも許可されています。
- [CNCF Landscape](https://landscape.cncf.io/) - cloud native エコシステムの地図。
