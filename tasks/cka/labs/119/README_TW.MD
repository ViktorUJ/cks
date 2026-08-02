[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 119 - 速度訓練與 JSONPath

## 說明

針對 CKA/CKAD 的速度訓練器:一連串短而同類的任務,練習用命令式方式建立物件
(Pod、Deployment、Service、ConfigMap、Secret),另有一個獨立的 `-o jsonpath` 區塊 -
把叢集物件中的資料取出並寫入檔案。

所有任務都以考試風格撰寫,並透過 `check_result` 指令自動驗證。這種訓練的目的
不是講解理論,而是速度與肌肉記憶:把命令式指令「練到熟」,並跟上考試的節奏
(每題約 6-8 分鐘)。JSONPath 任務的答案檔案儲存在 `/home/ubuntu/answers/`。

## 目標

鞏固以下課程章節的內容:

- [第 3 章。使用 kubectl:命令式與宣告式做法](../../course/03/README.md) - 快速的命令式指令、`--dry-run=client -o yaml`、物件產生器
- [第 47 章。CKAD 考試:JSONPath 與 kubectl 生產力](../../course/47/README.md) - 透過 `-o jsonpath` 取出資料、custom-columns、`--sort-by`
- [第 48 章。CKA 考試:時間管理與策略](../../course/48/README.md) - 時間分配與解題順序

## 我們要做什麼,以及為什麼

| 區塊 | 任務 | 技能 |
|------|--------|-------|
| **速度訓練** | namespace、Deployment、Service、ConfigMap、Secret | 命令式指令的速度、`--dry-run`(第 3 章) |
| **JSONPath** | 節點版本、Pod 的映像、Service 的 ClusterIP → 寫入檔案 | `-o jsonpath`、在計時下取出資料(第 47 章) |

## 基礎架構

環境透過 Terragrunt 部署在 AWS(`eu-central-1`),由以下部分組成:

| 元件       | 說明                                                                  |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16`,含公有子網路                                        |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                                                 |
| `k8s-1`    | Kubernetes `1.35.2`(kubeadm),CNI Calico,metrics-server,單節點        |
| `worker`   | 工作機,具備 `kubectl` 與 `check_result`                                |

執行個體:`t3.medium`(master),Ubuntu `22.04`。叢集為單節點 - master
已解除污點(移除了 `control-plane` taint),因此 Pod 會直接排程到它上面。

## 部署

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立名為 `drill` 的 namespace(命名空間) - 其他任務的物件都會放在裡面(`kubectl create namespace drill`)。 |
| 驗收標準            | - namespace `drill` 存在。 |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `drill` 中建立名為 `api` 的 Deployment,映像為 `viktoruj/ping_pong:latest`,並有 3 個副本(`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`)。 |
| 驗收標準            | - `drill` 中的 Deployment `api`:3 個就緒的副本。 |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 把 Deployment `api` 以 ClusterIP 類型的 Service(服務)發佈出來,名稱為 `api-svc`,埠為 80(`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`)。 |
| 驗收標準            | - Service `api-svc`(ns `drill`):Endpoints 不為空。 |
---
|        **4**        | **ConfigMap 與 Secret**                                      |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `drill` 中建立 ConfigMap `cfg`,含鍵 `APP_COLOR=blue`,以及 Secret `sec`,含鍵 `PASSWORD`(值可任意)。請使用 `--from-literal`。 |
| 驗收標準            | - `cfg.data.APP_COLOR=blue`;<br/>- Secret `sec` 具有鍵 `PASSWORD`。 |
---
|        **5**        | **JSONPath:節點版本**                                        |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 透過 `-o jsonpath` 取出所有節點的 `kubeletVersion`,並把結果儲存到檔案 `/home/ubuntu/answers/versions.txt`(路徑 `{.items[*].status.nodeInfo.kubeletVersion}`)。 |
| 驗收標準            | - `versions.txt` 的內容與節點的 `jsonpath` 輸出一致。 |
---
|        **6**        | **JSONPath:Pod 的映像**                                      |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 透過 `-o jsonpath` 取出 namespace `drill` 中所有 Pod 的容器映像,並儲存到 `/home/ubuntu/answers/images.txt`(路徑 `{.items[*].spec.containers[*].image}`)。 |
| 驗收標準            | - `images.txt` 中的映像集合與 `drill` 中 Pod 的 `jsonpath` 輸出一致。 |
---
|        **7**        | **JSONPath:Service 的 ClusterIP**                            |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 透過 `-o jsonpath` 取出 Service `api-svc` 的 ClusterIP,並儲存到 `/home/ubuntu/answers/api-ip.txt`(路徑 `{.spec.clusterIP}`)。 |
| 驗收標準            | - `api-ip.txt` 中的值與 Service `api-svc` 的 `.spec.clusterIP` 一致。 |
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

速度與 JSONPath 的基礎技能,在所有 CKA 與 CKAD 模擬考中都會用到。

## 刪除叢集與資源

```bash
TASK=119 make delete_cka_task
```

