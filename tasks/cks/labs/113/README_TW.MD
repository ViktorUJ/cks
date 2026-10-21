[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 113 - 透過 kubeadm 升級 Kubernetes 叢集(minor upgrade)

## 目標

在這個 CKS 實驗中，你要透過 `kubeadm` 對自行管理的叢集親自執行真正的 minor-upgrade:
先 control-plane，再 worker 節點，依正確的順序進行，
且不讓已在執行的 workload 發生計畫外的 downtime。叢集一開始是
Kubernetes `1.35.x`；你的任務是把兩個節點都升級到 `1.36.x`，遵守
官方的 `kubeadm upgrade` 程序，並把套件 repository
`pkgs.k8s.io` 切換到新的 minor。

## 開始前先自我檢查

<details>
<summary>1. 為什麼 `kubeadm upgrade` 要求「嚴格地」在 worker 節點之前先升級 control-plane，而不是任意順序？</summary>

control-plane 上的 `kubeadm upgrade apply` 會更新 API server 與其他 control-plane 元件的版本；叢集的 version skew policy 就是以這個版本為基準來計算的。相對於 API server 而言 kubelet 太新的 worker 節點，可能違反所支援的 skew(kubelet 不得比 kube-apiserver 更新)。先升級 control-plane，可以保證當 worker 升級到同一個版本時，API server 已經是目標版本 - 這不是任意的建議，而是 Kubernetes version skew policy 的要求。
</details>

<details>
<summary>2. 為什麼在升級到新的 minor 時必須切換 apt repository `pkgs.k8s.io`，而 patch 升級卻不需要？</summary>

自從從 `packages.cloud.google.com`/`apt.kubernetes.io` 遷移之後，`pkgs.k8s.io` 是以**每個 minor 版本一個獨立的 repository**(`core:/stable:/v1.35`、`core:/stable:/v1.36` 等)的方式組織的，而不是包含所有版本的單一 repository。在已經接上的 repo `v1.35` 內，只有 `1.35.x` 的 patch 版本可用。要讓 `apt install kubeadm=1.36.x-*` 看得到 `1.36` 的版本，必須先在 `sources.list.d/kubernetes.list` 中加入 `core:/stable:/v1.36` 這個 repo(只有 URL 中的版本會改變；包含簽章金鑰 `Release.key` 的 keyring 保持不變)。
</details>

<details>
<summary>3. 為什麼在叢集升級之前做 `kubectl drain` 不只是「好習慣」，而是針對什麼具體情況的防護？</summary>

control-plane 上的 `kubeadm upgrade` 會重新建立各元件(kube-apiserver、controller-manager、scheduler)的 static Pod manifests，而在任何節點上升級 kubelet 都需要重新啟動它 - 在那一刻，節點會暫時失去正確回報 Pod 狀態與接受新 Pod 的能力。`drain` 會事先把一般的 workload Pod 遷移到其他節點(或把它們標記為 evicted)，讓這種節點暫時的失效不會演變成應用程式的 downtime。沒有 `drain`，正在升級的節點上的 Pod 在 restart 期間可能無法使用，而沒有移到其他節點上作為補償。
</details>

## 與課程的關聯

- [第 13 章。為消除弱點而更新 Kubernetes](../../course/13/tw.md)

## 基礎架構

Terragrunt 在 `eu-central-1` 建立 self-managed 的 Kubernetes `1.35.4`、containerd、
Calico CNI:

| 元件 | 用途 |
|---|---|
| `k8s-1` control-plane | 一般的 control-plane 節點，允許一般的 Pod(single control-plane，沒有專用的第二個 control-plane 節點) |
| `k8s-1` worker `worker1` | 位於相同起始版本的一般 worker 節點 |
| `worker` | 具備 `kubectl`、`check_result`，並可 SSH 存取叢集兩個節點的工作機 |

升級的目標版本是 `1.36.x`(實驗當時最新可用的 patch)，也就是說
任務完成之後，叢集將處於與其餘核心實驗 101-112 相同的 training baseline 版本。
kubeadm 不支援跳過 minor 版本(例如直接從 `1.35` → `1.37`)-
本實驗也不需要這樣的跳躍。

要存取節點，請使用別名 `k8s113_controlPlane_1` 與 `k8s113_node_worker1`。

Namespace `upgrade-113` 以及 Deployment `canary`(2 個 replica)已經部署 - 這是你用來
確認沒有 downtime 的指標。在整個升級過程中，至少要有一個 replica 保持 `Available`;
每個節點 `uncordon` 之後以及最後，Deployment 必須
恢復到 `2/2`。Bootstrap 事先把兩個 replica 分散到不同的
nodes(required `podAntiAffinity`)，並建立帶有 `minAvailable: 1` 的 `PodDisruptionBudget`。

## 部署

```bash
TASK=113 make run_cks_task
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
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## 任務

---
| **1** | **把 control-plane 升級到目標 minor** |
| :---: | :--- |
| 要做什麼 | • 登入 `k8s113_controlPlane_1`(`ssh`，然後 `sudo -i`)。<br/>• 把 apt repository `pkgs.k8s.io` 從 `core:/stable:/v1.35` 切換到 `core:/stable:/v1.36`：在 `/etc/apt/sources.list.d/kubernetes.list` 中只更改 URL 中的版本(Kubernetes 文件中是這樣描述的，keyring 不變)。<br/>• 把套件 `kubeadm` 升級到 `1.36.x`，執行 `kubeadm upgrade plan`，然後 `kubeadm upgrade apply v1.36.x`。<br/>• 只有在 `apply` 成功之後，才對這個節點執行 `kubectl drain`。<br/>• 把套件 `kubelet`/`kubectl` 升級到 `1.36.x`，重新啟動 `kubelet`，然後執行 `kubectl uncordon`。 |
| 驗收標準 | • control-plane 上的 `kubeadm version`、`kubelet --version`、本機的 `kubectl version --client` 以及 API server 的版本(`kubectl version`)都回報 `v1.36.x`。<br/>• control-plane 節點(`kubectl get no` 中的 `<cp-名稱>`)的狀態為 `Ready`。<br/>• 指令 `kubeadm upgrade apply` 的完整輸出(帶有 `SUCCESS` 一行以及目標版本)被逐字儲存到工作機上的 `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt`(指令在節點上執行，輸出寫入節點上的檔案，然後用 `scp` 複製)。 |

<details>
<summary>💡 任務 1 的提示</summary>

順序至關重要：先 `apt-mark unhold kubeadm` → 升級套件 → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`，並且只有在 `apply` 成功「之後」- 才進行 `drain` 以及 `kubelet`/`kubectl` 的升級。在呼叫 `kubeadm upgrade apply` 之前不需要升級 `kubelet`，官方程序也不建議這樣做。請把 `kubeadm upgrade apply` 的輸出儲存到節點上的檔案(`> /tmp/kubeadm-upgrade-apply.txt 2>&1`)，而不是事後憑記憶重建 - 測試尋找的是帶有單字 `SUCCESS` 的逐字文字。
</details>

---
| **2** | **把 worker 節點升級到目標 minor** |
| :---: | :--- |
| 要做什麼 | • 在 `k8s113_node_worker1` 上(`ssh`、`sudo -i`)，以同樣的方式把 `pkgs.k8s.io` 切換到 `core:/stable:/v1.36`，並升級 `kubeadm`。<br/>• 執行 `kubeadm upgrade node`(不是 `apply` - 那是只用於 control-plane 的指令)。<br/>• 對這個節點執行 `kubectl drain`(從工作機執行，而不是在節點本身上)。<br/>• 升級 `kubelet`/`kubectl`，重新啟動 `kubelet`，執行 `kubectl uncordon`。 |
| 驗收標準 | • worker 節點上的 `kubeadm version`、`kubelet --version` 與本機的 `kubectl version --client` 都回報 `v1.36.x`。<br/>• `kubectl get nodes` 對 worker 節點在 `kubeletVersion` 中顯示 `v1.36.x`，且狀態為 `Ready`。<br/>• `kubeadm upgrade node` 的輸出被儲存到節點上的檔案，並用 `scp` 複製到工作機上的 `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt`。 |

<details>
<summary>💡 任務 2 的提示</summary>

`kubeadm upgrade node` 正是用於 worker 節點(以及額外的 control-plane 節點)的指令，`kubeadm upgrade apply` 只用於「第一個」/唯一的 control-plane 節點。請只在任務 1 完全完成、control-plane 已經在 `1.36.x` 上為 `Ready` 之後，才開始這個任務 - 否則你會違反 version skew policy。
</details>

---
| **3** | **遵守正確的升級順序** |
| :---: | :--- |
| 要做什麼 | • 在開始 worker 節點的升級(任務 2)「之前」，先完整執行 control-plane 的升級(任務 1)，包括 uncordon。<br/>• 這個任務在叢集中不需要單獨的動作：順序由 checker-owned 的叢集狀態與版本監控器自動檢查。 |
| 驗收標準 | • Checker-owned monitor 記錄了初始的 `1.35.x` baseline。<br/>• 然後記錄到 control-plane 完全轉換到 `1.36.x`(包括 `Ready` 與 schedulable)，而 worker 仍在 `1.35.x`，只有在這之後才開始 worker 節點的升級。<br/>• 狀態能撐過監控器的重新啟動；缺少 baseline 或觀察中斷超過 60 秒不予計分。 |

<details>
<summary>💡 任務 3 的提示</summary>

如果你已經開始(更不用說已經完成)了 worker 節點在 control-plane 之前的升級 - 請停下來 - 透過重新下載 `1.35.x` 套件把 worker 回退，無法用簡單的方式做到；正確的做法是完成 control-plane 的升級，然後繼續/重做 worker 節點的升級。關鍵是 - worker 節點的下一次升級(無論何時開始)必須發生在 control-plane 升級完全完成「之後」。在 `kubectl get node <cp-名稱>` 顯示 `v1.36.x` 與 `Ready` 之前，不要開始任務 2。
</details>

---
| **4** | **證明既有 workload 沒有 downtime** |
| :---: | :--- |
| 要做什麼 | • 在你執行任務 1-2 的同時，在工作機上另開一個工作階段，啟動一個迴圈，每隔幾秒輪詢 namespace `upgrade-113` 中 Deployment `canary` 的可用性。<br/>• 把每一行輪詢結果追加寫入 `/var/work/tests/artifacts/4/canary-availability.log`，格式中包含 `available=N`(例如 `available=2`)。<br/>• 在兩個節點整個升級期間持續輪詢。 |
| 驗收標準 | • Deployment `canary` 最終有 `2/2` 個可用 replica，初始的 Deployment/PDB 與 required Pod anti-affinity 被保留。<br/>• 是否沒有 downtime，由 checker-owned monitor 僅依據來自 `upgrade-113` 的 Pod Ready 與 CRI 容器來檢查；API/SSH/CRI 的錯誤被視為 UNKNOWN，而不是零。<br/>• 學員檔案 `/var/work/tests/artifacts/4/canary-availability.log` 至少包含兩行格式為 `<unix_timestamp> available=N` 或 `<unix_timestamp> available=api-unreachable` 的記錄，其中有 control-plane 升級之前以及 worker 升級開始之後的觀察。 |

<details>
<summary>💡 任務 4 的提示</summary>

輪詢迴圈的範例，可以在單獨的終端機/`screen`/`tmux` 中，在執行任務 1-2 的整個期間讓它持續運作：`while true; do if available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`。如果 Deployment 短時間內失去了所有 replica - 請檢查 `kubectl get pods -n upgrade-113 -o wide`，以及連續的 drain 是否遵守了 PDB 與 required anti-affinity。
</details>

## 檢查

```bash
check_result
```

檢查包含 `0 Init` 與五個必要的測試。測試 1-2 分別檢查 control-plane 與 worker 節點上
`kubeadm`/`kubelet`/本機 `kubectl` 的版本與 `Ready` 狀態，
以及帶有 `kubeadm upgrade` 輸出的逐字 evidence 檔案。測試 3
依 checker-owned 的叢集狀態監控器檢查升級的順序，而不是依
檔案的修改時間。測試 4 檢查 workload `canary` 沒有停機，
並以同一個 checker-owned monitor 作為真相來源。測試 5 是最終
檢查，確認兩個節點確實都在目標版本，而且沒有被留在
`cordon` 狀態。

## 解答

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=113 make delete_cks_task
```
