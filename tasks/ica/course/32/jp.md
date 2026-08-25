[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md)

# 第32章. ICA 試験: 形式と準備

> **最終章。** このコース全体を通じて、認定資格 **Istio Certified Associate (ICA)**
> に向けて理論と実践の両方を準備してきました。ここでは、試験の仕組み、
> 準備方法、そして模擬試験である mock 試験の利用先をまとめます。

## 32.1. 試験とは何か

**ICA (Istio Certified Associate)** は、CNCF と Linux Foundation による
（当初は Tetrate が開発した）、Istio を扱う能力を証明する認定資格です。試験は
**オンラインの監督付き**で、形式は**ハイブリッド - 実技（performance-based）
課題と選択式（multiple-choice）の問題**です。実技パートではクラスターへのアクセスが
提供され、ルーティングの設定、mTLS の有効化、ポリシーの作成、問題の発見と修正などを
自分で行います。理論パートでは、原則と用語の理解が問われます。試験時間は **2時間**、
環境は **Istio v1.26** に更新されています。

試験中は公式ドキュメント（istio.io とそのサブドメイン、通常は Istio ブログおよび
Kubernetes ドキュメントも利用可能です。許可されたリソースの最新リストは Candidate Handbook
で確認してください）へのアクセスが許可されています。これは重要です。すべての YAML
フィールドを暗記する必要はありませんが、必要なものを**素早く**見つけて適用できなければ
なりません。

> 正確な詳細（試験時間、合格点、課題数、再受験のルール）は、時間の経過やプログラムの
> バージョンにより変わります。必ず公式ページを確認してください:
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica).

## 32.2. ドメインと重点を置くべき内容

試験は重み付けされたドメインで構成されています。最新の内訳（2025年8月のプログラム更新後）:

| ドメイン | 重み | コースの章 |
|-------|-----|-------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

新しいプログラムについて知っておくべき点:

- **独立した「Advanced Scenarios」ドメインはなくなりました** - そのトピックは再配分され、
  ambient のインストールは Installation に、egress と外部サービスとの接続は Traffic
  Management に移りました。
- **Installation は20%に増加**し、**sidecar と ambient モードでの**インストール、
  カスタマイズ、アップグレード（canary/in-place）を明示的に含むようになりました。
- **Traffic Management には egress、ingress、resilience**（circuit breaking、
  failover、outlier detection、タイムアウト、リトライ）**および fault injection**が含まれます。
- **Securing Workloads** - 認可、認証（mTLS、JWT）、および**エッジトラフィックの
  TLS 保護**です。
- **Troubleshooting** - 設定、control plane、data plane を扱います。

結論: **トラフィック管理を最も重点的に練習してください**（Gateway、VirtualService、
DestinationRule、ルーティング、レジリエンス、egress、fault injection）。これは最大の
ドメイン（35%）です。次の優先順位はほぼ同じです。セキュリティ（25%）、
インストール/アップグレードと troubleshooting（各20%）であり、比重が大きく増えた
インストールとトラブルシューティングを省かないでください。

## 32.3. 実践的なアドバイス

CKA/CKS の経験はそのまま活かせます:

- **エイリアスと自動補完。** `alias k=kubectl` を設定し、`kubectl` と `istioctl` の
  completion を有効にしてください。各課題の時間を節約できます。
- **コンテキストを確認する。** 特に課題が多い場合は、どのクラスターと namespace で作業
  しているか（`kubectl config current-context`）を常に確認してください。
- **課題を文字どおりに読む。** リソース、namespace、ポート、バージョンの正確な名前を
  確認してください。subset や selector の名前を間違えるとルールが機能しません（第5章）。
- **結果を確認する。** 設定後は Pod から `curl` を実行し、コードとヘッダーを確認して、
  トラフィックが実際に意図した場所へ流れていることを確かめてください。
- **`istioctl analyze` は頼れる味方です。** 設定エラーを素早く検出します（第24章）。
  問題がある場合は `proxy-status`（SYNCED?）と `proxy-config` を確認してください。
