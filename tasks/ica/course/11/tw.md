[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [日本語版](jp.md)

# 第 11 章。Kubernetes Gateway API

> **接下來。** 在第 5-10 章中，我們透過 Istio 資源：Gateway 與
> VirtualService 管理流量。但 Kubernetes 針對同一件事推出了一套通用標準--
> Kubernetes Gateway API。Istio 完整支援它，並將其視為 ingress 的未來。本章將探討它是什麼、將它與 Istio 資源比較，以及最重要的是，瞭解該使用什麼及何時使用。

## 11.1. 為何需要獨立標準

來自 `networking.istio.io` 的 `Gateway` 與 `VirtualService` 資源運作得很好，但它們有一個缺點：這是 **Istio 專屬** API。若明天決定更換 mesh 或 ingress-controller，所有 manifest 都必須針對其他產品重寫。每個解決方案（Istio、nginx、Traefik、雲端 gateway）都有自己的一組資源。

Kubernetes 社群以一套統一標準解決了這個問題--**Kubernetes Gateway API**
(`gateway.networking.k8s.io`)。這是用於管理入站流量的供應商中立 API，許多產品都實作它，包括 Istio。依標準撰寫一次，就能在任何相容的實作上運作。

先提醒名稱上的混淆。有兩種名稱含有 `Gateway` 的不同資源：

- 來自 `networking.istio.io` 的 `Gateway`--Istio 資源（自第 5 章開始我們一直使用它）。
- 來自 `gateway.networking.k8s.io` 的 `Gateway`--Kubernetes Gateway API 標準資源。

它們是結構不同的 API。以下提到「Gateway API」時，指的是後者，即標準 API。

## 11.2. Gateway API 的角色與資源

在 Gateway API 中，職責分割為多種資源，每種資源各司其職：

| 資源 | 負責內容 | Istio 中的對應項 |
|--------|-------------|----------------|
| `GatewayClass` | 實作類型（誰處理流量） | 在安裝時設定 |
| `Gateway` | 要監聽什麼：連接埠、通訊協定、TLS | Istio `Gateway` |
| `HTTPRoute` | HTTP 路由規則 | Istio `VirtualService` |

除 `HTTPRoute` 外，還有其他供不同通訊協定使用的路由：`TCPRoute`、`TLSRoute`、
`GRPCRoute`。概念與 Istio 相同：將「監聽什麼」（Gateway）和「導向何處」（Route）分開。

## 11.3. 安裝 Gateway API CRD

有一個常見的實務重點：Gateway API 資源是 **CRD，
預設可能不存在於叢集中**。Istio 實作此標準，但定義本身（`GatewayClass`、`Gateway`、`HTTPRoute`…）必須由社群或 Istio 安裝。若未安裝 CRD，manifest 根本無法套用。

檢查是否存在：

```bash
kubectl get crd gateways.gateway.networking.k8s.io
```

若沒有 CRD，請從標準的官方發行版本安裝（`standard` 管道包含穩定資源，`experimental` 還包含 `TCPRoute`/`TLSRoute` 等）：

```bash
kubectl apply -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

Istio 在安裝時會自動安裝名為 `istio` 的 `GatewayClass`（istiod 監視 CRD 並建立此 class）。確認 class 已就緒：

```bash
kubectl get gatewayclass istio
```

## 11.4. Gateway 與 HTTPRoute 範例

讓我們在連接埠 80 建立 gateway，並將所有流量導向 `reviews` service。

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio    # 此實作由 Istio 提供
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
  - name: my-gateway         # 路由繫結至哪個 Gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: reviews          # 直接是 Kubernetes Service 名稱
      port: 8080
```

```mermaid
flowchart LR
    C["用戶端"] --> GW["Gateway<br>class: istio"]
    GW --> HR["HTTPRoute<br>路由規則"]
    HR --> S["Service reviews"]
    style C fill:#673ab7,color:#fff
    style GW fill:#326ce5,color:#fff
    style HR fill:#326ce5,color:#fff
    style S fill:#0f9d58,color:#fff
```

重要欄位：

- **`gatewayClassName: istio`**--表示此 Gateway 由 Istio 實作。這相當於在 Istio Gateway 中透過 `selector` 綁定至 ingress gateway 的方式。
- HTTPRoute 中的 **`parentRefs`** 將路由連結至特定 Gateway。在 Istio 中，此角色由 VirtualService 的 `gateways` 欄位擔任。
- **`backendRefs`** 直接指向 Kubernetes Service 與連接埠。基本 Gateway API 中沒有 subsets 和 DestinationRule--版本與政策以其他方式描述。

還有一項便利之處：當您使用 `gatewayClassName: istio` 建立 `Gateway` 時，Istio 可以自動為此 gateway 部署獨立的 Envoy deployment。不需要預先安裝 ingress gateway--它會針對該 Gateway 出現。

## 11.5. TLS：Gateway API 上的 HTTPS

第 9 章的 Edge TLS 在 Gateway API 中以其專屬欄位描述。以 `protocol: HTTPS` 與 `tls` 區塊宣告 HTTPS listener，其中包含模式與指向含憑證 Secret 的參照：

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
      mode: Terminate                # gateway 終止 TLS（等同 Istio 的 SIMPLE）
      certificateRefs:
      - kind: Secret
        name: myapp-cert             # 與第 9 章相同的 tls Secret
    allowedRoutes:
      namespaces:
        from: All                    # 哪些 namespace 可繫結路由（見 11.7）
```

與第 9 章模式的對應關係：

- **`mode: Terminate`**--gateway 解密 TLS（如同 Istio 中的 `SIMPLE`/`MUTUAL`）。用戶端憑證（相當於 `MUTUAL`）透過 `frontendValidation`/`BackendTLSPolicy` 設定，並取決於標準版本。
- **`mode: Passthrough`**--gateway 不解密，流量透過 SNI 直通（如同 `PASSTHROUGH`）；應使用 `TLSRoute` 而非 `HTTPRoute`。

憑證儲存在普通 Kubernetes `Secret`、類型為 `tls` 中--也可以由 cert-manager（第 9 章）簽發，只是路由現在透過 `certificateRefs` 而非 `credentialName` 參照它。

## 11.6. HTTPRoute 中的 Canary 與 filters

加權流量分割（第 6 章的 canary）在 Gateway API 中是**標準**能力，而非擴充：`backendRefs` 具備 `weight` 欄位。

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
    - name: reviews-v1       # 90% 流量導向 v1
      port: 8080
      weight: 90
    - name: reviews-v2       # 10% 導向 v2
      port: 8080
      weight: 10
```

請注意：Gateway API 沒有 subsets/DestinationRule，因此不同版本是**不同 Kubernetes Service**（`reviews-v1`、`reviews-v2`），而非同一 service 的 subset。

HTTPRoute 可以透過 **filters**（`filters`）修改請求--這相當於 VirtualService 的部分能力：

```yaml
  rules:
  - filters:
    - type: RequestHeaderModifier      # 新增/移除標頭
      requestHeaderModifier:
        add:
        - name: x-env
          value: prod
    - type: RequestMirror              # 流量鏡像（第 6 章）
      requestMirror:
        backendRef:
          name: reviews-shadow
          port: 8080
    backendRefs:
    - name: reviews
      port: 8080
```

實用的 filter 類型：`RequestHeaderModifier`/`ResponseHeaderModifier`（headers）、`RequestRedirect`（redirect，包括 HTTP→HTTPS）、`URLRewrite`（重寫 path/host）、`RequestMirror`（鏡像流量）。但標準中沒有 **fault injection**--它仍是 Istio API 的獨有功能（第 8 章）。

## 11.7. 跨 namespace 路由：allowedRoutes 與 ReferenceGrant

Gateway API 的強項是明確且安全地在 namespace 之間分離權限。這裡有兩種機制。

**listener 上的 `allowedRoutes`**--Gateway 自行決定允許哪些 namespace 的路由綁定它（`from: Same`--僅自身、`All`--任意、`Selector`--依 namespace labels）：

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
            team: frontend      # 僅接受帶有此 label 的 namespace 的路由
```

**`ReferenceGrant`**--當一個 namespace 中的資源參照**另一個** namespace 的資源時（例如 `apps` 中的 HTTPRoute 想將流量傳送到 `data` 中的 Service），預設是禁止的。由**目標** namespace 中的 `ReferenceGrant` 授權：

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-apps-to-data
  namespace: data              # 目標 Service 所在的 namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: apps            # 誰在參照
  to:
  - group: ""
    kind: Service              # 允許參照的對象
```

這可防止其他人的路由未經您的同意就將流量「帶走」到您 namespace 中的 service--Istio API 沒有這種內建機制。

## 11.8. 與 Istio API 比較

| | Istio API | Kubernetes Gateway API |
|---|-----------|------------------------|
| 入站資源 | `Gateway` + `VirtualService` | `Gateway` + `HTTPRoute` |
| 路由綁定 | VirtualService 中的 `gateways` 欄位 | Route 中的 `parentRefs` |
| 實作選擇 | ingress gateway 上的 `selector` | `gatewayClassName` |
| 版本/subsets | `DestinationRule` (subsets) | 不同的 Service + `backendRefs` 中的 `weight` |
| 加權 Canary | `VirtualService` weight | `backendRefs.weight`（原生） |
| 鏡像 | `VirtualService` mirror | `RequestMirror` filter（原生） |
| Fault injection | 有 | 無（僅 Istio） |
| 後端政策 | `DestinationRule` (LB, circuit breaking) | 無（僅 Istio） |
| 依 namespace 的權限分隔 | 無內建功能 | `allowedRoutes` + `ReferenceGrant` |
| 標準 | Istio 專屬 | 通用、供應商中立 |
| 可攜性 | 僅 Istio | 任何相容的 ingress/mesh |

表格的主要結論是：Gateway API 在標準化、可攜性及團隊間權限分隔上勝出，而 Istio API 在後端能力的完整性（`DestinationRule`：負載平衡、circuit breaking、subsets）與 fault injection 上更強。兩種 API 都支援鏡像與加權 canary。

## 11.9. 使用什麼及何時使用（best practices）

以下是現實專案中的選擇實務建議。

**以下情況請選擇 Kubernetes Gateway API：**

- 正在開始新專案，且想使用最新標準；
- 可攜性很重要：不想在 manifest 層級綁定 Istio；
- 需要團隊間清楚分工（平台團隊擁有 `Gateway`，產品團隊擁有各自的 `HTTPRoute`）；
- 標準路由能力（依 path、headers、weights）已足夠；
- 使用 **ambient mode**：waypoint-proxy（第 22 章）正是透過 Gateway API 設定。

**以下情況請繼續使用 Istio API（VirtualService/DestinationRule）：**

- 需要標準中沒有的功能：**fault injection**（第 8 章）、`DestinationRule` 政策（細緻的負載平衡、circuit breaking、outlier detection、subsets）、路由委派；
- 已有大量可運作的 Istio API manifest，且沒有理由重寫它們。

（兩種 API 都有鏡像與加權 canary，因此無須為此遷移或留下。）

### 傳統 Kubernetes Ingress 資源（legacy）

還有第三種入站選項--普通 Kubernetes `Ingress`（`networking.k8s.io/v1`），也就是曾搭配 nginx-ingress、Traefik 與雲端 controller 使用的那個資源。Istio 可擔任它的 ingress-controller：當 `Ingress` 資源指定 `istio` class 時，istio ingress gateway 會讀取它們。

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
  ingressClassName: istio          # 由 istio ingress gateway 服務
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
    secretName: myapp-cert          # tls Secret，如第 9 章
```

它為何屬於 **legacy**，以及為何不應選作新流量的方案：

- `Ingress` 標準本身的能力非常有限：host、path、TLS--就這些。沒有 weights、鏡像、redirects、依 headers 分流。
- 額外功能皆由 controller 的**非標準 annotations** 實作（如第 26 章的 nginx）。各 controller 的 annotations 彼此不相容，而 Istio 僅支援其中很小的一部分--大多熟悉的 `nginx.ingress.kubernetes.io/*` 都無法運作。
- 產業與 Istio 本身的發展都朝向 Gateway API；它正是作為「下一代 `Ingress`」而打造。

實務結論：Istio 中保留傳統 `Ingress`，僅是為了遷移期間（第 26 章）與舊 manifest 相容。新的 ingress 請選擇 Kubernetes Gateway API，或在需要 Istio 功能時選擇 Istio `Gateway` + `VirtualService`。

**通用規則：**

- 不要同時透過 VirtualService 與 HTTPRoute 描述同一條路由--這會造成混淆與衝突。每個 service 應二選一。
- Istio API 不會消失，且仍獲完整支援，因此可以漸進式遷移：新 service 使用 Gateway API，舊的維持原樣。
- 產業發展方向是 Gateway API，因此即使目前主要流量使用 Istio API，也值得瞭解並掌握它。

## 11.10. 章節總結

- Kubernetes Gateway API (`gateway.networking.k8s.io`) 是管理入站流量的供應商中立標準；Istio 實作它。
- 請勿混淆 Istio `Gateway` 與 Gateway API 的 `Gateway`--它們是不同資源。
- Gateway API 中的角色：`GatewayClass`（實作）、`Gateway`（監聽什麼）、`HTTPRoute` 與其他 Route（導向何處）。
- 路由透過 `parentRefs` 綁定至 gateway，並透過 `gatewayClassName: istio` 選擇實作。
- Gateway API CRD 預設可能不存在--需個別安裝（`standard` 管道），而 `GatewayClass istio` 由 Istio 自行建立。
- TLS：HTTPS listener 使用 `tls.mode: Terminate`/`Passthrough`，並透過 `certificateRefs` 參照 Secret（相當於 `credentialName`）；憑證同樣由 cert-manager 簽發。
- 加權 canary（`backendRefs.weight`，但版本是不同的 Service）與鏡像（`RequestMirror` filter）是原生功能；fault injection 與 `DestinationRule` 政策僅存在於 Istio API。
- namespace 間的權限分隔：listener 上的 `allowedRoutes` 及用於 cross-namespace 參照的 `ReferenceGrant`--Istio API 中沒有內建對應項。
- Best practice：新 ingress、標準情境與 ambient 使用 Gateway API；需要 fault injection 或 DestinationRule 政策時使用 Istio API；不要將兩者混用於同一條路由。
- Istio 也會處理傳統 Kubernetes `Ingress`（`ingressClassName: istio`），但它屬於 legacy：能力有限，進階功能須透過非標準 annotations（僅支援小部分）。為遷移相容性而保留，新的流量不選用它。

## 11.11. 自我檢查問題

1. 相較於 Istio API，Kubernetes Gateway API 解決了什麼問題？
2. 名稱為 `Gateway` 的兩種資源有何不同？
3. 哪些 Gateway API 資源對應 Istio Gateway 與 VirtualService？
4. `gatewayClassName` 與 `parentRefs` 分別負責什麼？
5. 哪些情況下應繼續使用 Istio VirtualService/DestinationRule？Gateway API 缺少哪些功能？
6. 為何不應同時在兩種 API 中描述同一條路由？
7. 如何在 Gateway API 中設定 HTTPS 與加權 canary？canary 與 Istio 有何不同（subsets 如何處理）？
8. 為何需要 `allowedRoutes` 與 `ReferenceGrant`？它們解決什麼安全問題？
9. 若 Gateway API manifest 無法套用至叢集，應檢查什麼？
10. Istio 能否處理傳統 Kubernetes `Ingress`？為何它被視為 legacy？何時仍會使用它？

## 實作練習

透過 Kubernetes Gateway API（Gateway + HTTPRoute）設定 ingress：

🧪 實驗 16：[tasks/ica/labs/16](../../labs/16/README_TW.MD)

---
[目錄](../README_TW.md) · [第 10 章](../10/tw.md) · [第 12 章](../12/tw.md)
