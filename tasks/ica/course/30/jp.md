[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md)

# 第30章. control plane のパフォーマンスと運用

> **この先に学ぶこと。** 基礎からマルチクラスター、VM までを学んできました。この章で
> 運用のブロックを締めくくります。control plane の仕組み、パフォーマンスに影響する要因、
> 監視方法、チューニング方法、そして本番環境で mesh を健全に保つ方法です。続く章はあと 2 つです。
> ハードニングと脅威モデル（第31章）、および ICA 試験の準備（第32章）です。

## 30.1. control plane の動作とパフォーマンスに影響する要因

第4章の内容を思い出しましょう。istiod（control plane）はトラフィック自体を処理しません。その役割は、
クラスターの状態（Service、Pod、独自の設定）を追跡し、すべての Envoy に xDS 経由で
**最新の設定を配信すること**です。control plane に負荷をかけるのは、まさにこの処理です。

```mermaid
flowchart LR
    E["変更<br>（Pod / 設定）"] --> D["debounce / バッチ処理"]
    D --> C["istiod が再計算"]
    C --> P["すべてのプロキシへ xDS で push"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

istiod のパフォーマンスには次の要因が影響します。

- **Service と Pod の数** - 多いほど、計算して送信する設定も多くなります。
- **変更頻度（churn）** - 新しい Pod、Service やルールの変更のたびに、再計算と配信が
  実行されます。
- **接続しているプロキシ数** - それぞれに設定を配信する必要があります。
- **プロキシごとの設定サイズ** - 各 sidecar が mesh 全体を把握する場合（第19章）、
  ボリュームは二次関数的に増加します。

## 30.2. control plane の監視

istiod はアプリケーションとは別に監視する必要があります。その「ゴールデンシグナル」を基準にしてください。

- **設定配信のレイテンシー** - `pilot_proxy_convergence_time`。最も重要なシグナルです。
  変更がプロキシに到達するまでの時間を示します。増加は、control plane が
  処理しきれていない最初の兆候です。
- **push とエラー** - `pilot_xds_pushes`（配信回数）および拒否された設定／xDS エラーの
  カウンターです。エラーの急増は、設定または接続の問題を示します。
- **接続しているプロキシ** - istiod に接続されている Envoy の数です。
- **飽和状態** - istiod の CPU とメモリ。制限に達すると、設定配信全体が
  影響を受けます。

これらのメトリクスは control plane のアラートの基盤です（第17章）。istiod が利用できなくても、
稼働中のプロキシは最後に受け取った設定で動作し続けますが、新しい変更は届きません。
そのため istiod の健全性は非常に重要です。

**自分の作業を確認しましょう。** istiod のゴールデンシグナルに対する基本的な PromQL クエリです。

```promql
# 設定の収束時間の p99 (秒) - 主要なシグナル
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# タイプ別の xDS プッシュ頻度 (cds/eds/lds/rds)
sum(rate(pilot_xds_pushes[5m])) by (type)

# 拒否された設定 - 0 であるべき
sum(rate(pilot_total_xds_rejects[5m]))

# istiod に接続しているプロキシの数
pilot_xds
```

p99 の収束時間の増加または `pilot_total_xds_rejects` がゼロ以外であることは、調査すべきシグナルです。
istiod の過負荷、壊れた設定、または接続の問題が考えられます。

## 30.3. パフォーマンスのチューニング

主なレバーは次のとおりです（多くはすでに取り上げました）。

- **discovery selectors**（第19章）- istiod は必要な namespace だけを監視し、
  それ以外を無視します。クラスターの一部が mesh 内にない場合、最も大きな効果があります。
- **Sidecar scope**（第19章）- 各プロキシは、mesh 全体ではなく必要な Service だけの設定を受け取ります。
  設定ボリュームと istiod の負荷を大幅に削減します。
- **イベントのバッチ処理と debounce** - istiod は小さな変更ごとに設定を配信するのではなく、
  短い間隔の変更をグループ化（debounce）し、push の頻度を throttle します。これらのパラメータ
  （たとえば `PILOT_DEBOUNCE_AFTER`、`PILOT_PUSH_THROTTLE`）は負荷に応じて調整できます。
  バッチ処理を増やすと push は減りますが、配信レイテンシーはわずかに上がります。
- **istiod のリソースと HA**（第27章）- 複数レプリカ + HPA、十分な CPU／メモリを確保します。
- **churn の削減** - 不要な変更を減らす（たとえば、必要なく設定を変更しない）
  = 再計算を減らします。

バッチ処理のパラメータは、istiod の環境変数として `IstioOperator` の
`components.pilot.k8s.env` で設定します。

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # 再計算前に静止を待つ時間
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # ただしこれ以上は待たない
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # 同時プッシュの上限
          value: "100"
```

