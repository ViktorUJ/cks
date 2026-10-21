[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 101 - NetworkPolicy:default-deny、隔離與 EC2 IMDS

## 說明

`NetworkPolicy` 的運作方式就像 allow-list:在 default-deny 之後,所需的流量只會透過明確的規則重新放行。規則的強制執行由 Calico 負責。本實驗的 worker 是由 Terraform 管理的 EC2 instance;它的 Instance Metadata Service(IMDS)位於 `http://169.254.169.254/`。Terraform 明確啟用了 HTTP endpoint,保留 IMDSv1 GET 以便進行安全的 probe,並將 response hop limit 設為 `2`,這樣在 default-deny 之前,一般的 Pod 就能確認 IMDS 在網路上是可達的。

本實驗只檢查 IMDS endpoint 在網路層面的可達性,不會讀取 metadata 或 credentials。只要實際收到任何 `1xx–5xx` 的 HTTP status,就表示通往 IMDS 的 TCP/HTTP 路徑存在。`HTTPCODE:000` 加上 transport error/timeout,表示沒有收到 HTTP 回應。具體的 HTTP status 取決於 EC2 metadata options:如果 token usage 為 `required`,沒有有效 IMDSv2 token 的 GET 會得到 `401`;如果允許 IMDSv1,不帶 token 的 GET 會被視為 IMDSv1 請求,並可能得到一般的 HTTP 回應。

**殘餘風險。** worker EC2 掛載了 IAM instance profile,而不帶 token 的 IMDSv1 GET 對 `latest/meta-data/iam/security-credentials/<role>` 的請求,實際上會回傳臨時的 AWS credentials(AccessKeyId/SecretAccessKey/SessionToken)- 這不是假設性的風險,而是目前環境的實際行為。該角色本身被限制在近乎零的權限(least privilege:它甚至無法透過 `iam:GetRole` 讀取自己的 IAM 角色),因此對攻擊者而言洩漏的實際價值極低,但學員必須清楚理解:在 production 中,同樣的設定(`HttpTokens=optional`,允許 IMDSv1)下,同一條指令會回傳具有真實權限的工作角色的真實 credentials。本實驗刻意重現第 02.1 章中的這個反模式(允許 IMDSv1,response hop limit 為 `2`),目的是進行 probe,並學習如何透過 NetworkPolicy 找出這個漏洞;在 production 中請使用 `HttpTokens=required`(僅限 IMDSv2)與 `HttpPutResponseHopLimit=1`。

## 部署

在管理機上啟動環境:

```bash
TASK=101 make run_cks_task
```

部署成功後,Terraform 會輸出連線到 worker 的 SSH 指令,格式如下:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

例如:

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

連線時只需使用指令中的位址:

```bash
ssh ubuntu@<IP>
```

當 SSH 要求輸入密碼時,請輸入 Terraform 在 `password=` 後面顯示的值。

**執行期(runtime)檢查**請使用臨時的診斷 Pod,其 labels 要與被檢查的 identity 相同。HTTP 檢查需要包含 curl 的映像(`curlimages/curl:8.11.1`);DNS 檢查需要包含 nslookup 的映像(`busybox`)。檢查完畢後,請刪除臨時的 Pod 與臨時的 policy。

請在 worker 上操作。開始之前,先確認 namespaces 是乾淨的(以防萬一):

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

請自行在你的資源上檢查每一個階段;完成任務後再執行 `check_result`,而參考解答請在自己嘗試過之後,或遇到困難時再打開。

## 目標

設定最小化的 ingress/egress allow-list,固定 image digest,證明 AND selector 的語意以及針對 IMDS 的精確 `ipBlock.except`,然後比較一般 Pod 與 `hostNetwork` Pod,不要事先假設一個通用的結果。

## 基礎架構

| 元件 | 用途                                                                                 |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `cks-101`        | 應用程式與你的 `NetworkPolicy` 所在的 namespace                                        |
| `cks-101-legacy` | legacy-client 情境使用的 namespace                                                     |
| `imds-control`   | 獨立、沒有 policy 的 namespace,用於 baseline 與重複的 control probe |
| worker EC2       | 由 Terraform 管理的 EC2 instance,IMDS 為 `http://169.254.169.254/` |
| CNI                | Calico                                                                                               |

## 任務

---

|           **1**           | **應用程式**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       要做什麼       | Namespace `cks-101`;Deployments `frontend` 與 `backend`,`replicas: 1`,不使用 `hostNetwork`,使用相同的 `viktoruj/ping_pong@sha256:<64hex>`;Service `backend` TCP/8080。<br/><br/>**如何取得最新的 digest:**<br/>1. 暫時用映像 `viktoruj/ping_pong:latest` 啟動一個 Pod。<br/>2. 等待 pull 完成並變成 Ready。<br/>3. 執行 `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)`,得到 `sha256:<64hex>`。<br/>4. 刪除臨時的 Pod。<br/>5. 兩個 Deployment 都使用取得的 digest:`viktoruj/ping_pong@sha256:<64hex>`。 |
| 驗收標準 | 兩個 replicas 都是 Ready,image references 相同,Service 有 endpoint。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|        檢查        | 執行 `kubectl -n cks-101 get deploy,svc,endpoints` 並確認:<br/>1. 兩個 Deployment 都是 `1/1 Ready`。<br/>2. Service `backend` 有 endpoint。<br/><br/>檢查 pinned image 時請執行:<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>兩個 Deployment 都必須使用相同、形式為 `viktoruj/ping_pong@sha256:<64hex>` 的映像。 |

---

|           **2**           | **Baseline、default-deny 與重複的 probe**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 建立 namespace `imds-control` 與一個臨時的 curl Pod。在 `cks-101` 中建立 frontend probe。**在 `default-deny` 之前**確認兩個 baseline:frontend → backend 與 frontend → IMDS 可達;`imds-control` → IMDS 同樣可達。然後建立 `default-deny`。**在 `default-deny` 之後**重複 IMDS probes:frontend 必須得到 `HTTP 000` 與 curl `7`/`28`,而 `imds-control` 必須仍然得到真實的 HTTP `1xx–5xx` 且 exit `0`。Backend 的 deny 在 DNS 恢復後於 Task 3 中檢查。 |
| 驗收標準 | deny 之前 backend 與 IMDS 實際可達。deny 之後 frontend → IMDS 為 `HTTP 000` + curl `7`/`28`;獨立的 `imds-control` 保持 HTTP `1xx–5xx` + exit `0`。 |
|        檢查        | 1. 在 `default-deny` 之前:從 frontend probe 對 `http://backend:8080/` 執行 curl,必須收到 HTTP 回應 + exit `0`。<br/>2. 在 `default-deny` 之前:frontend 與 `imds-control` 必須從 IMDS 收到真實的 HTTP 回應。<br/>3. 檢查 `default-deny`:空的 `podSelector`,`Ingress` + `Egress`,沒有 allow-rules。<br/>4. 在 `default-deny` 之後:frontend → IMDS 必須回傳 `HTTP 000` + curl `7`/`28`;`imds-control` → IMDS 必須仍然收到 HTTP `1xx–5xx` + exit `0`。<br/>5. 在 DNS 恢復之前不要檢查 backend 的 deny - 它在 Task 3 中檢查。 |

---

|           **3**           | **DNS**                                                                                                                                                                                                                                                                                                                                                                                                                 |
| :-----------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 在 `default-deny` 之後,以第一條 allow-rule 讓 frontend 恢復對 `kube-system/kube-dns` 的存取,而且只限精確的 UDP/53 與 TCP/53,不使用 `endPort`。檢查時請另外用 `busybox:1.36.1` 建立一個帶 label `app=frontend` 的 `dns-probe`。 |
| 驗收標準 | DNS allow-set 剛好是 UDP/53 + TCP/53;`nslookup kubernetes.default.svc.cluster.local` 可以運作。此時 backend 還不應該能透過 TCP/8080 存取。 |
|        檢查        | 1. 在 YAML 中檢查 `allow-frontend-dns`:只有 UDP/53 與 TCP/53,沒有 `endPort` 與額外的埠。<br/>2. 在 `dns-probe` 中執行 `nslookup kubernetes.default.svc.cluster.local`。<br/>3. DNS 成功之後,從 frontend probe 對 `http://backend:8080/` 執行 curl:在 Task 4 之前預期為 `HTTP 000` + curl `7`/`28`。 |

---

|           **4**           | **應用程式的 NetworkPolicy**                                                                                                                                                                         |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 建立 `allow-frontend-egress-to-backend` 與 `allow-backend-ingress-from-frontend`。之後 frontend 必須從 `http://backend:8080/` 得到真實的 HTTP 回應。 |
| 驗收標準 | 允許 frontend → backend:8080;foreign identity 仍然被阻擋。                                                                                                                |
|        檢查        | Positive:frontend 透過 Service DNS 執行 curl。Negative:帶有指向 backend 的臨時 egress policy 的 foreign Pod,不得通過 backend ingress。                                                              |

---

|           **5**           | **IMDS 最終驗證**                                                                                                                                                                                                                                                                                                                   |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 在加入 DNS 與應用程式的 allow policies 之後,從 frontend Pod 以及獨立的 `imds-control` 重複相同的 IMDS probe。目的是證明新的 allow policies 沒有開放 IMDS。不需要建立輔助的 artifact 檔案。 |
| 驗收標準 | `imds-control`:真實的 HTTP `1xx–5xx` + exit `0`;frontend:`HTTP 000` + curl `7`/`28`。                                                                                                                                                                                                                                      |
|        檢查        | 從兩個 Pod 執行同一條有時間限制的 curl(`-m 5`),並比較實際結果。不要使用 `curl -f`:HTTP `401/403/404/...` 同樣代表網路可達。                                                 |

---

|           **6**           | **Legacy AND 與 IMDS except**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 建立 namespace `cks-101-legacy`,其中有 Deployment `legacy-client`:replicas=1,不使用 hostNetwork,映像 `curlimages/curl:8.11.1`,指令 `sleep 3600`。在 namespace `cks-101` 中建立 NetworkPolicy `allow-backend-ingress-from-legacy`:選取 backend,包含一個使用 AND selector 的 ingress peer(namespaceSelector 與 podSelector 位於同一個 `from` 元素中),TCP/8080。在 namespace `cks-101-legacy` 中建立 NetworkPolicy `allow-legacy-egress`:選取 app=legacy-client,包含 ipBlock cidr=0.0.0.0/0,且唯一的 except 為 169.254.169.254/32,沒有額外的 allow-rules。檢查:1) 從 legacy-client 到 IMDS 被阻擋;2) legacy-client 可以到達 backend;3) 同一個 namespace 中帶有其他 label 的 Pod 無法通過 ingress;4) namespace cks-101 中帶有 label=legacy-client 的 Pod 無法通過 ingress。檢查完畢後,刪除臨時的 Pod 與臨時的 policy。 |
| 驗收標準 | IMDS 被阻擋,實際的 legacy 對 backend 的存取被允許,錯誤的 label/namespace 被阻擋。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|        檢查        | 1. 執行 `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` - 確認 `ipBlock.cidr=0.0.0.0/0`,且唯一的 `except` 等於 `169.254.169.254/32`。<br/>2. 執行 `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` - 確認 `namespaceSelector` 與 `podSelector` 位於同一個 `from` 元素中,埠為 TCP/8080。<br/>3. 從 `legacy-client` 對 IMDS 執行 curl,必須回傳 `HTTP 000` 與 exit `7` 或 `28`。<br/>4. 從 `legacy-client` 對 backend 執行 curl,必須收到真實的 HTTP 回應。<br/>5. `cks-101-legacy` 中帶有其他 label、且帶有指向 backend 的臨時 egress 的 Pod,不得通過 backend ingress。<br/>6. namespace `cks-101` 中帶有 `app=legacy-client`、且帶有指向 backend 的臨時 egress 的 Pod,同樣不得通過 backend ingress。 |

