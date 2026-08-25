[Русская версия](COST_MODEL_RU.md) · [Eng version](COST_MODEL.md) · [Versión en español](COST_MODEL_ES.md) · [Version française](COST_MODEL_FR.md) · [Deutsche Version](COST_MODEL_DE.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [繁體中文版](COST_MODEL_TW.md)

# EKS クラスターのコストモデル: 見積もりテンプレート

[コース目次](README_JP.md) · [第43章](43/jp.md) · [用語集](GLOSSARY_JP.md)

これは第43章の実務用フォームです。同じコスト構造を、エンジニアが自分のクラスターの見積もりを作成するための表と式で示します。ここに新しい内容はありません。

## 使い方

- このフォームには価格を含めません。料金はリージョンによって異なり、変動し、コースより速く古くなるため、「料金（入力）」列は意図的に空欄です。
- 料金は対象リージョンの AWS Pricing Calculator から取得して空欄に入力します。すでに稼働中のクラスターの実績は Cost and Usage Report（第43章）から取得します。
- このテンプレートの価値は数値の正確さではなく、項目一覧の網羅性にあります。請求書には現れるが見積もりから漏れた項目を忘れないようにします。
- 見積もりは right-sizing の前後で 2 回作成します。2 回の計算結果の差が、節約の約束ではなく、エンジニアリング上の判断による測定済みの効果です。
- フォーム全体で単位を統一してください（月あたりの時間、GB と GiB など）。そうしないと行どうしを合算できません。
- ノード購入モデルの変更、AZ の追加、新しいログ種別の有効化、egress トポロジーの変更後には、このフォームを再計算してください。

## コスト項目

| 項目 | 依存要因 | 単位 | 料金（入力） | 章 |
|---|---|---|---|---|
| クラスター control plane | クラスター数、稼働時間 | クラスター時間 |  | [02](02/jp.md) |
| extended support の追加料金 | standard support 対象外のバージョン | クラスター時間 |  | [38](38/jp.md) |
| EC2 ノード | インスタンスタイプ、ノード数、購入モデル | インスタンス時間 |  | [09](09/jp.md) |
| Auto Mode の管理追加料金 | Auto Mode が管理するインスタンス | インスタンス時間 |  | [09](09/jp.md) |
| Fargate: vCPU | Pod の CapacityProvisioned、存続時間 | vCPU 時間 |  | [15](15/jp.md) |
| Fargate: メモリ | Pod の CapacityProvisioned、存続時間 | GB 時間 |  | [15](15/jp.md) |
| EBS volume | volume タイプ、容量、指定 IOPS、throughput | GiB 月 |  | [23](23/jp.md) |
| EBS snapshot | 取得データ量、保持期間 | GiB 月 |  | [23](23/jp.md) |
| NAT Gateway: 稼働 | NAT 数（AZ ごとに 1 つ）、存続時間 | NAT 時間 |  | [31](31/jp.md) |
| NAT Gateway: 処理 | Pod egress、イメージ pull、AWS API 呼び出し | GB |  | [31](31/jp.md) |
| Cross-AZ トラフィック | AZ 間 east-west、別 AZ のデータベースへのアクセス | GB |  | [31](31/jp.md) |
| インターネットへの送信トラフィック | クライアントへの応答、外部へのデータ出力 | GB |  | [31](31/jp.md) |
| Interface endpoints (PrivateLink) | endpoint 数、処理済み量 | endpoint 時間と GB |  | [31](31/jp.md) |
| ログ: 取り込み（ingestion） | 取り込まれた Pod と control plane のログ量 | GB |  | [34](34/jp.md) |
| ログ: 保存 | 指定した retention 内の量 | GB 月 |  | [34](34/jp.md) |
| ロードバランサー（NLB、ALB） | ロードバランサー数、処理済み量 | 時間と量 |  | [26](26/jp.md) |

S3 と DynamoDB 用の gateway endpoints は、この表に項目として不要です。無料ですが、有料の NAT からトラフィック量を移すため、「NAT Gateway: 処理」の項目に影響します（第31章）。

## 一般形の式

```text
表記: HOURS - 計算対象月の時間、RATE_* - 上表の料金。
すべての使用量は設計計画ではなく、メトリクスと請求データから取得する。

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT - extended support 対象バージョンのクラスター。通常のクラスター
# 時間料金に対する追加料金であり、同じ料金ではない（第38章）。

nodes = プール P ごとの合計: NODES[P] * HOURS[P] * RATE_INSTANCE[P, 購入モデル]
# 購入モデル: On-Demand、Spot、Reserved または Savings Plans の適用範囲（第43章）。

auto_mode = nodes(Auto Mode プール)                         # EC2 部分
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # 管理の追加料金
# 必須: Reserved Instances と Savings Plans が引き下げるのは EC2 部分のみ。
# Auto Mode の管理追加料金にはこれらの割引は適用されず、請求では別項目として
# 扱われる（第09章）。control plane の EKS 時間料金にも Compute Savings Plans は
# 適用されない（第43章）。

fargate = Pod ごとの合計: VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV と MEM_PROV_GB は CapacityProvisioned annotation から得られる割り当て
# 組み合わせ、すなわち requests 自体ではなく、切り上げられた requests（第15章）。

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# BASELINE_COMPUTE は right-sizing の後に算出する。そうしなければ空き容量を
# コミットすることになる。SPOT_SUSTAINED は計画上ではなく安定して達成できる
# Spot の割合。Savings Plans は Spot をカバーせず、時間ごとのコミットメントは
# 時間をまたいで繰り越せず、未使用分は毎時失効する。一方、On-Demand への fallback は
# 使用量の一部をコミットメント対象に戻す（第43章、第13章）。コミットメントは
# 実績の utilization と coverage に基づいて見直す。

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# NAT の存在に対する料金と、処理された各ギガバイトに対する料金という、独立した 2 要素。

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# 両方向で課金される。CROSS_AZ_GB にはリクエストとレスポンスの両方を含める（第31章）。

storage = volume ごとの合計: SIZE_GIB * RATE_VOLUME[タイプ]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# ファイルシステム内の使用量ではなく、要求した volume サイズに対して支払う。

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB は取り込み量であり、通常は最大の項目である（第34章）。

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## よく忘れられること

- **Auto Mode の追加料金。** 請求では EC2 料金に加わる別項目であり、割引モデルの対象外です。Auto Mode を独自スタックと比較する際は、明示的に計算します（第09章）。
- **追加料金としての extended support。** 古いバージョンのクラスターは、稼働 1 時間あたりの費用が高くなります。同額ではありません。見積もりでは別の加算項です（第38章）。
- **双方向の cross-AZ。** ある AZ のサービスが別 AZ のデータベースを呼び出す場合、リクエストだけでなく通信全体に支払います。両方向を計算します（第31章）。
- **NAT は二重に課金される。** NAT が存在する間は時間料金が発生し、それとは別に処理したギガバイトごとに支払います。通常忘れられるのは後者です（第31章）。
- **ログは主に取り込みに対して支払う。** retention を短縮しても保存分だけに影響するため、節約効果は小さいです。収集間隔、ログレベル、series のフィルタリングが有効です（第34章）。
- **忘れられた volume と snapshot。** PVC を削除しても volume は残ることがあります。snapshot は何年も蓄積します。これは請求でしか見えない静かな漏れです（第23章）。
- **削除済み Service の後に残るロードバランサー。** Kubernetes 経由以外で Service を削除すると、NLB または ALB が残って課金され続けます（第26章）。
- **Idle 容量。** 使用量ではなく予約済み requests に対して支払います。requested と used の差は、レプリカ数を掛けた支払い済みの空き容量です（第43章）。

## 最適化の順序

1. **Right-size と bin-pack** - requests を実際の使用量に合わせ、consolidation によりノードを高密度化します（第43章、第14章、第12章）。
2. **安定した baseline へのコミットメント** - 削減後に、何か月も維持される量に対して Savings Plans を適用します（第43章）。
3. **柔軟なワークロードを Spot へ** - 中断可能なものを、タイプと AZ の多様化を伴って Spot に移します（第13章）。
4. **トラフィック、ログ、ストレージ** - S3 用 gateway endpoint、AZ ごとの NAT、発生源でのログ量、volume と snapshot を扱います（第31章、第34章、第23章）。

順序が重要なのは、各ステップが前のステップで縮小された基盤に適用されるからです。膨らんだ容量をコミットまたは Spot 化することは、空き容量への支払いを固定することです。

## テンプレートの範囲

- このフォームは、予測のための AWS Pricing Calculator と実績のための Cost and Usage Report を置き換えるものではありません。費目と式を定めるものであり、数値はそれらから取得します。
- クラスター外のアプリケーションサービス（データベース、キュー、cache、アプリケーションデータ用 S3）は、製品の請求には含まれますが、ここでは計算しません。
- チームおよび namespace ごとの配賦は、この表ではなく第43章の配賦ツールで行います。この表はクラスター全体についてのものであり、内部で誰がいくら使ったかを示すものではありません。
- Shared コスト（control plane、システム namespace、idle）は、フォームではクラスターの項目として表示します。チーム間で分配するルールは別途選択します（第43章）。
- AWS との契約による割引とコミットメント適用の順序は、このフォームではモデル化しません。これらは実際の billing でのみ確認できます。