[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 111 - 映像分析、靜態修正與 supply-chain evidence

## 目標

在這個 CKS 實驗中，你要為容器應用程式組裝可重現的 evidence artifacts：弱點報告與靜態分析器的報告、`Dockerfile` 與 workload manifest 的安全修正、兩份 SBOM、相依套件版本的搜尋，
以及映像簽章的驗證。結果不只是終端機的輸出：每份報告都必須
儲存在指定的位置，並適合稽核。

這是關於 security tooling 與 supply chain 的 CKS 任務，而不是 CKA 的練習。大多數
artifacts 都在 worker 上於本機分析；唯一的例外是任務 4，其中
需要套用 hardened Deployment，以檢查 Ready/Available 與 HTTP smoke test。

## Threat model

本實驗透過幾個獨立的威脅來模擬對 supply chain 的信任。惡意
程式碼或 image 中已知的弱點，由 Trivy、kubesec、
kube-linter 與 Hadolint 這些掃描器，在映像、Dockerfile 與 manifest 的對應層級上偵測。

不小心留在 layer 中的 secret 與 token，需要單獨的檢查：secret
scanning(例如 Trivy secret scanning)以及映像 history 的檢視(`docker history`、
擷取 layer)。SBOM 解決的是另一個問題 - 元件與
套件版本的盤點；它有助於 supply-chain investigation(例如找出有弱點的函式庫),
但並不是在 layer 歷史中尋找 secret 的可靠機制，也不能取代 secret
scanning。即使目前的設定已經不包含 secret，它仍然可能
留在 layer 歷史中而可被存取。

mutable-tag tampering 的威脅在於，部署之後，在沒有改變的、帶有
標籤的引用下，可以替換成另一個惡意的 image。這正是為什麼 digest pinning 在
任務 3–5 中很重要：它固定的是映像的具體內容，而不只是它的名稱與標籤。

任務 7 中的簽章驗證證明，具體的 digest 是由受信任的
key/identity 簽署的(signature integrity)，而任務 1 中的 Trivy scan 則是在目前的 vulnerability DB 下，沒有偵測到
落在其 detection coverage 內的已知弱點
(Trivy 自己的文件記載了偏向 precision 的 trade-off，在這種情況下可能出現 false
negatives - "0 findings" 不等於沒有弱點的 formal proof)。這是不同的
防護軸：它們沒有一個能取代另一個，因為 vulnerability != signature。簽章
並不等同於 provenance/attestation
(例如關於 artifact 是由什麼、如何建置的 SLSA-style build metadata):`cosign
verify` 確認的是簽章的真實性，而不是完整的建置歷史 - 對於 attestation,
Sigstore 提供單獨的指令 `cosign attest`/`cosign verify-attestation`，本實驗中
沒有使用。

本機的 `cosign verify`(任務 7)本身並不是 enforcement：它證明的是具體 image reference 在檢查當下的
簽章，但不妨礙任何人透過直接的 `kubectl apply`，繞過 CI 去執行
未簽署或以其他方式簽署的映像。只有
admission-time 的檢查(任務 9a-9c)才讓簽章成為 Pod 被允許進入叢集的必要條件 -
這就是「我們檢查了簽章」與「叢集不會執行
未簽署的映像」之間的差別。

證明這個特性需要謹慎：對已經存在的 Deployment 再次 `kubectl apply`，如果 template 沒有改變，就不會建立新的 Pod，因此
`Running` 可能意味著「在 policy 之前建立的舊 Pod」，而不是「policy 允許了
這個映像」(任務 9b 明確檢查 `creationTimestamp`)。同樣地，unsigned
DENY 只有在被檢查的 digest 確實存在，並且在與已簽署映像相同的
repository 中可以 pull 時才證明這個特性(任務 9c)- 否則 admission 可能因為
registry 中缺少 manifest 而拒絕，而不是因為缺少簽章。

## 開始前先自我檢查

<details>
<summary>1. 為什麼 SBOM 不是尋找留在 image layer 中的 secret 的可靠機制？</summary>

SBOM 解決的是盤點「元件」與套件版本的問題(安裝了什麼，什麼版本)- 這是對套件管理器 metadata 的結構化分析，而不是在 layer 檔案內容中搜尋任意字串/secret。例如在建置期間留在環境變數 ENV 或暫存檔中的 secret，即使最終的 layer 不包含它，仍可能留在 layer 的歷史中 - 對此需要單獨的工具(secret scanning、`docker history`、擷取 layer)，而不是 SBOM。
</details>

<details>
<summary>2. Trivy scan(任務 1)所證明的，與 Cosign 簽章(任務 9a-9c)所證明的，有什麼差別？</summary>

在檢查當下，以目前的 vulnerability DB 與 Trivy 的偵測邏輯，掃描「沒有偵測到」落在其 detection coverage 內的已知弱點 - 這關乎映像內容的品質/安全性，範圍僅限於 Trivy 能看到的部分。Trivy 文件本身明確描述了偏向 precision(最小化 false positives)的 trade-off，在這種情況下可能出現 false negatives - 也就是說，"0 findings" 並不等同於完全沒有弱點的正式證明。Cosign 簽章證明的是 SIGNATURE INTEGRITY - 具體的 digest 是由受信任的金鑰/identity 簽署的，也就是有被授權的人確認這正是應該部署的 artifact。這「不等同於」provenance/attestation(完整的建置歷史 - artifact 是由什麼、由誰、如何建置的)：對於 attestation,Sigstore 有單獨的指令(`cosign attest`/`cosign verify-attestation`)，本實驗中沒有使用。映像可以完全安全(0 CVE)卻沒有簽署 - 也可以已簽署，卻包含未知的弱點。這是兩個獨立的防護軸。
</details>

<details>
<summary>3. 為什麼在 CI 中本機執行的 `cosign verify` 無法阻止有人透過 `kubectl apply` 部署未簽署的映像？</summary>

在本機(例如在 CI pipeline 中)執行的 `cosign verify`，只是檢查簽章並把結果回傳給呼叫者的一個指令。它並沒有內建在 Kubernetes API 的 admission 路徑中 - 沒有任何東西能阻止有叢集存取權的人，直接以「任何」映像執行 `kubectl apply`，完全繞過 CI。只有內建在叢集本身、作為 policy 的 admission-time 檢查(任務 9a-9c)，才讓簽章成為允許的「必要」條件 - 這就是「我們檢查過了」與「叢集在物理上不會放行」之間的差別。
</details>

## 基礎架構

環境由 Terragrunt 在 AWS `eu-central-1` 建立。

| 元件 | 用途 |
|---|---|
| `vpc` | VPC `10.111.0.0/16`，含公有子網路 |
| `ssh-keys` | 存取節點 |
| `k8s-1` | 單節點 kubeadm Kubernetes `1.36.0`、containerd 與 **Calico** |
| `worker` | 用於分析的工作站、`kubectl`、`check_result` 與 security tools |

這是 CKA 風格的基礎架構：唯一的 control-plane 節點允許 workload，並
被標上 `cks.io/lab=111`。主要的指令與 security tools 都在 worker 上執行。
Kubernetes 叢集被用作目標環境，用來檢查 hardened workload 與
admission-time 的簽章 policy：任務 4 部署 `catalog`，而任務 9b/9c
執行 positive/negative admission probes。

worker 上事先備妥了恰好這些固定的版本：

| 工具 | 版本 | 用途 |
|---|---:|---|
| Trivy | `0.74.0` | 映像的 CVE 與套件清單 |
| kubesec | `2.14.0` | Kubernetes YAML 的 security score |
| kube-linter | `0.8.3` | Kubernetes YAML 的 policy lint |
| Hadolint | `2.12.0` | Dockerfile 的 lint |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON(`bom` 的原生格式) |
| Cosign | `3.1.3` | OCI 映像簽章的 signing 與 verification |

Helm 與 `install-kyverno` 在 worker 上同樣可用，但 Kyverno 刻意**沒有安裝**:
安裝它是任務 9 的一部分，就像實驗 108 中一樣。`install-kyverno` 固定了 Kyverno
`1.19`/chart `3.9.0`；該版本上游官方的 support matrix 是 Kubernetes
`1.33-1.35`，而這個叢集是 `1.36`。這是刻意設置、超出
已測試範圍的 lab-specific 例外(與實驗 108 中的先例類似)，而不是有保證的
官方支援 - 升級 Kyverno 時請取消這個例外。

## 先決條件與限制

**podman 與 registry 在實驗環境中已經設定好**。建置與發布映像請使用 `podman`
(考試清單中的工具；rootless，以使用者 `ubuntu` 身分)。任務 3 與 9c 需要建置並
**發布**映像到 worker 與叢集都能存取的 registry
(immutable 引用 `repo@sha256:...` 取自 registry，本機的 image ID 不適用)。這樣的 registry -
control-plane 上的 `registry:2` - 由 bootstrap 啟動：

- 位址：`<control-plane 的 IP>:5000`，它被寫在 worker 的 `/etc/cks111/registry` 中；
- 協定 - VPC 內部的一般 HTTP:worker 上的 podman 與節點上的 containerd 都把它設定為
  insecure registry(不需要旗標 `--tls-verify=false`)，而 Kyverno 的 `ImageValidatingPolicy` 需要
  `credentials.allowInsecureRegistry: true`;
- 資料儲存在節點本機的 PV(`/var/lib/cks111-registry`)上，因此能撐過
  registry Pod 的重新啟動；
- 已發布映像的 digest 請從 `podman push --digestfile` 取得，而 manifest 是否存在
  請用對 `/v2/` 的請求檢查(registry 中沒有像 `docker buildx imagetools` 這類僅限 HTTPS 的工具);
- 詳細的指令順序 - 在[參考解答](worker/files/solutions/1_TW.MD)的「0. 準備」步驟中。

**Docker Hub 的限制**。同一個 IP 的匿名 pull 有限制(約每 6 小時 100 個請求)。
為了讓 `check_result` 不會撞上它，bootstrap 一次性把實驗的映像下載到本機快取
(`nginx:1.27.3-alpine` 以及任務 1b/1c 的候選映像)，而 Trivy 與 Syft 在重複掃描時，透過同樣的引用 `name@sha256:...`
從這個快取取得映像，不會存取 Docker Hub。`bom` 只能
從 registry 讀取映像，因此它每次執行仍然會發出幾個請求。
如果 Docker Hub 仍然回傳 `TOOMANYREQUESTS`，請等待(限制的視窗是滑動的)，或以你自己的帳號
執行 `podman login docker.io`。

**Cosign 與金鑰密碼。**`cosign generate-key-pair` 與 `cosign sign --key` 會詢問金鑰的
密碼；對於學習用的金鑰對，可以留空(`export COSIGN_PASSWORD=""`)，讓指令
不用等待輸入。

**`trivy sbom` 與沒有 OS 的 SBOM(任務 8)。**`bom` 為 multi-arch 映像產生的 SPDX 不包含
OS 的資訊：Trivy 會寫下 `Detected OS family="none"`，並且找不到弱點(`Results` 為空)。
因此在任務 8 中掃描的是任務 7 的 CycloneDX - 其中有元件 `operating-system`,
而 `trivy sbom` 會給出非空的 `Results`。

## 部署

```bash
TASK=111 make run_cks_task
```

連線到 worker 並選擇 context:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

最初的 `Dockerfile` 與 `deployment.yaml` 是刻意設置為不安全的。工作用的 artifacts
請只建立在 `/var/work/tests/artifacts/<編號>/` 中。

## 任務

`nginx:1.27.3-alpine` 是 mutable tag，而不是固定的引用。首先從 Trivy JSON 的 `Metadata.RepoDigests[0]` 取得標準的 registry manifest digest，並使用 immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>`(以下稱 `$IMAGE`)。對於你自己的 hardened image，先建置並發布 image 到叢集可存取的 registry，然後使用它的 manifest digest；本機的 image ID 與 layer DiffID 不是 registry manifest digest。

---
| **1** | **Trivy：映像弱點報告** |
| :---: | :--- |
| 要做什麼 | • 用 Trivy 掃描 immutable 的 `$IMAGE`，包括 OS 與 library 的弱點。<br/>• 把結構化的 JSON 儲存到 `/var/work/tests/artifacts/1/trivy-report.json`。 |
| 驗收標準 | • **檔案**：非空，JSON 能被 `jq` 解析，包含 `Results` 與被分析映像的 immutable reference。<br/>• **新的檢查**:checker 會自己對同一個映像重複執行 `trivy image`，並要求這次新的掃描在 `ArtifactName` 上成功相符。<br/>• 手動撰寫、但語法有效的 JSON 無法通過。 |

<details>
<summary>💡 任務 1 的提示</summary>

`$IMAGE` 分兩步建立：先掃描 `nginx:1.27.3-alpine`(一般的 tag)，並從「這第一份」JSON 報告中取出 `Metadata.RepoDigests[0]`，然後用 `nginx:1.27.3-alpine@sha256:<digest>` 重組指令，並掃描已經是 immutable 的引用 - 需要儲存為最終報告的正是這第二份。不要把 Trivy 輸出中的 `ImageID`/`DiffID` 當作 registry digest 的替代品 - 它們是「本機的」識別碼，與 registry 中的 manifest digest 不相符。
</details>

---
| **1b** | **Multi-image CVE triage：找出包含特定 CVE 的映像** |
| :---: | :--- |
| 要做什麼 | • 打開 `~/cks-111/candidates.txt` - 那裡有三個 immutable image reference(`CANDIDATE_1/2/3`)以及目標 `TARGET_CVE`，它們是 bootstrap 時針對你這個實驗實例個別決定的。<br/>• 用 Trivy 掃描**全部三個**映像，找出其中哪一個確實包含 `TARGET_CVE`。<br/>• 把正是這個映像的 JSON 報告儲存到 `/var/work/tests/artifacts/1b/target-scan.json`。<br/>• 把字串 `OFFENDING_IMAGE=<這個映像的完整引用>` 儲存到 `/var/work/tests/artifacts/1b/answer.txt`。 |
| 驗收標準 | • **答案：**`answer.txt` 指出的正是其真實 Trivy 掃描包含 `TARGET_CVE` 的那個 `CANDIDATE_N`。<br/>• **報告：**`target-scan.json` 是這同一個映像真實的 Trivy 輸出(checker 會自己重複掃描並比較)。 |

<details>
<summary>💡 任務 1b 的提示</summary>

`TARGET_CVE` 對每個實驗實例都不同 - 它是在 provisioning 期間從即時的 Trivy vulnerability DB 計算出來的，而不是事先寫死的，所以這個檔案中有你自己的答案。不要憑標籤名稱猜測(「最舊的 - 大概有弱點」)- 請真正掃描全部三個，並在 JSON 中找到 `VulnerabilityID` 的精確相符。每個映像一條指令：`trivy image --format json "$ref" | tee scan.json`，然後 `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` 表示這個具體的 CVE 不在這個映像中(其中很可能有其他 CVE - 這不會被檢查)。
</details>

---
| **1c** | **依 CRITICAL severity 做 workload image triage** |
| :---: | :--- |
| 要做什麼 | • namespace `cks-111` 中已經部署了 4 個 Deployment(label `cks.io/task=1c`)，每個都只有一個 immutable、以 digest 固定的 image。<br/>• 從這些 LIVE Deployments 取得 image references(不要依標籤名稱猜測)，用 Trivy 以 `--severity CRITICAL` 掃描**全部 4 個**映像，並計算每個映像中不重複的 CRITICAL `VulnerabilityID` 數量。<br/>• 找出 CRITICAL 數量最多的 Deployment(「最脆弱的」)以及數量最少的兩個 Deployment(「兩個最不脆弱的」)。把它們的名稱寫入 `/var/work/tests/artifacts/1c/ranking.txt`，格式為 `MOST_VULNERABLE=<deployment-name>`、`LEAST_VULNERABLE_1=<deployment-name>`、`LEAST_VULNERABLE_2=<deployment-name>`。<br/>• 對最有弱點的 Deployment 的映像，**以 Trivy**(`trivy image --format cyclonedx`)產生 CycloneDX SBOM 到 `1c/cyclonedx.json`。<br/>• 然後進行 remediate：只在兩個最不脆弱的 Deployment 上保留 `replicas > 0`，其餘兩個(包括最有弱點的)縮減到 `replicas: 0`。 |
| 驗收標準 | • **Ranking**:checker 會自己重複對全部 4 個 live images 的 Trivy CRITICAL 掃描，並重新計算 ranking - `ranking.txt` 必須與這次新的掃描相符，而不是與過時的/猜測的結果相符。<br/>• **SBOM:**`cyclonedx.json` 是有效的 CycloneDX 文件，正是來自 Trivy，並且屬於真正最有弱點的 Deployment 的映像。<br/>• **Remediation**：恰好 2 個 Deployment(依新掃描最不脆弱的)具有 `replicas > 0`，其餘 2 個 - `replicas: 0`。 |

<details>
<summary>💡 任務 1c 的提示</summary>

請用形如 `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` 的指令取得 image references - 不要試圖從 Deployment 的名稱猜測哪個映像「較新」或「較安全」。計數的指令：`trivy image --scanners vuln --severity CRITICAL --format json <ref>`，然後 `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`。對於 CycloneDX，請使用 `trivy image --format cyclonedx --output <file> <ref>` - 不是 Syft(Syft 已經在任務 7 中用於另一個映像，這裡明確要求的是 Trivy)。縮放透過 `kubectl scale deployment/<name> -n cks-111 --replicas=0` 完成(對保留的則是 `--replicas=1`)。
</details>

---
| **2** | **初始的靜態分析報告** |
| :---: | :--- |
| 要做什麼 | • 在修正「之前」(任務 3 開始之後，不要動這三個檔案中的任何一個)儲存結果：Hadolint 到 `2/hadolint-before.txt`,kubesec JSON 到 `2/kubesec-before.json`,kube-linter JSON 到 `2/kube-linter-before.json`。<br/>• 直接對「初始的」起始 `Dockerfile`/`deployment.yaml` 執行它們。<br/>• 不要在報告檔案中透過 `\|\| true` 隱藏錯誤：linter 的非零 exit code 是預期的。 |
| 驗收標準 | • **Artifacts**：三個都存在；Hadolint 包含 findings,kubesec 包含 `scoring`,kube-linter 是有效的 KubeLinter JSON 物件，帶有欄位 `Reports` 與 `Summary`；修正之前 `Reports` 包含 findings。<br/>• **與 baseline 比對**:checker 把這三個 artifacts 的內容與它自己的 baseline 比較，該 baseline 是在 provisioning 時、在把初始起始檔案發給學員「之前」針對它們取得的。<br/>• 手動撰寫、但語法有效的報告無法通過。 |

<details>
<summary>💡 任務 2 的提示</summary>

linter 在發現問題時回傳非零 exit code 是「預期的」行為，而不是你的指令的錯誤。如果你把呼叫包在 `|| true` 中，只是為了讓腳本不會因 `set -e` 而停止，請確認指令的輸出仍然被儲存到檔案中(在 `|| true` 「之前」透過 `tee` 或重新導向)，而不是遺失。
</details>

---
| **3** | **依 findings 修正 Dockerfile** |
| :---: | :--- |
| 要做什麼 | • 修正 `/home/ubuntu/cks-111/Dockerfile`：用 immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` 固定基礎映像。<br/>• 不要使用帶 URL 的 `ADD`，不要把 token 存放在 `ENV` 中，不要安裝 `sudo`。<br/>• 加入非特權的 `USER`(uid 不是 `0`)。使用 `COPY`，並且只在必要時才使用可重現的套件安裝。<br/>• 在其他指令旁邊加入 `ARG CKS_SIGNATURE_TEST=signed` 與 `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` - 這是映像中唯一受控的差異點，任務 9c 會需要它，以保證在不改變此處已驗證的 security 特性的情況下得到不同的 digest。<br/>• 修改之後，把成功的 Hadolint 輸出儲存到 `3/hadolint-after.txt`。 |
| 驗收標準 | • **Dockerfile**：沒有 `latest`，移除了 remote `ADD`，沒有留下 `API_TOKEN`/`TOKEN`，有 non-root `USER`，有 `ARG CKS_SIGNATURE_TEST` 與 `LABEL cks.signature-test`。<br/>• **Hadolint**：最終報告不包含 `DL3007`、`DL3013`、`DL3020`、`DL3045`。 |

<details>
<summary>💡 任務 3 的提示</summary>

`CKS_SIGNATURE_TEST` 的 `ARG`/`LABEL` 看起來可能與目前 Hadolint 的 findings 無關 - 它是特意在這裡事先加入的，讓任務 9c(要晚得多)能夠透過 `--build-arg` 建置物理上不同的映像，而不必再次改寫 Dockerfile。請現在就加入這兩行，即使它們的用處要到 9c 才會明白。
</details>

---
| **4** | **依 kubesec 與 kube-linter 修正 workload YAML** |
| :---: | :--- |
| 要做什麼 | • 首先建置並發布任務 3 的 hardened image，然後在 `deployment.yaml` 中指定它的 immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>`(不是上游的 nginx)。<br/>• 在 Pod 層級加入 `automountServiceAccountToken: false`、`runAsNonRoot: true`、`seccompProfile: RuntimeDefault`。<br/>• 在容器中設定 `allowPrivilegeEscalation: false`、`readOnlyRootFilesystem: true`、`capabilities.drop: ["ALL"]`、CPU 與 memory 的 requests/limits。<br/>• 對 nginx，把可寫的 `emptyDir`/tmpfs 掛載到 temp、pid/run、cache 與 config 路徑，並在啟動前準備好 config。<br/>• 移除 `privileged`，套用 Deployment，確認 Ready/Available 以及成功的 HTTP request。<br/>• 儲存新的報告 `4/kubesec-after.json` 與 `4/kube-linter-after.json`。 |
| 驗收標準 | • **映像**:YAML 使用以 digest 固定、帶有 `USER 101` 的 hardened image，而不是上游的 nginx。<br/>• **Manifest**：需要的欄位、init container `prepare-nginx-config` 與可寫的 mounts 都存在；沒有 `privileged`。<br/>• **可運作性**:Deployment 為 Available，且 HTTP request 成功。<br/>• **報告**：兩份最終報告都是有效的 JSON。 |

<details>
<summary>💡 任務 4 的提示</summary>

`readOnlyRootFilesystem: true` 要求為 nginx 通常會寫入的「每一個」目錄提供可寫路徑：`/tmp`、`/var/run`(PID 檔案)、`/var/cache/nginx`(快取)以及 `/etc/nginx/conf.d`(如果 config 是在啟動時產生的)。只要漏掉一個 - 容器會啟動，但在 nginx 第一次嘗試寫入那裡時就會失敗。Init container `prepare-nginx-config` 是用來在主容器啟動「之前」把預設設定複製到單獨的可寫 volume 中 - 這正是為什麼它在驗收標準中被單獨提及。
</details>

---
| **5** | **搜尋套件版本** |
| :---: | :--- |
| 要做什麼 | • 對 `$IMAGE` 以列出所有套件的模式使用 Trivy。<br/>• 把指令、immutable image reference、來自 `Metadata.RepoDigests[0]` 的標準 `nginx@sha256:<manifest-digest>`，以及至少三行 `name=version`，儲存到 `/var/work/tests/artifacts/5/version-search.txt`。<br/>• 不要用手動清單取代搜尋：evidence 中必須有帶有 `trivy image --list-all-pkgs` 的指令行。 |
| 驗收標準 | • **Artifact**：包含指令、immutable 的 `nginx:1.27.3-alpine@sha256:...`、來自 Trivy 的 `repo_digest=nginx@sha256:...`，以及至少三組 package/version。<br/>• **新的檢查**:checker 會自己對同一個映像重複執行 `trivy image --list-all-pkgs`，並要求 `repo_digest=` 與至少三組儲存的 `name=version` 與這次新的掃描相符。<br/>• 手動撰寫、但語法上看似合理的清單無法通過。 |

<details>
<summary>💡 任務 5 的提示</summary>

旗標的名稱正是 `--list-all-pkgs`，而不是 `--list-packages` 或類似的變體 - 如果指令無法運作，請在 `trivy image --help` 中檢查確切的旗標名稱。請把指令「真實的」輸出儲存到檔案中(例如透過 `tee`)，不要「憑記憶」手動改寫幾行 package=version - 測試會尋找帶有指令本身的行，作為資料來自工具的證明。
</details>

---
| **5b** | **在 workload 映像中找出套件版本並移除有問題的 containers** |
| :---: | :--- |
| 要做什麼 | • namespace `cks-111` 中已經部署了 Deployment `pkg-audit-app`，有三個 containers(`c1`、`c2`、`c3`)，每個都使用自己的 immutable、以 digest 固定的 image。<br/>• 三個 images 中恰好有兩個包含同一個特定版本的套件 - 你這個實驗實例的 `TARGET_PACKAGE`/`TARGET_VERSION` 是在 provisioning 時動態決定的，沒有寫死的值。<br/>• 從 live Deployment 取得三個 image references，對每一個執行 `bom generate`(把每個 SBOM 分別儲存到 `/var/work/tests/artifacts/5b/bom/`)。<br/>• 找出哪兩個 containers 確實包含同一個 package/version，並把找到的組合以 `TARGET_PACKAGE=<name>` 與 `TARGET_VERSION=<version>` 寫入 `5b/answer.txt`。<br/>• 從 Deployment 中刪除正是這兩個有問題的 containers(透過 `kubectl edit`/`kubectl apply` 修正後的 manifest)，讓只剩下「乾淨的」container，而 Deployment 保持 `Available`。 |
| 驗收標準 | • **答案：**`answer.txt` 指出的是真實存在於三個初始 images 中恰好兩個的 package/version(不是猜出來的)。這兩個映像有很多共同的套件：任何一組不在第三個映像中的 `name=version` 都可以。<br/>• **SBOM:**`5b/bom/` 中至少有一份真正的 `bom generate` 輸出，證實這個發現。<br/>• **獨立檢查**:checker 會獨立地對初始的 candidate images(在 provisioning 時保存的)執行 `bom generate`，並把你的答案與這次獨立的執行比對。<br/>• **Deployment**：最終的 Deployment 只包含「乾淨的」container，並保持 `Available`。 |

<details>
<summary>💡 任務 5b 的提示</summary>

指令是 `bom generate --format json --output <file> --image <ref>`，對三個 image references 中的「每一個」分別執行。請成對比較 SBOM：如果同一組 `name`/`versionInfo` 出現在兩個 containers 的 SBOM 中，但不在(或版本不同於)第三個中，那麼這個套件就被視為「有問題的」。不要試圖從映像的名稱/標籤猜測 - 有些成對的映像可能看起來「相似」，但實際上套件是否相符，只能透過比較真實的 SBOM 來決定。編輯 Deployment 時，請把 container 從 `spec.template.spec.containers` 中整個刪除，而不只是更改它的 image。
</details>

---
| **6** | **透過 bom 的 SPDX SBOM** |
| :---: | :--- |
| 要做什麼 | • 用工具 `bom` 為 immutable 的 `$IMAGE`(與任務 1 中使用的同一個 `tag@digest`，而不是 bare tag `nginx:1.27.3-alpine`)產生 SPDX JSON SBOM；儲存到 `/var/work/tests/artifacts/6/bom.spdx.json`。<br/>• 在檔案 `6/bom-command.txt` 中寫入所執行的指令，帶有精確的 `--image $IMAGE`。 |
| 驗收標準 | • **SBOM**：有效的 JSON，具有 `spdxVersion`，包含陣列 `packages`；被 `documentDescribes` 引用的 top-level 套件之一(透過 `versionInfo`/`name`)識別出與任務 1 的 `$IMAGE`「相同的」manifest digest。<br/>• **指令：**`bom-command.txt` 包含精確的 immutable `$IMAGE`，並使用 `bom generate`。<br/>• 另一個映像(與任務 1 的 `$IMAGE` 無關)的 SBOM 無法通過，即使 `bom-command.txt` 是偽造的。<br/>• **新的檢查**:checker 還會自己用同一個 `bom` 為同一個映像重新產生 SBOM，並要求你的 SBOM 中的套件集合(`name`/`versionInfo`)與這次新的執行相符 - 只有一個 top-level 套件、手動撰寫的最小 SPDX 文件無法通過。 |

<details>
<summary>💡 任務 6 的提示</summary>

指令 `bom generate -o <output.json> -i <image>` - 務必帶旗標 `-o` 指定輸出檔案，否則輸出會進入 stdout。`bom` 的輸出格式 - 是它「自己的」SPDX JSON，在細節上與 Syft 可能產生的 SPDX 不同 - 在產生同一種標準格式時，不要把這兩個不同的工具混為一談。
</details>

---
| **7** | **透過 Syft 的 CycloneDX SBOM 與 Cosign 驗證** |
| :---: | :--- |
| 要做什麼 | • 為任務 1 中同一個 immutable `$IMAGE`(`nginx:1.27.3-alpine@sha256:<manifest-digest>`)產生 Syft 的 CycloneDX JSON SBOM，並儲存到 `7/syft.cdx.json`。<br/>• 然後透過 keyless Cosign 驗證公開映像 `gcr.io/distroless/static-debian13:nonroot` 的簽章，並把完整的成功輸出儲存到 `7/cosign-verify.txt`。<br/>• 對 Distroless，使用 issuer `https://accounts.google.com` 與 identity `keyless@distroless.iam.gserviceaccount.com`。 |
| 驗收標準 | • **Syft SBOM:**`bomFormat: CycloneDX`，非空的 `components`,`metadata.component.type == "container"`，且 `metadata.component.version` 等於任務 1 中同一個 `$IMAGE` 的 manifest digest - 另一個映像(bare tag、alpine、busybox 等)的 SBOM 無法通過。<br/>• **Cosign**：對 `gcr.io/distroless/static-debian13:nonroot` 的真實 `cosign verify` 指令(這是目前受支援的標籤；不帶後綴 `-debian13` 的 `gcr.io/distroless/static:nonroot`，依據 Distroless 官方 README 已被視為 deprecated，並且不再更新)，帶有指定的 issuer/identity，以 exit code `0` 結束，而完整的輸出已儲存到 `7/cosign-verify.txt`。<br/>• **新的檢查**:checker 還會自己用同一個 Syft 為同一個映像重新產生 SBOM，並要求你的 SBOM 中的元件集合(`name`/`version`)與這次新的執行相符 - 只有一個 top-level 元件、手動撰寫的最小 CycloneDX 文件無法通過。 |

<details>
<summary>💡 任務 7 的提示</summary>

Syft 透過旗標 `-o cyclonedx-json` 產生 CycloneDX(不要與同一個工具的 SPDX 輸出混淆)。對 Distroless 的 keyless verification，既不需要金鑰，也不需要 `cosign generate-key-pair` - 請使用 `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>`，並帶有任務中指定的「精確」issuer/identity 字串 - 其中任何一個有錯字，都會導致驗證錯誤。
</details>

---
| **8** | **`trivy sbom`：對現成的 SBOM 檔案掃描弱點** |
| :---: | :--- |
| 要做什麼 | • 任務 7 的 CycloneDX SBOM(`7/syft.cdx.json`)描述了 image 的組成與它的 OS，但本身不包含關於弱點的結論。<br/>• 用工具 `trivy sbom` 掃描正是這個 SBOM 檔案(而不是直接掃描 image)，並把結構化的 JSON 儲存到 `/var/work/tests/artifacts/8/sbom-scan.json`。<br/>• 指令必須明確地把 SBOM 檔案作為輸入，而不是重新掃描 `$IMAGE`；請把它的文字儲存到 `/var/work/tests/artifacts/8/sbom-scan-command.txt`。 |
| 驗收標準 | • **檔案**：非空，JSON 能被 `jq` 解析，`ArtifactType` = `cyclonedx`,`Results` 非空並包含找到的弱點。<br/>• **指令：**`sbom-scan-command.txt` 包含帶有通往 `7/syft.cdx.json` 路徑的 `trivy sbom` 指令。<br/>• **新的檢查**:checker 會自己對這個檔案重複執行 `trivy sbom`。 |

<details>
<summary>💡 任務 8 的提示</summary>

指令是 `trivy sbom <sbom-檔案的路徑>`，而「不是」`trivy image <檔案的路徑>` - 這是輸入邏輯不同的不同子指令。如果你不小心把 SBOM 檔案的路徑傳給 `trivy image`,Trivy 會試圖把它解釋為 image reference 的名稱，並以錯誤或出乎意料的行為結束。
</details>

---
| **9a** | **Kyverno：安裝並建立針對 trusted signature 的 `ImageValidatingPolicy`** |
| :---: | :--- |
| 要做什麼 | • 透過 `install-kyverno` 安裝 Kyverno，並等待 `admission controller` 就緒。<br/>• 用 `cosign generate-key-pair` 產生本機金鑰對(學習用的金鑰對，不是 production key)。<br/>• 用你的 private key 簽署任務 4 中**你自己的** hardened image(`$HARDENED_IMAGE`，不是上游的 nginx)，並把 `cosign sign` 的輸出儲存到 `9a/cosign-sign.txt`。<br/>• 建立 `ImageValidatingPolicy` `require-signed-catalog-images`，它以你的 public key 透過 `verifyImageSignatures` 檢查所有在你的 `$HARDENED_IMAGE` 所屬 repository 中帶有 image 的 Pod，包括 `pods/ephemeralcontainers` UPDATE 以及所有 container 清單，並**拒絕**(`validationActions: [Deny]`)未簽署/簽署無效的映像。 |
| 驗收標準 | • **Kyverno**：已安裝，其 admission controller 為 `Available`。<br/>• **簽章：**`9a/cosign-sign.txt` 包含正是對 `$HARDENED_IMAGE` 簽署成功的輸出；真實的指令 `cosign verify --key cosign.pub "$HARDENED_IMAGE"` 成功結束。<br/>• **Policy**：已套用的 `ImageValidatingPolicy require-signed-catalog-images` 存在，具有 `apiVersion: policies.kyverno.io/v1`、`validationActions: [Deny]`、public key 與 `verifyImageSignatures`。<br/>• **作用範圍**：它的 `matchImageReferences` 限制在正是 `$HARDENED_REPO:*` 與 `$HARDENED_REPO@*`，而不是不安全的前綴 `$HARDENED_REPO*`。 |

<details>
<summary>💡 任務 9a 的提示</summary>

`cosign generate-key-pair` 會在目前目錄中建立 `cosign.key`/`cosign.pub` - 這是學習用的金鑰對，不綁定任何 OIDC issuer，這與任務 7 的 keyless verification 不同。請把 private key 存放在 `/home/ubuntu/cks-111` 之外，因為這個目錄在任務 9c 中會被重複用作 Docker build context - 留在其中的 `cosign.key` 會透過 `COPY . /usr/share/nginx/html` 直接進入所發布 image 的檔案系統。policy 中的 `matchImageReferences` 必須把它的作用限制在「正是」你的 repository(`$HARDENED_REPO`)，而不是整個叢集 - 否則 policy 會阻擋「所有」沒有簽章的 Pod，包括 Kubernetes 的系統元件。
</details>

---
| **9b** | **Fresh signed ALLOW:policy 建立之後的新 Pod** |
| :---: | :--- |
| 要做什麼 | • 任務 9a 的 policy 必須允許已簽署的 `$HARDENED_IMAGE` - 但對已經存在的 Deployment 再次 `kubectl apply` **並不能證明**這一點：如果 template 沒有改變，新的 ReplicaSet/Pod 可能不會被建立，而 `Running` 只是在 policy 之前建立的舊 Pod。<br/>• 建立一個**新的**、先前不存在的物件：`kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`。<br/>• 把這個 Pod 的 `creationTimestamp`、9a 中 policy 的 `creationTimestamp`，以及最終的 `status.phase`/`Ready` condition 儲存到 `9b/signed-admission-check.json`。 |
| 驗收標準 | • **Pod:**`signed-admission-check` 存在，使用的正是 `$HARDENED_IMAGE`；對它成功執行 `cosign verify --key cosign.pub "$HARDENED_IMAGE"`,`status.phase` 不是 `Failed`，而 `Ready` 條件達到 `True`。<br/>• **Artifact:**`9b/signed-admission-check.json` 包含這個 image，並且 Pod 的 `creationTimestamp` **晚於** `ImageValidatingPolicy require-signed-catalog-images` 的 `creationTimestamp`。<br/>• 這證明了 policy 之後對可驗證簽署的 image 的 fresh admission，而不是撐過 policy 的舊 Pod。 |

<details>
<summary>💡 任務 9b 的提示</summary>

不要為這項檢查重複使用任務 4 中的 Deployment `catalog` - 請使用字面上全新的 `kubectl run`，搭配新的 Pod 名稱，如任務所指定的。兩個 timestamp(Pod 與 policy)都是 UTC 的 ISO8601 字串，可以像一般字串一樣以字典序比較(`"2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z"` 在 bash 中，對這種格式能正確運作)。
</details>

---
| **9c** | **Signature-specific DENY：同一個 repository 中確實存在的 unsigned digest** |
| :---: | :--- |
| 要做什麼 | • 在與 `$HARDENED_IMAGE` 相同的 repository 中，建置並發布**第二個** tag(例如 `${HARDENED_TAG%:*}:unsigned-1.0`)，不要簽署它。<br/>• 這個映像必須是**物理上不同的 artifact**，而不是與已簽署的 `$HARDENED_IMAGE` 相同的 digest：如果不加更改地建置同一個 `Dockerfile`/context,reproducible/cached build 可能產生相同的 digest，那麼「unsigned」標籤實際上會指向已經簽署的 artifact，而 `cosign verify` 會出乎意料地通過。<br/>• 透過 build-arg 引入受控的差異(例如 `--build-arg CKS_SIGNATURE_TEST=unsigned-1`，並在 Dockerfile 中有對應的 `ARG`/`LABEL`)，並明確把 `$UNSIGNED_DIGEST != $HARDENED_DIGEST` 的證明儲存到 `9c/digest-comparison.txt`。<br/>• 以與任務 3 相同的方式(`podman push --digestfile`)取得 registry manifest digest，在同一個 repository 中組成 `$UNSIGNED_IMAGE`。<br/>• 明確證明這個 digest **存在且 pullable**(對 registry 的請求 `GET /v2/catalog/manifests/<digest>` 成功)，並且**沒有**以你的金鑰簽出的有效簽章(`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` 以錯誤結束)- 把兩個輸出分別儲存到 `9c/unsigned-exists.txt` 與 `9c/unsigned-not-signed.txt`。<br/>• 然後以這個 `$UNSIGNED_IMAGE` 建立 Pod `catalog-unsigned-probe`，並把 admission denial 儲存到 `9c/admission-deny.txt`。 |
| 驗收標準 | • **Artifact:**`9c/digest-comparison.txt` 包含 `hardened_digest=`、`unsigned_digest=` 與 `unsigned_image=`(與 `$HARDENED_IMAGE` 在同一個 repository 中的完整 `tag@digest` 引用，帶有 genuinely 不同的 digest)。<br/>• **checker 的檢查**：會自己在 registry 中解析 `unsigned_image`，透過自己的 `cosign verify` 確認沒有有效的簽章，以這個映像建立它「自己的」新 Pod，並要求它自己的 policy 的唯一 validation message:`catalog image must have a valid release signature`。<br/>• 只有這則訊息才算數，而不是任何 admission 錯誤：來自另一個 policy 的一般 admission/signature 錯誤不會得到 PASS，`manifest unknown`/registry 查詢錯誤也不夠。<br/>• 沒有真實 admission control 的手動撰寫 evidence 檔案不會得到 PASS - checker 不信任任何文字檔，除了作為指向真實待檢查映像的指標 `unsigned_image=`。 |

<details>
<summary>💡 任務 9c 的提示</summary>

證明的順序對於它們的可信度很重要：先證明 `$UNSIGNED_IMAGE` 「存在」且 PULLABLE(否則之後的 denial 可能只是 "manifest unknown",而不是關於簽章)，然後證明「沒有」簽章，而「之後」才嘗試建立 Pod。如果 `digest-comparison.txt` 中的 digest 比較顯示相符 - 請設法讓 content 真正不同(例如把 `CKS_SIGNATURE_TEST` build-arg 改成另一個值並重新建置)。
</details>

## 檢查

```bash
check_result
```

檢查包含 `Init` 與十四個獨立的評分測試(任務 9 分為 9a/9b/9c)。它檢查檔案與
JSON 的內容，而不只是名稱是否存在。Trivy、SBOM 與
Cosign 需要對外的 registry 請求；如果 registry 暫時無法使用，請重複執行對應的指令。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=111 make delete_cks_task
```
