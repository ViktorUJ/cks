[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 109 - etcd 中 Secret 的加密與最小存取

## 目標

在這個 CKS 實驗中，你要證明沒有 encryption at rest 的 Kubernetes Secret，在 etcd 中是以可讀取的 bytes 儲存的
(base64 不是加密)，透過 `EncryptionConfiguration` 啟用 `aescbc`，把它接到 static `kube-apiserver`,
重寫舊的 Secret，並用 RBAC 與 `automountServiceAccountToken` 限制對資料的存取。

這裡選擇 `aescbc` 只是為了練習考試中 `EncryptionConfiguration` 與 re-encryption 的操作機制。目前的 Kubernetes 文件認為 AES-CBC
較弱，並由於 padding-oracle 攻擊的風險而不建議使用它；`aesgcm` 同樣需要
自動化的金鑰輪替。在 production 中，請依據最新文件與 threat model 選擇 provider；若有外部 key manager,
則偏好 KMS v2
(參見 [第 21 章](../../course/21/tw.md))。

## Threat model

Encryption at rest 防範的是 storage compromise：假設攻擊者取得了對 etcd snapshot 或 storage layer 的 read-only 存取權，例如透過 backup 或 volume snapshot，但沒有經過授權的 API 存取權。任務 1 證明的正是這個透過 raw 讀取 etcd 而得的初始風險。

啟用 encryption at rest 之後，任務 2–4 縮小這種存取的 blast radius：直接讀取的資料不應揭露 Secret。這不是通用的防護，也不能取代對 API 的存取控制。

如果攻擊者擁有合法的、具有讀取 Secret 權限的 API 存取權，encryption at rest 無法防範這種威脅：API 會在解密之後回傳值。因此任務 5 另外限制 RBAC 與 automount，縮小具有此類權限的 workload identity 的 blast radius。

## 開始前先自我檢查

<details>
<summary>1. 為什麼 `Secret.data` 中的 base64 不是加密？</summary>

base64 只是編碼，不需要金鑰就能還原：任何能存取這些 bytes 本身的人(例如透過 raw 讀取 etcd)，都可以立刻解碼這個值，不需要任何密碼學操作。加密需要金鑰才能反向轉換 - base64 完全沒有這個特性。
</details>

<details>
<summary>2. 為什麼 `identity` provider 必須放在 providers 清單的「最後」，而不是第一個？</summary>

`EncryptionConfiguration` 中的 providers 會依序嘗試用於「讀取」既有記錄，而第一個 provider 用於「寫入」新資料。如果 `identity`(即「不加密」)排在第一個，儘管清單中有 `aescbc`，所有新記錄還是會以「未加密」的方式寫入。把 `identity` 放在最後，可以讀取舊的(尚未遷移的)plaintext 記錄，同時保證所有新記錄都由第一個 provider 加密。
</details>

<details>
<summary>3. 為什麼不能在加入新的加密金鑰之後，立刻刪除舊的金鑰？</summary>

etcd 中既有的記錄，在被明確重寫(re-encryption)之前，仍然是以「舊」金鑰加密的。如果在所有記錄都以新金鑰重寫之前，就把舊金鑰從 active `EncryptionConfiguration` 中移除，API server 就無法透過目前的 provider chain 解密剩餘的舊記錄 - 在舊金鑰被放回設定之前，它們將無法讀取。單是從設定中刪除金鑰，並不會在實體上銷毀 key material：如果把保存下來的舊金鑰重新加入 provider chain，存取就會恢復。只有當 key material 本身真正遺失或被銷毀時(例如金鑰在刪除之前從未被保存到任何地方)，才會發生不可逆的資料遺失。順序：先把新金鑰加在最前面 → 重寫所有 Secret → 確認所有記錄都使用新金鑰 → 把舊金鑰保存在可靠的地方以便 rollback → 然後才從設定中移除它。
</details>

## 基礎架構

環境由 Terragrunt 部署在 AWS `eu-central-1`:

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.10.0.0/16`，含公有子網路 |
| `ssh-keys` | 用於 worker 與 control-plane 的 SSH 金鑰 |
| `k8s-1` | 單節點 kubeadm control-plane:Kubernetes **1.36.0**、containerd、**Calico** |
| `worker` | 已設定好 `kubectl` 的工作機；control-plane(`ssh control-plane`)上安裝了標準的 `etcdctl` 3.6.0，就像考試中一樣 |

Control-plane 刻意接受一般的 Pod - 不會建立單獨的 Kubernetes worker。
在任務開始之前，bootstrap 會建立 namespace `encryption-109` 以及無害的
`legacy-secret`。這個 Secret 是在 EncryptionConfiguration **之前**建立的，因此作為
plaintext 狀態的受控證明。

對節點的操作在 control-plane 本身上執行，就像考試中一樣：登入它
(`ssh control-plane`)，在那裡工作，然後離開(`exit`);`kubectl` - 在工作機上。etcd 的 raw 記錄
透過 Kubernetes 文件中的標準 `etcdctl` 讀取，使用位於
`/etc/kubernetes/pki/etcd/` 的 kubeadm 憑證(`ca.crt`、`server.crt`、`server.key`)。現成的指令範例 -
在參考解答的「在文件中哪裡可以找到範例」一節中。

## 部署

```bash
TASK=109 make run_cks_task
```

連線到工作機。Context `cluster1-admin@cluster1` 已經設定好。

```bash
time_left
check_result
```

## 任務

---
| **1** | **證明初始的 plaintext Secret** |
| :---: | :--- |
| 要做什麼 | • 在啟用加密之前，用標準的 `etcdctl get ... --print-value-only` 請求 raw 記錄 `/registry/secrets/encryption-109/legacy-secret`<br/>• 登入 control-plane(`ssh control-plane`)並在上面工作，就像考試中一樣：把輸出透過 `strings` 處理，將結果儲存到 control-plane 上的檔案(`/tmp/plaintext-proof.txt`)，然後用 `scp` 指令把它複製到工作機的 `/var/work/109/plaintext-proof.txt` |
| 驗收標準 | • 檔案包含初始 raw 記錄 `strings` 的完整輸出(與 bootstrap 的快照相符，包括 marker `cks-109-legacy-plaintext`)，且不包含 `k8s:enc:`<br/>• 手動輸入的字串不被接受<br/>• 這是初始狀態的證明：`Secret.data` 是 base64，不是 encryption at rest |

<details>
<summary>💡 任務 1 的提示</summary>

這個任務必須「最先」完成，在任務 2 之前 - 一旦你啟用 EncryptionConfiguration 並重寫 Secret,plaintext 的證明就消失了，你無法事後再記錄它。帶有 `--cacert/--cert/--key` 旗標的 `etcdctl` 指令取自 Kubernetes 官方文件(Encrypting Confidential Data at Rest 頁面的「Verify that newly written data is encrypted」一節);kubeadm 的憑證路徑：`/etc/kubernetes/pki/etcd/ca.crt`、`server.crt`、`server.key`。確切的連結 - 在參考解答的「在文件中哪裡可以找到範例」一節中。
</details>

---
| **2** | **為 Secret 建立 EncryptionConfiguration** |
| :---: | :--- |
| 要做什麼 | • 在 control-plane 上建立 `/etc/kubernetes/enc/encryption-config.yaml`,owner `root:root`,mode `0600`<br/>• 格式：`apiserver.config.k8s.io/v1`、`EncryptionConfiguration`<br/>• 對 `secrets`，第一個 provider 設為 `aescbc`，帶有由 **32 個隨機 bytes** 組成、有名稱的 base64 金鑰，然後是 `identity: {}` |
| 驗收標準 | • 檔案為 `root:root` mode `0600`，位於 `root:root` mode `0700` 的目錄中<br/>• `secrets` 主要生效的 provider 是排在**第一個**的 `aescbc`，帶有正確的、由 32 bytes 組成的 named base64 key<br/>• `identity` 只允許作為最後的、針對 legacy plaintext 的臨時 fallback<br/>• 禁止指向檔案/目錄的 symlink |

<details>
<summary>💡 任務 2 的提示</summary>

用 `head -c 32 /dev/urandom | base64` 產生金鑰 - 正是 32 個位元組(不是 32 個 base64 字串字元，後者因編碼而會更長)。自行檢查：`echo -n "<你的-base64-金鑰>" | base64 -d | wc -c` 必須回傳恰好 `32`。
</details>

---
| **3** | **把 config 接到 static kube-apiserver** |
| :---: | :--- |
| 要做什麼 | • 謹慎地修改 `/etc/kubernetes/manifests/kube-apiserver.yaml`：加入旗標 `--encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml`、read-only 的 `volumeMount` `/etc/kubernetes/enc`，以及對應的 `hostPath` volume `/etc/kubernetes/enc`<br/>• 在修改之前先保存 manifest 的 backup |
| 驗收標準 | • 執行中的 manifest 包含旗標、mount 與 hostPath<br/>• static Pod 重新啟動之後，`kubectl get --raw='/readyz'` 回傳 `ok` |

<details>
<summary>💡 任務 3 的提示</summary>

需要同時進行三個獨立的修改：旗標 `--encryption-provider-config` 本身、`volumeMounts`(容器內)以及 `volumes`(Pod spec 層級的 hostPath)- 漏掉三者中的任何一個，都會導致 CrashLoopBackOff(旗標指向容器看不到的檔案)，或旗標根本沒有被傳入。請把 backup 保存在 `/etc/kubernetes/manifests` **之外**，例如 `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak-109`。Kubelet 會讀取 static manifests 目錄中額外的非隱藏檔案；相鄰的 `kube-apiserver.yaml.bak` 可能被當作第二個 static Pod，並阻擋新設定的套用。
</details>

---
| **4** | **Re-encrypt 並證明 ciphertext** |
| :---: | :--- |
| 要做什麼 | • API server 就緒之後，在 `encryption-109` 中建立 Secret `encrypted-secret`，帶有 literal `token=cks-109-fresh-ciphertext`<br/>• 透過 API 重寫所有先前存在的 Secret(`kubectl get secrets --all-namespaces -o json \| kubectl replace -f -`)<br/>• 透過 API 與 raw etcd 檢查這兩個 Secret<br/>• 只有在這項檢查之後，才刪除臨時的 `identity` fallback，重新啟動 static kube-apiserver，並再次檢查 `/readyz` 以及兩個 Secret 的讀取 |
| 驗收標準 | • `legacy-secret` 與 `encrypted-secret` 透過 API 讀取到的是初始的值<br/>• 各自的 raw value 以 `k8s:enc:aescbc:v1:` 開頭<br/>• Legacy marker 在 raw etcd 中不再可見<br/>• 整個 bootstrap Secret corpus 的初始 payload/UID 被保留，所有記錄都以第一個生效的金鑰加密<br/>• 最終檔案中的金鑰能夠解密兩個 canary Secret 的 ciphertext<br/>• 最終設定中沒有 `identity`,API 健康 |

<details>
<summary>💡 任務 4 的提示</summary>

順序至關重要：建立 `encrypted-secret` → 透過 `kubectl replace` 重寫「所有」既有的 Secret → 檢查「兩者」(legacy 與 encrypted)的 raw etcd → 「之後才」從設定中移除 `identity`。如果在 `legacy-secret` 被重寫之前就移除 `identity`,API server 就無法再透過 provider chain 讀取舊的 plaintext 記錄，`legacy-secret` 將變得無法存取。
</details>

---
| **5** | **最小化 RBAC 並停用 automount** |
| :---: | :--- |
| 要做什麼 | • 在 `encryption-109` 中建立帶有 `automountServiceAccountToken: false` 的 ServiceAccount `secret-reader`<br/>• Role `secret-reader-109` 必須只授予對 Secret `encrypted-secret` 的 `get`<br/>• 用同名的 RoleBinding 把它綁定<br/>• 建立 Pod `secret-reader-109`，使用這個 ServiceAccount,`automountServiceAccountToken: false`，映像 `registry.k8s.io/pause:3.10` |
| 驗收標準 | • 對 ServiceAccount 連同其標準群組而言，effective RBAC 允許 `encryption-109` 中的 `get encrypted-secret`，並禁止其他 Secret 操作，包括存取其他 namespace 的 Secret<br/>• Role/RoleBinding 精確<br/>• Pod 為 Running，只有一個 `pause:3.10`，沒有自動或手動掛載的 ServiceAccount token，也沒有其他帶有 credential 的來源(Secret/hostPath/CSI/PVC volumes、Secret env/envFrom)<br/>• 無害的 emptyDir/ConfigMap volumes 是允許的<br/>• Pod 與 ServiceAccount 中都有 `automountServiceAccountToken: false` |

<details>
<summary>💡 任務 5 的提示</summary>

在 Role 中使用 `resourceNames: ["encrypted-secret"]` - 沒有這個欄位，對資源 `secrets` 的 `get`/`list` 會給予對 namespace 中「所有」Secret 的存取權，包括 `legacy-secret`，這違反 least-privilege 的要求。`pause:3.10` 是佔位用的映像，完全不需要 Kubernetes API，因此 automount 在兩個層級(SA 與 Pod)都被停用，不會有功能上的影響。
</details>

## 檢查

```bash
check_result
```

檢查包含 Init 與五個必要的測試。測試 4 檢查的不只是設定
檔案是否存在，而是新的與先前的 etcd 記錄的真實 ciphertext `k8s:enc:aescbc:v1:`，以及最終設定中不存在僅用於遷移的 `identity`。在真實環境中進行大規模 re-encryption 之前，需要 snapshot、金鑰輪替計畫以及受控的時間視窗；本實驗不是 production runbook。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)

## 刪除

```bash
TASK=109 make delete_cks_task
```

## 補充：KMS v2 與完整的輪替生命週期

**KMS v2(選擇性的 walkthrough)**。外部 KMS-plugin 以 `EncryptionConfiguration` 中的
provider `kms` 接到 API server；它的 endpoint 是本機的 Unix socket，而 provider 的金鑰
有穩定的名稱，例如 `kms-v2-primary`。在 KMS v2 中，API server 透過 plugin 取得加密的 seed(以外部
**KEK** 包裝過)，並據此推導出用來加密個別物件的金鑰。KMS v2
在 API server 層級使用 seed/DEK，而不是對每個 Secret 單獨呼叫 KMS。
etcd 中儲存的是 Secret 的 ciphertext 以及還原金鑰所需的資料。因此，KEK 不存放在 etcd 中；KMS 的 availability、ACL 與 backup 成為
安全模型的一部分。最小的**示意性** provider(endpoint 必須
與已安裝的 plugin 相符)如下所示：

```yaml
resources:
- resources: [secrets]
  providers:
  - kms:
      apiVersion: v2
      name: kms-v2-primary
      endpoint: unix:///var/run/kms-plugin/socket.sock
```

把 provider 放在第一位，用於新的記錄，把 socket 掛載到 static `kube-apiserver`,
並在 re-encryption 之前等待 plugin 的 health。對於真實的設定，請使用
受支援的 plugin，以及所用 Kubernetes 版本文件中最新的 `kms` v2 格式；本實驗不會啟動 KMS-plugin，也不會提供可用的 socket。

**provider 金鑰的完整輪替**。任務 4 中執行的、把 plaintext 遷移到第一個
`aescbc` 金鑰的遷移，並不是完整的金鑰輪替。要進行完整輪替：(1) 做受保護的 etcd snapshot，並
確認舊金鑰已保存並可用於 rollback;(2) 把新金鑰加在 `aescbc.keys` 的最前面，
舊金鑰留在第二位，然後重新啟動 API server;(3)
透過 API 重寫既有的 Secret，讓它們以新的第一個金鑰加密；
(4) 對抽樣的、然後是所有的 raw etcd 記錄，確認前綴
`k8s:enc:aescbc:v1:<新金鑰的名稱>:`;(5) 只有在完整遷移、backup 以及
讀取檢查之後，才刪除舊金鑰，重新啟動 API server，並再次檢查 `/readyz`
與 Secret。對於 KMS v2，等價的做法是先切換 primary KEK/plugin，進行
re-encryption，然後才依照 KMS 的程序讓舊的 KEK 退出使用。
