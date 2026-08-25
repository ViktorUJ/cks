[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [繁體中文版](README_TW.md)

# Istio: 実践的セルフスタディ

ラボ演習（`tasks/ica/labs`）に連動した Istio service mesh の実践コースです。
CKA を取得したエンジニア向けです。第 1 部では ICA 試験を扱い、
第 2 部では実運用における best practices を扱います。

構成: 各トピックは番号付きのフォルダーです。内部にはローカライズ済みファイルがあります。
主要言語はロシア語（`ru.md`）であり、翻訳はこれを元に作成されます。

利用可能なローカライズ（コースの章とラボ演習は完全に翻訳済みです）:

- 🇷🇺 Русский - `ru.md`（主要、信頼できる情報源）
- 🇬🇧 English - `en.md`
- 🇪🇸 Español - `es.md`
- 🇫🇷 Français - `fr.md`
- 🇩🇪 Deutsch - `de.md`
- 🇬🇪 ジョージア語 - `ge.md`
- 🇹🇼 繁体中国語 - `tw.md`
- 🇯🇵 日本語 - `jp.md`

言語の切り替えは、各章の先頭行およびこの目次のヘッダーにあるリンクから行えます。
モック試験（`tasks/ica/mock`）は英語でのみ利用できます。

## 目次

### 第 1 部. ICA の基礎と準備

1. [service mesh と Istio アーキテクチャの概要](01/jp.md)
2. [Istio のインストールと設定](02/jp.md)
3. [Istio のアップグレード: Helm、リビジョン、canary、in-place](03/jp.md)
4. [Data plane: Envoy と sidecar injection](04/jp.md)
5. [トラフィック管理: Gateway、VirtualService、DestinationRule](05/jp.md)
6. [リリース戦略: canary、header-routing、traffic mirroring](06/jp.md)
7. [ロードバランシングと locality-aware failover](07/jp.md)
8. [レジリエンス: fault injection、timeouts、retries、circuit breaking](08/jp.md)
9. [Edge TLS: SIMPLE、MUTUAL、PASSTHROUGH モードの ingress](09/jp.md)
10. [TCP、gRPC、WebSocket のルーティング](10/jp.md)
11. [Kubernetes Gateway API](11/jp.md)
12. [Egress: ServiceEntry、egress gateway、TLS origination](12/jp.md)
13. [mTLS と PeerAuthentication: Zero Trust モデル](13/jp.md)
14. [AuthorizationPolicy: service-to-service の認可](14/jp.md)
15. [ユーザー認証: RequestAuthentication と JWT](15/jp.md)
16. [証明書管理: カスタム CA、cert-manager、istio-csr](16/jp.md)
17. [Observability: Prometheus、Grafana、Jaeger、Kiali](17/jp.md)
18. [Telemetry API: access logs と分散トレーシング](18/jp.md)
19. [Sidecar scoping とプロキシ設定の最適化](19/jp.md)
20. [Rate limiting: ローカルのリクエスト制限](20/jp.md)
21. [Data plane の拡張: EnvoyFilter、Lua、WasmPlugin](21/jp.md)
22. [Ambient mode: ztunnel と waypoint proxy](22/jp.md)
23. [mesh 内の StatefulSet と headless サービス](23/jp.md)
24. [Istio のトラブルシューティング](24/jp.md)

### 第 2 部. 実運用のための Best practices

25. [Flagger を使用したプログレッシブデリバリー](25/jp.md)
26. [ダウンタイムなしの本番移行: ingress-nginx → Istio](26/jp.md)
27. [EKS 上の Istio: 本番環境へのインストール](27/jp.md)
28. [マルチクラスター mesh](28/jp.md)
29. [非 Kubernetes ワークロード: mesh 内の VM](29/jp.md)
30. [Control plane のパフォーマンスと運用](30/jp.md)
31. [mesh のハードニングと脅威モデル](31/jp.md)

### 試験対策

32. [ICA 試験: 形式と準備](32/jp.md)
