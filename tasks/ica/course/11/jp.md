[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md)

# 第11章 Kubernetes Gateway API

> **次に進む前に。** 第5〜10章では、Istio の `Gateway` と
> `VirtualService` リソースを通じてトラフィックを管理しました。しかし Kubernetes には、同じ目的のための共通標準である
> Kubernetes Gateway API が登場しました。Istio はこれを完全にサポートし、ingress の将来と位置づけています。この章では、その概要を説明し、Istio リソースと比較して、最も重要な、何をいつ使うべきかを理解します。

## 11.1. なぜ別の標準が必要になったのか

`networking.istio.io` の `Gateway` と `VirtualService` リソースは優れていますが、
一つ欠点があります。これは **Istio 固有の** API です。明日 mesh や ingress
コントローラーを変更することになれば、すべてのマニフェストを別の製品向けに書き直さなければなりません。各ソリューション（Istio、nginx、Traefik、クラウドゲートウェイ）には、それぞれ独自のリソースセットがありました。

Kubernetes コミュニティは、この問題を単一の標準である **Kubernetes Gateway API**
（`gateway.networking.k8s.io`）によって解決しました。これは、Istio を含む多くの製品が実装する、受信トラフィック管理のベンダー中立な API です。標準に従って一度書けば、互換実装ならどれでも動作します。

名前の混同について、あらかじめ注意しておきます。`Gateway` という語を含む異なるリソースが二つあります。

- `networking.istio.io` の `Gateway` - Istio のリソースです（第5章から使用してきました）。
- `gateway.networking.k8s.io` の `Gateway` - Kubernetes Gateway API 標準のリソースです。

これらは構造の異なる API です。以降で「Gateway API」と言う場合は、後者の標準のものを指します。

## 11.2. Gateway API の役割とリソース

Gateway API では責任が複数のリソースに分割され、それぞれが特定の役割を担います。

| リソース | 担当すること | Istio での対応物 |
|--------|-------------|----------------|
| `GatewayClass` | 実装の種類（誰がトラフィックを処理するか） | インストール時に指定 |
| `Gateway` | リッスンするもの：ポート、プロトコル、TLS | Istio `Gateway` |
| `HTTPRoute` | HTTP ルーティングルール | Istio `VirtualService` |

`HTTPRoute` のほか、異なるプロトコル向けの `TCPRoute`、`TLSRoute`、
`GRPCRoute` もあります。考え方は Istio と同じです。何をリッスンするか（Gateway）と、どこへ送るか（Route）を分けます。

## 11.3. Gateway API CRD のインストール

実務上、しばしばつまずく重要な点があります。Gateway API リソースは **CRD であり、
デフォルトではクラスターに存在しないことがあります**。Istio は標準を実装しますが、定義そのもの（`GatewayClass`、`Gateway`、`HTTPRoute`…）はコミュニティまたは
Istio がインストールしなければなりません。CRD が未インストールの場合、マニフェストは適用できません。

存在を確認します。

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

CRD がなければ、標準の公式リリースからインストールしてください（`standard` チャネルには安定リソースが含まれ、`experimental` には `TCPRoute`/`TLSRoute` なども含まれます）。

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio はインストール時に `istio` という名前の `GatewayClass` を自動的に作成します（istiod が CRD を監視してクラスを作成します）。クラスが存在することを確認します。

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway と HTTPRoute の例

ポート 80 にゲートウェイを起動し、すべてのトラフィックを `reviews` サービスへ送ります。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # この実装は Istio が提供する
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-route
spec:
  parentRefs:
  - name: my-gateway         # どの Gateway に紐付くルートか
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # Kubernetes Service 名を直接指定
      port: 8080
