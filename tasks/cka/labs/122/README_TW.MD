[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 122 - 速練:Pod 排程

## 說明

Workloads & Scheduling 領域的速度訓練:一系列簡短且彼此獨立的任務,涵蓋
nodeSelector、nodeAffinity、requests/limits、PriorityClass 以及 taints/tolerations。
叢集為單節點 - label(標籤)與 taint 都掛在唯一的那個節點上。

任務以考試風格撰寫,並透過 `check_result` 指令自動驗證。速練的目的
不是鑽研理論,而是速度與肌肉記憶:把管理 Pod 排程的手感「練熟」,
並跟上考試的節奏。

> **重要:**任務 6(taint)請放到最後做 - `NoSchedule` taint 會讓沒有
> toleration 的 Pod 無法排程。

## 目標

鞏固以下課程章節的內容:

- [第 12 章。Pod 排程:nodeName、nodeSelector、affinity](../../course/12/README.md) - 透過 nodeSelector 與 nodeAffinity 把 Pod 綁定到節點
- [第 13 章。Taints 與 tolerations](../../course/13/README.md) - 用 taints 排斥 Pod,再用 tolerations 放行
- [第 14 章。資源:requests、limits、LimitRange、ResourceQuota](../../course/14/README.md) - 每個容器的 CPU/記憶體 requests 與 limits
- [第 15 章。Static Pods、PriorityClass、多個排程器](../../course/15/README.md) - 透過 PriorityClass 設定 Pod 優先權

## 我們要做什麼,以及為什麼

| 區塊 | 任務 | 技能 |
|------|--------|-------|
| **綁定到節點** | label `disk=ssd`、Pod `sel`(nodeSelector)、Pod `aff`(nodeAffinity) | 把 Pod 導向需要的節點(第 12 章) |
| **資源與優先權** | Pod `res`(requests/limits)、PriorityClass `high-prio` + Pod `prio` | requests/limits 與排程優先權(第 14、15 章) |
| **Taints 與 tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | 用 taint 隔離節點,再用 toleration 放行(第 13 章) |

## 基礎架構

環境透過 Terragrunt 部署在 AWS(`eu-central-1`),由以下部分組成:

| 元件       | 說明                                                                            |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16`,含公有子網路                                                  |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                                                           |
| `k8s-1`    | Kubernetes `1.35.2`(kubeadm),CNI Calico,metrics-server,單節點;namespace `sched` 已預先建立 |
| `worker`   | 工作機,具備 `kubectl` 與 `check_result`                                          |

執行個體:`t4g.medium`(master),Ubuntu `22.04`。叢集為單節點 - master
已解除污點(移除了 `control-plane` taint),因此 Pod 會直接排程到它上面。

## 部署

```bash
TASK=122 make run_cka_task
```

建立完成後,請透過 SSH 連線到工作機(worker),並在那裡完成任務。
`kubectl` 已經指向 `cluster1-admin@cluster1` context。

工作機上的實用指令:

```bash
time_left       # 還剩多少時間
check_result    # 檢查解答
```

## 任務

把唯一那個節點的名稱放進變數會很方便:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`。

---
|        **1**        | **節點上的標籤**                                              |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 為節點掛上 label(標籤)`disk=ssd`(`kubectl label node $NODE disk=ssd`)。 |
| 驗收標準            | - 節點具有 label `disk=ssd`。 |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 Pod `sel`(ns `sched`,映像 `viktoruj/ping_pong:latest`),設定 `nodeSelector: disk=ssd` - 該 Pod 只會排程到帶有這個 label 的節點上。 |
| 驗收標準            | - Pod `sel` 處於 `Running` 狀態,`nodeSelector` 為 `disk=ssd`。 |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 Pod `aff`(ns `sched`,映像 `viktoruj/ping_pong:latest`),設定 required nodeAffinity:鍵為 `disk`,運算子為 `In`,值為 `[ssd]`(`requiredDuringSchedulingIgnoredDuringExecution`)。 |
| 驗收標準            | - Pod `aff` 處於 `Running` 狀態,且已設定 nodeAffinity。 |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 Pod `res`(ns `sched`,映像 `viktoruj/ping_pong:latest`),在容器上設定 requests `cpu=100m`、`memory=64Mi`,以及 limits `cpu=200m`、`memory=128Mi`。 |
| 驗收標準            | - Pod `res` 處於 `Running` 狀態,且已設定 `cpu` 與 `memory` 的 limits。 |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 PriorityClass `high-prio`,其值為 `value: 1000`(`kubectl create priorityclass high-prio --value=1000`),接著建立 Pod `prio`(ns `sched`,映像 `viktoruj/ping_pong:latest`),設定 `priorityClassName: high-prio`。 |
| 驗收標準            | - PriorityClass `high-prio` 的 `value=1000`;<br/>- Pod `prio` 處於 `Running` 狀態,且 `priorityClassName: high-prio`。 |
---
|        **6**        | **Taint + toleration**(放到最後做)                          |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 為節點掛上 taint `dedicated=special:NoSchedule`(`kubectl taint node $NODE dedicated=special:NoSchedule`),接著建立 Pod `tol`(ns `sched`,映像 `viktoruj/ping_pong:latest`),並帶上對應的 toleration(`key=dedicated`、`operator=Equal`、`value=special`、`effect=NoSchedule`)。**這個任務請放到最後做** - taint 會妨礙其餘 Pod 的排程。 |
| 驗收標準            | - 節點具有 taint `dedicated=special:NoSchedule`;<br/>- Pod `tol` 處於 `Running` 狀態。 |
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

Workloads & Scheduling 領域(CKA 佔 15%)- 反覆練習 nodeSelector/affinity、資源、
PriorityClass、taints/tolerations。

## 刪除叢集與資源

```bash
TASK=122 make delete_cka_task
```