---

|           **7**           | **觀察 hostNetwork**                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       要做什麼       | 建立 `hostnetwork-probe`,映像 `curlimages/curl:8.11.1`,label `app=frontend`,以及 `spec.hostNetwork=true`。從中執行與一般 frontend Pod 相同的 IMDS curl。將實際觀察結果與 Task 5 比較。不需要建立輔助的 artifact 檔案。 |
| 驗收標準 | Pod 為 Ready,`hostNetwork=true`,並已執行真實的 IMDS probe。對 hostNetwork 不預設有通用的預期結果:行為取決於 CNI 與節點的設定。 |
|        檢查        | 確認 `hostNetwork: true`,然後執行有時間限制的 IMDS curl(`-m 5`)與 `echo $?`。將實際觀察結果與 Task 5 的一般 Pod 比較。 |

## 檢查

```bash
check_result
```

Checker 會建立並刪除它自己的 `imds-control` namespace 與 probes:在 `cks-101` 中 deny 之前與之後,它都會確認真實的 IMDS 能從沒有 policy 的獨立 namespace 回應。它不信任上一次嘗試遺留的 control 資源,也不能取代你自己做的 baseline/runtime 檢查。額外加入、擴大允許流量的 policy 會導致失敗。

參考解答:[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=101 make delete_cks_task
```
