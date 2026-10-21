[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 113 - 參考解答：kubeadm minor upgrade

> 像考試中一樣工作：`kubectl` 在工作機上執行，而對節點的操作(apt、kubeadm、
> kubelet)- 在節點本身上執行：用 `ssh <節點>` 登入，切換到 root(`sudo -i`),
> 執行指令，然後離開(`exit`、`exit`)。叢集的起始版本為 `1.35.x`，目標版本為
> `1.36.x`。節點名稱(`<cp-name>`、`<worker-name>`)取自 `kubectl get no`；在考試中它們是不同的，在本實驗中 ssh 別名是：`k8s113_controlPlane_1` 與 `k8s113_node_worker1`。

## 在文件中哪裡可以找到指令

| 需要什麼 | 頁面與章節 |
| :--- | :--- |
| 把 apt repository 切換到下一個 minor(只更改檔案 `/etc/apt/sources.list.d/kubernetes.list` 中 URL 的版本，keyring 保持不變) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| 選擇版本(`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| 升級 `kubeadm`、`kubeadm upgrade plan`、在第一個 control-plane 上執行 `kubeadm upgrade apply v1.xx.x` | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| 升級 `kubelet` 與 `kubectl`、`systemctl daemon-reload`、`restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Worker 節點：`kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

在 Ubuntu 節點上，`needrestart` 被設定為「只列出」模式(沒有 OK/Cancel 對話框)，因此
`apt-get install` 不會因為提問而停住。

指令中的 `1.36.x`，請代入來自 `apt-cache madison kubeadm` 以及
`kubeadm upgrade plan` 輸出中的真實 patch。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

請記住 `kubectl get no` 中的節點名稱(`ip-10-...`):`drain` 與 `uncordon` 會用到。下面
`<cp-name>` 代表 control-plane 的名稱，`<worker-name>` 代表 worker 節點的名稱。

## 步驟 0。同時啟動 availability 輪詢(任務 4)

在升級之前，在工作機上打開單獨的工作階段(`tmux`)，並讓輪詢 Deployment
`canary` 的迴圈在接下來所有步驟期間持續運作：

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. 升級 control-plane

```bash
ssh <cp-name>
sudo -i
```

```bash
# 在 control-plane 上(root):目前的版本
kubeadm version -o short; kubelet --version

# 把 repository 切換到下一個 minor:在檔案中把 v1.35 換成 v1.36
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

升級 kubeadm(用真實的 patch 取代 `x`)。**請單獨執行這個指令：**`apt-get`
會清空終端機的輸入緩衝區，因此緊接在它之後貼上的幾行會遺失。

```bash
# 在 control-plane 上(root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# 在 control-plane 上(root)
kubeadm version -o short
kubeadm upgrade plan
```

從 `plan` 的輸出中取得具體的版本並執行升級，同時儲存**完整的**輸出：

```bash
# 在 control-plane 上(root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 在工作機上:取回輸出供檢查
scp <cp-name>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

只有現在，在 `kubeadm upgrade apply` 成功「之後」，才 drain 節點並升級 kubelet/kubectl:

```bash
# 在工作機上
kubectl drain <cp-name> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <cp-name>
sudo -i
```

```bash
# 在 control-plane 上(root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# 在 control-plane 上(root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # 離開 root
exit   # 離開 control-plane
```

```bash
# 在工作機上
kubectl uncordon <cp-name>
kubectl get nodes
```

## 2. 升級 worker 節點

只有在 control-plane 在 `1.36.x` 上為 `Ready` 之後才開始(version skew policy:
worker 節點的 kubelet 不能比 control-plane 更新)。請等 `canary` 再次變成 `2/2`:

```bash
# 在工作機上:請重複執行,直到 AVAILABLE 變成 2
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <worker-name>
sudo -i
```

```bash
# 在 worker 上(root):與 control-plane 上相同的 repository
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# 在 worker 上(root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# 在 worker 上(root)
# 在 worker 節點(以及額外的 control-plane)上執行的是 upgrade node,而不是 apply
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # 離開 root
exit   # 離開 worker
```

```bash
# 在工作機上
scp <worker-name>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <worker-name> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <worker-name>
sudo -i
```

```bash
# 在 worker 上(root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# 在 worker 上(root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # 離開 root
exit   # 離開 worker
```

```bash
# 在工作機上
kubectl uncordon <worker-name>
kubectl get nodes
```

## 3. 檢查升級順序

任務 3 不需要單獨的指令：順序由 checker-owned 監控器證明
(工作機上的 `/var/lib/cks-lab113-checker/upgrade-monitor.log`)，它從 bootstrap 起
就一直在寫入。如果你依序執行了這些步驟(先完整做完第 1 節，再做第 2 節),
日誌中會有一行，其中 control-plane 已經在 `v1.36.x`、`Ready` 且 schedulable，而 worker 仍在
`v1.35.x`。

## 4. 檢查沒有 downtime

> 在唯一的 control-plane 上執行 `kubeadm upgrade apply` 期間，API server 會重新啟動幾秒鐘，
> 輪詢迴圈中的 `kubectl` 不會回應。這樣的行被記錄為
> `available=api-unreachable`，不計入最小值：API 無法連線 - 不是
> `canary` 停機。判定是否有 downtime 的是 checker 的獨立監控器(Pod Ready 以及透過 `crictl` 的容器)。

停止步驟 0 的輪詢迴圈(在它的工作階段中按 `Ctrl+C`)，並檢查 `available` 在整個執行期間
的最小值沒有降到 0:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

`canary` 的兩個 replica 被分散到不同的節點(required `podAntiAffinity`)，並受
帶有 `minAvailable: 1` 的 `PodDisruptionBudget` 保護，因此正確的連續 drain(先
一個節點，然後另一個，在 uncordon 之後)不會讓 `available` 低於 `1`。

## 最終檢查

```bash
kubectl get nodes
check_result
```

兩個節點都必須在 `v1.36.x` 上為 `Ready`，且沒有任何一個是 `SchedulingDisabled`。
