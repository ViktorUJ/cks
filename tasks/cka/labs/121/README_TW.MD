[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 121 - 快速訓練:RBAC

## 說明

RBAC 速度訓練:針對 ServiceAccount、Role/RoleBinding、
ClusterRole/ClusterRoleBinding,以及透過 `kubectl auth can-i` 檢查有效權限的
簡短獨立任務。namespace `rbac` 已預先建立。

任務以考試風格撰寫,並透過 `check_result` 指令自動驗證。這種訓練的目的
不是講解理論,而是速度與肌肉記憶:把命令式建立 RBAC 物件的手感「練起來」,
並跟上考試的節奏。

## 目標

鞏固以下課程章節的內容:

- [第 21 章。ServiceAccount;認證、授權、admission](../../course/21/README.md) - ServiceAccount、authn/authz/admission 鏈路
- [第 38 章。RBAC:Role、ClusterRole 與 binding](../../course/38/README.md) - Role/ClusterRole、RoleBinding/ClusterRoleBinding、用 `auth can-i` 檢查權限

## 我們要做什麼,以及為什麼

| 區塊 | 任務 | 技能 |
|------|--------|-------|
| **Namespaced RBAC** | ServiceAccount `app-sa`、Role `pod-reader`、RoleBinding `read-pods` | 透過 Role + binding 取得 namespace 範圍內的權限(第 38 章) |
| **Cluster-wide RBAC** | ClusterRole `cr-viewer`、ClusterRoleBinding `crb-viewer` | 透過 ClusterRole 存取叢集層級資源(nodes)(第 38 章) |
| **權限檢查** | 對 `app-sa` 使用 `kubectl auth can-i` | 快速驗證 ServiceAccount 的有效權限(第 21 章) |

## 基礎架構

環境透過 Terragrunt 部署在 AWS(`eu-central-1`),由以下部分組成:

| 元件       | 說明                                                                            |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16`,含公有子網路                                                  |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                                                           |
| `k8s-1`    | Kubernetes `1.35.2`(kubeadm),CNI Calico,metrics-server,單節點;namespace `rbac` 已預先建立 |
| `worker`   | 具備 `kubectl` 與 `check_result` 的工作機                                        |

執行個體:`t3.medium`(master),Ubuntu `22.04`。叢集為單節點 - master
已解除污點(移除了 `control-plane` taint),因此 Pod 會直接排程到它上面。

## 部署

```bash
TASK=121 make run_cka_task
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
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `rbac` 中建立 ServiceAccount `app-sa`(`kubectl -n rbac create serviceaccount app-sa`)。 |
| 驗收標準            | - namespace `rbac` 中存在 ServiceAccount `app-sa`。 |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `rbac` 中建立 Role `pod-reader`,對資源 `pods` 授予 `get,list,watch` 權限(`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`)。 |
| 驗收標準            | - Role `pod-reader` 對 `pods` 授予 `get`/`list`/`watch`。 |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `rbac` 中建立 RoleBinding `read-pods`,把 Role `pod-reader` 與主體 ServiceAccount `app-sa` 綁定(`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`)。 |
| 驗收標準            | - RoleBinding `read-pods` 引用 Role `pod-reader` 與主體 `app-sa`。 |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 ClusterRole `cr-viewer`,對叢集層級資源 `nodes` 授予 `get,list` 權限(`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`)。 |
| 驗收標準            | - ClusterRole `cr-viewer` 對 `nodes` 授予 `get`/`list`。 |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 ClusterRoleBinding `crb-viewer`,把 ClusterRole `cr-viewer` 與 namespace `rbac` 中的主體 ServiceAccount `app-sa` 綁定(`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`)。 |
| 驗收標準            | - ClusterRoleBinding `crb-viewer` 引用 ClusterRole `cr-viewer` 與主體 `rbac/app-sa`。 |
---
|        **6**        | **權限檢查(auth can-i)**                                    |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 透過 `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa` 檢查 `app-sa` 的有效權限:在 `rbac` 中 `get pods`、`get nodes`,以及在 `rbac` 中 `delete pods`。請確認綁定已正確授予。 |
| 驗收標準            | - namespace `rbac` 中 `get pods` = `yes`;<br/>- `get nodes` = `yes`;<br/>- namespace `rbac` 中 `delete pods` = `no`。 |
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

CKA 的 Cluster Architecture(RBAC)領域與 CKAD 的 Application Security 領域 - 反覆
練習 Role/ClusterRole 以及與 ServiceAccount 的綁定。

## 刪除叢集與資源

```bash
TASK=121 make delete_cka_task
```
