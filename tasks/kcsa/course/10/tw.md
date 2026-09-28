[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [日本語版](jp.md)

# 第 10 章：驗證與授權

> **接下來的內容。** 在第 07-09 章中，我們保護了叢集元件、工作節點、`Pod` 與網路邊界。現在將探討請求到 Kubernetes API 的路徑：叢集先確認身分，接著決定是否允許其執行動作。這屬於 KCSA **Kubernetes Security Fundamentals** 領域，權重為 22%。

## 10.1 誰在存取 API：使用者與 `ServiceAccount`

每個對 Kubernetes API 的請求都會經過驗證，或稱 authentication。其目標是回答「這是誰？」。驗證成功後，API Server 會將使用者名稱與群組傳給下一個階段，即授權。

一般使用者，例如叢集外的工程師或 CI 系統，並不是 Kubernetes `User` 物件。Kubernetes 從已設定的驗證機制取得此類身分。`ServiceAccount` 是 Kubernetes API 物件，主要供 `Pod` 中的程序使用。其完整名稱包含 namespace：`system:serviceaccount:shop:catalog`。

| 方式 | 使用時機 | 重要限制 |
|---|---|---|
| TLS 用戶端憑證 | 管理員、叢集元件或自動化工具 | 必須保護私密金鑰及憑證有效期限。 |
| Bearer token | 自動化或整合 | token 會傳遞其持有者的權限，不得放入程式碼或日誌。 |
| `ServiceAccount` token | `Pod` 內的程序存取 API | 權限由 RBAC 決定，而非僅因擁有 token。 |
| OIDC | 外部身分提供者，例如企業 SSO | API Server 必須信任 issuer 並驗證 token claims。 |
| Authentication webhook | 外部服務確認用戶端 credential | 這是 authentication integration，而不是 admission webhook 或 authorizer。 |
| Bootstrap token | 用於節點初始加入的用途受限 token | 用於 bootstrap/TLS bootstrap，而非長期 application identity。 |

啟用匿名驗證時，匿名請求會成為使用者 `system:anonymous` 和群組 `system:unauthenticated`。這不是一般 API 存取的便利模式。在安全設定中，應停用匿名存取，或僅允許其存取刻意公開且安全的端點。

驗證本身不會授予存取權。憑證、token 或 OIDC 身分只會指出主體的名稱。該主體可以執行什麼動作，由授權決定。

## 10.2 `ServiceAccount` token 與 `default` 帳戶的風險

每個 `Namespace` 都含有名為 `default` 的 `ServiceAccount`。若 `Pod` 規格未指定 `serviceAccountName`，Kubernetes 便會指派它。這不表示 `default` 自動擁有廣泛權限：當為了便利而授予其 `RoleBinding` 或 `ClusterRoleBinding` 時，才會產生風險。

現代 Kubernetes（包括 v1.36）通常會透過 TokenRequest 機制向 `Pod` 發出 projected bound token。這種 token 與 `ServiceAccount` 和特定 `Pod` 繫結，具有有限生命週期，並由 kubelet 自動更新。除非有合理理由，否則不應建立含有 `ServiceAccount` token 的長期 Secret。

若應用程式不需要 Kubernetes API，就不需要 token。可在 `Pod` 或 `ServiceAccount` 本身停用其掛載：

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

若容器遭入侵，掛載的 token 可被讀取，並在有效期內於叢集外使用。因此，應為每個 `Pod` 選擇具有最小權限的專屬 `ServiceAccount`，而不將 `default` 用作應用程式的共用帳戶。停用 automount 不會取消 RBAC，但會從不需要 API 的 Pod 檔案系統中移除祕密。

## 10.3 授權：RBAC 與其他 authorizer

授權回答「已驗證的主體能否執行這項動作？」。API Server 會評估使用者或群組、`verb`、資源、namespace，以及有時的物件名稱與 API 路徑之組合。

Kubernetes 中可啟用多個 authorizer。它們會依設定順序檢查：第一個傳回 `Allow` 或 `Deny` 的 authorizer 會立即結束判定；僅當所有 authorizer 都傳回 `NoOpinion` 時，請求才會預設遭拒。RBAC 是多數叢集主要且建議使用的機制。

| 機制 | 用途 | 實務意義 |
|---|---|---|
| RBAC | `Role`、`ClusterRole` 與 binding 中的規則 | 適合可管理、可檢查存取控制的一般選擇。 |
| Node | 限制 kubelet 以節點身分執行的動作 | 用於節點身分，而非取代使用者的 RBAC。 |
| Webhook | 查詢外部授權服務 | 適合決策依賴外部系統時使用。 |
| ABAC | 將請求比對靜態 policy 檔案 | 對新專案而言已過時，難以稽核與維護。 |

請勿混淆 RBAC 與 authentication。`RoleBinding` 不會確認身分，也不會建立 token。它將已知主體與一組權限連結。同樣地，`NetworkPolicy` 限制網路連線，但不會取代 API Server 對資源權限的決定。

### Node authorizer 與 `NodeRestriction`：相鄰但不同的層次

**Node authorizer** 是供群組 `system:nodes` 中 kubelet/node identity `system:node:<nodeName>` 使用的特殊 authorizer。它限制 kubelet 可針對其節點及排程至該節點的 `Pod` 執行哪些 API 操作，包括所需的 `Secret`、`ConfigMap` 與 volume 資訊。這是 **authorization**。

**`NodeRestriction`** 是 validating admission plugin。它額外限制 kubelet 可修改哪些 `Node` 物件與相關 `Pod`：已正確識別的 kubelet 不應修改其他節點的 Node/Pod，或任意設定受保護的 labels。這是 **admission**，而不是 authorizer。

> **請勿混淆。** Node authorizer 回答「是否允許 node identity 執行此 API 動作？」。`NodeRestriction` 回答「即使已獲授權，這項物件變更是否允許？」。兩種機制對 kubelet 的 least privilege 都很重要，但不會取代使用者 RBAC、TLS 或節點防護。

## 10.4 RBAC：角色、binding 與最小權限

`Role` 僅描述一個 `Namespace` 內的規則。`ClusterRole` 描述整個叢集層級的規則，或可透過 `RoleBinding` 繫結至一個 namespace。`RoleBinding` 在自己的 namespace 內生效，`ClusterRoleBinding` 則作用於整個叢集。

RBAC 權限是累加的：多個 binding 的權限會合併，且不存在單獨的「拒絕」規則。因此，最小權限原則代表只授予所需的 `apiGroups`、`resources` 和 `verbs`，並選擇最小的作用範圍。

以下 `Role` 只允許應用程式讀取 namespace `shop` 中的一個 `ConfigMap`。這是狹窄規則的範例，而非所有任務的範本。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

可使用 `kubectl auth can-i` 命令檢查預期權限。例如，管理員可檢查特定帳戶的動作：

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

此命令可用於驗證，但不能取代對 manifest 與實際 binding 的審查。對 `secrets` 的 `get`、`list` 和 `watch` 權限，以及對工作負載的 `create`、`update`、`patch` 和 `delete` 權限，都需要特別注意。存取 RBAC 資源、`bind`、`escalate` 與 `impersonate` 可讓人授予或使用額外權限。`cluster-admin`、`verbs: ["*"]` 與 `resources: ["*"]` 並非安全的起始選擇。

這些特殊 authorization checks 處理不同任務：

- `bind` 涉及建立或修改 `RoleBinding` / `ClusterRoleBinding`。一般而言，caller 必須已擁有在相應 scope 中、所繫結 `Role`/`ClusterRole` 包含的 permissions。對特定角色明確授予 `bind`，即使沒有自己的全部這些 permissions，也可以進行 binding。

- `escalate` 不涉及 binding，而是建立或修改 `Role` / `ClusterRole`。一般而言，caller 無法將自己不擁有的 permissions 寫入角色。明確授予 `escalate` 是此防護的例外。

- classic `impersonate` 允許以指定 user/group/ServiceAccount 或其他受支援的 identity attribute 身分傳送請求。這是獨立能力，不能與 `bind` 或 `escalate` 混為一談。

在 Kubernetes v1.36 中，也提供預設啟用的 beta 機制 `ConstrainedImpersonation`。它新增更狹窄的 `impersonate:*` 與 `impersonate-on:*` verb 系列，不僅限制 identity，也限制代表該 identity 執行的動作。使用 classic `impersonate` 的現有 RBAC rules 仍可運作；API Server 可以使用 constrained checks，並在需要時 fallback 至 classic `impersonate`。

對 `pods` 的 `create` 權限值得特別注意：即使主體無法直接存取目標資料，建立 `Pod` 的能力本身也可能成為提升該主體影響力的一步。推理鏈如下：主體具有建立 `Pod` 的權限 → 新 `Pod` 可指定 namespace 中可用的任一 `ServiceAccount` 作為 `serviceAccountName`，除非另有設定明確禁止 → 透過所選的 `ServiceAccount` 或掛載的 `Secret`/`ConfigMap`/volume，該 `Pod` 可取得原始主體未直接擁有的資料或 API 權限。最終影響範圍取決於 namespace 中實際可用的 `ServiceAccount` 與 volume，以及個別限制 controls（例如 `automountServiceAccountToken: false`、PSA/PSS、現有 `ServiceAccount` 的受限 RBAC binding）。不應將建立 workload 的權限視為無條件通往任何 `Secret` 或叢集任何 `ServiceAccount` 的途徑：它只會依照其餘 namespace 設定所允許的程度擴大可能影響。

## 10.5 如何在實務中套用

平台團隊會區分人員與機器身分。員工透過企業 OIDC 登入，自動化工具取得獨立 credentials，而 `Namespace` 中每個元件都使用獨立的 `ServiceAccount`。

對於不呼叫 Kubernetes API 的應用程式 HTTP 服務，會設定 `automountServiceAccountToken: false`。需要 API 的 controller 會取得獨立的 `ServiceAccount`，以及具備明確資源和 verb 的 `Role`。在發布變更前，使用 `kubectl auth can-i` 進行檢查，接著審查 `RoleBinding` 與 `ClusterRoleBinding`。

定期尋找綁定至 `default` 的項目與寬泛的 `ClusterRoleBinding`。員工離職、token 外洩或憑證金鑰遺失時，應撤銷或替換 credentials，並重新審視相關權限。如此一來，單一 token 的外洩不會成為對整個叢集的永久存取權。

## 10.6 Exam vocabulary / 迷你詞彙表

| 術語 | 意義 |
|---|---|
| authentication | 確認 API 請求傳送者的身分。 |
| authorization | 決定該身分是否允許執行特定動作。 |
| `ServiceAccount` | Kubernetes 為通常在 `Pod` 中執行的程序提供的身分。 |
| bearer token | 持有者可取得與之關聯權限的 token。 |
| OIDC | 將 Kubernetes 連線至外部身分提供者的協定。 |
| RBAC | 透過角色與角色 binding 進行的存取控制。 |
| `Role` / `ClusterRole` | 單一 namespace / 叢集層級的一組規則。 |
| `RoleBinding` / `ClusterRoleBinding` | 將角色繫結至使用者、群組或 `ServiceAccount`。 |
| `bind` | 一項特殊 RBAC 權限，可繫結 Role/ClusterRole，而無須自己擁有被繫結角色的所有 permissions。 |
| `escalate` | 一項特殊 RBAC 權限，可建立/修改 Role/ClusterRole 並包含超出 caller 自身 permissions 的 permissions。 |
| `impersonate` | 對其他 identity 進行 impersonation 的 classic Kubernetes permission；在 v1.36 中也有使用更狹窄 verb 的 beta ConstrainedImpersonation。 |

## 10.7 Exam Essentials / 本章重點

- 一般使用者透過外部機制驗證，而 `ServiceAccount` 是 Kubernetes 為 `Pod` 中程序提供的物件。
- 用戶端憑證、bearer tokens、`ServiceAccount` token 與 OIDC 可確認身分，但未經授權不會提供權限。
- `default` 不會自動擁有廣泛權限，但將權限繫結給它，會使所有隱性使用它的 Pod 都可能持有那些權限。
- 不需要的應用程式 `ServiceAccount` token 不應透過 `automountServiceAccountToken: false` 掛載。
- RBAC 是主要 authorizer；與叢集層級的對應項目相比，`Role` 和 `RoleBinding` 通常能縮小存取範圍。
- 權限會累加，因此危險的 verb 與寬泛 wildcard 規則會增加遭入侵的後果。

## 10.8 請勿混淆及其在考試中的出現方式

在 MCQ（multiple choice question，選擇題）中，通常需要區分 authentication 與 authorization，並選擇最狹窄且安全的存取方式。常見陷阱：

- 認為 `ServiceAccount` 或 token 本身就會授予權限；權限由 RBAC binding 決定；
- 混淆 `RoleBinding` 與 `ClusterRoleBinding`：前者僅限於自己的 namespace；
- 認為 `default` 無條件危險：風險取決於授予它的權限及 token 掛載；
- 將 OIDC 當作授權方式：OIDC 確認外部身分，而存取決策由 authorizer 做出；
- 選擇 `cluster-admin` 或 wildcard，而非具有精確資源和 verb 集合的獨立角色。

先判斷問題在問什麼：誰發出請求、以何種方式確認身分，或允許什麼動作。接著檢查範圍：單一 namespace 或整個叢集。

## 10.9 自我檢查問題

### 1. 關於 `ServiceAccount` 的哪一項說法正確？

   - a. 它會在自己的 namespace 中自動取得 `cluster-admin`。

   - b. 它是供 `Pod` 中程序使用的 Kubernetes 身分；其權限由 RBAC binding 定義。

   - c. 它會取代用於網路存取的 `NetworkPolicy`。

   - d. 它是始終透過 OIDC 驗證的外部使用者。

<details>
<summary>答案與說明</summary>

**正確答案：b。** `ServiceAccount` 通常由 Pod 中的程序使用，其能力由角色與 binding 決定。OIDC、`cluster-admin` 與網路規則都不會因建立 `ServiceAccount` 而自然產生。

</details>

### 2. 對不需要 Kubernetes API 的 `Pod`，什麼可降低風險？

   - a. 啟用 API Server 的匿名驗證。

   - b. 在 `ClusterRole` 中加入 `verbs: ["*"]`。

   - c. 指派具有 `cluster-admin` 的 `default` `ServiceAccount`。

   - d. 設定 `automountServiceAccountToken: false`。

<details>
<summary>答案與說明</summary>

**正確答案：d。** 如此 Kubernetes 不會將 `ServiceAccount` token 掛載到 Pod 中。其餘選項會擴大存取權或建立不必要的攻擊面。

</details>

### 3. 哪個物件定義受限於一個 `Namespace` 的權限？

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>答案與說明</summary>

**正確答案：a。** `Role` 定義 namespace 範圍的規則（哪些資源允許哪些 verb），但本身不會將這些權限授予主體：實際授權使用同一 namespace 中的 `RoleBinding`，將 `Role` 繫結至特定 subjects。

</details>

### 4. Kubernetes 中用於管理使用者與 `ServiceAccount` 權限的主要選擇是哪個機制？

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>答案與說明</summary>

**正確答案：c。** RBAC 透過角色與 binding 定義可檢查的存取規則。OIDC 屬於驗證，Node authorizer 服務節點身分，而 ABAC 基於靜態 policies。

</details>

### 5. 為何對 `secrets` 的 `get` 權限需要特別謹慎？

   - a. 它可能洩露 credentials、金鑰和 token，進而提供 Kubernetes 或外部系統的存取權。
   - b. 它只會傳回 Secret metadata，且永遠不允許 API 用戶端取得儲存的值。
   - c. 即使 RBAC 未包含相應權限，它也會自動授予主體建立 `Pod` 的權利。
   - d. 它會使 API Server 在每次讀取時重新加密 Secret，因而增加用戶端權限。

<details>
<summary>答案與說明</summary>

**正確答案：a。** `Secret` 通常包含可開啟其他資源存取權的資料。因此，應依 least privilege 授予 `get`，尤其是範圍更廣的 `list/watch`。讀取 Secret 不會自動建立其他 RBAC 權限。

</details>

> **下一步。** 請深入學習第 10 章 CKS：RBAC 與存取最小化、第 11 章 CKS：ServiceAccounts 與 token，以及第 12 章 CKS：限制 Kubernetes API 存取。角色的基本語法也見於第 38 章 CKA：RBAC，而 `ServiceAccount` 與 admission 的鏈結見於第 21 章 CKA。在 KCSA 中，請繼續閱讀關於 Pod Security Standards 與 Pod Security Admission 的[第 11 章](../11/tw.md)。

[目錄](../README_TW.md) · [第 09 章](../09/tw.md) · [第 11 章](../11/tw.md)
