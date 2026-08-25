[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 117 - 參考解答(control plane 與節點的 troubleshooting)

從工作機連線到節點:

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (名稱請見 /etc/hosts)
```

## 任務 1。修好 kube-apiserver(透過 crictl 除錯)

`kubectl` 無法使用(`connection refused`)- API 伺服器崩潰了。唯一能夠
釐清狀況的辦法,就是透過 `crictl` 在容器執行層級除錯。

```bash
ssh k8s1_controlPlane_1
sudo -i

# 查看容器 - 找出處於 Exited 狀態的 kube-apiserver
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# 讀取崩潰容器的日誌
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# 修改清單檔 - 刪除含有壞掉旗標的那一行
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# 刪除這一行:    - --invalid-nonexistent-flag=true
```

> **替代做法:**用 `grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> 找出該行,然後執行 `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`。

修改清單檔之後,kubelet 會重新建立 static pod。等約 30 秒:

```bash
# 在 control plane 上
crictl ps | grep kube-apiserver    # 應該是 Running
exit
```

```bash
# 在 worker PC 上 - 進行檢查
kubectl get --raw='/healthz'       # ok
```

## 任務 2。修好 kube-scheduler

```bash
# 症狀:新的 pod 無法被排程
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# 查看原因
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# 在 control plane 節點上修改 static pod
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (版本 = 叢集的版本)
```

修改清單檔之後,kubelet 會自行重新建立 static pod。
大約 30-60 秒後排程器會啟動,`sched-check` 會轉為 Running。

> 映像的確切版本可以從一個正常運作的元件取得:
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## 任務 3。修好 worker 節點(NotReady)

```bash
kubectl get nodes                     # worker 處於 NotReady
kubectl describe node <worker>        # kubelet 沒有回報狀態

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# 移除壞掉的 drop-in(它把設定檔路徑換掉了)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

大約 30 秒後節點會回到 Ready。

## 任務 4。修好 control plane 上壞掉的 static pod

```bash
kubectl get pods -n default           # staticweb-<cp> 處於 ImagePullBackOff
kubectl describe pod staticweb-<cp> -n default   # 映像 viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet 會重新建立 static pod,mirror pod `staticweb-<cp>` 會轉為 Running。

## 檢查

```bash
check_result
```