```

```mermaid
flowchart LR
    C["クライアント"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>ルートルール"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

主なフィールドは次のとおりです。

- **`gatewayClassName: istio`** - この Gateway を Istio が実装することを示します。これは、Istio Gateway で `selector` を通じて ingress gateway に結び付けていたことに相当します。
- HTTPRoute の **`parentRefs`** は、ルートを特定の Gateway に結び付けます。Istio では、VirtualService の `gateways` フィールドがこの役割を担います。
- **`backendRefs`** は Kubernetes Service とポートを直接指定します。基本の Gateway API には subsets や DestinationRule はなく、バージョンとポリシーは別の方法で記述します。

もう一つ便利な点があります。`gatewayClassName: istio` を持つ `Gateway` を作成すると、Istio はそのゲートウェイ用の専用 Envoy デプロイメントを自動的に展開できます。事前に ingress gateway を用意する必要はなく、特定の Gateway 用に作成されます。

## 11.5. TLS: Gateway API の HTTPS

第9章の Edge TLS は、Gateway API では専用フィールドで記述します。HTTPS listener は `protocol: HTTPS` と、モードおよび証明書を持つ Secret への参照を含む `tls` ブロックで宣言します。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: istio-system
spec:
  gatewayClassName: istio
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    hostname: myapp.example.com
    tls:
      mode: Terminate                # gateway が TLS を終端する (Istio の SIMPLE 相当)
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # 第9章と同じ tls-Secret
    allowedRoutes:
      namespaces:
        from: All                    # どの namespace がルートを紐付けられるか (11.7 参照)
```

第9章のモードとの対応は次のとおりです。

- **`mode: Terminate`** - ゲートウェイが TLS を復号します（Istio の `SIMPLE`/`MUTUAL` と同様）。クライアント証明書（`MUTUAL` に相当）は `frontendValidation`/`BackendTLSPolicy` で設定し、標準のバージョンに依存します。
- **`mode: Passthrough`** - ゲートウェイは復号せず、トラフィックは SNI によってそのまま通過します（`PASSTHROUGH` と同様）。これには `HTTPRoute` ではなく `TLSRoute` を使用します。

証明書は通常の `tls` タイプの Kubernetes `Secret` に保存されます。cert-manager（第9章）で同様に発行できますが、ルートは `credentialName` ではなく `certificateRefs` 経由でそれを参照します。

## 11.6. HTTPRoute の Canary とフィルター

重み付けされたトラフィック分割（第6章の canary）は、Gateway API では拡張ではなく **標準の** 機能です。`backendRefs` に `weight` フィールドがあります。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews-canary
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - backendRefs:
    - name: reviews-v1       # トラフィックの 90% を v1 へ
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% を v2 へ
      port: 8080
      weight: 10
```

注意してください。Gateway API には subsets/DestinationRule がないため、異なるバージョンは、一つのサービスの subset ではなく、**異なる Kubernetes Service**（`reviews-v1`、`reviews-v2`）になります。

HTTPRoute は **フィルター**（`filters`）によってリクエストを変更できます。これは VirtualService の機能の一部に相当します。

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # ヘッダーを追加/削除
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # トラフィックのミラーリング (第6章)
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

便利なフィルタータイプには、`RequestHeaderModifier`/`ResponseHeaderModifier`（ヘッダー）、
`RequestRedirect`（HTTP→HTTPS を含むリダイレクト）、`URLRewrite`（パス/ホストの書き換え）、
`RequestMirror`（ミラーリング）があります。一方、標準には **fault injection** はありません。これは Istio API（第8章）だけの機能です。

## 11.7. namespace 間のルート: allowedRoutes と ReferenceGrant

Gateway API の強みは、namespace 間の権限を明確かつ安全に分離できることです。ここには二つの仕組みがあります。

**listener の `allowedRoutes`** - Gateway 自身が、どの namespace からルートの結び付けを許可するかを決定します（`from: Same` - 自身のみ、`All` - 任意、`Selector` - namespace ラベルによる）。

```yaml
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            team: frontend      # このラベルを持つ namespace のルートのみ
```

**`ReferenceGrant`** - ある namespace のリソースが **別の** namespace のリソースを参照する場合（たとえば、`apps` 内の HTTPRoute が `data` 内の Service にトラフィックを送りたい場合）、デフォルトでは禁止されています。許可は **対象** namespace 内の `ReferenceGrant` が与えます。

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # 対象の Service がある namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # 参照する側
  to:
  - group: ""
    kind: Service              # 参照を許可する対象
```

これにより、別のルートがあなたの同意なしにあなたの namespace 内のサービスへトラフィックを「奪う」ことを防ぎます。Istio API には、このような組み込みの仕組みはありません。

## 11.8. Istio API との比較

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| 入口リソース | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| ルートの結び付け | VirtualService の `gateways` フィールド | Route の `parentRefs` |
| 実装の選択 | ingress gateway の `selector` | `gatewayClassName` |
| バージョン/subsets | `DestinationRule`（subsets） | 異なる Service + `backendRefs` の `weight` |
| 重みによる Canary | `VirtualService` weight | `backendRefs.weight`（標準） |
| ミラーリング | `VirtualService` mirror | `RequestMirror` フィルター（標準） |
| Fault injection | あり | なし（Istio のみ） |
| バックエンドポリシー | `DestinationRule`（LB、circuit breaking） | なし（Istio のみ） |
| namespace ごとの権限分離 | 組み込みなし | `allowedRoutes` + `ReferenceGrant` |
| 標準 | Istio 固有 | 共通、ベンダー中立 |
| ポータビリティ | Istio のみ | 互換 ingress/mesh なら任意 |

表からの主な結論は次のとおりです。Gateway API は標準性、ポータビリティ、チーム間の権限分離で優れ、Istio API は受信側の機能の充実度（`DestinationRule`: 負荷分散、circuit breaking、subsets）と fault injection で優れます。ミラーリングと重みによる canary は、両方の API にあります。

## 11.9. 何をいつ使うか（best practices）

実際のプロジェクトで何を選ぶかについての実践的な推奨事項です。

**次の場合は Kubernetes Gateway API を選んでください。**

- 新しいプロジェクトを開始し、現在の標準を採用したい場合。
- ポータビリティが重要で、マニフェストのレベルで Istio に縛られたくない場合。
- チーム間で明確に責任を分ける必要がある場合（プラットフォームチームが `Gateway` を所有し、プロダクトチームが各自の `HTTPRoute` を所有する）。
- 標準のルーティング機能（パス、ヘッダー、重み）で十分な場合。
- **ambient mode** を使用する場合。waypoint プロキシ（第22章）は Gateway API を通じて設定します。

**次の場合は Istio API（VirtualService/DestinationRule）を使い続けてください。**

- 標準にはない機能が必要な場合。**fault injection**（第8章）、`DestinationRule` ポリシー（詳細な負荷分散、circuit breaking、outlier detection、subsets）、ルートの委譲。
- すでに多くの Istio API マニフェストが稼働しており、書き直す理由がない場合。

（ミラーリングと重みによる canary は両方の API にあるため、そのためだけに移行または維持する必要はありません。）

### 従来の Kubernetes Ingress リソース（legacy）

入口の第三の選択肢として、nginx-ingress、Traefik、クラウドコントローラーで使用されてきた通常の Kubernetes `Ingress`（`networking.k8s.io/v1`）があります。Istio はその ingress コントローラーとして動作できます。istio ingress gateway は、`istio` クラスが指定された `Ingress` リソースを読み取ります。

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
spec:
  controller: istio.io/ingress-controller
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reviews-ingress
  namespace: app
spec:
  ingressClassName: istio          # istio ingress gateway が処理する
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /reviews
        pathType: Prefix
        backend:
          service:
            name: reviews
            port:
              number: 8080
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-cert          # tls-Secret、第9章と同じ
```

これが **legacy** であり、新しいトラフィックに選ぶべきでない理由は次のとおりです。

- `Ingress` 標準自体の機能セットは非常に乏しく、ホスト、パス、TLS だけです。重み、ミラーリング、リダイレクト、ヘッダーによる分割はありません。
- 追加機能はすべてコントローラーの **非標準アノテーション** で実装されます（第26章の nginx のように）。アノテーションはコントローラー間で互換性がなく、Istio がサポートするのはそのごく一部です。一般的な `nginx.ingress.kubernetes.io/*` の大半は動作しません。
- 業界全体と Istio 自体の開発は、次世代の `Ingress` として作られた Gateway API の方向へ進んでいます。

実務上の結論は次のとおりです。Istio で従来の `Ingress` を維持するのは、第26章の移行時に古いマニフェストとの互換性を確保するためだけです。新しい ingress には Kubernetes Gateway API を選ぶか、Istio の機能が必要な場合は Istio `Gateway` + `VirtualService` を選んでください。

**共通ルール:**

- 同じルートを VirtualService と HTTPRoute の両方で同時に記述しないでください。混乱と競合の原因になります。一つのサービスには、どちらか一方を選んでください。
- Istio API は廃止されず、完全にサポートされます。移行は段階的に進められます。新しいサービスには Gateway API を使い、古いサービスはそのまま残せます。
- 業界の進む方向は Gateway API なので、現在の主なトラフィックが Istio API 上にあっても、それを知り習得する価値があります。

## 11.10. 章のまとめ

- Kubernetes Gateway API（`gateway.networking.k8s.io`）は、受信トラフィックを管理するベンダー中立の標準であり、Istio はこれを実装します。
- Istio の `Gateway` と Gateway API の `Gateway` を混同しないでください。異なるリソースです。
- Gateway API の役割は、`GatewayClass`（実装）、`Gateway`（何をリッスンするか）、`HTTPRoute` とその他の Route（どこへ送るか）です。
- ゲートウェイへのルートの結び付けは `parentRefs` 経由、実装の選択は `gatewayClassName: istio` 経由です。
- Gateway API の CRD はデフォルトで存在しないことがあり、別途インストールします（`standard` チャネル）。`GatewayClass istio` は Istio 自身が作成します。
- TLS: `tls.mode: Terminate`/`Passthrough` を持つ HTTPS listener と、`certificateRefs` を通じた Secret への参照（`credentialName` に相当）。証明書は同様に cert-manager が発行します。
- 重みによる Canary（`backendRefs.weight`、ただしバージョンは異なる Service）とミラーリング（`RequestMirror` フィルター）は標準で利用できます。fault injection と `DestinationRule` ポリシーは Istio API のみです。
- namespace 間の権限分離には、listener 上の `allowedRoutes` と cross-namespace 参照用の `ReferenceGrant` があります。Istio API には組み込みの対応物がありません。
- Best practice: 新しい ingress、標準シナリオ、ambient には Gateway API、fault injection または DestinationRule ポリシーが必要な場合には Istio API を使用します。一つのルートで両者を混在させないでください。
- 従来の Kubernetes `Ingress`（`ingressClassName: istio`）も Istio が処理しますが、legacy です。機能は乏しく、高度な機能は非標準アノテーション（そのごく一部のみ）を通じます。移行時の互換性のために維持しますが、新しいトラフィックには選びません。

## 11.11. 自己確認のための質問

1. Kubernetes Gateway API は Istio API と比べてどのような問題を解決しますか？
2. `Gateway` という名前を持つ二つのリソースは何が異なりますか？
3. どの Gateway API リソースが Istio Gateway と VirtualService に対応しますか？
4. `gatewayClassName` と `parentRefs` は何を担いますか？
5. どのような場合に Istio VirtualService/DestinationRule を使い続けるべきですか？ Gateway API にはどの機能がありませんか？
6. 一つのルートを両方の API で同時に記述すべきでないのはなぜですか？
7. Gateway API で HTTPS と重みによる canary を設定するにはどうしますか？ canary は Istio とどう異なりますか（subsets はどうなりますか）？
8. `allowedRoutes` と `ReferenceGrant` は何のために必要ですか？ どのセキュリティ問題を解決しますか？
9. Gateway API マニフェストがクラスターに適用できない場合、何を確認しますか？
10. Istio は従来の Kubernetes `Ingress` を処理できますか？ なぜ legacy と見なされますか？ それでも使うのはどのような場合ですか？

## 実践

Kubernetes Gateway API（Gateway + HTTPRoute）を通じて ingress を設定してください。

🧪 ラボ16: [tasks/ica/labs/16](../../labs/16/README_JP.MD)

---
[目次](../README_JP.md) · [第10章](../10/jp.md) · [第12章](../12/jp.md)