変更が急増したときは、debounce を大きくすると再計算と push が減りますが、
配信レイテンシーはわずかに上がります（`pilot_proxy_convergence_time`、30.2節を確認してください）。
デフォルト値は大半のケースに適しています。特定の問題に対して、意図的に変更してください。

## 30.4. デプロイポリシー: OPA Gatekeeper

大規模な mesh では、チームが安全でない設定や破壊的な設定をデプロイしないようにすることが重要です。
ここで役立つのが **OPA Gatekeeper** です。これは、作成時にリソースを検証し（第4章の webhook と同様）、
ルールに適合しないものを拒否する admission コントローラーです。

Istio の典型的なポリシー:

- アプリケーションを含む namespace で、インジェクションラベル（または `istio.io/rev`）を必須にする。
- `mode: DISABLE` の `PeerAuthentication` を禁止する（誰かが誤って mTLS を無効化しないようにするため）。
- Service のポートに正しい名前が付いていることを必須にする（第10章）。
- レビューなしの広すぎる `AuthorizationPolicy` や `EnvoyFilter` を禁止する。

Gatekeeper は、このコースのベストプラクティスを**自動的に適用されるルール**へと変換します。
「このように運用することで合意した」ではなく、「そうしなければデプロイできない」のです。

例: `mode: DISABLE` の `PeerAuthentication` を禁止します。ポリシーは 2 つのリソース、
`ConstraintTemplate`（Rego で何を検証するか）と `Constraint`（何に適用するか）で記述します。

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "PeerAuthentication mode DISABLE はポリシーで禁止されています"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

これで、mTLS を無効にしたすべての `PeerAuthentication` は admission 時に拒否されます。
誰も誤って mesh に「穴を開ける」ことはできません。Rego を使わないより簡潔な YAML 構文を持つ
Gatekeeper の代替は **Kyverno** です。通常、両者の選択はチームで採用しているツールによって決まります。

## 30.5. EKS/AWS での運用

control plane に影響する、EKS に特有のいくつかのポイントです。

- **マネージドサービスによる istiod の監視。** istiod のゴールデンシグナルは、
  **Amazon Managed Prometheus (AMP)** に書き込み、**Grafana (AMG)** で確認すると便利です。
  メトリクスは **ADOT** エージェントで収集します（第17章）。istiod は stateless であるため、
  **Fargate** 上で実行することもできます（第27章）。
- **Karpenter と spot ノードは churn を増加させます。** ノードのオートスケーリング（Karpenter）と、
  中断がある spot は、ノードと Pod の頻繁な出現／消滅を意味します。control plane にとってこれは
  **churn の増加**です。再作成される Pod ごとに endpoints のイベントと新しい xDS push が発生します。
  対策: Karpenter の **consolidation** を過度に積極的にしないこと、ノードプールに `disruption budget`、
  アプリケーションに PDB を設定することです。これにより、ノードが絶えず「再構成」されるのを防げます。
  さらに、同じ scope（第19章）により、クラスターの一部で生じた変更の急増がすべてのプロキシに配信されないようにします。
