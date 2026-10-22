[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission:restricted、audit/warn 與 read-only root filesystem

## 目標

在這個 CKS 實驗中，你要透過 namespace 的 labels 設定內建的 **Pod Security Admission (PSA)**。
對於 production namespace，會以 `enforce` 模式啟用 `restricted`，驗證不安全的 Pod 被拒絕，
並部署一個能通過的 hardened Pod。
對於另一個單獨的 namespace，你要啟用 `baseline` 等級的觀察模式 `audit` 與 `warn`。
最後，容器的 root filesystem 會變成 read-only，而唯一
必要的寫入則只允許在 `emptyDir` 中進行。

請只操作任務中的物件。叢集中事先建立了空的 namespace
`psa-restricted-107`、`psa-observe-107` 與 `psa-controller-107`；其中沒有 PSA-labels 也沒有 workload。

## 開始前先自我檢查

<details>
<summary>1. 在 Pod Security Admission 中，`enforce` 與 `audit`/`warn` 有什麼不同？</summary>

`enforce` 會真正阻擋違反所選 PSS 等級的 Pod 的建立 - admission request 會以錯誤結束。`audit`/`warn`「不會」阻擋請求：Pod 仍然會被建立，但 `audit` 會在 kube-apiserver 的 audit log 中加入 annotation，而 `warn` 會在 `kubectl apply` 時向使用者顯示文字警告。這是不同層級的職責：`audit`/`warn` 用於在啟用真正的阻擋之前進行觀察，`enforce` 才是真正的防護。
</details>

<details>
<summary>2. 為什麼對 namespace 需要把 `*-version` label 與 PSS 等級一起固定？</summary>

沒有固定的版本(`enforce-version`),PSA 在每次檢查時都會使用目前的 Kubernetes 版本 - 如果叢集升級了，`restricted`/`baseline` 的規則集合可能在你不知不覺中改變，昨天能通過的 Pod 可能今天就開始被拒絕，而你什麼也沒做。固定版本讓行為可預測、可重現，不受未來叢集升級的影響。
</details>

<details>
<summary>3. 為什麼任務 6 中的 `ValidatingAdmissionPolicy` 不是重複 PSA，而是補充它？</summary>

PSS `restricted` 定義的是固定的、標準化的 security 欄位集合(non-root、capabilities、seccomp、escalation)。`automountServiceAccountToken` 不在這個集合中 - PSA 完全不檢查它。這意味著 Pod 可以完全相容於 `restricted`，卻仍然悄悄取得它不需要的、被掛載的 API token。自訂的 `ValidatingAdmissionPolicy` 補上的正是這個缺口，而不是試圖取代或重複 PSA 已經做的事。
</details>

## 基礎架構

環境透過 Terragrunt 部署在 AWS `eu-central-1`:

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`，含公有子網路 |
| `ssh-keys` | 用於存取機器的 SSH 金鑰 |
| `k8s-1` | 單節點 kubeadm 叢集 Kubernetes `1.36.0`、containerd 與 **Calico** |
| `worker` | 具備 `kubectl`、context `cluster1-admin@cluster1` 與 `check_result` 的工作機 |

Control-plane 接受一般的 Pod，因此不需要單獨的 Kubernetes worker 節點。
所有任務都在工作機上執行。

## 部署

```bash
TASK=107 make run_cks_task
```

透過 SSH 連線到工作機，並檢查對叢集的存取：

```bash
time_left
kubectl get nodes
check_result
```

## 任務

---
| **1** | **以固定版本 enforce restricted** |
| :---: | :--- |
| 要做什麼 | 在 namespace `psa-restricted-107` 上設定 `pod-security.kubernetes.io/enforce=restricted` 與 `pod-security.kubernetes.io/enforce-version=v1.36`。確認 PSA 確實會拒絕不安全的 Pod：在這個 namespace 中，對帶有 `hostNetwork: true` 的 Pod 做 server-side dry-run，必須以包含 `violates PodSecurity` 的錯誤結束。不要更改系統 namespace 的 labels。 |
| 驗收標準 | 兩個 enforce-label 的值精確；不安全的 Pod 在 `psa-restricted-107` 中無法通過 admission；系統 namespace `kube-system`、`kube-public` 與 `kube-node-lease` 在本實驗範圍內不會取得 `pod-security.kubernetes.io/*` labels。 |

<details>
<summary>💡 任務 1 的提示</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - 兩個 label 會立即生效，PSA 不需要重新啟動任何東西。請透過帶有 `hostNetwork: true` 的 `kubectl apply --dry-run=server` 自行檢查 - 必須是 `--dry-run=server`(而不是 `client`)，因為包括 PSA 在內的 admission controllers 只在 server-side 運作。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

先做 baseline - 在設定 labels「之前」，確認同一個不安全的 manifest
能通過(否則無法確定 denial 是由你的 enforce label 還是由其他原因造成):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

設定兩個 label，然後重複「同一個」manifest - 現在必須出現
帶有文字 `violates PodSecurity` 的 admission 錯誤：

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **能通過 restricted 的 Hardened Pod** |
| :---: | :--- |
| 要做什麼 | 在 `psa-restricted-107` 中以 `busybox:1.36` 建立 Pod `restricted-app`，不以 root 執行，並且不會立刻結束。設定 pod-level `runAsNonRoot: true`、`runAsUser: 1000` 與 `seccompProfile: RuntimeDefault`。在 container securityContext 中，禁止 privilege escalation，捨棄 capability `ALL`，明確保留 `privileged: false`，並設定 `seccompProfile: RuntimeDefault`。 |
| 驗收標準 | Pod 被 PSA 接受並正在執行；以 UID 1000/non-root 執行，且沒有任何 container/init/ephemeral container 覆寫 pod-level `runAsUser: 1000`;seccomp 為 `RuntimeDefault`;escalation 與 privileged 被禁止；capabilities `ALL` 已被捨棄。 |

<details>
<summary>💡 任務 2 的提示</summary>

如果 Pod 收到 admission rejection - 請仔細閱讀錯誤訊息，它通常會指出「確切」缺少的欄位(例如 "container has no capabilities.drop")。關於 Kubernetes 1.36 中 PSS `restricted` 語意的一個重要細節：它要求實際生效的(不一定要逐字重複設定的)、允許的 `seccompProfile` - pod-level 的 profile(`spec.securityContext.seccompProfile.type`)可以被沒有設定自己欄位的容器繼承，反過來，如果 container-level 的欄位在「所有」容器上都明確設定，即使沒有 pod-level 的 profile 也足夠。也就是說，PSS 本身並不要求字面上同時有「兩個」層級。**在這個實驗中，我們刻意要求在 Pod 與容器上都明確設定 `RuntimeDefault`** - 不是因為 PSS 要求這樣，而是為了讓你練習兩個層級的設定。同樣地，`runAsUser: 1000` 是這個實驗自己明確的 hardening 決定：PSS `restricted` 禁止 UID `0`，但並不要求具體是 `1000`(任何非零值或完全不設定這個欄位，對 PSS 本身都是允許的)。
</details>

---
| **3** | **baseline 的觀察模式** |
| :---: | :--- |
| 要做什麼 | 在 namespace `psa-observe-107` 上啟用 PSA 的兩個模式：`pod-security.kubernetes.io/audit=baseline`、`pod-security.kubernetes.io/audit-version=v1.36`、`pod-security.kubernetes.io/warn=baseline`、`pod-security.kubernetes.io/warn-version=v1.36`。不要加入 `enforce`：這是用於在阻擋之前分階段觀察的 namespace。 |
| 驗收標準 | 有四個 audit/warn labels，等級為 `baseline`，版本為 `v1.36`；沒有 enforce-label。 |

<details>
<summary>💡 任務 3 的提示</summary>

四個獨立的 label - 很容易漏掉其中一個(特別是某個模式的 `-version`)。一次檢查全部四個：`kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

Baseline - 在設定 labels「之前」，違規的 manifest 應該能不帶 PSA 警告地通過
(namespace 還沒有被觀察):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

設定全部四個 label，然後重複「同一個」manifest - 現在 `kubectl apply`
必須輸出 `Warning: ... would violate PodSecurity "baseline:v1.36"`，而指令
仍然必須成功結束(exit 0)，而不是以錯誤結束：

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit 不會阻擋 legacy workload** |
| :---: | :--- |
| 要做什麼 | 在 `psa-observe-107` 中以 `busybox:1.36` 建立 Pod `baseline-audit-sample`，它使用 `hostNetwork: true` 並執行 `sleep 3600`。在 `kubectl apply` 時記錄 PSA 對違反 baseline 的警告：Pod 必須被建立，因為 `warn` 與 `audit` 本身並不禁止請求。 |
| 驗收標準 | `baseline-audit-sample` 存在，具有 `hostNetwork: true`，並已被 API 接受；namespace 中仍然沒有 enforce 模式。 |

<details>
<summary>💡 任務 4 的提示</summary>

如果 Pod「沒有」建立 - 請檢查你是否在任務 3 中不小心設定了 `enforce` label，而不是只有 `audit`/`warn`。PSA 的 warning 會直接出現在 `kubectl apply` 的輸出中(`Warning: would violate PodSecurity "baseline:v1.36"`)，不需要到單獨的 log 中尋找。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

這個任務實際上是重複任務 3 的 self-check，只是使用持久的 Pod。建立
`baseline-audit-sample` 之後，確認它確實存在，並且
是 `Running`/`Pending`(沒有被拒絕):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

與 namespace `psa-restricted-107`(任務 1)比較：同一個不安全的 manifest 在那裡
「必須」被拒絕，而在這裡 - 被接受。差別正在於 `enforce` label，它存在於
一個 namespace 而不存在於另一個：

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **帶有可寫 emptyDir 的 Read-only root filesystem** |
| :---: | :--- |
| 要做什麼 | 完善 `restricted-app`：在容器上啟用 `readOnlyRootFilesystem: true`。建立 `emptyDir` 類型的 volume `writable-tmp`(建議 `medium: Memory`，讓暫存檔案不會落到節點的磁碟上)，並把它掛載到 `/tmp`，不帶 `readOnly: true`。容器只被允許寫入這個暫存 volume；不要使用 `hostPath`。透過 Pod 內的即時呼叫證明兩種結果：嘗試寫入容器的根目錄(例如 `touch /root-write-test.txt`)必須以錯誤 `Read-only file system` 結束，而寫入 `/tmp/test.txt` - 必須成功。在修改 Pod 的不可變欄位時，請刪除並以相同的名稱重新建立 `restricted-app`。 |
| 驗收標準 | 容器具有 read-only root filesystem；名為 `writable-tmp` 的 `emptyDir` 以可寫方式掛載到 `/tmp`；對 regular containers 而言，這是唯一可寫的 declarative `volumeMount`，而所有額外的 `volumeMounts` 都是 read-only；任務 2 的 hardened 設定被保留；即時嘗試寫入容器根目錄會回傳 `Read-only file system`，而寫入 `/tmp/test.txt` 成功結束且內容可讀取。 |

<details>
<summary>💡 任務 5 的提示</summary>

`readOnlyRootFilesystem` 屬於無法在既有 Pod 上修改的欄位(immutable field)- 帶有修改後 securityContext 的 `kubectl apply` 會回傳錯誤。請刪除 Pod(`kubectl delete pod restricted-app`)並以相同的名稱重新建立，而不是試圖原地更新既有的 Pod。
</details>

---
| **6** | **Native ValidatingAdmissionPolicy：要求 `automountServiceAccountToken: false`** |
| :---: | :--- |
| 要做什麼 | • PSA `restricted` 已經要求 `allowPrivilegeEscalation: false`、`capabilities.drop` 包含 `ALL`、non-root 與 seccomp - 任務 2 展示的正是這些。<br/>• 但 PSS `restricted` **不檢查** `automountServiceAccountToken`：不需要 Kubernetes API 的 Pod，可能悄悄取得被掛載的 ServiceAccount token，並完整通過 PSA。這是另一個不在 PSS 涵蓋範圍內的 control，因此這裡適合使用自訂的 `ValidatingAdmissionPolicy`，而不是重複內建的 PSA。<br/>• 建立 `ValidatingAdmissionPolicy` `require-no-automount-token`，其 CEL 運算式要求在 Pod 層級 `automountServiceAccountToken == false`。<br/>• 套用 `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`，透過 `matchResources.namespaceSelector` 限制在 `psa-restricted-107`，並帶有 `validationActions: [Deny]`。<br/>• 用 server-side dry-run 證明全部三種狀態：完全相容於 PSA 的 Pod(帶有任務 2 的所有欄位 - non-root、seccomp、drop ALL、escalation false)在沒有該欄位時，必須從 policy+binding 這個確切的組合得到 DENY;`automountServiceAccountToken: false` 必須得到 ALLOW;`automountServiceAccountToken: true` 必須再次從同一個組合得到 DENY。<br/>• 建立 policy 之後，`psa-restricted-107` 中的新 Pod(包括重新建立的 `restricted-app`)本身必須包含 `automountServiceAccountToken: false`，否則 policy 會拒絕它們。 |
| 驗收標準 | • **物件：**`ValidatingAdmissionPolicy require-no-automount-token` 與它的 `ValidatingAdmissionPolicyBinding` 存在，`validationActions` 包含 `Deny`,Binding 只比對 `psa-restricted-107`。實驗中這個 policy 恰好存在一個 Binding - `require-no-automount-token-binding`；不會為其他 namespace 建立這個 policy 的額外 Binding。<br/>• **三種狀態**：對相容於 PSA、但沒有 `automountServiceAccountToken: false` 的 Pod 做 server-side dry-run，被拒絕的原因正是 `ValidatingAdmissionPolicy 'require-no-automount-token'` 與 `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` 這個組合(不是 PSA 的訊息 `violates PodSecurity`，也不是其他 policy)；帶有 `automountServiceAccountToken: false` 的 Pod 被接受，而帶有 `automountServiceAccountToken: true` 的 Pod 被同一個確切的組合拒絕。<br/>• **涵蓋所有 Pod**:policy 涵蓋 `psa-restricted-107` 內，它的 `resourceRules` 所選取的所有 Pod。不要在 `ValidatingAdmissionPolicy` 中加入 `spec.matchConditions`、`matchConstraints.objectSelector` 或 `matchConstraints.namespaceSelector`，也不要在 Binding 的 `matchResources` 中加入 `objectSelector` - 它們會把 coverage 縮小到部分 Pod,workload 就可能因 label 或請求條件而逃過檢查。<br/>• **Namespace scope**：只由 Binding 的 `matchResources.namespaceSelector` 設定，精確綁定到 `psa-restricted-107`;selector 不包含針對其他 namespace-label 鍵的條件，而且本身就明確地把 scope 限制在這個 namespace。<br/>• **CEL**:validation 不包含依 Pod 的名稱/labels/annotations、user/request、`namespaceObject`、`params`、`variables` 或其他欄位而定的例外：決定只取決於 `object.spec.automountServiceAccountToken`(任何正確的 CEL 形式都可以，包括 optional 語法 `object.spec.?automountServiceAccountToken.orValue(true) == false`)。`spec.auditAnnotations` 不存在或為空：它各自的 CEL expressions 可能透過 `failurePolicy` 影響 admission，因此 admission control 只由 `spec.validations` 設定。不使用 `variables` 與 `paramKind`。<br/>• **Resource scope:**`matchConstraints.resourceRules` 把 policy 恰好限制在 `core/v1 pods` 的 `CREATE` 與 `UPDATE` 操作，沒有 `resourceNames`;`scope` 不存在、等於 `*` 或 `Namespaced`，但不是 `Cluster`；不使用 `excludeResourceRules`。Binding 不透過自己的 `resourceRules`/`excludeResourceRules` 縮小 resource/operation scope。<br/>• 這讓我們能夠用 `missing / false / true` 三種狀態證明完整的 boolean contract，而不是只靠幾個挑選出來的 workload 範例。 |

<details>
<summary>💡 任務 6 的提示</summary>

這個任務的測試 Pod 必須「完全」相容於 PSA(任務 2 的所有欄位)，只缺少 `automountServiceAccountToken: false` - 如果測試 Pod 同時違反 PSS 與你新的 policy，你就無法證明是「你的」policy 起了作用，而不是內建的 PSA。沒有 `matchResources.namespaceSelector` 的 `ValidatingAdmissionPolicyBinding` 會套用到「整個」叢集 - 務必把 scope 精確地限制在一個 namespace `psa-restricted-107`(例如透過 `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`)，而不是透過帶有多個值的 `matchExpressions`，其中 `psa-restricted-107` 只是幾個符合的 namespace 之一：如果你的 selector 不小心也比對到 `psa-observe-107`，同一條規則就會在那裡意外地生效。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

Baseline - 在建立 VAP/Binding「之前」，同一個相容於 PSA、但沒有 automount opt-out 的
Pod 應該能通過(PSA 本身不會拒絕它，`automountServiceAccountToken` 不屬於
PSS):

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

建立 VAP + Binding，並重複不帶該欄位的 manifest - 現在請求必須得到
正是 `ValidatingAdmissionPolicy 'require-no-automount-token'` 透過 binding
`require-no-automount-token-binding` 發出的 DENY，「不是」來自 PSA。然後檢查兩個明確的值：
`false` 必須通過，而 `true` 必須從同一個確切的組合得到 DENY。

```bash
kubectl apply -f require-no-automount-token.yaml   # 你的 VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 預期:ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

使用同一個相容於 PSA 的 manifest，設定 `automountServiceAccountToken: false` - 請求
必須通過：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 預期:pod/self-check-automount-false created(或 server-side dry-run success)
```

現在設定 `automountServiceAccountToken: true` - 請求必須再次被
完全相同的 policy 與 binding 拒絕：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# 預期:ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

最後，也是最重要的 - 檢查 scope 的「邊界」，而不只是 denial 的事實：同一個
manifest(沒有 automount opt-out)，但在 namespace `psa-observe-107` 中，必須「通過」- 如果
它也被拒絕，表示你的 `namespaceSelector` 比對到的不只一個 namespace:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# 預期:0(沒有被 denied)- 否則 binding 的 scope 太寬
```
</details>

---

| **7** | **Controller-driven admission denial：透過 ReplicaSet events 診斷** |
| :---: | :--- |
| 要做什麼 | 在空的 namespace `psa-controller-107` 中建立 Deployment `controller-app`(label `app=controller-app`,replicas=1)，使用沒有 hardening 的簡單 Pod template(例如 `busybox:1.36`、`sleep 3600`，沒有 `securityContext`)- 它必須成功啟動，PSA 目前還不會妨礙。然後在這個 namespace 上啟用 `pod-security.kubernetes.io/enforce=restricted` 與 `enforce-version=v1.36`(已經存在的 Pod 會繼續運作 - PSA 不會動已經建立的物件)。刪除目前的 Pod:ReplicaSet 會嘗試建立替代的 Pod，而這次 admission 會拒絕它。透過 `kubectl -n psa-controller-107 describe rs` 與 `kubectl -n psa-controller-107 get events` 檢查原因 - 那裡會有 `FailedCreate`，文字為 `violates PodSecurity "restricted:v1.36"`。修正 Deployment 的 Pod template(加入與任務 2 相同的 hardening 欄位：non-root、`seccompProfile: RuntimeDefault`、`capabilities.drop: [ALL]`、`allowPrivilegeEscalation: false`)，並等待 ReplicaSet 成功建立新的、能通過的 Pod。 |
| 驗收標準 | Namespace 強制執行 `restricted:v1.36`;Deployment 中的 Pod template 完全符合 PSS `restricted`；刪除目前的 Pod 之後，ReplicaSet 確實會在目前的 enforce 模式下建立新的 Ready Pod(不只是「物件存在」- 而是透過即時刪除與重新建立來檢查)。 |

<details>
<summary>💡 任務 7 的提示</summary>

順序很重要：先建立沒有 hardening 的 Deployment(能通過，PSA 目前還不是 enforce)，然後
在 namespace 上設定 label enforce=restricted(既有的 Pod 不受影響)，然後 `kubectl
delete pod -l app=controller-app` - ReplicaSet 正是在這時會撞上 admission deny。
如果不手動刪除 Pod，你根本看不到拒絕，直到自然發生某次
reschedule 為止。需要修正的是 Deployment 中的 `spec.template`(`kubectl
edit deployment controller-app` 或帶有修正後 manifest 的 `kubectl apply`)，而不是
namespace label - 回退 enforce 不是這個任務的解法。
</details>

---

## 檢查

在工作機上執行：

```bash
check_result
```

檢查包含 Init 與七個獨立的任務。它還會額外對不安全的 Pod 執行
server-side dry-run，因此 restricted namespace 中沒有持久的「壞」Pod,
是預期且正確的結果。任務 7 中 checker 會自己刪除
目前的 Pod `controller-app`，並檢查 ReplicaSet 確實會重新建立 Ready Pod -
它不接受 events 的文字作為證明。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)

## 刪除

```bash
TASK=107 make delete_cks_task
```

## 關於 PSA 版本與 audit 可觀測性的說明

本實驗刻意把 PSA labels 固定在 `v1.36`，因為學習用的叢集本身執行的是
Kubernetes 1.36.0。截至 2026-09-06，官方 CKS blueprint 以 Kubernetes
`v1.35` 為準；因此這是 **forward-looking** 的學習設定，而不是對考試版本的聲明。
要準備目前的考試，請把 `*-version` 後綴換成 `v1.35`，並對照該版本文件
核對行為。

`audit` 模式會在 **kube-apiserver 的 audit event** 中為違規的 Pod 加入 annotation
`pod-security.kubernetes.io/audit-violations`。學習用的基礎架構
沒有設定也沒有提供 audit-log sink，因此在這裡無法透過 `kubectl` 讀取這個 annotation。
任務 4 中可觀察的證明，是 server-side admission 時 PSA 的警告
(`Warning: ... would violate PodSecurity "baseline"`)，以及在沒有 `enforce` 的情況下
Pod 成功建立；audit mode 已有說明，但它的 log annotation 不在本實驗的檢查範圍內。
