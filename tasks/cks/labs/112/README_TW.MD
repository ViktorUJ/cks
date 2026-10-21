[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime:Falco、audit 日誌與不可變的 root filesystem

## 目標

在這個 CKS 實驗中，你要在節點上設定對 runtime 事件的控制，以及 control plane 的 API audit 記錄，
然後讓 workload 在執行期間成為不可變的。工作在單一
節點上進行：`control-plane` 同時也是 workload 節點，因此 Falco 看得到來自測試 Pod 的事件，
而 kube-apiserver 位於 static Pod manifest 中。

## 開始前先自我檢查

<details>
<summary>1. 為什麼 Kubernetes 的 audit log 不能取代 Falco 做 runtime 偵測？</summary>

Audit log 記錄的是對 API server 的 REQUEST 層級事件(誰、什麼時候、透過 `kubectl`/API 請求了什麼)- 這是 control plane 層級的 evidence。而 Falco 觀察的是節點上執行中容器內部的系統呼叫(syscalls)- 例如開啟 shell、spawn 行程、寫入檔案。像 `docker exec`/`crictl exec` 這樣的動作，或在節點上透過 `ctr` 直接啟動，完全「不會」經過 Kubernetes API，也不會進入 audit log，但 Falco 會把它看作 syscall 事件。
</details>

<details>
<summary>2. audit policy 的 `RequestResponse` 與 `Metadata` 等級有什麼差別，為什麼 Secret 需要的正是 `Metadata`?</summary>

`RequestResponse` 會記錄請求與回應的完整內容，包括資源的內容。`Metadata` 只記錄請求的 metadata(誰、什麼時候、哪個資源、哪個 verb)，「不含」內容。對 `secrets` 來說這很關鍵：`RequestResponse` 會把 secret 本身的值(以 base64 編碼，但仍然是敏感資料)以可讀檔案的形式寫入磁碟上的 audit log - 這會造成新的洩漏面。`Metadata` 提供 forensic 的軌跡(「誰在什麼時候讀取了這個 Secret」)，而不會把 secret 本身複製到 log 中。
</details>

<details>
<summary>3. 為什麼 `readOnlyRootFilesystem: true` 不等同於在執行期間完全防範容器被入侵？</summary>

`readOnlyRootFilesystem` 會阻擋對容器根檔案系統的寫入，這妨礙攻擊者修改應用程式的二進位檔，或在容器的磁碟上建立 persistence。但它「不會」妨礙：(a) Pod 自己明確掛載的可寫 volumes/emptyDir(例如 `/tmp`)、(b) 在行程記憶體中執行的動作(不寫入磁碟的 RCE)、(c) 從容器內部發起的網路攻擊、(d) 讀取已經掛載的 Secret/ConfigMap。rootfs 的不可變性只是一層防護，而不是完整的隔離。
</details>

## 與課程的關聯

- [第 29 章。執行期的行為分析：Falco](../../course/29/tw.md)
- [第 30 章。威脅偵測與攻擊階段調查](../../course/30/tw.md)
- [第 31 章。執行期的容器不可變性](../../course/31/tw.md)
- [第 32 章。Kubernetes 的 Audit 日誌](../../course/32/tw.md)
- [第 26 章。Registries、簽署與 artifacts 的驗證](../../course/26/tw.md) - 任務 9 把 registry allowlist 的 admission 控制與對繞過行為的 runtime 偵測連結起來(不是 signature verification - 那由實驗 111 檢查)。

## 基礎架構

| 元件 | 用途 |
|---|---|
| `k8s-1` | 單節點 Kubernetes `1.36.0`、containerd 與 Calico；節點名稱為 `control-plane` |
| `worker` | 具備 `kubectl`、`check_result` 以及 SSH 存取 `ssh control-plane` 的工作機 |
| `runtime-112` | 準備好的 namespace；其中已經有 Secret `audit-secret` |

Bootstrap 刻意**不**安裝 Falco，也**不**啟用 audit backend。它只
準備目錄 `/etc/kubernetes/audit`、log 目錄
`/var/log/kubernetes/audit`，以及用於受控 API 請求的 Secret。不要更改 CNI、
叢集版本、Secret 或任務 4 與 8 之外的 Kubernetes manifests。

## 部署

```bash
TASK=112 make run_cks_task
```

在工作機上：

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## 如何操作節點

打開兩個終端機：**終端機 1** - `ssh control-plane`，然後 `sudo -i`(對節點的操作：
Falco、audit、`crictl`、`/proc`),**終端機 2** - 工作機(`kubectl`、`scp`、檢查)。
在節點上取得的 artifacts，請儲存到 `control-plane` 上的檔案，並用
`scp` 指令複製到工作機的 `/var/work/tests/artifacts/<任務編號>/`。

## 任務

在 containment 之前，先在心中評估 blast radius 會有幫助：被入侵的 Pod 的 ServiceAccount
能否讀取 Secrets、建立 workload，或到達其他
namespace。這可以、也值得以 Pod `falco-shell` 的 ServiceAccount(`--as=system:serviceaccount:runtime-112:default`)的身分，透過 `kubectl auth can-i`
快速檢查，作為附加步驟；它不是必須的，不影響
驗收標準，也不會被測試。

---
| **1** | **在 workload 節點上安裝並啟動 Falco** |
| :---: | :--- |
| 要做什麼 | • 在 `control-plane` 上，從 Falco 官方 repository 安裝 Falco 套件並啟動服務。<br/>• 使用 modern eBPF engine；不要手動安裝 kernel module。<br/>• 透過 systemd 啟用服務。 |
| 驗收標準 | • `falco --version` 可以執行<br/>• `systemctl is-active falco` 回傳 `active`<br/>• 設定包含 `engine.kind: modern_ebpf` |

<details>
<summary>💡 任務 1 的提示</summary>

Modern eBPF engine 是透過 `/etc/falco/falco.yaml` 中或 `/etc/falco/config.d/` 下 drop-in 檔案中的 `engine.kind: modern_ebpf` 設定的(而不是透過 legacy engine 所需的單獨 kernel module driver)- 如果安裝之後 Falco 無法啟動或在啟動時失敗，請檢查 `journalctl -u falco-modern-bpf`(套件安裝的是 unit `falco-modern-bpf.service`，而 `falco.service` 只是指向它的 alias:`systemctl status/restart falco` 可以運作，但 `journalctl -u falco` 是空的)，查看載入 eBPF program 的錯誤，這可能表示核心不相容。
</details>

---
| **2** | **記錄容器中標準的 shell 事件** |
| :---: | :--- |
| 要做什麼 | • 在 `runtime-112` 中以 `busybox:1.36` 建立 Pod `falco-shell`，讓它保持 Running(`sleep 3600`)，並啟用 `stdin: true`、`tty: true`。<br/>• 在其中打開互動式 `/bin/sh`，並等待 Falco 的規則 **Terminal shell in container** 觸發。<br/>• 把 Falco journal 中符合的那一行(在 `control-plane` 上讀取)儲存到節點上的檔案，並用 `scp` 複製到工作機的 `/var/work/tests/artifacts/2/falco-shell.log`。 |
| 驗收標準 | • Pod `falco-shell` 為 Running<br/>• artifact 非空，並包含 alert 行 `A shell was spawned in a container with an attached terminal`(Falco 0.45 的文字輸出中，規則 **Terminal shell in container** 就是這樣印出事件的；規則名稱只出現在 JSON 輸出中)<br/>• 事件必須是由 Falco 接收到的，而不是手動寫入的 |

<details>
<summary>💡 任務 2 的提示</summary>

單單建立帶有 `stdin: true, tty: true` 的 Pod 是不夠的 - 需要「真正」打開互動式工作階段(`kubectl exec -it falco-shell -- /bin/sh`),Falco 才會記錄容器內 shell 行程的 spawn。請在 `control-plane` 上(從 worker 透過 SSH)透過 `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` 尋找事件，不要試圖手動把這一行寫入檔案 - 測試預期的是來自 journal 的真實 timestamp/格式。
</details>

---
| **3** | **加入並觸發自訂的 Falco rule** |
| :---: | :--- |
| 要做什麼 | • 在 `control-plane` 上，於 `/etc/falco/falco_rules.local.yaml` 中加入名為 `CKS112 Custom Shell Marker` 的規則。<br/>• 它必須捕捉容器中 `proc.cmdline` 包含 `CKS112_CUSTOM_EVENT` 的 spawned process。<br/>• 它必須輸出精確的片語 `CKS112 custom shell marker`，以及 `container=%container.id`、`pid=%proc.pid`、`ppid=%proc.ppid`、`user=%user.name` 與 `command=%proc.cmdline`。<br/>• 重新啟動 Falco。<br/>• 在 `falco-shell` 中執行任何簡短的、命令列中包含 marker 的指令，例如：`kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`。<br/>• 在 `control-plane` 上的 Falco journal 中找出這次觸發的那一行(其中有 `CKS112 custom shell marker`)，把它儲存到節點上的檔案，並用 `scp` 複製到 `/var/work/tests/artifacts/3/falco-custom.log`。這一行必須是真正的 journal 行，手動撰寫的不被接受。 |
| 驗收標準 | • 本機 rules 檔案存在，包含規則名稱、marker 條件與調查用的識別碼<br/>• Falco 服務為 active<br/>• 真正的 journal artifact 包含 marker、container ID 與 PID |

<details>
<summary>💡 任務 3 的提示</summary>

`falco_rules.local.yaml` 中的自訂規則需要 `condition`，使用 `spawned_process`(或 `evt.type=execve`)搭配 `proc.cmdline contains "CKS112_CUSTOM_EVENT"` - 沒有針對事件類型的基本條件，規則可能完全不會觸發，或對錯誤的事件觸發。修改檔案之後，請執行 `systemctl restart falco`，以確定性地確認規則已套用。在目前的 Falco 中，啟用 `watch_config_files: true` 時也可能自動 reload，但本實驗使用明確的 restart。
</details>

---
| **4** | **啟用 audit 記錄：ConfigMap 使用 RequestResponse,Secret 使用 Metadata** |
| :---: | :--- |
| 要做什麼 | • 在 `control-plane` 上建立 `/etc/kubernetes/audit/policy.yaml`。Policy 必須**只在 namespace `runtime-112` 中**對 core resource `configmaps` 記錄 `RequestResponse`(在非敏感資源上的受控 forensic 範例)。<br/>• 對 core resource `secrets` 只使用 `Metadata`,**讓 Secret 的內容不會進入日誌**。<br/>• 對高流量/低風險的流量使用明確的 `None` 規則，以及 `omitStages: [RequestReceived]`，真正降低雜訊。<br/>• 以安全的 catch-all `Metadata` 結束 policy，作為 *fallback logging*，而不是用來降噪。<br/>• 在 static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` 中加入 `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`、`--audit-log-path=/var/log/kubernetes/audit/audit.log` 以及輪替(`--audit-log-maxage`、`--audit-log-maxbackup`、`--audit-log-maxsize`)。<br/>• 為 policy 目錄與 log 目錄加入必要的 hostPath volume/volumeMount。等待 API 恢復。<br/>• 在 `runtime-112` 中建立 ConfigMap `audit-config`，讀取它(`kubectl get configmap audit-config -n runtime-112 -o json`)，並把 RequestResponse event 儲存到 `/var/work/tests/artifacts/4/configmap-request-response.json`。<br/>• 然後讀取 `kubectl get secret audit-secret -n runtime-112 -o json`，並把它的 Metadata event 儲存到 `/var/work/tests/artifacts/4/secret-metadata.json`。Events 取自 `control-plane` 上的 audit log：先儲存到節點上，再用 `scp` 複製。 |
| 驗收標準 | • Kube-apiserver 健康<br/>• Static manifest 包含兩個 audit 旗標與 mounts<br/>• Policy 對 `configmaps` 設定 `RequestResponse`，對 `secrets` 設定 `Metadata`<br/>• `/var/work/tests/artifacts/4/configmap-request-response.json` 中是 ConfigMap 的 RequestResponse event<br/>• `/var/work/tests/artifacts/4/secret-metadata.json` 中是 `Metadata` 等級的 Secret 事件，**沒有欄位 `requestObject`/`responseObject`**(Secret 的內容沒有被記錄) |

<details>
<summary>💡 任務 4 的提示</summary>

audit policy 中規則的順序很重要：Kubernetes 由上而下套用「第一個」符合的規則，因此針對 `runtime-112` 中 `configmaps`/`secrets` 的具體規則，必須排在檔案結尾的通用 catch-all `Metadata` 「之前」- 如果 catch-all 排在最前面，它會在具體規則之前「攔截」所有請求。編輯 static manifest 之後，kubelet 會自動偵測並套用變更(不需要 `kubectl apply`/restart)- 但請等到 `kubectl get --raw=/readyz` 再次成功，再繼續。
</details>

---
| **5** | **建立 root filesystem 為唯讀的 Pod** |
| :---: | :--- |
| 要做什麼 | • 在 `runtime-112` 中建立 Pod `immutable-app`：容器 `app`、映像 `busybox:1.36`、`sleep 3600`。<br/>• 在容器上啟用 `securityContext.readOnlyRootFilesystem: true`。<br/>• 建立 `emptyDir` `writable-tmp`，並把它掛載到 `/tmp`，不帶 `readOnly: true`。不要使用 `hostPath`。<br/>• 證明 `touch /cks-112-write-denied` 失敗，而 `touch /tmp/allowed` 成功；把拒絕的結果儲存到 `/var/work/tests/artifacts/5/rootfs-write-denied.log`。 |
| 驗收標準 | • Pod 為 Running<br/>• Root filesystem 為 read-only<br/>• `/tmp` - 可寫的 `emptyDir`<br/>• Pod 中沒有 `hostPath`<br/>• 對 rootfs 的寫入被阻擋，對 `/tmp` 的寫入被允許<br/>• artifact 非空 |

<details>
<summary>💡 任務 5 的提示</summary>

請儲存指令 `touch /cks-112-write-denied` 的「錯誤輸出」(stderr 中的 `Read-only file system`)，而不只是指令以非零代碼結束這個事實 - 測試檢查的是 log 的內容。不要把 `emptyDir`(暫時性的，與 Pod 同生命週期)與 `hostPath`(在節點上持久，在這個任務中被禁止)混為一談 - 兩者在技術上都「解決」了可寫目錄的問題，但這裡只允許前者。
</details>

---
| **6** | **從 alert 到隔離的最小 containment 鏈** |
| :---: | :--- |
| 要做什麼 | • 啟用 audit backend 之後，在 `falco-shell` 中啟動一個受控的、長時間執行的行程，其命令列中有 `CKS112_CUSTOM_EVENT`，例如：`kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`。行程存活 10 分鐘：在它存活期間，可以取得它的 `/proc/<PID>`。<br/>• **從新的 Falco alert 開始調查**，而不是從 Pod manifest。從 alert 中取出 short container ID 與 host PID。<br/>• 在 `control-plane` 上透過 `crictl ps/inspect/inspectp`，把 container → Pod sandbox → namespace/Pod 對應起來；透過 Kubernetes API 確定節點。儲存 `crictl inspect` 與 `inspectp`。<br/>• 在行程存活期間，儲存 `/proc/<PID>/status`、`cmdline`、`cgroup` 以及 PID/PPID/user 的樹狀結構。<br/>• 在 audit log 中找出 `runtime-112/falco-shell` 的 `pods/exec` event，並在不含 request/response body 的情況下儲存它。<br/>• 把階段分類為 `Execution`，技術分類為 `Container Administration Command`，撰寫 `evidence-summary.txt`。在 `control-plane` 上取得的檔案，請用 `scp` 複製到 `/var/work/tests/artifacts/6/`。<br/>• 然後套用 default-deny ingress+egress 的 `NetworkPolicy` `incident-quarantine`，刪除被入侵的 Pod，並儲存負向檢查：再次 `kubectl exec` 無法通過。<br/>• 這是最小的 containment 鏈：credential 的撤銷/輪替與完整的 remediation 需要單獨的 incident-response 流程。 |
| 驗收標準 | • `/var/work/tests/artifacts/6/` 中有真正的 Falco alert、CRI inspect/inspectp、三個 `/proc` artifacts、process lineage、`pods/exec` 的 Metadata audit event、最終摘要以及 containment 的結果<br/>• Pod `falco-shell` 不存在<br/>• `incident-quarantine` 選取所有 Pod 並封閉 ingress+egress<br/>• 再次 exec 的 exit code 非零 |

<details>
<summary>💡 任務 6 的提示</summary>

嚴格的操作順序對調查的可信度很重要：請從 Falco alert 開始(這才是真正會觸發 incident response 的東西)，而「不是」從已經知道的 Pod 名稱開始 - 否則你只是在確認已經知道的事，而不是進行真正的 correlation。請在行程「存活」期間收集 `/proc/<PID>/*` artifacts - 一旦你刪除 Pod(最後一步)，這個 PID 的 `/proc` 就會永遠消失，因此一旦把「先 evidence、後 containment」的順序弄反，就無法挽回。
</details>

---
| **7** | **Override 上游的 Falco macro，在 output 中加入 Pod/namespace evidence,JSON 寫入檔案** |
| :---: | :--- |
| 要做什麼 | • 標準的 Falco 規則 **Terminal shell in container** 也會對合法的 CI/CD 工具觸發，這類工具會正常地在容器中打開 shell(例如 `kubectl debug` 或帶有維護腳本的 sidecar)。不要編輯規則本身，而是 override 專門為這條規則設計的上游 macro。<br/>• 在 `/etc/falco/falco_rules.local.yaml` 中覆寫 `user_expected_terminal_shell_in_container_conditions`(在規則 **Terminal shell in container** 本身中預設為 `(never_true)` - 不要與 `user_shell_container_exclusions` 混淆，後者屬於另一條規則 **Run shell untrusted**/"Shell spawned by untrusted binary")，讓它允許 namespace `runtime-112` 中具體的 Pod `ci-runner`。<br/>• 請使用 `k8s.pod.name` 與 `k8s.ns.name`，而不是 `container.name`:`container.name` 是**容器**的名稱(在這個任務中是 `app`)，而不是 Pod 的名稱，依容器名稱比對，幾乎總會得到錯誤或過寬的 allowlist。<br/>• 規則 **Terminal shell in container** 的標準 output 不包含 `k8s.pod.name`/`k8s.ns.name`(請自己檢查上游的 `falco_rules.yaml` - 那裡沒有)；沒有這些欄位，就無法可靠地把具體的 alert 與具體的 Pod 做 correlation。請透過同樣的 `override` 機制，在規則的 output 結尾加入(`output: append`)`k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name`。<br/>• 在 `runtime-112` 中以 `busybox:1.36` 建立帶有互動式 `sh`(`stdin: true`、`tty: true`)的 Pod `ci-runner`，並確認對它**不**會產生 alert `Terminal shell in container`，而對任務 5 的 `immutable-app`(沒有例外)alert 仍然會觸發。<br/>• 另外透過 `/etc/falco/config.d/cks112-output.yaml` 啟用 `json_output: true` 與 `file_output.enabled: true`，帶有 `file_output.filename: /var/log/falco/events.log`；重新啟動 Falco。<br/>• 透過結構化的 JSON(`jq .output_fields`)，而不是文字的 `grep`，確認為 `immutable-app` 寫入的 alert 包含 `k8s.pod.name == "immutable-app"` 與 `k8s.ns.name == "runtime-112"`。 |
| 驗收標準 | • `falco_rules.local.yaml` 包含 `macro: user_expected_terminal_shell_in_container_conditions`，其條件引用 `k8s.pod.name = "ci-runner"` 與 `k8s.ns.name = "runtime-112"`(不是 `never_true`，不是 `container.name`)，以及單獨的 `override: output: append`，把 `%k8s.ns.name`/`%k8s.pod.name` 加到規則 `Terminal shell in container`<br/>• 在觀察期間，`ci-runner` 中的 shell 不會產生 alert，而 `immutable-app` 中的 shell 會產生<br/>• `config.d/cks112-output.yaml` 包含 `json_output: true` 與 `file_output: {enabled: true, filename: /var/log/falco/events.log}`<br/>• `/var/log/falco/events.log` 包含有效的 JSON 行，其中 `rule == "Terminal shell in container"` 且 `output_fields["k8s.pod.name"] == "immutable-app"`、`output_fields["k8s.ns.name"] == "runtime-112"`<br/>• 任務 2 的 Pod `falco-shell` 到這時已經被刪除(任務 6)，不在這裡使用 |

