[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 104 - 限制對 Kubernetes API 的存取：RBAC、ServiceAccount 與 anonymous-auth

## 目標

在這個 CKS 實驗中，你要依據最小權限原則限制對 Kubernetes API 的存取。實作涵蓋最小化的 namespaced RBAC、
現代的短效 ServiceAccount token、沒有 API token 的 Pod、移除過時的
過度權限，以及停用對 API server 的匿名存取。

請只操作任務中指定的物件。Namespace `security-104` 與
刻意設置的危險綁定 `legacy-operator-admin` 已由啟動腳本準備好，任務 10-12 的
fixtures 也是：Secret `legacy-config`、namespace `rbac-a`/`rbac-b` 與
namespace `development`。這是學習用的設定，不是 production 的範例。

## Threat model

假設攻擊者已經在某個 Pod 中執行程式碼，並試圖利用 workload 的 identity 或缺少 authentication 的情況，朝 Kubernetes API 移動。在這種情況下，重要的不只是初始存取，還有 compromise 之後的 blast radius。

任務 1 收斂過度的 RBAC scope，任務 2 收斂長效 token，任務 3 收斂 Pod 中不必要的 API 存取。這會減少 compromise 之後利用 workload identity 的可能性。

任務 4 消除 wildcard 的 cluster-wide 權限，任務 5 消除 anonymous access。這些路徑中的每一條，單獨都可能把 blast radius 擴大到 Kubernetes API。

任務 6 收斂另一條獨立的洩漏路徑：透過 environment variable 傳入的 secret，會成為行程環境的一部分，任何有權限對容器 `exec` 的行程都能從 `/proc/1/environ` 讀取它，而且如果程式本身或診斷工具會印出 environment，它還可能出現在 application logs、crash dump 或其他診斷輸出中。對於帶有 `secretKeyRef` 的 `env`，`kubectl describe pod` 只會顯示對 Secret 及其鍵的引用(`<set to the key ... in secret ...>`)；而對於帶有 `secretRef` 的 `envFrom`，則只會顯示 Secret 的名稱，而不是解析後的值 - 不要把這個引用誤認為是值本身的洩漏。帶有 `defaultMode: 0400` 的 Volume mount 並不會消除容器內被授權行程對該值的存取，但它把 secret 從行程環境中移除，並把檔案的讀取權限限制為只有擁有者。

任務 7 收斂隱藏的 RBAC privilege escalation 路徑：`impersonate`、`bind`/`escalate` 與 CSR approval 不會直接擴大可存取的資源清單，而是讓人能夠以他人的名義行動，或自行替自己授予更廣的權限 - 這與任務 4 中的 wildcard `*` 屬於不同類別的風險。任務 8 提供的是系統性、而非逐點的防護：namespace/default SA 層級的 automount，即使對開發者忘了明確停用 token 的 Pod 也有效。

任務 9 說明預防(任務 1-8)與偵測是不同但互補的層次。即使任務 7 已經堵住了具體的 escalation 路徑，為了應對未來的資安事件，仍需要一種方法來看出**危險的 RBAC 變更**(例如，錯誤或惡意地把 `cluster-admin` 授予某人)，而不必持續手動執行 `kubectl get`:audit log 提供可重現的 forensic evidence，說明究竟是誰發起了這項變更，而不只是 RBAC 狀態目前的快照。

ATT&CK T1528(Steal Application Access Token)與 T1613 為這個情境提供了背景：這些任務並不模擬某一次特定的攻擊，而是限制已經被入侵的 workload 所造成的後果。

任務 10-12 涵蓋三個基本的、在考試中經常出現的 workflow，而不是新的威脅：任務 10 - 安全地重複使用既有的 secret，而不必在 manifest 中逐案寫死值；任務 11 - 針對性地修補過度的 Role，以及正確的跨 namespace RBAC 綁定(這裡很容易在 scope 上出錯)；任務 12 - 透過憑證完整地 onboarding 新使用者，從 private key 到可驗證的存取，而不只是分析一份現成的 kubeconfig。

## 開始前先自我檢查

在打開 `check_result` 之前，請確認你能有把握地回答這些問題。如果不能 - 請回頭閱讀 [第 10 章](../../course/10/tw.md)(RBAC)、[第 11 章](../../course/11/tw.md)(ServiceAccounts)與 [第 12 章](../../course/12/tw.md)(限制對 API 的存取)。

<details>
<summary>1. 在任務 1 的情境下，`Role`+`RoleBinding` 與 `ClusterRole`+`ClusterRoleBinding` 有什麼不同？</summary>

`Role` 只在單一 namespace 中有效，但它的 `RoleBinding` 「可以」引用來自「任何」其他 namespace 的主體(例如 ServiceAccount)- Kubernetes 正式支援與 `RoleBinding` 自己的 namespace 不同的 `subjects[].namespace`。保持固定的是所授予權限的 SCOPE：權限只在建立 `RoleBinding` 的 namespace 中有效，無論主體來自何處。`RoleBinding` 也可以引用 `ClusterRole`(而不只是 `Role`)- 這種情況下，權限來自 cluster-wide 的範本，但只在該 `RoleBinding` 所在的 namespace 中授予。`ClusterRole`+`ClusterRoleBinding` 則提供對整個叢集的存取。任務 1 要求最小化的 **namespaced** 存取，因此要用 `Role`，而不是 `ClusterRole`，否則 scope 會比需要的更寬。
</details>

<details>
<summary>2. 為什麼 bound projected token(任務 2)被認為比 legacy Secret-based token 更安全？</summary>

Bound projected token 是短效的(由 `expirationSeconds` 指定)，會自動過期並由 kubelet 輪替，而且綁定到具體的 Pod - Pod 被刪除時 token 就失效。Legacy Secret-token 沒有 expiration，以一般 `Secret` 的形式儲存在 etcd 中，即使 Pod 已經不存在，也會無限期保持有效。
</details>

<details>
<summary>3. `automountServiceAccountToken: false` 在 Pod 層級與在 ServiceAccount 層級所提供的效果有什麼差別？</summary>

在 ServiceAccount 層級 - 這是 baseline：該值套用於所有使用這個 SA 的 Pod，除非 Pod 明確覆寫它。在 Pod 層級 - 這是 override:Pod spec 中明確的欄位優先於 SA 的值。任務 8 專門檢查 SA/namespace 層級的 baseline，而任務 2-3 檢查的是在具體 Pod 層級的明確設定。
</details>

<details>
<summary>4. 為什麼 `impersonate`/`bind`/`escalate`(任務 7)與 wildcard `*`(任務 4)不屬於同一類風險？</summary>

`resources`/`verbs` 中的 wildcard `*` 直接擴大**可用的操作與資源清單**。`impersonate`/`bind`/`escalate` 本身並不提供對新資源的存取 - 它們讓人能夠**以他人的名義行動**(`impersonate`)，或**自行授予自己原本沒有的權限**(`bind`/`escalate`)。這是另一類獨立的 privilege escalation，如果在稽核 RBAC 時只看 `verbs`/`resources`，而沒有考慮這三個特殊的動詞，就很容易漏掉。
</details>

## 基礎架構

環境透過 Terragrunt 部署在 AWS `eu-central-1`:

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`，含公有子網路 |
| `ssh-keys` | 用於存取節點的金鑰 |
| `k8s-1` | 單節點 kubeadm 叢集 Kubernetes `1.36.0`、containerd 與 **Calico** |
| `worker` | 已設定好 `kubectl` 與 `check_result` 的工作機 |

Control-plane 允許執行一般的 Pod，因此不需要單獨的 worker 節點。
任務 5 需要 SSH 存取 control-plane:API server 的
static Pod manifest 就位於那裡。

## 部署

```bash
TASK=104 make run_cks_task
```

透過 SSH 連線到工作機。`cluster1-admin@cluster1` context 已經設定好。

```bash
time_left
check_result
```

## 任務

---
| **1** | **用於讀取 Pod 的最小 RBAC** |
| :---: | :--- |
| 要做什麼 | 在 namespace `security-104` 中建立 ServiceAccount `auditor`、Role `pod-observer` 與 RoleBinding `auditor-pod-observer`。Role 必須**只**允許 core API 資源 `pods` 的 `get`、`list`、`watch`。只把它綁定到 ServiceAccount `auditor`。 |
| 驗收標準 | Role 恰好包含一條針對 `pods`、動詞為 `get`、`list`、`watch` 的規則；RoleBinding 引用這個 Role 與 ServiceAccount `auditor`；以 `auditor` 的身分不能刪除 `secrets`。 |

<details>
<summary>💡 任務 1 的提示</summary>

常見的錯誤是加入多餘的動詞(例如「以防萬一」加上 `create`)，或使用 `ClusterRole` 而不是 `Role`。自行檢查：`kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` 必須回傳 `yes`，而 `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` 必須回傳 `no`。如果 Role 與 RoleBinding 位於不同的 namespace，綁定不會生效 - `RoleBinding` 必須與 `Role` 在同一個 namespace 中，而其中的主體必須在 `name`/`namespace` 上完全吻合。
</details>

---
| **2** | **短效的 projected ServiceAccount token** |
| :---: | :--- |
| 要做什麼 | 在 `security-104` 中建立 ServiceAccount `api-client` 與 Pod `token-client`。不要使用 legacy Secret-token。停用一般的 token 自動掛載，並透過**恰好一個** projected `serviceAccountToken` source，把需要的 token 掛載到 `/var/run/secrets/tokens/api-token`，使用 `path: api-token`,`expirationSeconds` 在 `600` 到 `3600` 之間(含邊界)- 不要在同一個(或另一個)projected volume 中加入任何額外的 `serviceAccountToken` source。**不要設定 `audience`**，讓 kubelet 請求 API server 預設的 identifier。如果應用程式需要單獨的 audience，請先對照 API server 上的 `--api-audiences`(或 `--service-account-issuer` 的預設值)，然後再明確設定。 |
| 驗收標準 | Pod 使用 `api-client`，具有 `automountServiceAccountToken: false`，並且在整個 Pod 規格中包含**恰好一個** projected `serviceAccountToken` source - 沒有寫死的 audience，指定了 path，且 `expirationSeconds` 在 `600`-`3600` 範圍內(兩端皆含)。從 admin context 對掛載的 token 執行的 TokenReview 回傳 `authenticated: true` 與名稱 `system:serviceaccount:security-104:api-client`；另一個獨立的 RBAC 檢查確認這個 ServiceAccount 不能刪除 `secrets`。 |

<details>
<summary>💡 任務 2 的提示</summary>

不需要死記 `projected.sources[].serviceAccountToken` 的精確語法 - 在 `kubernetes.io/docs` 上有現成的範例：Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/),**"serviceAccountToken projected volumes"** 一節。最常見的錯誤是明確設定 `audience: kubernetes.default.svc`，以為這是標準值。對 kubeadm 叢集來說，這「不是」有保證的預設值 - 如果設定了 API server 透過 `--api-audiences` 不接受的 audience,TokenReview 會回傳 `authenticated: false`。完全不要指定 `audience` 欄位 - kubelet 這時會請求 API server 預設的 identifier，伺服器一定會接受它。另外別忘了 Pod 本身的 `automountServiceAccountToken: false` - 否則 Kubernetes 除了你的 projected volume 之外，還會額外加入一般的(legacy 風格的)token volume。另一個常見的錯誤是選擇太小的 `expirationSeconds`(例如 `300`):Kubernetes API 要求 `serviceAccountToken` projected volume 至少 `600` 秒 - 更小的值會被 API server 在 `kubectl apply` 時以 invalid 為由拒絕(`must be at least 10 minutes`)。
</details>

---
| **3** | **沒有 Kubernetes API token 的 Pod** |
| :---: | :--- |
| 要做什麼 | 建立帶有 `automountServiceAccountToken: false` 的 ServiceAccount `no-token-sa`，以及在 `security-104` 中使用這個 ServiceAccount 的 Pod `no-token`。在 Pod 本身也要明確設定 `automountServiceAccountToken: false`。使用任何安全的長時間執行的映像，例如帶有 `sleep 3600` 的 `busybox:1.36`。不要另外手動掛載任何帶有 ServiceAccount token 的 Secret - Pod 完全不應該有任何 API token，無論是透過 automount，還是透過明確掛載的 legacy Secret。 |
| 驗收標準 | ServiceAccount 與 Pod 都停用了自動掛載；Pod 使用 `no-token-sa`；它的規格中沒有自動加入的 ServiceAccount token volume，也沒有手動掛載的 `kubernetes.io/service-account-token` 類型的 Secret；在容器內嘗試讀取 `/var/run/secrets/kubernetes.io/serviceaccount/token` 會以錯誤結束(檔案不存在)，而 `kubectl exec` 本身必須成功執行。 |

<details>
<summary>💡 任務 3 的提示</summary>

與任務 8 的差別：技術上只在一個層級(SA 或 Pod)停用 automount 就足夠了，但任務要求**兩個**層級同時停用(defence in depth)。自行檢查：`kubectl get pod no-token -o jsonpath='{.spec.volumes}'` 不得包含任何類似 `kube-api-access-*` 的內容。如果 volume 還是出現了 - 請檢查你是在建立 Pod「之前」而不是之後停用了 automount(修改 SA 不會影響已經建立的 Pod)。停用 automount 並不妨礙手動透過 `volumes[].secret` 掛載舊的(legacy)`type: kubernetes.io/service-account-token` 的 `Secret` - 如果你這樣做，Pod 在形式上沒有 automount 的 volume，但實際上仍會得到有效的 API token。任務要求的是完全沒有 token，而不只是沒有 automount。
</details>

---
| **4** | **移除過度的 cluster-wide 權限** |
| :---: | :--- |
| 要做什麼 | 叢集中刻意留下了帶有 wildcard 權限的 ClusterRole `legacy-operator-admin`，以及同名、針對 `security-104` 中 ServiceAccount `legacy-operator` 的 ClusterRoleBinding。請刪除**兩個**物件。不要把 wildcard 存取換成另一個寬鬆的 ClusterRole。 |
| 驗收標準 | `legacy-operator-admin` 無論作為 ClusterRole 還是 ClusterRoleBinding 都不存在；ServiceAccount `legacy-operator` 不能再讀取 `security-104` 中的 `secrets`。 |

<details>
<summary>💡 任務 4 的提示</summary>

只刪除 `ClusterRoleBinding` 而不刪除 `ClusterRole`，會把危險的範本留在叢集中 - 之後有人可能建立新的綁定指向它。請刪除兩個物件。用兩個獨立的指令自行檢查：`kubectl get clusterrole legacy-operator-admin` 與 `kubectl get clusterrolebinding legacy-operator-admin` - 兩者都必須回傳 `NotFound`。
</details>

---
| **5** | **停用對 API server 的 anonymous access** |
| :---: | :--- |
| 要做什麼 | • 在 control-plane 上建立檔案 `/etc/kubernetes/authentication-config.yaml`，內容為 `AuthenticationConfiguration`，對除了 `/livez`、`/readyz` 與 `/healthz` 以外的所有 endpoint 停用 anonymous access - kubeadm 使用 `/livez` 與 `/readyz` 做 API server static Pod 的 HTTPS liveness/readiness/startup probes(`/healthz` 為了相容性而保留)，而直接以 `--anonymous-auth=false` 全面停用則會破壞 probes 本身，而不只是阻擋攻擊者的存取。<br/>• 透過 `hostPath` volume 與參數 `--authentication-config=<容器內的路徑>` 在 `/etc/kubernetes/manifests/kube-apiserver.yaml` 中掛載這個檔案，並**移除**既有的 `--anonymous-auth=true` - 兩種設定 anonymous access 的方式是互斥的，如果同時設定，kube-apiserver 將無法啟動。Kubelet 會自動重新啟動 static Pod。<br/>• 等待 API server 就緒(Pod 保持 Running/Ready)，並確認未經驗證的請求對 `/version` 會得到 `401`，而對 `/livez` 與 `/readyz` 會得到 `200`。<br/>• 另外檢查生效的 `--authorization-mode` 包含 `Node,RBAC`，並且**不**包含 `AlwaysAllow`(沒有限制性授權的 authentication 毫無意義)。<br/>• 稽核 subjects 為 `system:anonymous`/群組 `system:unauthenticated` 的 ClusterRoleBinding：叢集中刻意留下了一個危險的(lab-owned)這類綁定 `lab104-unintended-anonymous-access`，請把它連同它的 ClusterRole 一起刪除。**不要動**標準的 kubeadm 綁定 `system:public-info-viewer` - 它同樣綁定到 `system:unauthenticated`，但只提供對 non-resource URL `/livez`、`/readyz`、`/healthz`、`/version`、`/version/` 的存取，這是 bootstrap 的正常部分(default Kubernetes RBAC)，不是這個任務要找的問題。<br/>• 這是與本任務中 `AuthenticationConfiguration` 分開的另一個層次：那裡的 `anonymous.conditions` 刻意只允許匿名 identity 存取 `/livez`/`/readyz`/`/healthz` - `/version` 之所以無法匿名存取，正是因為對它的請求在 authentication 階段根本不會取得 anonymous identity，所以根本走不到透過 `system:public-info-viewer` 的授權，即使這個 non-resource URL 清單更寬也一樣。 |
| 驗收標準 | • API server 的 static Pod 使用 `--authentication-config`，它引用的 `AuthenticationConfiguration` 具有 `anonymous.enabled: true`，且 `conditions` 恰好包含 `/livez`、`/readyz`、`/healthz`。<br/>• 沒有參數 `--anonymous-auth`。<br/>• 重新啟動後 kube-apiserver Pod 保持 `Running`/`Ready`。<br/>• 未經驗證的 `GET /version` 回傳 `401`。<br/>• 未經驗證的 `GET /livez` 與 `GET /readyz` 回傳 `200`。<br/>• 經過驗證的(帶有有效 credentials)對 `/readyz` 的請求同樣可用。<br/>• 生效的 `--authorization-mode` 包含 `Node,RBAC`，且不包含 `AlwaysAllow`。<br/>• ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` 已刪除。<br/>• 標準的 `system:public-info-viewer` 保持原樣。<br/>• 群組 `system:unauthenticated` 在任何 namespace 中都不能讀取 `pods`/`secrets`/`configmaps`。 |

<details>
<summary>💡 任務 5 的提示</summary>

不要透過 `kubectl edit pod` 編輯 Pod 物件 - kubelet 會監看 manifest 檔案，並把任何透過 API 做的變更覆寫回原來的狀態。請編輯節點磁碟上的 `/etc/kubernetes/manifests/kube-apiserver.yaml` 檔案。儲存之後請等待：kubelet 不會立刻發現檔案的變更，而且在 static Pod 重新啟動期間，API server 會有幾秒鐘無法使用 - 如果儲存檔案之後 `curl` 馬上沒有回傳任何東西，不要慌。

單純的 `--anonymous-auth=false` 在這裡**不適用**:kubeadm `release-1.36` 產生的 kube-apiserver static Pod，正好在 `/livez` 與 `/readyz` 上使用 HTTPS liveness/readiness/startup probes，而 kubelet 的 HTTP probes 不會傳遞 client credentials - 完全停用 anonymous access 時，這些請求會得到 `401`,kubelet 會認為容器不健康，並可能讓 kube-apiserver 反覆重新啟動，這不只會破壞這個任務，也會破壞後面的任務 9。正確的做法是 `AuthenticationConfiguration`，搭配 `anonymous.enabled: true` 與 `anonymous.conditions`，把 anonymous access 只限制在需要的 health 路徑：

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` 與 `--anonymous-auth` 不能同時設定 - 如果 manifest 中兩個參數都存在，kube-apiserver 將無法啟動。請確認你已經完全移除了 `--anonymous-auth=true`，而不只是把值換成 `false`。

稽核匿名的 ClusterRoleBinding:`kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`。你至少會看到兩個
綁定 - 標準的 `system:public-info-viewer`(不要動)與 lab-owned 的
`lab104-unintended-anonymous-access`(連同它的 ClusterRole
`lab104-anonymous-debug-access` 一起刪除)。可以依據它們所引用的 ClusterRole 名稱來區分：
`kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` 會顯示 `system:public-info-viewer` - 這是受限於
non-resource URL 的 ClusterRole，而不是一般的 resources。
</details>

---
| **6** | **透過 env 在 `/proc/1/environ` 洩漏 Secret：改用 volume** |
| :---: | :--- |
| 要做什麼 | • `security-104` 中的 Pod `app-vulnerable` 透過 `envFrom.secretRef` 取得 `db-creds` - 任何能對容器執行 `kubectl exec`(`cat /proc/1/environ`)的人，或在意外輸出 env 時能讀取 logs/describe 的人，都能取得這個值。<br/>• 確認這個洩漏：執行 `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ`，並把輸出(包含 `DB_PASSWORD`)儲存到 `/var/work/tests/artifacts/6/env-leak-before.txt`。<br/>• 以相同的名稱 `app-vulnerable` 重新建立 Pod：移除帶有這個 secret 的 `envFrom`/`env`，把 `db-creds` 掛載為 volume `db-creds-vol` 到 `/etc/secrets`,**read-only**，並帶有 `defaultMode: 0400`。<br/>• 確認新的 `/proc/1/environ` 中沒有變數 `DB_PASSWORD`，並把所掛載檔案的 `stat -L -c '%a'` 儲存到 `/var/work/tests/artifacts/6/secret-file-mode.txt`(旗標 `-L` 是必須的 - secret 是透過 `..data` 符號連結鏈掛載的，沒有 `-L` 時 `stat` 會顯示符號連結本身的 mode，而不是實際檔案的)。 |
| 驗收標準 | `env-leak-before.txt` 包含 Secret `db-creds` 中 `DB_PASSWORD` 的真實值(而不只是文字 `DB_PASSWORD`)；最終的 Pod `app-vulnerable` 沒有引用 `db-creds` 的 `env`/`envFrom`，也沒有第二種掛載同一個 Secret 的方式；volume `db-creds-vol` 以 `readOnly: true` 與 `defaultMode: 0400`(十進位 `256`)掛載到 `/etc/secrets` - checker 會自己在容器內檢查 `stat -L -c %a`，並要求恰好是 `400`；最終 Pod 的 `/proc/1/environ` 中沒有 `DB_PASSWORD`(在 `exec` 成功執行的前提下 - 失敗的 `exec` 不算作證明)；同時應用程式行程仍然確實能從 `/etc/secrets/DB_PASSWORD` 讀取 secret 的值(positive control)。 |

<details>
<summary>💡 任務 6 的提示</summary>

確認洩漏步驟中的 `/proc/1/environ` 並不是看到這個值的唯一方式
(`kubectl exec ... -- env` 或 `echo $DB_PASSWORD` 也會得到同樣的結果，因為
container runtime 預設會給 exec 出來的行程與 PID 1 相同的環境)。
`/proc/1/environ` 是直接透過 `/proc` 讀取 PID 1 的環境，而不是依賴
你具體的 exec-shell 所繼承的內容 - 這正是在 security 分析中實際使用的做法，
用來查看任何行程的環境，而不只是自己的。

Volume mount **不會剝奪已經有 `kubectl exec` 的人的存取權** - 修正之後 `cat
/etc/secrets/DB_PASSWORD` 讀取這個值,和修正之前 `cat
/proc/1/environ` 讀取它一樣輕鬆，這是預期的(任務中的 positive control 專門
檢查這一點)。這個任務的重點不是封閉 exec 存取 - 只要行程有權限讀取這個值，
無論是檔案還是變數，都不可能做到。真正的差別在於
不需要明確 `exec` 就會觸發的洩漏路徑：
- 環境變數會被**任何**子行程自動繼承(`fork()`
  會複製整個 env)- 應用程式內部的第三方函式庫、plugin 或意外的 subprocess
  都會得到 `DB_PASSWORD`，即使開發者沒有想到這一點；檔案不會這樣
  傳遞 - 子行程必須明確知道路徑並開啟它；
- crash handler 與 error logger 在崩潰時經常會把行程整個 `environ` 都印出來 -
  這會自動進入 logs；而檔案的內容本身不會
  進入 logs，除非程式碼明確地讀取並記錄它；
- 環境變數沒有存取權限模型 - 容器 namespace 中的任何行程都看得到；
  而帶有 `defaultMode: 0400` 的檔案有 - 只有具備相應 UID 的行程才能讀取。

```text
[FAIL] Secret Volume 的 defaultMode 指定錯誤。
💡 你指定了 defaultMode: 400(十進位 400)。
   YAML 支援以前導零表示的八進位字面值(0400),Kubernetes 會把它
   解讀為一般的 Unix 權限;沒有前導零的 400 會被讀成十進位
   數字 400,而不是權限 0400(它的十進位值是 256)。
```

這是這個任務最常見的錯誤：`defaultMode` 是帶有 POSIX mode bits 的數值欄位，而
Kubernetes YAML 對它同時支援八進位與十進位的寫法 - 不像
JSON 只允許十進位。如果你寫 `defaultMode: 400`(沒有前導
零),Kubernetes 會把它當作**十進位**的 400，而不是慣用的 Unix 權限
`0400`。正確的做法是寫 `defaultMode: 0400`(帶前導零，YAML
會識別為八進位字面值)，或明確指定十進位的等價值 `256`。自行
檢查：`kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
必須回傳 `256`，而在容器內執行 `stat -L -c '%a' /etc/secrets/DB_PASSWORD` 必須回傳 `400`。
</details>

---
| **7** | **稽核並撤銷隱藏的 RBAC privilege escalation 路徑(`impersonate`、`bind`、`escalate`、CSR approval)** |
| :---: | :--- |
| 要做什麼 | • ClusterRole `build-agent-hidden-privesc` 不含 wildcard `*`(這是另一條、已在任務 4 中消除的路徑)，但它讓 `security-104` 中的 ServiceAccount `build-agent` 擁有三條真正可被利用的 privilege escalation 路徑：<br/>• 對 `users`/`groups`/`serviceaccounts` 的 `impersonate` - 偽冒身分，如果攻擊者知道有這樣的使用者，甚至包括 cluster-admin。<br/>• 對 `clusterroles` 的 `create`/`update`/`bind`/`escalate`，以及對 `clusterrolebindings` 的 `create`/`update` - 基本動詞讓人能夠建立/修改這些物件本身，而 `bind`/`escalate` 繞過內建的 RBAC 檢查，否則該檢查會禁止授予/綁定比自己更廣的權限(沒有基本的 `create`/`update`，單靠 `bind`/`escalate` 不足以真正完成 escalation)。<br/>• 對 `certificatesigningrequests/approval` 的 `update` + 對 signer `kubernetes.io/kube-apiserver-client` 的 `approve` - 能夠核准帶有任意 identity 的 CSR(但這個 ClusterRole 本身並不提供 `create certificatesigningrequests`：要把攻擊進行到簽發憑證，該 identity 還需要另一項建立 CSR 的能力，例如透過另一個被入侵的角色，或已經能夠送出 CSR 的被入侵自動化)。<br/>• 找出其 ClusterRole 允許 `impersonate`、`bind` 或 `escalate` 的**所有** ClusterRoleBinding(例如，透過 `kubectl get clusterrole -o json \| jq` 依據 `rules[].verbs`)，並把它們寫入 `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`。<br/>• 刪除 ClusterRoleBinding `build-agent-hidden-privesc` **以及** ClusterRole `build-agent-hidden-privesc`(如果你找到其他非預期的 - 也一併刪除，但不要動系統的 `system:*` ClusterRoleBinding)。<br/>• 透過 `kubectl auth can-i` 對找到的「所有」權限確認已撤銷：`impersonate users`、`bind clusterroles`、`escalate clusterroles`、`update certificatesigningrequests/approval`，以及對 signer `kubernetes.io/kube-apiserver-client` 的 `approve` - 全部都必須回傳 `no`。 |
| 驗收標準 | • `dangerous-bindings-before.txt` 在找到的項目中包含 `build-agent-hidden-privesc`，作為 ClusterRoleBinding(而不是 ClusterRole 的名稱，如果兩者不同的話)。<br/>• 修正之後 ClusterRoleBinding **以及** ClusterRole `build-agent-hidden-privesc` 都不存在。<br/>• `build-agent` 不能 `impersonate`、`bind`、`escalate`、`update certificatesigningrequests/approval`。<br/>• `build-agent` 不能對 signer `kubernetes.io/kube-apiserver-client` 執行 `approve`。<br/>• 系統的 `system:*` ClusterRoleBinding 未被動到。 |

<details>
<summary>💡 任務 7 的提示</summary>

CSR approval 是與 `impersonate`/`bind`/`escalate` 不同的類別：它不在同一個依據 `verbs` 的 `jq` 篩選條件中，因為它是針對資源 `certificatesigningrequests/approval`、動詞 `update` 的獨立規則，再加上對具體 `signer` 的 `approve`。如果你只依據 `impersonate`/`bind`/`escalate` 篩選，你會找到一條路徑，但漏掉 CSR - 請分別搜尋兩者，而且對每一個都要儲存 **ClusterRoleBinding** 的名稱，而不是它所引用的 ClusterRole(在這個實驗中名稱相同，但一般情況下無法保證)。不要刪除帶有 `system:` 前綴的系統 `ClusterRoleBinding` - Kubernetes 的核心元件需要它們來進行合法的 `impersonate`(例如 `system:kube-controller-manager`)。
</details>

---
| **8** | **Namespace 層級的 baseline：不帶 automount 的 `default` ServiceAccount** |
| :---: | :--- |
| 要做什麼 | • 任務 3 是針對性地停用 automount，在具體的 Pod 及其自己的 ServiceAccount 內部。這裡需要的是 **namespace** 層級的 baseline。<br/>• 建立 namespace `security-104-baseline`，等待其中自動建立的 ServiceAccount `default` 出現(ServiceAccount 的建立是由獨立的 controller 非同步進行的，而不是與 namespace 本身同時建立)。<br/>• 然後才在這個 ServiceAccount 上設定 `automountServiceAccountToken: false`:`kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`。<br/>• 在這個 namespace 中，以 `busybox:1.36`(`sleep 3600`)建立 Pod `implicit-default-sa`,**不要**明確指定 `serviceAccountName` 或 `automountServiceAccountToken` - 它必須隱含地使用 `default` SA 並繼承它的值。<br/>• 確認最終 Pod 的規格中沒有欄位 `automountServiceAccountToken`(而不是等於 `false`)，沒有 token volume，而且在容器內嘗試讀取 token 檔案時，恰好會因檔案不存在而出錯(此時 `kubectl exec` 本身必須成功執行)。 |
| 驗收標準 | • `security-104-baseline` 中的 ServiceAccount `default` 具有 `automountServiceAccountToken: false`。<br/>• Pod `implicit-default-sa` 使用 `serviceAccountName: default`(隱含或明確皆可)。<br/>• 它的規格中**沒有**欄位 `automountServiceAccountToken`(既沒有明確設為 `true`，也沒有設為 `false`)。<br/>• 沒有自動加入的帶有 ServiceAccount token 的 `projected`/`secret` volume，也沒有手動掛載的 `kubernetes.io/service-account-token` 類型的 legacy `Secret`。<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` 成功結束(exit code `0`)，透過成功的 exec 來確認檔案不存在，而不是透過任意的錯誤。 |

<details>
<summary>💡 任務 8 的提示</summary>

操作順序至關重要：如果你在 `patch` 套用到 namespace 的 `default` SA「之前」就建立了 Pod,Pod 會依據舊的(預設 `true`)值取得 token。另外，不要在 `kubectl create namespace` 之後「立刻」、沒有檢查就修補 `default` SA - ServiceAccount `default` 是由獨立的 controller 建立的，在 namespace 建立後的最初一小段時間內可能還不存在；請等它出現(`kubectl get serviceaccount default -n security-104-baseline`)，然後才修補。任務刻意不在 Pod 中指定 `serviceAccountName` - 這模擬的是開發者單純忘了 ServiceAccount 的真實情況，而 baseline 必須預設保護他。在 Pod 「本身」明確設定 `automountServiceAccountToken: false` 只能證明針對性的設定(就像任務 3 那樣)- 這裡需要把這個欄位完全留空，才能證明確實是從 SA/namespace 繼承的。
</details>

---
| **9** | **整合任務：透過 audit log 偵測 RBAC 升權並予以圍堵** |
| :---: | :--- |
| 要做什麼 | • 這個任務把 RBAC(本實驗)與 audit 記錄結合起來(參見 [第 32 章](../../course/32/tw.md))- 沒有 audit log，危險的 RBAC 變更這件事本身，只能事後透過 `kubectl get` 看出來，而不是可重現的 forensic evidence。<br/>• 在 control-plane 上啟用最小的 audit backend：建立 `/etc/kubernetes/audit/policy.yaml`，其中有針對 `apiGroups: ["rbac.authorization.k8s.io"]`、資源 `clusterroles` 與 `clusterrolebindings` 的 `RequestResponse` 規則，以及作為 fallback 的 catch-all `Metadata`。<br/>• 在 static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` 中加入 `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`、`--audit-log-path=/var/log/kubernetes/audit/audit.log`，以及需要的 hostPath volume/volumeMount(請事先建立目錄)。等待 API 恢復。<br/>• 以管理員身分(`cluster1-admin`)建立 ClusterRoleBinding `incident-simulated-escalation`，把 ClusterRole `cluster-admin` 綁定到 `security-104` 中的 ServiceAccount `build-agent` - 這**不是** `build-agent` 自己嘗試 escalation(任務 7 已經撤銷了它真正的 privilege escalation 路徑)，而是由管理員模擬的危險 RBAC 變更：真實的情境是有人(人類操作員、腳本、被入侵的 CI/CD)錯誤或惡意地把 `cluster-admin` 授予某個 ServiceAccount，而 SOC/security 工程師的任務，正是透過 audit log 偵測到這樣的事件，而不是持續手動執行 `kubectl get`。<br/>• 在 audit log 中找出針對 `clusterrolebindings`、帶有這個名稱、`requestObject.roleRef` 指向 `cluster-admin`，且 `requestObject.subjects` 中有 `system:serviceaccount:security-104:build-agent` 的 `create` 事件，把整個事件(包括 `user.username` - 真正發起請求的人)儲存到 `/var/work/tests/artifacts/9/audit-escalation-event.json`。這不只是「確認 audit 規則有在運作」- SOC 工程師在這裡真正的任務，是**擷取並保存具體的記錄**作為 forensic evidence(checker 會自己獨立地讀取 control-plane 上的 `audit.log`，並把你的 artifact 的 `auditID` 與真實記錄比對 - 捏造的、即使看起來相似的 JSON 都不會通過)。<br/>• 執行 containment：刪除 `incident-simulated-escalation`，並透過 `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent` 確認存取已被撤銷；把最終的 `no` 儲存到 `/var/work/tests/artifacts/9/containment-result.txt`(不帶 `-n`/`-A` 的 `can-i` 只檢查你的 kubeconfig context 目前的 namespace，而不是整個叢集 - 請明確指定 namespace)。 |
| 驗收標準 | • kube-apiserver 的 static manifest 包含 `--audit-policy-file` 與 `--audit-log-path`,API server 健康。<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` - 有效的 JSON audit event，具有 `verb: create`、`objectRef.resource: clusterrolebindings`、`objectRef.name: incident-simulated-escalation`、`requestObject.roleRef.name: cluster-admin`，且 `requestObject.subjects` 中有來自 `security-104` 的 ServiceAccount `build-agent`。<br/>• containment 之後 ClusterRoleBinding `incident-simulated-escalation` 不存在。<br/>• `containment-result.txt` 包含 `no`。 |

<details>
<summary>💡 任務 9 的提示</summary>

針對 `rbac.authorization.k8s.io` 的 `RequestResponse` 規則必須放在 policy 規則清單的「第一位」- 較具體的規則必須在通用的 `Metadata`-catch-all 之前，否則 catch-all 會先攔截事件，你只會得到 `Metadata` 層級，而不是帶有請求內容的 `RequestResponse`。請在整個 policy 層級加上 `omitStages: [RequestReceived]` - 這個階段還沒有 `requestObject`/`responseStatus`，而 `Metadata`-catch-all 會套用到叢集的所有請求，因此沒有 `omitStages`,`audit.log` 會成長兩倍快，卻對這個任務沒有任何額外的好處。請在 API server 以新的 audit backend 重新啟動「之後」再建立 `incident-simulated-escalation` - 否則事件根本不會進入 log。這個任務檢查的是偵測危險的 RBAC 變更本身，而不是檢查它確實是 `build-agent` 做的 - 在 audit log 中，欄位 `user.username` 會顯示真正的發起者(管理員)，而不是 `build-agent`;`build-agent` 在這個事件中只是作為權限的接收者出現(`requestObject.subjects`)。`audit-escalation-event.json` 必須是從 `/var/log/kubernetes/audit/audit.log` 複製來的**真實**記錄(包括它的 `auditID`)- 手動拼湊、有幾行相符的 JSON 無法通過檢查，因為 self-check 會自己讀取 control-plane 上的 log 並比對 `auditID`。別忘了 containment：刪除 `ClusterRoleBinding` 本身只是任務的一半，另一半是透過 `kubectl auth can-i` 證明存取確實被撤銷了，而不只是物件變得無法讀取。
</details>

---
| **10** | **解碼、建立並掛載 Secret** |
| :---: | :--- |
| 要做什麼 | • `security-104` 中已經存在帶有兩個鍵 `SERVICE_USER` 與 `SERVICE_TOKEN` 的 Opaque Secret `legacy-config`。透過 API 讀取它，並把兩個值從 base64 解碼。<br/>• 以 literal 值(`kubectl create secret generic ... --from-literal=...`)建立新的 generic Secret `rehydrated-config`，使用「相同的」鍵名與「相同的」解碼後的值。<br/>• 以 `busybox:1.36`(`sleep 3600`)建立 Pod `secret-workflow`，它把 `rehydrated-config` 以 **read-only** volume 掛載到 `/etc/rehydrated`。<br/>• 確認容器內兩個檔案確實可以讀取，並包含預期的值。 |
| 驗收標準 | • `rehydrated-config` 存在，且它解碼後的 `SERVICE_USER`/`SERVICE_TOKEN` 與原本的 `legacy-config` 相符。<br/>• Pod `secret-workflow` 以 `readOnly: true` 把這個 Secret 掛載到 `/etc/rehydrated`。<br/>• 在容器內執行 `kubectl exec` 能讀取兩個檔案，且內容正確。 |

<details>
<summary>💡 任務 10 的提示</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` 會給你
真實的值 - 不要把任意字串寫進新的 Secret,checker 會自己重新
解碼原本的值並比對。`kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` 會自動編碼這些值 -
透過 `--from-literal` 建立時，不需要自己做 base64-encode。
別忘了 volumeMount 上的 `readOnly: true` - 掛載了但可寫入的 Secret 不會
通過驗收標準，字面上就是以這個旗標為準，即使 Pod 本身運作正常也一樣。
</details>

---
| **11** | **修復既有的 Role，並把它綁定到另一個 namespace 的 SA** |
| :---: | :--- |
| 要做什麼 | • 在 namespace `rbac-a` 中已經存在 ServiceAccount `dev`、Role `pod-role` 與 RoleBinding `pod-role-binding`。Role 目前允許對 `pods` 的 `get`、`list`、`delete` - 這裡的 `delete` 是多餘的(請移除)，而 `watch` 缺少，但實際需要(請加入)。請修正既有的那個 Role，不要建立新的。<br/>• 另外，在 namespace `rbac-b` 中已經存在 ConfigMap `shared-config`。請在 `rbac-b` 中建立新的 Role 與 RoleBinding，讓來自 **namespace `rbac-a`** 的 ServiceAccount `dev` 對 `rbac-b` 中的 `configmaps` 具有 `get`/`list`(而且只有這些)的存取。<br/>• 在 `rbac-a` 中建立一個帶有 `serviceAccountName: dev` 的 Pod。 |
| 驗收標準 | • `rbac-a` 中的 Role `pod-role` 恰好允許對 `pods` 的 `get`、`list`、`watch`。<br/>• `dev` 不能在 `rbac-a` 中 `delete pods`。<br/>• `dev` 可以在 `rbac-b` 中 `get`/`list configmaps`，但不能 `delete configmaps`，也不能讀取同一處的 `secrets`。<br/>• 在 `rbac-a` 中存在使用 ServiceAccount `dev` 的 Pod。 |

<details>
<summary>💡 任務 11 的提示</summary>

`RoleBinding` 可以引用來自「任何」其他 namespace 的主體(`ServiceAccount`)-
Kubernetes 透過 `subjects[].namespace` 正式支援這一點。但 `RoleBinding` 本身，
以及與它相關的權限，永遠只在「它自己」所在的 namespace 中有效 - 因此
新的 Role+RoleBinding 必須建立在 `rbac-b` 「中」，而不是 `rbac-a`。自行檢查：
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` 必須
回傳 `yes`，而 `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
回傳 `no`。
</details>

---
| **12** | **透過 CSR + namespaced RBAC 建立用戶端憑證使用者** |
| :---: | :--- |
| 要做什麼 | • 建立新的 Kubernetes 使用者 `john`，以用戶端憑證驗證：產生 private key，然後產生帶有 `CN=john` 的 CSR(`openssl req -new`)。<br/>• 把它作為 Kubernetes `CertificateSigningRequest` `john-csr` 送出，帶有 `signerName: kubernetes.io/kube-apiserver-client`；核准 CSR(`kubectl certificate approve`)。<br/>• 從 `status.certificate` 取出簽發的憑證(base64-decode)，並把它連同 private key 儲存到 `/var/work/tests/artifacts/12/john.crt` 與 `.../john.key`。<br/>• 在 namespace `development`(已建立)中建立允許對 `pods` 執行 `create`/`list`/`get` 的 Role，以及針對 subject `{kind: User, name: john}` 的 RoleBinding。<br/>• 為 John 組合出單獨的 kubeconfig(`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`)，並把它儲存為 `/var/work/tests/artifacts/12/john.kubeconfig`；確認 `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` 確實可以運作，而對另一個 namespace 的同樣請求會得到 `Forbidden` - 這和直接的 TLS 請求一樣證明了憑證可用，但是透過慣用的 `kubectl`，而不是 `curl`。<br/>• 透過即時的 `kubectl auth can-i --as=john` 檢查來確認：John 可以在 `development` 中 `create`/`list`/`get` pods，在同一處不能 `delete` 它們，而且在另一個 namespace 中沒有相同的權限。 |
| 驗收標準 | • `john-csr` 使用正確的 signer 並且為 `Approved`。<br/>• 簽發的憑證具有 `CN=john`，並且確實能通過這個叢集 CA 的驗證。<br/>• `development` 中的 Role+RoleBinding 讓 John 對 `pods` 恰好有 `create`/`list`/`get`。<br/>• John 在同一處不能 `delete` pods，在其他 namespace 中也沒有存取權。<br/>• 儲存的 `john.crt`/`john.key` 在直接的 TLS 請求下確實會被 API server 接受(而不只是透過 `--as=john` impersonation)。<br/>• 組合出的 kubeconfig 存在於路徑 `/var/work/tests/artifacts/12/john.kubeconfig`，且 `kubectl --kubeconfig=<這個檔案> get pods -n development` 確實可以運作，而對另一個 namespace 的同樣請求以 `Forbidden` 結束。 |

<details>
<summary>💡 任務 12 的提示</summary>

不要把這個任務與實驗 114 搞混：在那裡你分析的是 kubeconfig 中「已經存在」的憑證，
而這裡需要從零開始簽發一個全新的、真正可用的 identity。
以憑證為基礎的使用者，其 RBAC 是透過 `subjects: [{kind: User, name:
john}]` 綁定的,而不是 `ServiceAccount` - Kubernetes 中的 `User` 沒有單獨的 API 物件，它的
「存在」完全取決於用戶端憑證中的 CN 與 binding 中的
`name` 相符。`kubectl auth can-i` 中的 `--as=john` 只檢查 RBAC 邏輯
(impersonation)，並不能證明憑證確實有效 - 請另外確認，
在 control-plane 上針對 `/etc/kubernetes/pki/ca.crt` 執行 `openssl verify` 會回傳 `OK`。
</details>

## 檢查

在工作機上執行：

```bash
check_result
```

檢查包含 Init 與十二個獨立的任務。修改 API server 之後，
部分測試可能會短暫等待 static Pod 重新啟動。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)

## 刪除

```bash
TASK=104 make delete_cks_task
```