- **時間管理。** 一つの課題に固執しないでください。難しい課題は飛ばして後で戻りましょう。
  CKA と同じです。
- **ドキュメントを手元に置く。** istio.io の Gateway、VirtualService、PeerAuthentication
  の例がどこにあるかをあらかじめ把握してください。試験ではそこからコピーして修正する
  ことになります。

## 32.4. 模擬試験（mock）

最良の準備は、現実的な試験を時間を計って実行することです。このリポジトリには、ICA の
形式を模倣した**2つの mock 試験**があります:

- **Mock 01** - インストール、Gateway/VirtualService、AuthorizationPolicy、
  インジェクション管理という基本トピックの17課題。
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02** - オペレーターによる canary アップデート、Helm によるインストール、
  egress gateway、port-level バランシング、fault injection、クロス namespace 認可という
  高度なパターンの16課題。
  [tasks/ica/mock/02](../../mock/02/README.MD)

環境の概要、コマンド（`check_result`、`time_left`、`hosts`）、およびアドバイスは、
インフラストラクチャのルート README にあります: [tasks/ica/README.MD](../../README_JP.MD).

mock の使い方:

1. 該当トピックの章とラボを終えてください。
2. 実際の試験のように、ヒントなしで mock を**時間を計って**実行してください。
3. `check_result` で自己確認し、解答を通じて誤りを分析してください。
4. **70%+** の結果で時間内に安定して完了できるようになるまで繰り返してください。

mock は試験の**実技**パートを訓練します。ただし、形式はハイブリッドであり、原則と用語の
理解を問う選択式問題もあることを忘れないでください。したがって mock だけでなく、各章の
**理論**（各リソースの役割、mTLS、xDS、locality バランシングの仕組み）も復習してください。
「手を動かしてできること」と「なぜそうなるかを理解していること」の両方が問われます。

## 32.5. このコースでの準備方法

推奨する進め方:

1. **パート1（第1～24章）** - 試験の基礎とすべてのドメイン。各章をラボ（🧪）で定着
   させてください。
2. **mock**（第32.4章） - パート1の後に、時間を計って実行してください。
3. **パート2（第25～31章）** - 実運用のための best practices。試験そのものには必須では
   ありませんが、単にテストに合格するだけでなく、本番で Istio を理解するエンジニアに
   なれます。

## 32.6. まとめ

- ICA はオンラインの監督付き試験で、形式は**ハイブリッド**です。クラスター上の実技課題と
  選択式問題から構成され、istio.io ドキュメントへのアクセスが許可されます。試験時間は2時間、
  環境は v1.26 です。
- 最新のドメイン（2025年8月時点）: **Traffic Management 35%**、Securing Workloads 25%、
  Installation/Upgrade/Config 20%、Troubleshooting 20%。「Advanced Scenarios」ドメインは
  なくなりました。
- トラフィック管理を最も重点的に練習してください。ただし、比重が20%に増えたインストールと
  troubleshooting を省かないでください。
- CKA/CKS の習慣を活かしましょう: エイリアス、自動補完、コンテキストの確認、課題を
  文字どおりに読むこと、結果の確認、時間管理です。
- 実技のために **mock 01 と mock 02** を時間を計って実行し、理論も各章で復習してください
  （multiple-choice パートのため）。安定して70%+を達成しましょう。
- 正確な試験運営とルール（合格点、問題数、許可リソース）は、ICA の公式ページで確認して
  ください。

---

これでコースは終了です。service mesh の考え方から Istio の本番運用まで、トラフィック管理、
レジリエンス、セキュリティ、オブザーバビリティ、高度なシナリオ、troubleshooting、実際の
移行、ハードニング、そして試験準備までを学んできました。必要に応じて章、ラボ、mock に
戻ってください。ICA と実戦での Istio の成功を願っています。

[目次](../README_JP.md) · [第31章](../31/jp.md)