<details>
<summary>💡 任務 7 的提示</summary>

兩種不同的 override 機制很容易搞混：`macro` override 改變規則觸發的「條件」(要排除誰)，而帶有 `append` 的 `output` override 只改變「輸出的格式」(要印出什麼)- 這個任務兩者都需要，分別在獨立的區塊 `- macro: ...` 與 `- rule: ... / override: / output: append` 中。請逐字檢查 `user_expected_terminal_shell_in_container_conditions` 的拼寫 - Falco 針對不同規則有幾個名稱相似的 macro(任務中提到的 `user_shell_container_exclusions` 屬於「另一條」規則)，使用錯誤的 macro 不會產生載入錯誤，但 allowlist 就是不會運作。
</details>

---
| **8** | **取代/配合本機檔案的 Audit webhook backend** |
| :---: | :--- |
| 要做什麼 | • 使用 bootstrap 已經準備好的 HTTP 接收器 `audit-receiver`(Deployment + 埠 `8080` 上的 Service，映像 `ghcr.io/mendhak/http-https-echo:40`)，它會接收 audit 事件。<br/>• 在 `control-plane` 上建立 kubeconfig 格式的 `/etc/kubernetes/audit/webhook-config.yaml`，帶有 `server: http://<接收器的 ClusterIP>:8080/audit`(實驗中允許 HTTP；在 production 中 webhook 需要 HTTPS 與 client certificate - 參見第 32 章)。<br/>• 在 static manifest `kube-apiserver.yaml` 中加入 `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` 與 `--audit-webhook-batch-max-wait=1s`(縮短 batch 的延遲，以便在實驗中觀察)，並保留任務 4 中已經設定的 `--audit-policy-file` 與 `--audit-log-path` - webhook 是補充，而不是取代本機 file backend。<br/>• API 恢復之後，執行任何會被稽核的請求(例如 `kubectl get configmap audit-config -n runtime-112`)，並在 `audit-receiver` 的日誌中確認事件已送達。 |
| 驗收標準 | • `audit-receiver` 為 Running，帶有 Service<br/>• `webhook-config.yaml` 是有效的 kubeconfig，其 `server` 指向這個 Service<br/>• kube-apiserver 的 static manifest 包含 `--audit-webhook-config-file` 與 `--audit-webhook-batch-max-wait`，以及任務 4 中保留的 file backend 旗標<br/>• 修改之後 Kube-apiserver 健康<br/>• `audit-receiver` 的日誌在至少一個所接收 HTTP 請求的 body 中，包含 JSON 格式、帶有欄位 `objectRef` 的 audit event |

