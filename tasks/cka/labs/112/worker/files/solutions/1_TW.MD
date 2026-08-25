[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 112 - 參考解答(etcd:快照與還原)

所有 etcd 相關操作都在 control plane 節點上進行(`ssh k8s1_controlPlane_1`,`sudo -i`)。
`etcdctl` 已經安裝好;憑證位於 `/etc/kubernetes/pki/etcd/`。

方便的做法是一次性設定好連線到 etcd 的共用參數:

```bash
# 在 control plane 上,以 root 身分
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## 任務 1。拍下快照 S1(基準狀態)並複製到 worker

```bash
# 在 control plane 上
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

把快照複製到工作機(用於檢查):

```bash
# 從 worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(如果 `scp` 無法從 `/root` 取得檔案,請在 control plane 上把它複製到 `/tmp` 並
給予權限:`cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`,
然後再從 `/tmp` 執行 `scp`。)

## 任務 2。對叢集進行變更

我們建立一些「標記資源」- 之後就靠它們看出兩份快照之間的差異。這些指令
在工作機上執行(`kubectl` 是在那裡設定好的)。

```bash
# 在 worker PC 上
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## 任務 3。拍下快照 S2(變更之後)

```bash
# 在 control plane 上
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# 從 worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

差別在於:`etcd-snapshot-1.db` 是在建立 `snapshot-demo` **之前**拍的,而 `etcd-snapshot-2.db`
是**之後**拍的。也就是說,S2 包含 namespace `snapshot-demo` 及其資源,而 S1 沒有。

## 任務 4。還原 S1 並確認多出來的資源已消失

我們還原最早的那份快照 - 叢集應該回到建立 `snapshot-demo` **之前**的
狀態。

還原的順序(採用「停止靜態 Pod → 還原到 `/var/lib/etcd` → 重新啟動靜態
Pod」這個方法):

```bash
# 在 control plane 上,以 root 身分
# 1. 從目前的 etcd 清單檔中查出節點名稱與位址 - restore 時會用到
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# 輸出範例:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. 停止 control plane 的所有靜態 Pod(kubelet 會關掉它們的容器)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# 等到 etcd/apiserver 的容器消失
crictl ps

# 3. 移走目前的資料,並把快照 S1 還原到 /var/lib/etcd
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. 把清單檔放回原處 - kubelet 會用還原後的資料把 control plane 拉起來
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **關於 `--name` 的重點(etcd 3.6+)。** 執行 restore 時,`--name`、
> `--initial-cluster` 與 `--initial-advertise-peer-urls` 必須與 etcd 清單檔中的
> **完全相同**。否則還原出來的 member 會跟靜態 Pod 啟動時所用的不一致,
> etcd 就會以 `member unknown` panic 掛掉。這些值取自步驟 1。

檢查叢集是否已經起來,以及 `snapshot-demo` 是否**消失**了:

```bash
# 從 worker PC(等約 1 分鐘,讓 API 起來)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound - 沒有多出來的資源
kubectl get pods -n kube-system
```

## 任務 5。從 S2 還原叢集

現在還原第二份快照 - `snapshot-demo` 及其資源應該會回來。程序相同,
快照換成 `/root/etcd-snapshot-2.db`。

```bash
# 在 control plane 上,以 root 身分
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # 等容器停止

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

檢查叢集是否健康,以及 `snapshot-demo` 是否**回來**了:

```bash
# 從 worker PC
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config 與 demo-web 都在
kubectl get pods -n kube-system
```

結論:快照就是叢集狀態在拍下那一刻的完整快照影像。從 S1 還原會把叢集
回退到「空的」狀態,從 S2 還原則會把建立的資源帶回來。
