[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 110 - gVisor RuntimeClass、Cilium WireGuard 與 Istio mTLS

## 目標

在這個 CKS 實驗中，你要組裝三個獨立的 workload 防護層：透過 `runsc` 的 sandboxed runtime
**gVisor**、Cilium WireGuard 的節點間加密，以及 Istio 的 service-to-service
mTLS。最後，你不只會看到這些設定，還要用可觀察的
結果來證明它們：gVisor 在 kernel view 上的差異、不含 HTTP marker 的 WireGuard 封包，以及
來自 mesh 內與 mesh 外 plaintext 用戶端的呼叫結果不同。

## 開始前先自我檢查

<details>
<summary>1. gVisor 的 userspace kernel 與虛擬機器的 guest kernel 有什麼本質上的差異？</summary>

gVisor(`runsc`)在 USERSPACE 中實作它自己的 Linux syscalls 子集，攔截容器的系統呼叫並自己處理，而不直接把它們傳遞給主機的核心 - 容器行程看到的是另一個「核心」(不同的 `uname -r`，某些 syscalls 的行為也不同)。Guest kernel(例如 Kata Containers)則是在輕量級 VM 內執行「完整的」Linux 核心 - 隔離更強，但帶有完整虛擬化的開銷，而 gVisor 沒有這種開銷。
</details>

<details>
<summary>2. WireGuard peer 究竟驗證的是什麼，為什麼這與 ServiceAccount 的 identity「不是」一回事？</summary>

WireGuard 透過 Cilium 為每個節點產生的密碼學金鑰，驗證叢集的「節點」(nodes) - 加密發生在 node-to-node 隧道層級。這可以保護「節點之間」的流量不被網路層級竊聽，但與該流量中具體 Pod/ServiceAccount 的 identity 無關 - Cilium WireGuard 不會檢查在應用程式層級「是誰」傳送的，只檢查「是哪個節點」。
</details>

<details>
<summary>3. 為什麼 mesh 內狀態碼 200 的成功 `curl`，並不能證明 plaintext client 確實被阻擋了？</summary>

在 mesh「內」的成功回應，只證明兩個 sidecar 之間的 mTLS 連線在運作 - 這是 positive control。要證明 STRICT 確實阻擋了「非 mesh」的流量，需要單獨的 negative control：沒有 sidecar 的用戶端，嘗試存取同一個服務並被拒絕。單單一個成功的測試是不夠的 - 兩者都需要：對 mesh identity 是 allowed，對 plaintext 是 denied。
</details>

## 與課程的關聯

- [第 22 章 Container Runtime Sandbox](../../course/22/tw.md)
- [第 23 章 Pod-to-Pod 加密與 mTLS](../../course/23/tw.md)

## 基礎架構

Terragrunt 在 `eu-central-1` 建立 Kubernetes `1.36.0`:

| 元件 | 用途 |
|---|---|
| `k8s-1` control-plane | 一般的 containerd workload node、Cilium，以及用於擷取節點間封包的 `tcpdump` |
| `k8s-1` worker `gvisor` | 單獨的節點，帶有 containerd、已安裝的 `runsc` 以及 CRI handler `runsc` |
| CNI | **Cilium**(透過 Cilium CLI 安裝，Helm release 為 `cilium`);WireGuard 在任務 4 之前刻意關閉 |
| `worker` | 具備 `kubectl`、`cilium`、`istioctl`、`check_result` 以及通往各節點的 SSH aliases 的工作機 |

2026-08-31 驗證過的矩陣(每次建置之前請再核對)：lab 中的 Kubernetes
`1.36.0`;Cilium data plane - 受支援的 lab 版本，它與
Kubernetes `1.36` 的相容性需要依據最新的 requirements matrix 確認；Cilium CLI `0.19.7`
(與 Cilium `1.17+` 相容);Istio `1.30.4`(分支 `1.30` 官方支援 Kubernetes
`1.32–1.36`)。考試的版本在這裡並不決定 lab 工具的相容性；依據 LF 的資料，
目前是 `v1.34`，並在考試之前另行確認。

bootstrap 之後有兩個 workload placement label 可用：

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Control-plane 可以讓一般的 Pod 在沒有 tolerations 的情況下使用。gVisor 節點另外被標上 taint
`sandbox.runtime/gvisor=true:NoSchedule`：只有能容忍這個 taint 的 Pod 才會被排程到它上面
(帶有 `RuntimeClass gvisor` 的 Pod 會從該 class 的 `scheduling.tolerations` 取得需要的 toleration)。

Namespaces `sandbox-110` 與 `market` 已經存在。`market` 事先設定了
label `istio-injection=enabled`;Istio control plane 沒有安裝。要從 worker 存取
sandbox 節點，請使用 alias `k8s110_node_gvisor`，存取 control-plane 則使用
`k8s110_controlPlane_1`。

## 部署

```bash
TASK=110 make run_cks_task
```

連線到工作機並選擇現成的 context:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

在開始之前，建立證明用的目錄：

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 任務

---
| **1** | **設定 containerd runtime 並為 runsc 建立 RuntimeClass** |
| :---: | :--- |
| 要做什麼 | • 在 `k8s110_node_gvisor` 上，二進位檔 `runsc` 已經安裝，但 bootstrap 刻意從 `/etc/containerd/config.toml` 中移除了帶有 `runtime_type = "io.containerd.runsc.v1"` 的區段 `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` - 這是考試中典型的 config.toml 損壞的情況。<br/>• 把這個區段還原(備份位於 `/etc/containerd/config.toml.bak`，或手動補寫)，並執行 `sudo systemctl restart containerd`。<br/>• 建立 `RuntimeClass` `gvisor`，帶有精確的 `handler: runsc`。<br/>• 在 `scheduling` 中設定 `nodeSelector` `sandbox.runtime/gvisor: "true"`，讓帶有這個 class 的 Pod 永遠不會被排程到一般節點上，並為 gVisor 節點的 taint(`sandbox.runtime/gvisor=true:NoSchedule`)設定 `tolerations`，否則 Pod 無法到達那裡。 |
| 驗收標準 | • 節點上 `containerd` 為 active，且 `config.toml` 包含有效的區段 `runtimes.runsc`，帶有 `runtime_type = "io.containerd.runsc.v1"`<br/>• `kubectl get runtimeclass gvisor` 存在，handler 等於 `runsc`,`scheduling` 中有 `nodeSelector`，以及針對 gVisor 節點 taint 的 `tolerations`<br/>• `/var/work/tests/artifacts/1/runsc-runtime.txt` 中有精確的一行 `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 任務 1 的提示</summary>

備份 `/etc/containerd/config.toml.bak` 是最快的恢復途徑，但在複製回去之前請先檢查它的內容(與目前的檔案做 `diff`)，以了解究竟缺少了什麼。還原區段 `runtimes.runsc` 之後，務必 `systemctl restart containerd` - 單純編輯檔案並不會把變更套用到正在執行的行程。
</details>

---
| **2** | **在 gVisor sandbox 中的 Pod** |
| :---: | :--- |
| 要做什麼 | • 在 `sandbox-110` 中建立 Pod `gvisor-sandbox`，帶有 `runtimeClassName: gvisor`、容器 `app` 與映像 `busybox:1.36`。<br/>• 在 Pod 中明確指定 `nodeSelector` `sandbox.runtime/gvisor: "true"` 與針對 gVisor 節點 taint 的 `tolerations`(與 RuntimeClass 的 `scheduling` 相同；沒有它們，Kubernetes 會自己從 RuntimeClass 加入，但在 manifest 中看不出來)。<br/>• 在容器中啟動監聽 `8080` 的 HTTP server，回傳字串 `CKS110-WIREGUARD-MARKER`。<br/>• 在 `8080` 上建立 Service `gvisor-echo`，選取這個 Pod。<br/>• 停用 ServiceAccount token 的 automount。<br/>• 把 Pod 中 `uname -r` 與 `dmesg` 的輸出記錄到 artifact:gVisor sandbox 內的 `dmesg` 以 `Starting gVisor...` 這一行開頭，而不是節點真實的核心 log - 這是隔離的直接證明，獨立於 `uname -r` 的差異之外。 |
| 驗收標準 | • Pod 在帶有 `sandbox.runtime/gvisor=true` 的節點上為 `Running`,Service 選取了它，而 `/var/work/tests/artifacts/2/gvisor-kernel.txt` 包含一行 `gvisor uname -r: <實際的值>` 以及來自 `dmesg` 輸出的一行 `Starting gVisor` |

<details>
<summary>💡 任務 2 的提示</summary>

如果 Pod 無法啟動(卡在 `ContainerCreating`，並帶有事件 `FailedCreatePodSandBox`，例如 `no runtime for "runsc" is configured`)，很可能是任務 1 沒有完全完成 - RuntimeClass 必須確實指向正在運作的 containerd handler。所使用的 `busybox:1.36` 中有 applet `httpd` - 請使用 `httpd -f -p 8080 -h /www` 做最小的 HTTP server(可以透過 `busybox --list | grep '^httpd$'` 檢查 applet 是否存在)。
</details>

---
| **3** | **與一般 runc Pod 比較** |
| :---: | :--- |
| 要做什麼 | • 在 `sandbox-110` 中建立 `runc-baseline`:`busybox:1.36`、容器 `app`、`sleep 3600`。<br/>• 沒有 `runtimeClassName`，帶有 nodeSelector `lab.cks.io/role: control-plane`，並且沒有 SA token。<br/>• 把它的 `uname -r` 與 gVisor Pod 的 `uname -r` 進行比較，並把兩個結果儲存到 `/var/work/tests/artifacts/3/runtime-comparison.txt`。 |
| 驗收標準 | • Baseline Pod 在 control-plane 上為 `Running`，沒有 `runtimeClassName`<br/>• 它的 release 與 gVisor 的 release 不同<br/>• artifact 中有 `gvisor uname -r:` 與 `runc uname -r:` 兩行，帶有實際的值 |

<details>
<summary>💡 任務 3 的提示</summary>

這個 Pod 是刻意透過 nodeSelector `lab.cks.io/role: control-plane` 放在「另一個」節點(control-plane，不是 gvisor 節點)上的 - 這不只是「任何一個一般的 Pod」，而是與已知放置位置的受控比較。如果兩個 Pod 的 `uname -r` 恰好相同 - 請檢查 `gvisor-sandbox` 是否確實使用了 `runtimeClassName: gvisor`。
</details>

---
| **4** | **啟用 Cilium transparent encryption** |
| :---: | :--- |
| 要做什麼 | • 首先把 Kubernetes、Cilium agent 與 Cilium CLI 的版本記錄到 `/var/work/tests/artifacts/4/tool-versions.txt`，並確認 data plane 支援 Kubernetes `1.36`。<br/>• 在由 `cilium install` 建立的既有 Helm release 中啟用 WireGuard:`cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`。<br/>• 重新啟動 agents(`kubectl -n kube-system rollout restart daemonset/cilium`):Helm 只更改 ConfigMap，而 DaemonSet 的 template 保持不變。<br/>• 檢查 `cilium-config`(`enable-wireguard: "true"`)以及兩個 Cilium agents 是否就緒。<br/>• 直接 patch ConfigMap 只允許作為短暫的學習用 baseline 探測，並且必須有經過確認的 rollback。不要尋找指令 `cilium encrypt enable`：用戶端 `cilium` CLI 沒有這個子指令。<br/>• 把 agent 端的 `cilium-dbg encrypt status` 與 `cilium-dbg debuginfo --output json` 儲存到 `/var/work/tests/artifacts/4/cilium-encrypt-status.txt`(`cilium-dbg status` 沒有旗標 `--all-encryption`)。 |
| 驗收標準 | • 版本 evidence 存在，並與 DaemonSet `kube-system/cilium` 的實際映像相符<br/>• Cilium agents(DaemonSet)完全 Ready<br/>• Status 顯示 WireGuard，並且沒有同時顯示 IPsec<br/>• Debuginfo JSON 包含節點間狀態的 peer/allowed-IP(或 remote-node)evidence<br/>• ConfigMap `kube-system/cilium-config` 包含 `enable-wireguard: "true"`，作為來自 Helm values 的已套用 effective 設定<br/>• 設定能撐過重新啟動一個 agent Pod(checker 會重新啟動 Pod 並再次檢查 status) |

<details>
<summary>💡 任務 4 的提示</summary>

請把既有 release `cilium` 的 Helm values 作為啟用 WireGuard 的長期 source-of-truth，而不是暫時性的指令 - 在 Helm values 之外的修改可能撐不過 agent 的重新啟動或 Helm release 的更新，而測試專門檢查設定是否撐得過重新啟動。`cilium-dbg` 是透過 `kubectl exec` 在 agent Pod「內部」呼叫的，而不是 worker 上單獨的本機二進位檔。`cilium-dbg status` 「沒有」旗標 `--all-encryption` - 若要取得詳細的 peer/allowed-IP evidence，請使用 `cilium-dbg debuginfo --output json`。
</details>

---
| **5** | **證明節點之間沒有 plaintext** |
| :---: | :--- |
| 要做什麼 | • 針對同一個節點間 flow，建立之前/之後的 baseline 證明。<br/>• **Baseline(WireGuard 關閉)**：在 control-plane 上針對遠端節點的 IP 執行 `tcpdump`(`host <remote-node-ip>`，不事先以 `udp port 51871` 過濾)；暫時停用 WireGuard(在 `cilium-config` 中設為 `enable-wireguard: "false"`,`rollout restart daemonset/cilium`)；執行請求 `runc-baseline -> gvisor-echo`；儲存這個 baseline-capture，並確認其中可以看到 plaintext `CKS110-WIREGUARD-MARKER`。<br/>• **之後(WireGuard 啟用)**：恢復 `enable-wireguard: "true"`，等待 Ready，並以「相同的」擷取範圍(`host <remote-node-ip>`，不帶埠過濾)重複「同一個」請求。<br/>• Capture 在 control-plane 上擷取(寫入節點上的檔案)，然後用 `scp` 複製到工作機的 `/var/work/tests/artifacts/5/wireguard-tcpdump.txt`：其中現在應該只能看到 WireGuard UDP/`51871`，沒有 plaintext marker。 |
| 驗收標準 | • 針對相同 peer/interface 範圍的最終(變更之後)capture 包含 UDP/`51871`，但**不**包含 `CKS110-WIREGUARD-MARKER`<br/>• 不同節點之間的呼叫在 HTTP 回應中成功取得 marker<br/>• Checker 會自己針對相同的 peer/interface 範圍重複變更之後的 capture(並不事先只限於 `udp port 51871`)，同時自己暫時停用並恢復 WireGuard，以取得它自己的 baseline 確認，證明同一個 flow 在 plaintext 狀態下確實在 wire 上暴露了 marker |

<details>
<summary>💡 任務 5 的提示</summary>

請在節點「真正的」實體網路介面(例如 `eth0`)上擷取流量，而不是在 Pod 的虛擬介面/veth 或 Cilium 內部介面 `cilium_wg0` 上 - 依 WireGuard 隧道的設計，`cilium_wg0` 承載的是「已經解密的」流量(這正是它的用途)，因此即使實體 NIC 上的加密運作正常，在 `any` 上擷取也會在那裡看到 marker。請透過 `ip route get <remote-node-ip>` 找出具體的實體介面，並務必使用這個介面。如果 capture 發生在 WireGuard 加密之前的 Pod 路徑「內部」，無論 node-to-node 加密是否啟用，你都會看到 plaintext HTTP。請在執行 HTTP 請求「之前」於背景啟動 `tcpdump`，而不是之後。「只」依 `udp port 51871` 的擷取過濾，會事先把 plaintext TCP 從結果中排除，因此「無法」證明它不存在 - 請使用不帶埠過濾的 `host <remote-node-ip>`，讓同一個範圍能夠真正顯示啟用 WireGuard 之前/之後的差異。Checker 會在發出自己請求的同時，執行它自己的 `tcpdump`(包括暫時停用 WireGuard、之後經過驗證地恢復的 baseline 探測) - 你的 artifact 在學習上有用，但不是唯一的證明：如果在檢查時加密確實沒有運作，checker 的即時 capture 會獨立於你的檔案內容而發現這一點。
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| 要做什麼 | • 用準備好的 `istioctl` 安裝固定版本的 Istio `1.30.4`(minimal profile 就足夠)，並記錄 control plane 的版本。<br/>• 在 `market` 中建立 `market-api` Deployment 與 Service `market-api`：應用程式監聽 `8080`,service port 命名為 `http`。`market-api` 必須執行在 gVisor 節點上：`nodeSelector` `lab.cks.io/role: gvisor` 以及針對它的 taint 的 toleration(`sandbox.runtime/gvisor=true:NoSchedule`)。<br/>• 在 `market` 中建立注入了 sidecar 的 Deployment `market-client`，並在 `default` 中建立 plaintext Pod `mesh-outside`；這三個 workload 都必須是 Running - **沒有** `PeerAuthentication` STRICT。<br/>• **Baseline**：同一個來自外部的 plaintext 請求打到 `market-api` 必須得到 HTTP 200(還不需要 mTLS)；單獨儲存這個 baseline 回應。<br/>• 套用 namespace `market` 的 `PeerAuthentication` `market-strict`，帶有 `mtls.mode: STRICT`，並重複「同一個」外部請求：沒有 sidecar 的 plaintext client 不得取得成功的 application 回應，而 in-mesh 的請求必須得到 HTTP 200。<br/>• 把 status/headers/exit code 儲存到 `artifacts/6/market-inside.txt` 與 `market-outside.txt`(在兩個檔案結尾都補寫一行 `exit_code=<curl 的結束代碼>`)；不要比對具體的 socket error 字串。 |
| 驗收標準 | • Namespace 保持 `istio-injection=enabled`<br/>• `PeerAuthentication market-strict` 具有 `STRICT`<br/>• 在 mesh 內有 HTTP 200，而 mesh 外的 plaintext 呼叫沒有取得成功的 HTTP 回應(curl 失敗，沒有 2xx，檔案中的 `exit_code` 非零) - 與具體的錯誤文字無關<br/>• 兩個證明都已儲存，`market-inside.txt` 包含 `exit_code=0`<br/>• 不要用 sidecar 取代 plaintext client：正是因為沒有 sidecar，才能證明 STRICT 的拒絕。<br/>• Checker 還會自己重複之前/之後：暫時把同一個 policy 切換到 `PERMISSIVE`，重複同一個 plaintext 請求並要求 200 - 這證明先前的拒絕正是由 STRICT mTLS 造成的，而不是獨立的 DNS/網路問題<br/>• 然後 checker 會恢復 `STRICT` |

<details>
<summary>💡 任務 6 的提示</summary>

Service port「必須」正好命名為 `http`(不是 `market-api` 或其他名稱) - Istio 使用 named port 的慣例來判斷協定，並透過 sidecar 正確處理流量。`market-client` 是在 namespace 取得 `istio-injection=enabled` 「之後」才建立的 - 如果 Deployment 是在這個 label 「之前」建立的，sidecar 不會被自動加入，你需要重新建立 Pod(不是 Deployment)才能注入。
</details>

## 檢查

```bash
check_result
```

檢查包含 `0 Init` 與六個必要的測試。測試 1-3 檢查
`RuntimeClass`、placement 以及 `uname` 的真實差異；測試 4-5 檢查 WireGuard
status、節點間的請求，以及 tcpdump 中沒有 marker；測試 6 會重新執行兩個
mTLS 呼叫並檢查 artifacts。如果 Istio Pods 仍在建立中，請等待
`kubectl get pods -n market` 顯示注入了 sidecar 的 workload 為 `2/2 Running`。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=110 make delete_cks_task
```