<details>
<summary>💡 任務 8 的提示</summary>

`webhook-config.yaml` 是「KUBECONFIG 格式」(帶有 `clusters`/`users`/`contexts`)，而不是帶有欄位 `server` 的任意 YAML - 如果檔案的結構不符合 kubeconfig schema,kube-apiserver 無法解析它，也根本無法啟動。別忘了，webhook 是「補充」file backend，而不是取代 - 如果你刪除了任務 4 中的旗標 `--audit-policy-file`/`--audit-log-path`，任務 4 的測試就不會再通過。
</details>

---
| **9** | **整合任務：透過 containerd 直接繞過 admission allowlist，並透過 Falco 偵測這次嘗試** |
| :---: | :--- |
| 要做什麼 | • 這個任務把 Supply Chain Security(參見 [實驗 111](../111/README_TW.MD) 與 [第 26 章](../../course/26/tw.md))與本實驗的 Runtime Security 連結起來。**與實驗 111 的重要差別**：在那裡 `ImageValidatingPolicy` 檢查的是**密碼學簽章**(Cosign)。在這裡，policy 只檢查 **registry/repository allowlist**(permitted registry，沒有 signature/attestor)- 更簡單，但同樣是真實的 admission control，原則相同：它只在 API admission 路徑上運作，看不到那些不經過它的動作。<br/>• 這個任務的 controlled abuse fixture 是 lab-owned 的本機 registry，而不是公開的 Docker Hub:bootstrap 已經在 `control-plane` 上於本機 containerd content store 中準備了三個具有不同 digest 的映像，並把它們的名稱儲存在 `/etc/cks112/registry.env`(`CKS112_REGISTRY=cks112.local:5000`、`CKS112_TRUSTED_REPO=cks112/trusted`、`CKS112_UNTRUSTED_REPO=cks112/untrusted`、`CKS112_TRUSTED_IMAGE`、`CKS112_UNTRUSTED_IMAGE`、`CKS112_PREFIX_IMAGE`)- 在任務開始時 `source` 這個檔案，並且只使用這些值。<br/>• 安裝 Kyverno(`install-kyverno`，如實驗 111 中)，並建立 `ValidatingPolicy` `require-trusted-registry-runtime-112`(native CEL,`apiVersion: policies.kyverno.io/v1`)，它透過 `image(c.image).registry()`/`.repository()`(Kyverno CEL Image library)**拒絕** `runtime-112` 中任何 image 不精確等於 `registry: $CKS112_REGISTRY` 與 `repository: $CKS112_TRUSTED_REPO` 的 Pod - 不要用 `startsWith`，以免放過像 `cks112/trusted-evil` 這樣相似的名稱。給 policy 一個唯一的 denial 訊息，例如 `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`。<br/>• 確認這條路徑：套用帶有 image `$CKS112_UNTRUSTED_IMAGE`(不在 allowlist 中)的 Pod `blocked-attempt`，並把 admission denial 的輸出儲存到 `9/admission-deny.txt`。<br/>• 然後在 `control-plane` 上透過 `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'`(映像自 bootstrap 起就已存在於本機，不需要再次 pull)，模擬不經過 API server、admission controller 也看不到的路徑(helper 會自己透過 CRI 以 detached 模式啟動；請使用唯一的 ID 以便重複檢查，然後透過 `cks112-rm <id>` 刪除容器)。<br/>• **在撰寫 Falco 規則之前，請先確定你的 containerd/Falco 堆疊上，受信任的 `$CKS112_TRUSTED_IMAGE` 其欄位 `%container.image.repository` 的真實 observed 值** - 這個欄位在不同版本中的形成方式不同(可能帶有 registry 的 hostname，也可能不帶)，因此不要事先假設格式：用帶有安全 marker 的臨時規則把這個值輸出到 log 中，並將它儲存為 `$TRUSTED_REPO`(把 evidence 儲存到 `9/observed-trusted-repo.txt`)。<br/>• 在 `falco_rules.local.yaml` 中加入自訂規則 `CKS112 Runtime Bypass of Admission`，它捕捉 `proc.cmdline` 包含 `CKS112_CTR_BYPASS` **且** `container.image.repository` 不在 allowlist 中的 spawned process，並輸出 `container.image.repository` 以及行程的識別碼。請使用與 observed 值的**精確**比較 `container.image.repository != "$TRUSTED_REPO"`(不是 `startswith`/prefix 檢查：`not container.image.repository startswith "$TRUSTED_REPO"` 會放過，也就是沒有發現像 `<observed-value>-evil` 這樣的 repository，因為它的名稱只是以允許的子字串開頭 - 這正是上面的 Kyverno policy 透過 `==` 而不是 `startsWith` 所避免的同一個錯誤)。<br/>• 另外檢查兩種受控的情況：受信任的 `$CKS112_TRUSTED_IMAGE` 不得觸發規則(只依 repository 這個條件 - marker `CKS112_CTR_BYPASS` 本身仍然可以另外檢查)，而帶有 repository `<observed-value>-evil` 的映像「必須」觸發規則 - 這正是證明比較是精確的、而不是基於 prefix 的。<br/>• 把觸發的結果儲存到 `9/falco-bypass-attempt.log`(在 `control-plane` 上取得的檔案，用 `scp` 複製到 `/var/work/tests/artifacts/9/`)。 |
| 驗收標準 | • Kyverno 已安裝且為 Available<br/>• `ValidatingPolicy require-trusted-registry-runtime-112` 存在，帶有 `apiVersion: policies.kyverno.io/v1`、validation action `Deny`，使用 `image(...).registry()`/`.repository()` 做精確(不是 `startsWith`)的比較，並且它的 `message`/`messageExpression` 包含唯一的標記 `CKS112_TRUSTED_REPO_POLICY`<br/>• Pod `blocked-attempt` 沒有建立(admission denial),`9/admission-deny.txt` 包含的正是這個標記(而不是任何一般的 admission 錯誤)<br/>• `9/observed-trusted-repo.txt` 包含受信任映像的 `%container.image.repository` 實際觀察到的值<br/>• `falco_rules.local.yaml` 包含規則 `CKS112 Runtime Bypass of Admission`，帶有針對 `container.image.repository` 的**精確**(不是 `startswith`/prefix)條件，使用的正是這個觀察到的值<br/>• `9/falco-bypass-attempt.log` 包含非空的觸發，帶有 `CKS112_CTR_BYPASS` 以及不在 allowlist 中的 image repository(在觀察到的值後加上後綴 `-evil`)- 這個 repository 是特意選作 prefix-trap 的：儘管它以允許的字串開頭，仍必須被偵測到 |

