[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 108 - 使用 Kyverno 的 Admission policies

## 目標

在這個 CKS 實驗中，你要安裝 Kyverno，並用 policy-as-code 規則保護 namespace `policy-108`。
實作涵蓋 validating admission：禁止 `latest` 標籤、強制 `runAsNonRoot`、registry 的 allowlist;
在最後的選擇性階段中，則是 admission 時對 Pod 的 mutation。任務 6 把這種做法與另一種機制比較 - 內建的
`ImagePolicyWebhook`，其中 image 的決定由外部 HTTP(S)-backend 透過 `ImageReview` API 做出，
而不是叢集內部的 CEL 運算式。最後的任務 7 是第三個、獨立的
admission engine:**Gatekeeper (OPA/Rego)**，你要修復一個已經部署、但不完整的
policy，而不是在 Kyverno 中撰寫 CEL。請只操作任務中指定的物件與名稱。

## 開始前先自我檢查

<details>
<summary>1. 為什麼只禁止明確的 `:latest` 標籤，並不能涵蓋 mutable-tag 的全部風險？</summary>

如果 image 完全沒有指定標籤(例如 `nginx`),Docker/OCI 預設會把它解析為 `nginx:latest` - 也就是 implicit latest。只檢查字串 `:latest` 是否逐字相符的 policy，會放過這樣的 image，儘管在語意上它與明確的 `:latest` 是一樣的。正確的 policy 必須同時拒絕明確的與 implicit latest - 或者要求明確的帶版本標籤/digest。
</details>

<details>
<summary>2. 為什麼 validating policy 需要把 `ephemeralContainers` 與 `containers`/`initContainers` 分開檢查？</summary>

`kubectl debug` 是透過獨立的 subresource API(`pods/ephemeralcontainers`)把 ephemeral container 加入「已經存在的」Pod，而不是透過一般的 Pod CREATE/UPDATE。如果 policy 只比對資源 `pods`，而沒有明確包含這個 subresource，那麼嘗試加入未經檢查/不受信任的 ephemeral container，就可能繞過所有為一般 containers 撰寫的 validating policies。
</details>

<details>
<summary>3. Kyverno 中的 `ValidatingPolicy` 與 `MutatingPolicy` 有什麼本質上的差異？</summary>

`ValidatingPolicy` 只檢查請求，並允許或拒絕它(Allow/Deny)- 物件不會被修改。`MutatingPolicy` 會在儲存之前「修改」物件(加入/修改欄位，例如 label)- 請求仍然會通過，但內容已被改變。任務 5 使用 mutation，正是因為目標是自動加入 label，而不是拒絕 Pod。
</details>

## 基礎架構

環境由 Terragrunt 部署在 AWS `eu-central-1`:

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`，含公有子網路 |
| `ssh-keys` | 用於存取節點的金鑰 |
| `k8s-1` | 單節點 kubeadm 叢集 Kubernetes `1.36.0`、containerd 與 **Calico** |
| `worker` | 具備 `kubectl`、Helm 與 `/usr/local/bin/install-kyverno` 的工作機 |

Control-plane 允許一般的 Pod，因此不會建立單獨的 Kubernetes worker。
Kyverno 在初始狀態下刻意**沒有安裝**：這是任務 1 的一部分。工作機上
準備了固定版本的 installer，不需要手動挑選 chart。
本實驗固定 Kyverno `1.19`(Helm chart `3.9.0`)，並使用穩定的基於 CEL 的 API
`policies.kyverno.io/v1`。從這個版本起，`kyverno.io/v1` 中的 legacy `Policy`/`ClusterPolicy`
已被 deprecated，只作為 migration 的參考資料來討論。

與 Kyverno 不同，任務 7 所用的 **Gatekeeper (OPA) 已經由 bootstrap 安裝在叢集中**,
同時還有起始的(刻意不完整的)`ConstraintTemplate` 與 `Constraint`。
這是刻意的：任務 7 檢查的是在已存在的 `ConstraintTemplate` 中找出並補寫 Rego 的能力，
而不是從零安裝 admission engine - 這一部分已經由 Kyverno 的任務 1 練習過了。任務 7 在單獨的 namespace
`gatekeeper-108` 中運作，與 Kyverno 的任務 1-5(`policy-108`)隔離，讓 Pod 不會
同時被兩個不同的 admission engine 拒絕。

## 部署

```bash
TASK=108 make run_cks_task
```

透過 SSH 連線到工作機。Context `cluster1-admin@cluster1` 已經設定好。

```bash
time_left
check_result
```

## 任務

---
| **1** | **安裝 Kyverno** |
| :---: | :--- |
| 要做什麼 | • 在 namespace `kyverno` 中安裝 Kyverno。<br/>• 使用在 worker 上準備好的指令 `/usr/local/bin/install-kyverno`；它會套用固定版本的 Helm chart。<br/>• 等待 admission controller 可用。 |
| 驗收標準 | • 叢集中有 CRD `validatingpolicies.policies.kyverno.io`<br/>• Kyverno 版本為 `1.19.x`<br/>• namespace `kyverno` 中至少有一個 Deployment 具有可用的 replica |

<details>
<summary>💡 任務 1 的提示</summary>

`/usr/local/bin/install-kyverno` 已經設定為固定的版本 - 不要試圖手動用其他 chart 透過 `helm install` 安裝 Kyverno，這可能導致 CRD 版本不相容。安裝之後請等待：admission controller 的 Pod 必須變成 `Available`，這不會立刻發生。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

第一個指令必須回傳 CRD 本身(而不是 `NotFound` 錯誤);image 的版本必須
包含 `v1.19.`；至少一個 Deployment 的 `AVAILABLE` 必須大於 `0`。
</details>

---
| **2** | **禁止帶有 `latest` 標籤的 image** |
| :---: | :--- |
| 要做什麼 | • 建立基於 CEL 的 `ValidatingPolicy` `deny-latest-tag`(`policies.kyverno.io/v1`)，帶有 `validationActions: [Deny]`。<br/>• 它必須套用到 namespace `policy-108` 的 Pod 與 subresource `pods/ephemeralcontainers`。<br/>• 它必須拒絕 `containers`、`initContainers` 或 `ephemeralContainers` 中任何屬於明確 `:latest` 或 implicit latest(完全沒有標籤也沒有 digest 的 image)的 image。 |
| 驗收標準 | • Policy 存在並以 Deny 模式運作<br/>• Admission 在三個 container 清單的每一個中，都同時拒絕明確的 `:latest` 與 implicit latest(無標籤)，包括帶有 registry 埠但沒有標籤的 image(`registry.example:5000/app`)，而在每個清單中都接受帶版本的受信任 image 與以 digest 固定的 image<br/>• 在對既有 Pod 做 UPDATE 時，把 `spec.containers[*].image` 或 `spec.initContainers[*].image` 改為 `:latest` 也會被這個 policy 拒絕(一般 Pod 的 image 欄位允許 in-place UPDATE) |

<details>
<summary>💡 任務 2 的提示</summary>

`matchConstraints.resourceRules` 必須分別涵蓋 `pods` 與 subresource
`pods/ephemeralcontainers` - 否則 `kubectl debug` 會繞過 policy。至於
CEL 邏輯本身：以最後一個 `/`「之後」的最後一個 `:`，把 image 字串拆成 `registry/path` 與 `tag`
(最後一個 `/` 之前出現的 `:` 可能是 registry 埠的一部分，而
不是標籤)；如果拆分之後完全沒有標籤 - 就是 implicit latest；如果有標籤，但
等於 `latest` - 同樣是被禁止的情況；digest(`@sha256:...`)- 是獨立的、永遠
允許的情況，完全不屬於標籤的範疇。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

在套用 policy 之前，先確認違規的 Pod 確實能通過 admission
(baseline)- 否則無法確定 denial 是由你的 policy 還是由其他原因造成：

```bash
# baseline:套用 policy 之前 - 必須通過(exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

套用 policy，然後重複「同一個」manifest - 現在必須以 admission 錯誤結束(exit 不為 0),
而訊息必須指向你的 policy:

```bash
kubectl apply -f deny-latest-tag.yaml   # 你的 policy 檔案
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

對下列情況重複同樣的 baseline→apply→probe→compare 循環：完全沒有標籤的 image
(`registry.k8s.io/pause`)、`registry.example:5000/app`(最後一個 `/` 之前的冒號是 registry 的埠，而不是標籤)、`initContainers` 中的 `:latest`，以及在已經執行中、且被允許的 Pod 上透過
`kubectl debug --image=...`(`pods/ephemeralcontainers`
subresource)使用 `:latest`/無標籤。最後，檢查 positive control - 帶版本的標籤在
套用 policy 之後也必須通過，而不只是之前。
</details>

---
| **3** | **要求不以 root 執行** |
| :---: | :--- |
| 要做什麼 | • 建立基於 CEL 的 `ValidatingPolicy` `require-run-as-non-root`,Deny 模式。<br/>• 對 `policy-108` 中的每個 Pod，欄位 `spec.securityContext.runAsNonRoot` 必須明確等於 `true`。<br/>• 在 Pod 層級與所有 containers 上禁止 `runAsUser: 0` 與 container-level 的 `runAsNonRoot: false`:container 的設定可以覆寫 Pod-level securityContext。 |
| 驗收標準 | • Policy 存在且為 Deny<br/>• 帶有 `runAsNonRoot: false` 或沒有這個欄位的 Pod、Pod-level `runAsUser: 0`，以及 `containers`、`initContainers`、`ephemeralContainers` 中帶有 `runAsNonRoot: false` / `runAsUser: 0` 的 container，都正是被這個 policy 拒絕<br/>• 安全的明確 container-level `runAsNonRoot: true`、`runAsUser: 1000` 被接受 |

<details>
<summary>💡 任務 3 的提示</summary>

要檢查的是「明確的」值 `true`，而不是「沒有 `false`」- 像 `object.spec.securityContext.runAsNonRoot == true` 這樣的 CEL 運算式，在欄位完全沒有設定時不會通過(`null != true`)，而這在這裡正是「需要的」：任務同時拒絕明確的 `false` 與缺少欄位的情況 - 兩種情況都必須被 denied，而不只是明確的 `false`。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

```bash
# baseline:套用 policy 之前,兩種變體都必須通過
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

套用 policy 並重複兩個 manifest - 現在「兩個」都必須以 admission 錯誤結束。
然後檢查 positive control：同一個 Pod，但明確帶有
`runAsNonRoot: true`，在套用 policy 之後也必須通過。
</details>

---
| **4** | **Container registry 的 allowlist** |
| :---: | :--- |
| 要做什麼 | • 建立基於 CEL 的 `ValidatingPolicy` `allow-approved-registries`,Deny 模式。<br/>• 對每個 container(`containers`、`initContainers`、`ephemeralContainers`)，只允許 `registry.k8s.io/*` 或 `ghcr.io/cks-lab/*`。<br/>• 禁止其他的 image registry。 |
| 驗收標準 | • Policy 存在且為 Deny<br/>• Untrusted image 在三個清單中都被拒絕<br/>• 兩個 approved prefix(`registry.k8s.io/` 與 `ghcr.io/cks-lab/`)在三個清單的每一個中都被允許<br/>• 把 image 改為未核准 registry 的一般 Pod UPDATE，會被 policy 本身拒絕<br/>• 同時還會檢查 init/ephemeral 清單中其他未核准的 registry，以及 host/path 的相似寫法(lookalikes) |

<details>
<summary>💡 任務 4 的提示</summary>

`startsWith('registry.k8s.io/')` 是最可靠的 prefix 檢查，但請確認兩個允許的 registry 是透過 OR 檢查的(兩者之一即可)，而不是 AND(兩者同時成立，對於一個 image 來說是不可能的)。要檢查的是 ALLOWLIST(image「只有」符合兩個 prefix 之一才被允許)，而不是針對特定 `docker.io` 的 denylist - 寫成「如果是 `docker.io` 就 deny，否則 allow」的 policy，會放過 `quay.io`、unqualified image 以及任何其他第三方 registry。另外請確認 prefix 是帶著結尾的 `/` 來比較的(`registry.k8s.io/`，而不只是 `registry.k8s.io`)，否則寫法相似的 host(`registry.k8s.io.evil.example`)可能會因為 case-insensitive 或不完整的比對而通過。與任務 2 一樣，別忘了 `ephemeralContainers` - 這是同樣的檢查三個 container 清單的模式。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

```bash
# baseline:套用 policy 之前 - untrusted registry 必須通過
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

套用 policy，重複同一個 manifest - 現在必須被 denied。這只是「一個」
具體的 untrusted 值(`docker.io`)，並不能證明是完整的
allowlist - 一個只是逐字禁止 `docker.io` 的 policy，卻放過
例如 unqualified image(沒有明確 host 的 implicit Docker Hub)、`quay.io` 或
寫法相似的 host(`registry.k8s.io.evil.example`)，也同樣能通過這「一項」
檢查。請至少對下列情況重複同樣的 baseline→apply→probe→compare:unqualified
image(完全沒有 host 的 `busybox:1.36`)、另一個明確的第三方 registry
(`quay.io/...`)、寫法相似的 host/path(`registry.k8s.io.evil.example/...`、
`ghcr.io/cks-lab.evil/...`)、`initContainers` 中的 untrusted image，以及在已經執行中、且被允許的 Pod 上透過 `kubectl debug` 使用 untrusted/trusted
image。最後是 positive control：兩個 container(main + init)都來自
`registry.k8s.io`/`ghcr.io/cks-lab` 的 Pod 必須通過；還要檢查 init 與 ephemeral container 中的 `ghcr.io/cks-lab/*`,
而不只是 `containers`。
</details>

---
| **5** | **選擇性：透過 Kyverno mutate label** |
| :---: | :--- |
| 要做什麼 | • 建立基於 CEL 的 `MutatingPolicy` `add-kyverno-managed-label`(`policies.kyverno.io/v1`)，如果 namespace `policy-108` 的 Pod 沒有 label `security.cks.io/managed-by: kyverno`，就替它加入。<br/>• 使用 mutation，而不是 validation。<br/>• 不要 mutate 其他 namespace 中的 Pod。 |
| 驗收標準 | • 對使用允許的 registry 與 `runAsNonRoot: true`、而且還「沒有」這個 label 的 Pod 做 server-side dry-run，在 mutation 之後會得到該 label，值為 `kyverno`<br/>• label「已經」以其他值設定的 Pod，保留原本的值<br/>• `default` 中的 Pod 保持沒有這個 label<br/>• 這個階段會顯示在 `check_result` 中，但可以跳過 |

<details>
<summary>💡 任務 5 的提示</summary>

這個階段是選擇性的 - 如果你時間用完了，可以跳過它，而不會影響實驗的其他部分。用於檢查 mutation 的測試 Pod，必須已經能通過任務 2-4 的 policies(受信任的 registry、non-root)- 如果它本身被先前的某個 policy 拒絕，你根本看不到 mutation 的結果。任務中的「如果它不存在」不只是願望：mutation 必須明確檢查 label 是否存在，並且在它已經存在時不動物件，否則即使沒有 label 的 Pod 得到了正確的值，任務也算沒有完成。
</details>

---
| **6** | **ImagePolicyWebhook：用外部 backend 取代 CEL policy** |
| :---: | :--- |
| 要做什麼 | • 工作機上已經準備好 `/opt/image-policy-backend/server.py` - 一個最小的 HTTPS 伺服器，實作了 `ImageReview` API(拒絕帶有標籤 `:latest` 或完全沒有標籤的 image)。<br/>• 把它部署為 namespace `image-policy` 中的 Deployment，置於埠 `8443` 上的 Service `image-policy-backend` 之後。Backend 必須透過 TLS 接受連線(上游的 `ImagePolicyWebhook` 約定要求 HTTPS，不支援 plain HTTP)。<br/>• 在 `control-plane` 上(`ssh`，然後 `sudo -i`)，為 plugin `ImagePolicyWebhook` 設定 `AdmissionConfiguration`(`defaultAllow: false`)，以及指向你的 backend 的 kubeconfig。<br/>• 在 static manifest `kube-apiserver.yaml` 中，把 `ImagePolicyWebhook` **加入**到既有的 `--enable-admission-plugins` 清單中(不要整個取代清單 - 否則有可能關閉已經啟用的 plugins)，並啟用 `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`。<br/>• API 恢復之後，建立帶有 `:latest` 的 Pod - 必須被拒絕；然後是帶有固定標籤的 Pod - 必須被建立。 |
| 驗收標準 | • `image-policy-backend` 為 Available<br/>• Kube-apiserver 健康，plugin 是被加入的(而不是取代既有清單)，並且設定了 `--runtime-config`<br/>• Backend 的 kubeconfig 使用 HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• 帶有 `:latest` 與 implicit latest(包括帶 registry 埠但沒有標籤)的 Pod，在 namespace `default` 中正是被 ImagePolicyWebhook 拒絕 - 無論是一般的 Pod，還是 init/ephemeral container<br/>• 使用者 annotation `alpha.image-policy.k8s.io/break-glass: "true"` 不會產生例外<br/>• Namespace `policy-108` 是專門留給任務 2–4 的 Kyverno 的，讓兩個獨立的 admission 機制不會互相掩蓋對方的拒絕<br/>• 為此，backend 在 `ImageReview.spec.namespace == policy-108` 時把決定委派給 Kyverno，而在所有其他 namespace 中 ImagePolicyWebhook 繼續運作<br/>• 帶有固定標籤的 Pod 已建立且為 Running<br/>• Service 在 backend 中斷期間確實失去 Endpoints,API 因為這個 endpoint 無法連線而拒絕(`defaultAllow: false`)，然後 Service selector 與 admission 被精確地恢復到原始狀態 |

<details>
<summary>💡 任務 6 的提示</summary>

`ImagePolicyWebhook` 是與任務 1-5 中的 Kyverno 本質上不同的機制：決定是由外部的 HTTPS-backend 透過 `ImageReview` API 做出的，而不是叢集內部的 CEL 運算式。請使用工作機上現成的 `/opt/image-policy-backend/server.py`(例如把它打包成 backend Deployment 使用的 ConfigMap；在 `control-plane` 上只需要為 webhook 的 kubeconfig 複製 CA 憑證)- 任務檢查的是你對 admission plugin 的 wiring、TLS 約定和 ImageReview API 的理解，而不是從零開始撰寫 HTTP 伺服器的能力。關於 TLS：先建立 Service(以得知 `ClusterIP`)，然後建立 SAN 中帶有這個 IP 的自簽憑證(`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`)，再建立同時掛載程式碼與憑證的 Deployment。不要用新的值整個取代既有的 `--enable-admission-plugins` - 請以逗號把 `ImagePolicyWebhook` 接在已經啟用的 plugins 之後(通常那裡已經有 `NodeRestriction`)。另外別忘了 `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` - 沒有明確啟用這個 API,backend 根本不會被呼叫。Namespace `image-policy` 沒有事先建立 - 請在 Deployment/Service 之前自己建立它。如果卡在資源/路徑/旗標的詳細順序上 - 標準的操作順序已在解答中給出。
</details>

---
| **7** | **Gatekeeper ConstraintTemplate：補寫 Rego blocklist** |
| :---: | :--- |
| 要做什麼 | • 叢集中已經安裝了 **Gatekeeper** (OPA)，以及 `ConstraintTemplate` `k8sblockedregistries` 與 `Constraint` `K8sBlockedRegistries/deny-bad-registries`，範圍限制在單獨的 namespace `gatekeeper-108`(不是 `policy-108` - 這是與 Kyverno 任務 1-5 分開的練習場，讓 Kyverno 與 Gatekeeper 不會同時拒絕同一個 Pod)。<br/>• `ConstraintTemplate` 內的 Rego 已經包含幾個被封鎖的 registry(`untrusted-registry.example`、`docker-fake.test`)，但**刻意不包含** `very-bad-registry.test`。<br/>• 找到 `ConstraintTemplate.spec.targets[].rego`，並在其中補寫針對 `very-bad-registry.test` 的規則 - 正是寫在 Rego 中，而不是 `Constraint` 的參數中。<br/>• `deny-bad-registries` 已經完全正確，而且完全不使用 `spec.parameters` - 不需要動它。 |
| 驗收標準 | • `ConstraintTemplate k8sblockedregistries` 與原本的 Constraint `K8sBlockedRegistries/deny-bad-registries` 存在<br/>• Rego 保留兩個原本有效的規則(`untrusted-registry.example`、`docker-fake.test`)，並包含針對 `very-bad-registry.test` 的新的有效規則<br/>• `gatekeeper-108` 中帶有這三個 registry 中任一個的 Pod，都正是被 Constraint `deny-bad-registries` 拒絕<br/>• 帶有來自受信任 `registry.k8s.io` 的 image 的 Pod 通過<br/>• Constraint 保持僅限 Pod、限制在 `gatekeeper-108`，沒有 parameters/selectors/exclusions<br/>• 不會建立這個類型的額外 Constraint |

<details>
<summary>💡 任務 7 的提示</summary>

透過 `kubectl get constrainttemplate k8sblockedregistries -o yaml` 找到 ConstraintTemplate。Rego 位於 `spec.targets[].rego`，是多行字串 - 需要編輯的正是它(`kubectl edit constrainttemplate k8sblockedregistries`，或 `get -o yaml` → 修改 → `apply`)。既有的 Rego 透過形如 `blocked_registry("untrusted-registry.example")` 的獨立事實宣告被封鎖的 registry - 請再補寫一行這樣針對 `very-bad-registry.test` 的內容，不要刪除或取代已經存在的。不要把這與 `Constraint.spec.parameters` 混淆 - 在這個版本的 policy 中，Constraint 完全不使用 parameters，那裡沒有可編輯的東西。
</details>

<details>
<summary>🔍 在 `check_result` 之前先自我檢查</summary>

Baseline - 修正「之前」：來自 `very-bad-registry.test` 的 Pod 必須通過(Rego 目前還沒有涵蓋它)，而已經被封鎖的 `untrusted-registry.example` 則必須被拒絕：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

補寫 Rego，重複「同一個」manifest(使用新的名稱，舊的 Pod 已經透過 dry-run
「建立」並且不會被保存)- 現在預期會出現來自
Gatekeeper、明確指向 `k8sblockedregistries` 的 admission 錯誤，針對「兩個」registry:

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

檢查 positive control - 受信任的 registry 在修正之後也必須通過：

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## 檢查

在工作機上執行：

```bash
check_result
```

檢查包含 Init 與七個測試。前四個、第六個與第七個是必須的。第五個
測試會執行 mutation 檢查，但如果沒有建立選擇性的
policy，實驗不會因此失敗。任務 2-4 與 7 使用 `--dry-run=server`，因此不會
下載映像，Pod 也不會留在 namespace 中；任務 6 檢查的是透過 ImagePolicyWebhook 的真實(非 dry-run)
admission，因此 Pod `webhook-pinned-ok` 確實
會被建立。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)

## 刪除

```bash
TASK=108 make delete_cks_task
```

## 相容性與禁止 image 的精確語意

本實驗固定 Kubernetes 1.36.0 與 Kyverno 1.19，以熟悉新的
`policies.kyverno.io/v1` API。這是 **forward-looking / unsupported combination**:Kyverno
1.19 官方是與 Kubernetes 1.33–1.35 一起測試的，而不是 1.36。在實驗之外套用之前，
請選擇受支援的版本矩陣，並核對 release notes。

在任務 2 中，「禁止 `latest`」也包含禁止隱含的 `latest`：沒有 tag 與 digest 的 `nginx`
和 `nginx:latest` 一樣不被允許。只允許帶有明確的、不是 `latest` 的
標籤的 image，或帶有 digest(`@sha256:...`)的 image。任務不會提供這個準則的
精確 CEL 邏輯成品 - 如果需要額外的依據，請參見任務 2 的提示。
