[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 114 - Troubleshooting:修復損壞的資源

## 說明

Troubleshooting 領域(佔 CKA 30%)的實作練習。叢集中已經預先部署了
**損壞的**物件 - 你的任務是找出並排除原因,並套用一條系統化的
除錯路線:`get` → `describe`(Events)→ `logs` → 修復。任務模擬了
典型的事故:ImagePullBackOff、因 selector 錯誤造成的空 Endpoints,以及
因缺少 ConfigMap 造成的 CreateContainerConfigError。

所有任務都以考試風格撰寫(就像真正的 CKA/CKAD 題目),並透過
`check_result` 指令自動驗證。

## 目標

鞏固以下課程章節的內容:

- [第 44 章。除錯應用程式故障](../../course/44/README.md) - `get` → `describe` → `logs` 路線、解讀 Pods 狀態
- [第 45 章。除錯 control plane 與 worker 節點](../../course/45/README.md) - 診斷節點與系統元件
- [第 46 章。除錯服務與網路](../../course/46/README.md) - Service ↔ Endpoints ↔ 標籤的串接

## 我們要修復什麼,以及為什麼

在這個實驗中,我們要修復三個彼此獨立的事故:壞掉的映像、Service 與 Pods 之間
斷掉的連結,以及缺少的設定。每一種故障都對應除錯路線上的
不同環節:

| 故障 | 症狀 | 原因 | 學到什麼 |
|---------|---------|---------|-----------|
| **ReplicaSet `rs-app2223`**(namespace `rsapp`) | ImagePullBackOff | 映像 tag 錯誤 | 分析映像問題並重建 RS 的 Pods(第 44 章) |
| **Service `svc-broken`**(namespace `tsvc`) | 空的 Endpoints | selector 與 Pods 的 label 不相符 | Service ↔ Endpoints ↔ 標籤的串接(第 46 章) |
| **Deployment `capp`**(namespace `cfgapp`) | CreateContainerConfigError | 缺少所需的 ConfigMap | 設定依賴關係(第 44 章) |

最終部署出來的整體樣貌:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints 為空"] -->|"fix selector"| b2["Endpoints 已填入"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## 基礎架構

環境透過 Terragrunt 部署在 AWS(`eu-central-1`),由以下部分組成:

| 元件       | 說明                                                                 |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16`,含公有子網路                                       |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                                                |
| `k8s-1`    | Kubernetes `1.35.2`(kubeadm),CNI Calico,metrics-server,單節點;啟動時會部署那些損壞的物件 |
| `worker`   | 工作機,具備 `kubectl` 與 `check_result`                               |

執行個體:`t3.medium`(master),Ubuntu `22.04`。叢集為單節點 - master
已解除污點(移除了 `control-plane` taint),因此 Pod 會直接排程到它上面。

## 部署

```bash
TASK=114 make run_cka_task
```

建立完成後,請透過 SSH 連線到工作機(worker),並在那裡完成任務。
`kubectl` 已經指向 `cluster1-admin@cluster1` context。

工作機上的實用指令:

```bash
time_left       # 還剩多少時間
check_result    # 檢查解答
```

## 任務

---
|        **1**        | **修復 ReplicaSet**                                          |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `rsapp` 中,ReplicaSet `rs-app2223` 的 Pods 卡在 `ImagePullBackOff`。請走一遍這條路線:`kubectl get po -n rsapp`(看到狀態)、`kubectl describe po -n rsapp <pod>`(在 Events 中 - 映像 `viktoruj/ping_pong:doesnotexist123` 無法拉取)。透過 `kubectl edit rs rs-app2223 -n rsapp` 把 RS 範本中的映像改成可用的(`viktoruj/ping_pong:latest`)。RS 在範本變更時不會重建 Pods - 請刪除舊的 Pods(`kubectl delete po -n rsapp -l <label>`),讓 RS 拉起新的。達成 `2` 個就緒副本。 |
| 驗收標準            | - ReplicaSet `rs-app2223`(namespace `rsapp`):`2` 個 Ready 副本。 |
---
|        **2**        | **修復 Service(空的 Endpoints)**                             |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | namespace `tsvc` 中的 Service `svc-broken` 無法轉發流量 - 它的 Endpoints 是空的。診斷:`kubectl get endpoints svc-broken -n tsvc`(空的)、`kubectl describe svc svc-broken -n tsvc`(selector,例如 `app=WRONG`)、`kubectl get pods -n tsvc --show-labels`(Pods 帶有 label `app=web`)。把 Service 的 selector 對齊 Pods 實際的 label(`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`),並確認 Endpoints 已經填入。 |
| 驗收標準            | - Service `svc-broken`(namespace `tsvc`):Endpoints 不為空(≥ 1 個位址)。 |
---
|        **3**        | **修復 Deployment(缺少 ConfigMap)**                          |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | namespace `cfgapp` 中的 Deployment `capp` 以 `CreateContainerConfigError` 失敗。路線:`kubectl get po -n cfgapp`(看到狀態)、`kubectl describe po -n cfgapp <pod>`(在 Events 中 - 找不到 ConfigMap `missing-config`)。建立缺少的 ConfigMap(`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`),並等到該 Deployment 變成就緒(`kubectl rollout status deploy capp -n cfgapp`)。 |
| 驗收標準            | - Deployment `capp`(namespace `cfgapp`):≥ 1 個 Ready 副本。 |
---

## 檢查結果

在工作機上執行自動檢查:

```bash
check_result
```

腳本會跑完測試,並顯示已完成多少任務。

## 解答

參考解答:[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)

## 模擬考涵蓋範圍

本實驗涵蓋模擬考中 troubleshooting 相關的題目:CKAD mock 01(第 4 題 - fix ReplicaSet);
來自 CKA mock 01/02 的通用 troubleshooting 技能(解讀狀態、Endpoints、
設定),以及 CKAD mock 02(第 7/第 8 題 - fix ingress/netpol)。

## 刪除叢集與資源

```bash
TASK=114 make delete_cka_task
```