<details>
<summary>💡 任務 9 的提示</summary>

這個任務的關鍵想法：`cks112-run`(`crictl` 的包裝器，直接透過 CRI 建立容器)存取 containerd，繞過 kube-apiserver，因此也繞過「任何」admission controller(包括 Kyverno)- 這展示了 admission control 只保護經過 Kubernetes API 的路徑，而不是整個節點。你的 Falco 規則必須在同一個 `condition` 中透過 `and` 檢查：容器行程(`container.id != host` - 在主機上啟動的指令本身也包含 marker)、marker `CKS112_CTR_BYPASS`，以及不在 allowlist 中的 repository - 如果只檢查 marker，規則連對命令列相似的合法測試行程也會觸發。
</details>

---
| **10** | **透過另一類 Falco 條件偵測對 `/dev/mem` 的存取並停止 workload** |
| :---: | :--- |
| 要做什麼 | • 任務 3、7 與 9 使用的是針對 `spawned_process`/`proc.cmdline` 的條件 - 依行程啟動來偵測。這裡需要的是本質上不同類別的 Falco condition：依**開啟檔案/裝置**來偵測。<br/>• `runtime-112` 中已經有 Deployment `mem-scanner`(2 個 replica)，兩個 replica 都會定期在容器內開啟 `/dev/mem` - 一般的應用程式 workload 沒有理由這樣做，這樣的存取是危險設定或嘗試繞過容器隔離的強烈指標。容器內的路徑 `/dev/mem` 是 synthetic safe fixture(其背後的裝置實際上是主機的 `/dev/null`，而不是主機真實的實體記憶體)；這對 Falco 並不重要 - 規則偵測的是依檔名 `fd.name = /dev/mem` 的系統呼叫 `open`/`openat`/`openat2` 本身，與其背後實際是哪個裝置無關。<br/>• 在 `control-plane` 上，於 `/etc/falco/falco_rules.local.yaml` 中加入規則 `CKS112 Container access to /dev/mem`，條件為 `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host`,priority `CRITICAL`,output 必須包含 `container_id=%container.id`、`k8s_pod=%k8s.pod.name` 與 `k8s_ns=%k8s.ns.name`。重新啟動 Falco。<br/>• 在 journal 中找出觸發的事件，並透過它確定**具體的** Pod(不要依名稱猜測 - 請使用 alert 本身的 `k8s_pod`)；依具體的 alert 確定究竟是哪個 replica 產生了所記錄的事件。把 alert 行儲存到節點上，並用 `scp` 複製到 `/var/work/tests/artifacts/10/falco-devmem.log`。<br/>• 在 containment 之前，把找到的 Pod 的 JSON(`kubectl get pod <alert 中的 pod> -n runtime-112 -o json`)儲存到 `/var/work/tests/artifacts/10/detected-pod.json`。<br/>• 執行 `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0`，並把最終狀態(`kubectl get deployment mem-scanner -n runtime-112 -o json`)儲存到 `/var/work/tests/artifacts/10/scaled-down.json`。 |
| 驗收標準 | • `falco_rules.local.yaml` 包含名為 `CKS112 Container access to /dev/mem` 的規則，條件針對 `fd.name = /dev/mem`(不是針對 `proc.cmdline`/spawned_process)以及 `container.id != host`,priority `CRITICAL`<br/>• Falco 為 active<br/>• `10/detected-pod.json` 記錄了 containment 之前的真實 Pod 與 owner chain<br/>• `10/falco-devmem.log` - 來自 journal 的真實一行，帶有這條規則以及非空的 `k8s_pod`<br/>• Deployment `mem-scanner` 已縮減到 `replicas: 0`<br/>• `10/scaled-down.json` 確認 `spec.replicas == 0` |

