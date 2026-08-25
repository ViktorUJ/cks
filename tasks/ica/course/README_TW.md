[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [日本語版](README_JP.md)

# Istio：實作自學課程

一門結合實作實驗課程（`tasks/ica/labs`）的 Istio service mesh 實務課程。
面向已通過 CKA 的工程師。第 1 部分涵蓋 ICA 考試，第 2 部分介紹實際營運的
best practices。

結構：每個主題對應一個帶編號的資料夾，內含在地化檔案。主要語言為俄文
（`ru.md`），所有翻譯均以此為來源。

可用的在地化版本（課程章節與實作實驗均已完整翻譯）：

- 🇷🇺 俄文 - `ru.md`（主要語言、唯一真實來源）
- 🇬🇧 英文 - `en.md`
- 🇪🇸 西班牙文 - `es.md`
- 🇫🇷 法文 - `fr.md`
- 🇩🇪 德文 - `de.md`
- 🇬🇪 喬治亞文 - `ge.md`
- 🇹🇼 繁體中文 - `tw.md`
- 🇯🇵 日文 - `jp.md`

各章第一行及本目錄頁首均提供語言切換連結。模擬考試
（`tasks/ica/mock`）僅提供英文版本。

## 目錄

### 第 1 部分：ICA 基礎與準備

1. [service mesh 與 Istio 架構簡介](01/tw.md)
2. [Istio 安裝與設定](02/tw.md)
3. [Istio 升級：Helm、修訂版、canary 與 in-place](03/tw.md)
4. [Data plane：Envoy 與 sidecar injection](04/tw.md)
5. [流量管理：Gateway、VirtualService、DestinationRule](05/tw.md)
6. [發佈策略：canary、header-routing、traffic mirroring](06/tw.md)
7. [負載平衡與 locality-aware failover](07/tw.md)
8. [韌性：fault injection、timeouts、retries、circuit breaking](08/tw.md)
9. [Edge TLS：SIMPLE、MUTUAL、PASSTHROUGH 模式的 ingress](09/tw.md)
10. [TCP、gRPC 與 WebSocket 路由](10/tw.md)
11. [Kubernetes Gateway API](11/tw.md)
12. [Egress：ServiceEntry、egress gateway、TLS origination](12/tw.md)
13. [mTLS 與 PeerAuthentication：Zero Trust 模型](13/tw.md)
14. [AuthorizationPolicy：service-to-service 授權](14/tw.md)
15. [使用者驗證：RequestAuthentication 與 JWT](15/tw.md)
16. [憑證管理：自訂 CA、cert-manager 與 istio-csr](16/tw.md)
17. [Observability：Prometheus、Grafana、Jaeger、Kiali](17/tw.md)
18. [Telemetry API：access logs 與 distributed tracing](18/tw.md)
19. [Sidecar scoping 與 proxy configuration 最佳化](19/tw.md)
20. [Rate limiting：本機請求限制](20/tw.md)
21. [擴充 data plane：EnvoyFilter、Lua 與 WasmPlugin](21/tw.md)
22. [Ambient mode：ztunnel 與 waypoint proxy](22/tw.md)
23. [mesh 中的 StatefulSet 與 headless services](23/tw.md)
24. [Istio 疑難排解](24/tw.md)

### 第 2 部分：實際使用的 Best practices

25. [使用 Flagger 進行漸進式交付](25/tw.md)
26. [零停機遷移生產環境：ingress-nginx → Istio](26/tw.md)
27. [EKS 上的 Istio：生產環境安裝](27/tw.md)
28. [多叢集 mesh](28/tw.md)
29. [非 Kubernetes 工作負載：mesh 中的 VM](29/tw.md)
30. [Control plane 效能與維運](30/tw.md)
31. [mesh 強化與威脅模型](31/tw.md)

### 考試準備

32. [ICA 考試：形式與準備](32/tw.md)
