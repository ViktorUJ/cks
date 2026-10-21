[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap、kube-proxy replacement 與 Mutual Authentication

> **Advanced / production track。不屬於正式的 CKS Core 考試要求。**
> 這個實驗超出 CKS 考試的範圍,但作為 production 技能很有用:從零安裝
> Cilium,作為 kube-proxy 的完整替代品,以及基於 SPIRE 的 Cilium Mutual Authentication。
> 如果你只是在準備考試,優先順序是實驗 101-114。

## 說明

這個實驗的 control-plane 是透過 `kubeadm init --skip-phases=addon/kube-proxy` 啟動的 - 沒有
`kube-proxy` DaemonSet,也**沒有安裝 CNI**。在你自己
安裝 Cilium 之前,Node 會保持 `NotReady`。這是刻意的:整個實驗都是關於手動安裝 Cilium,作為
kube-proxy 的完整替代品(`kubeProxyReplacement`)、逐步啟用 WireGuard
transparent encryption,以及基於 SPIRE 的 Cilium Mutual Authentication - 每一步
都是單獨安裝並檢查的,而不是直接給你現成的。

`cilium`/`hubble` CLI 已經安裝在 worker 上,並指向真實的叢集
(`~/.kube/config`),但在叢集中安裝 Cilium 本身,是你自己來完成的。

## 部署

```bash
TASK=115 make run_cks_task
```

部署之後,使用 Terraform 輸出中的指令(`worker_pc_ssh`)透過 SSH 連線。
登入之後 Node 會是 `NotReady` - 這是預期的 baseline,而不是錯誤。

## 目標

在已經啟動的、沒有 kube-proxy 的 kubeadm 叢集上,把 Cilium 安裝為 kube-proxy 的完整替代品,啟用 WireGuard encryption,啟用 Cilium Mutual Authentication
(SPIRE),並撰寫要求兩個 namespace 之間 mutual authentication 成功的 `CiliumNetworkPolicy`。

## 基礎架構

| 元件 | 用途 |
| --- | --- |
| control-plane EC2 | 在實驗交付時沒有 kube-proxy 也沒有 CNI 的 kubeadm 叢集 |
| `ingress-115` | 必須通過 mutual authentication 的用戶端的 namespace |
| `app-115` | 受帶有 `authentication.mode: required` 的 CiliumNetworkPolicy 保護的 backend 的 namespace |
| worker EC2 | `cilium`/`hubble` CLI,已設定好的 kubeconfig |

## 任務

---

|           **1**           | **Baseline:沒有 kube-proxy、沒有 CNI** |
| :-----------------------------: | :--- |
|       要做什麼       | • 在安裝任何東西之前,先確認叢集目前的狀態 |
| 驗收標準 | • `kube-proxy` DaemonSet 不存在<br/>• 在安裝 Cilium 之前觀察到最初的 `NotReady`<br/>• 在所有任務完成之後,checker 確認的是沒有 kube-proxy 且 API 可用,而不是歷史上的 `NotReady` |
|        檢查        | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`。`kubectl get nodes` -> `NotReady`(沒有 CNI)。 |

---

|           **2**           | **把 Cilium 安裝為 kube-proxy 的替代品** |
| :-----------------------------: | :--- |
|       要做什麼       | • 透過安裝在 worker 上的 `cilium` CLI 版本 `v0.19.7`,安裝 Cilium agent/chart 版本 `1.20.1`,帶有 `kubeProxyReplacement=true`,以及明確設定、指向真實 API server 的 `k8sServiceHost`/`k8sServicePort`(不是 Service ClusterIP - 沒有 kube-proxy 時,叢集在 Cilium 自己啟動之前無法解析 `kubernetes.default`) |
| 驗收標準 | • `KubeProxyReplacement: True/Strict`(在 agent 的 `cilium-dbg status` 中)<br/>• Node 變成 `Ready`<br/>• ClusterIP Service 在沒有 kube-proxy 的情況下可以存取 |
|        檢查        | `cilium status --wait`、`kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`,然後 `kubectl get nodes` -> `Ready`。從測試 Pod 中:`curl https://kubernetes.default.svc.cluster.local/` 必須得到 HTTP response(而不是連線錯誤)。 |

---

|           **3**           | **WireGuard transparent encryption** |
| :-----------------------------: | :--- |
|       要做什麼       | • 在已經安裝的 Cilium 之上啟用 `encryption.enabled=true`、`encryption.type=wireguard`(`cilium upgrade`,而不是從零重新安裝) |
| 驗收標準 | • `cilium-dbg status` 中有 `Encryption: Wireguard`,且 Cilium ConfigMap 中有 `enable-wireguard: "true"`<br/>• 任務 2 的路徑沒有退化<br/>• 單節點的實驗台確認了 WireGuard 設定已啟用,但無法證明節點間流量已加密(Peers: 0) |
|        檢查        | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`。重複任務 2 的 curl - 必須再次得到 HTTP response。 |

---

|           **4**           | **Cilium Mutual Authentication(SPIRE)** |
| :-----------------------------: | :--- |
|       要做什麼       | • 透過 Cilium helm chart 本身啟用內建的 SPIRE 安裝:`authentication.mutual.spire.enabled=true`、`authentication.mutual.spire.install.enabled=true` |
| 驗收標準 | • `spire-server` StatefulSet 與 `spire-agent` DaemonSet 在 namespace `cilium-spire` 中具有全部被要求的 Ready replica |
|        檢查        | `kubectl get pods -A \| grep spire` - 兩種 Pod 都處於 `Running` 且 Ready 狀態。 |

> **實驗台的特殊之處。**叢集中沒有 StorageClass,因此 SPIRE 伺服器需要暫時性的
> 儲存(`authentication.mutual.spire.install.server.dataStorage.enabled=false`)。映像
> `spire-server` 以 uid 1000 運作,無法在 `root:755` 的 hostPath 目錄中建立 socket -
> 請以 root 啟動它(`authentication.mutual.spire.install.server.securityContext.runAsUser=0`)。
> 另外 chart 要求 `authentication.enabled=true`。詳情 - 在參考解答中。

---

|           **5**           | **帶有強制 mutual authentication 的 CiliumNetworkPolicy** |
| :-----------------------------: | :--- |
|       要做什麼       | • 建立 `ingress-115`(client)與 `app-115`(backend,label `app=backend`,Service `backend`)<br/>• 在 `app-115` 中建立 `CiliumNetworkPolicy backend-auth-required`:針對 `app=backend` 的 `endpointSelector`,ingress 只來自 namespace `ingress-115`,並在這條 ingress 規則上設定 `authentication.mode: required` |
| 驗收標準 | • Policy 精確地選取 backend,包含一條來自 `ingress-115` 的、TCP/80 上帶有 `authentication.mode: required` 的 ingress 規則<br/>• 沒有額外的 ingress 規則與繞過路徑<br/>• 在隔離的 Lab 115 實驗台中,沒有其他會影響 backend 的 namespaced/global network policies<br/>• Service `backend` 指向 Ready 的 Pod `backend` |
|        檢查        | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - 檢查 `ingress[0]` 內的 `authentication.mode: required`。 |

---

|           **6**           | **Positive/negative control:已驗證的 identity 被允許,外來的則不行** |
| :-----------------------------: | :--- |
|       要做什麼       | • 用即時流量檢查 policy 的效果:來自 `ingress-115` 的 client 必須能到達 `backend`(在 SPIRE-based mutual auth handshake 成功之後)<br/>• 來自「錯誤的」namespace(`app-115`,而不是 `ingress-115`;backend 對自己的流量 Cilium 永遠放行)的單獨 Pod 必須被阻擋 |
| 驗收標準 | • 在隔離的鏡像 backend 中,baseline 允許兩個 client,套用 policy 的副本之後只允許 `ingress-115`<br/>• 實際運作的 backend 回應被允許的 client,拒絕來自 `app-115` 以及新的獨立 namespace 的 client<br/>• Cilium BPF auth map 中,針對 client/backend 的精確 identity 組合包含 `spire` |
|        檢查        | 從 `ingress-115` 中的 client Pod 對 `http://backend.app-115.svc.cluster.local/` 執行 `curl` -> HTTP response。從 `app-115` 中沒有 client label 的 Pod 執行同樣的 curl -> 連線錯誤。 |

## 檢查

```bash
check_result
```

Checker **從不移除運作中的** `app-115/backend-auth-required`。為了檢查 baseline,它會在一次性的 namespace `cks-115-*` 中建立臨時的鏡像 backend 與 Service,先在沒有 policy 的情況下檢查允許的流量,然後只把經過檢查的 CiliumNetworkPolicy 的副本套用到鏡像 backend 上。另外會單獨檢查真實的 backend、EndpointSlice、BPF auth map 中精確的 SPIRE identities 組合,以及對來自外來 namespace 的 client 的禁止。所有建立的 Pod、Service、policy 與臨時的 namespace,都會被刪除並檢查 cleanup。

參考解答:[worker/files/solutions/1_TW.MD](worker/files/solutions/1_TW.MD)。

## 刪除

```bash
TASK=115 make delete_cks_task
```