<details>
<summary>💡 任務 10 的提示</summary>

不要把這個條件與任務 3/7/9 混淆 - 在那裡 `spawned_process`/`execve` 依命令列捕捉行程的「啟動」，而在這裡 `open`/`openat`/`openat2` 捕捉對具體檔案/裝置的「開啟」，與哪個行程做的、命令列有什麼參數無關。`container.id != host` 會排除節點本身(不在容器中)上合法的系統行程，它們可能因其他原因需要存取 `/dev/mem`。在找到 alert 之前，不要縮減 Deployment - 先透過 Falco 偵測，然後才是 containment，否則你無法證明是透過監控找到 Pod，而不是事先依名稱挑選 Pod。請先取得 Falco alert，並只從它的 `k8s_pod` 確定產生這個事件的具體 replica。
</details>

## 檢查

```bash
check_result
```

檢查包含 Init 與十個獨立的測試。它透過 SSH 檢查 Falco 與
kube-apiserver 的狀態、API 物件、CRI/`/proc` evidence、audit correlation、containment,
以及 rootfs 寫入的實際拒絕。修改
static Pod manifest 之後，不要在不必要的情況下重新啟動 kubelet:kubelet 會自己
注意到變更。如果 API 暫時無法使用，請等待 `kubectl get --raw=/readyz`。
`kube-apiserver.yaml` 的 backup 請只保存在 `/etc/kubernetes/manifests` 之外：kubelet 會讀取這個目錄中任何開頭不是點的檔案。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=112 make delete_cks_task
```
