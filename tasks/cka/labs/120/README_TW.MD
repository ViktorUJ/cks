[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 120 - 速度練習:Services 與網路

## 說明

Services & Networking 領域的速度訓練器。一組短小而獨立的任務,涵蓋建立
Service(ClusterIP、NodePort、headless)、Ingress 與 NetworkPolicy,另外還有一個
JSONPath 區塊。

任務以考試風格撰寫,並透過 `check_result` 指令自動驗證。速度練習的目標
不是鑽研理論,而是速度與肌肉記憶:把手練熟,跟上考試的節奏。JSONPath
任務的答案檔案會儲存在
`/home/ubuntu/answers/`。

## 目標

鞏固以下課程章節的內容:

- [第 7 章。Services:ClusterIP、NodePort、LoadBalancer、Endpoints](../../course/07/README.md) - Service 的類型、透過 `expose` 發布、Endpoints
- [第 31 章。Service 內部原理、DNS 與 CoreDNS](../../course/31/README.md) - headless-Service(`clusterIP: None`)、DNS 名稱
- [第 32 章。Ingress 與 Ingress 控制器](../../course/32/README.md) - 依主機與路徑路由到 backend-Service
- [第 34 章。NetworkPolicy](../../course/34/README.md) - default-deny、podSelector、policyTypes

## 我們要做什麼,以及為什麼

| 區塊 | 任務 | 技能 |
|------|--------|-------|
| **Services** | Deployment `web`、ClusterIP、NodePort、headless | 用不同的 Service 類型快速發布負載(第 7、31 章) |
| **路由與隔離** | Ingress `web-ing`、NetworkPolicy `deny-all` | 依主機設定 Ingress 規則,以及 default-deny 流量(第 32、34 章) |
| **JSONPath** | Service `web-np` 的 nodePort → 寫入檔案 | 在計時壓力下透過 `-o jsonpath` 取出資料(第 47 章) |

## 基礎架構

環境透過 Terragrunt 部署在 AWS(`eu-central-1`),由以下部分組成:

| 元件       | 說明                                                                 |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16`,含公有子網路                                       |
| `ssh-keys` | 用於存取節點的 SSH 金鑰                                                |
| `k8s-1`    | Kubernetes `1.35.2`(kubeadm),CNI Calico,metrics-server,單節點        |
| `worker`   | 工作機,具備 `kubectl` 與 `check_result`                               |

執行個體:`t3.medium`(master),Ubuntu `22.04`。叢集為單節點 - master
已解除污點(移除了 `control-plane` taint),因此 Pod 會直接排程到它上面。

## 部署

```bash
TASK=120 make run_cka_task
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
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 建立 namespace(命名空間)`net`,然後在其中建立 Deployment `web`,容器映像為 `viktoruj/ping_pong:latest`,副本數為 2(`kubectl create ns net`、`kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`)。 |
| 驗收標準            | - Deployment `web`(ns `net`):2 個就緒的副本。 |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 把 Deployment `web` 發布為 ClusterIP 類型的 Service(服務),名稱為 `web-svc`,埠為 80(`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`)。 |
| 驗收標準            | - Service `web-svc`(ns `net`):Endpoints 不為空。 |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 為 `web` 建立 NodePort 類型的 Service `web-np`,並固定 `nodePort: 30080`(`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`)。 |
| 驗收標準            | - Service `web-np`:type 為 `NodePort`,`nodePort` 為 30080。 |
---
|        **4**        | **Headless-Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 為 `web` 的 Pod 建立 headless-Service `web-h`,設定 `clusterIP: None`(選擇器 `app=web`)。headless-Service 會直接把 DNS 記錄指向 Pod,繞過虛擬 IP。 |
| 驗收標準            | - Service `web-h`:`clusterIP` = `None`。 |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `net` 中建立 Ingress `web-ing`:主機為 `web.local`,路徑 `/` 導向 backend-Service `web-svc` 的 80 埠(`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`)。 |
| 驗收標準            | - 主機規則 `web.local` → backend Service `web-svc`,埠 80。 |
---
|        **6**        | **NetworkPolicy(default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 在 namespace `net` 中建立 NetworkPolicy `deny-all`,`podSelector: {}` 為空(套用到所有 Pod),並設定 `policyTypes: [Ingress]` - 該政策會拒絕所有入向流量。 |
| 驗收標準            | - NetworkPolicy `deny-all`:`policyTypes` 包含 `Ingress`,`podSelector` 為空。 |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| 要做什麼            | 透過 `-o jsonpath` 取出 Service `web-np` 的 `nodePort`,並儲存到 `/home/ubuntu/answers/nodeport.txt`(路徑為 `{.spec.ports[0].nodePort}`)。 |
| 驗收標準            | - `nodeport.txt` 中的值與 Service `web-np` 的 `.spec.ports[0].nodePort` 相符。 |
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

Services & Networking 領域(CKA 20% / CKAD 20%)- Service、Ingress、
NetworkPolicy 的基礎重複練習。

## 刪除叢集與資源

```bash
TASK=120 make delete_cka_task
```