- **オブザーバビリティのコスト。** Istio のメトリクスは高カーディナリティです。大規模な EKS クラスターでは、
  AMP／ストレージの請求額が急速に増加します。Telemetry API（第18章）で管理してください。
  不要な測定を無効化し、トレースを適切にサンプリングします。

## 30.6. スケール時の運用: チェックリスト

コース全体に散在する運用プラクティスをまとめましょう。

- **control plane を監視する**（istiod のゴールデンシグナル）。アプリケーションだけを監視しないでください。
- 大規模クラスターでは **scope を最適化する**（discovery selectors + Sidecar）。これがパフォーマンスの主なレバーです。
- 稼働中の本番環境で in-place 更新するのではなく、**revision/canary 経由で更新する**（第3章）。
- **PKI と共通 CA を早めに準備する**（第16、28章）。ルートのローテーションを計画します。
- マルチクラスターのクラスター間で Istio の**バージョンを統一する**（第28章）。
- Gatekeeper で**ポリシーを自動化する**。ベストプラクティスを必須ルールにします。
- アラートを備えた **mesh 全体のオブザーバビリティ**（第17～18章）と、適切なサンプリングを行います。
- 必要になる前に、**更新とロールバックをリハーサルする**。
- **早まって複雑にしない**。ambient、マルチクラスター、VM は、「できるから」ではなく、
  具体的な必要性に応じて導入してください。

## 30.7. 章のまとめ

- Control plane（istiod）はトラフィックを運びませんが、すべてのプロキシの設定を計算して配信します。
  これがその負荷です。
- パフォーマンスは、Service／Pod の数、変更頻度、プロキシ数、プロキシごとの設定サイズに依存します。
- istiod のゴールデンシグナルを監視します。設定配信時間
  （`pilot_proxy_convergence_time`）、push とエラー、プロキシ数、CPU／メモリです。
- チューニング: **discovery selectors** と **Sidecar scope**（第19章）、push のバッチ処理／throttle
  （`IstioOperator` 経由の `PILOT_DEBOUNCE_AFTER`／`PILOT_PUSH_THROTTLE`）、istiod のリソースと HA、
  churn の削減です。
- **OPA Gatekeeper**（または Kyverno）は、ベストプラクティスを必須の
  admission ルール（`ConstraintTemplate` + `Constraint`）に変換します。たとえば mTLS の `DISABLE` を禁止できます。
- EKS では、AMP／AMG／ADOT 経由で istiod を監視し、istiod は Fargate 上で実行できます。
  **Karpenter/spot** は churn を増加させます。consolidation を抑え、scope を狭く保ち、
  高カーディナリティメトリクスのコストを監視してください。
- 大規模運用では、control plane の監視、scope の最適化、revision 経由の更新、早期の PKI 準備、
  バージョン統一、ポリシーの自動化、エンドツーエンドのオブザーバビリティ、ロールバックのリハーサル、
  不要な複雑さの回避が重要です。

## 30.8. 自己確認の質問

1. control plane がユーザートラフィックを処理しない場合、何がその負荷になりますか？
2. istiod のパフォーマンスにはどのような要因が影響しますか？
3. control plane のゴールデンシグナルを挙げ、
   `pilot_proxy_convergence_time` の増加が何を意味するか説明してください。
4. どのようなパフォーマンスチューニングのレバーを知っていますか？ istiod のバッチ処理パラメータはどのように設定しますか？
5. Istio の運用において OPA Gatekeeper は何をもたらしますか？ ポリシーはどのリソースから構成され、何で代替できますか？
6. どのような PromQL クエリで control plane の健全性を確認しますか？
7. Karpenter と spot ノードは istiod の負荷にどのように影響し、どう対処しますか？

## 演習

discovery selectors と Sidecar scope、istiod のゴールデンシグナルの監視、OPA Gatekeeper による
デプロイポリシーを実践して、運用とパフォーマンスを身につけましょう。

🧪 ラボ 33: [tasks/ica/labs/33](../../labs/33/README_JP.MD)

---
[目次](../README_JP.md) · [第29章](../29/jp.md) · [第31章](../31/jp.md)
