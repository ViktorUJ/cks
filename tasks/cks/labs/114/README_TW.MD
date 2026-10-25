[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts、client certificates 與 API exposure

## 說明

發給學員的 kubeconfig 包含多個 context：可運作的 `cluster1-admin@cluster1`,
以及兩個刻意無法運作的(`staging-admin@staging`、`legacy-admin@legacy`)，它們指向不存在的
API server。登入之後 `current-context` 立刻被設為無法運作的 `staging-admin@staging` - 這是
刻意重現考試中的真實情況：考生拿到帶有多個
context 的 kubeconfig，需要自己判斷哪一個可以運作。

此外，同一個 kubeconfig 中還有使用者 `cluster9-admin`，帶有完整的、真正產生出來的
自簽 client certificate(`client-certificate-data`/`client-key-data`)。這個憑證在叢集中不提供
任何權限(apiserver 不信任它的 CA)- 任務教的是如何讀取並解析
kubeconfig 中的 client certificate，而不是用它進行驗證。

本實驗也涵蓋縮小 Service 攻擊面的經典情境：先由你刻意
建立 `NodePort` Service(從外部可以透過 control-plane 節點的 IP 存取)，然後把它縮減為
`ClusterIP`，並即時證明兩個方向的效果。

## 部署

在管理機上啟動環境：

```bash
TASK=114 make run_cks_task
```

部署成功後，Terraform 會輸出連線到 worker 的 SSH 指令：

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

請只使用 Terraform 輸出中的位址連線：

```bash
ssh ubuntu@<IP>
```

請在 worker 上操作。請自行檢查每一個階段；在完成任務之後再執行 `check_result`,
參考解答請在自己嘗試過之後，或遇到困難時再打開。

## 目標

學會安全地使用包含多個 context 的 kubeconfig，擷取並檢查
client certificate 而不用它進行驗證，並透過切換 `NodePort` -> `ClusterIP`
有意識地管理 Service 的 exposure。

## 基礎架構

| 元件 | 用途 |
| --- | --- |
| kubeconfig(`~/.kube/config`)| 4 個 context:1 個可運作的(`cluster1-admin@cluster1`)、2 個 decoy(`staging-admin@staging`、`legacy-admin@legacy`)、1 個帶有真正 client certificate 的(`cluster9-admin@cluster1`) |
| `cks-114` | 你的 backend 應用程式與 Service 所在的 namespace |
| control-plane EC2 | 單節點 kubeadm 叢集，CNI Calico |

## 任務

---

|           **1**           | **Kubeconfig context inventory** |
| :-----------------------------: | :--- |
|       要做什麼       | • 執行 `kubectl config get-contexts`，找出目前的(無法運作的)`current-context`。<br/>• 找出真正可運作的 context，並切換過去：`kubectl config use-context <name>`。 |
| 驗收標準 | • `current-context` == `cluster1-admin@cluster1`。<br/>• 透過這個 context 對 API server 的請求確實能成功(而不只是存在於檔案中)。 |
|        檢查        | `kubectl config current-context`，然後 `kubectl get nodes` - 必須回傳真實的節點清單，而不是連線錯誤。 |

---

|           **2**           | **Client certificate extraction** |
| :-----------------------------: | :--- |
|       要做什麼       | • 從 kubeconfig 中取出使用者 `cluster9-admin` 的 `client-certificate-data`，進行 base64 解碼，並透過 `openssl x509` 解析憑證。<br/>• 把結果以 `KEY=VALUE` 格式儲存到 `/var/work/tests/artifacts/task2-cert.txt`，每行一個值：`SHA256_FP`、`SUBJECT`、`ISSUER`、`NOTBEFORE`、`NOTAFTER`。 |
| 驗收標準 | • artifact 中的五個值，與從 `cluster9-admin` 的原始 bootstrap 憑證取出的內容相符。<br/>• Checker 會比對原始的 fingerprint、kubeconfig 中憑證是否未被更動，以及全部五個欄位。 |
|        檢查        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` 會輸出 `sha256 Fingerprint=AA:BB:...` - 在 artifact 中請寫入不帶冒號的 hex(大小寫皆可)。 |

---

|           **3**           | **Baseline: NodePort exposure** |
| :-----------------------------: | :--- |
|       要做什麼       | • 建立 namespace `cks-114`。<br/>• 建立 Deployment `backend`(例如 `viktoruj/ping_pong:alpine`，帶有 `SRV_PORT=80`,label `app=backend`)。<br/>• 建立類型為 `NodePort`、埠為 80、並明確指定 `nodePort: 30114` 的 Service `kubernetes-public`。<br/>• **不要動** `default/kubernetes` Service。 |
| 驗收標準 | • Backend 確實既能從 worker(叢集外部)透過 `<node-internal-ip>:30114` 存取，也能在叢集內部透過 `kubernetes-public.cks-114.svc.cluster.local` 存取。<br/>• `default/kubernetes` 保持 `ClusterIP`。<br/>• 任務 4 之後會把同一個 Service 變成 `ClusterIP`，因此到實驗結束時已經觀察不到 NodePort 狀態：歷史上的 NodePort 階段，由兩次 HTTP 200 的探測(從 worker 以及在 Pod 中透過 DNS)、對 backend/EndpointSlice 的檢查，以及保存 Service 與 Deployment UID 的監控器來確認。<br/>• 請先完整完成任務 3，並等待檔案 `/var/lib/cks-lab114-checker/nodeport-phase-seen`，它是由監控器在兩次成功的 live 探測之後建立的；然後才執行任務 4。這個檔案是對同一個 Service/Deployment 的歷史階段的確認。 |
|        檢查        | 從 worker(叢集外部):`curl http://<node-internal-ip>:30114/` -> HTTP 200。<br/>從叢集內部(帶有 curl 的臨時 Pod):`curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200。節點 IP:`kubectl get nodes -o wide`。 |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP** |
| :-----------------------------: | :--- |
|       要做什麼       | • 把 `kubernetes-public` 改為類型 `ClusterIP`。<br/>• 請記住：API server 不允許在類型為 `ClusterIP` 時明確指定 `nodePort` - 更可靠的做法是明確移除這個欄位(`kubectl edit svc kubernetes-public` 並刪除 `nodePort` 這一行，或使用對 `/spec/ports/0/nodePort` 執行 `op: remove` 的 JSON patch)。 |
| 驗收標準 | • 外部路徑 `<node-internal-ip>:30114` 現在在傳輸層被阻擋(connection refused/timeout)。<br/>• 叢集內部的路徑仍然可以運作。<br/>• Backend Pod 保持 Ready。 |
|        檢查        | 從 worker:`curl -m5 http://<node-internal-ip>:30114/` -> 連線錯誤(不是 HTTP 狀態碼)。<br/>從叢集內部：`curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200，和之前一樣。<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`，沒有任何一個埠有 `nodePort`。 |

## 檢查

```bash
check_result
```

Checker 會檢查 `current-context` 以及透過它對 API 發出的即時請求，獨立地擷取並解析
`cluster9-admin` 的憑證，相對於 bootstrap 的原始 fingerprint 檢查它，並與你的 artifact 比對，同時還會透過 Service DNS 執行叢集內部的 HTTP 200 探測，檢查 Deployment 與 EndpointSlice，並確認 `default/kubernetes` 未被更動。歷史上的 NodePort 階段，由 root 擁有的監控器在切換 Service 之前以兩次 live 探測來確認；在 ClusterIP 狀態下，checker 會檢查 live DNS 以及 NodePort 的傳輸層拒絕。

參考解答：[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=114 make delete_cks_task
```
