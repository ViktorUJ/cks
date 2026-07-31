[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 123 - 參考解答(從零安裝 CNI + 低階網路)

叢集在啟動時**不含 CNI**:`kubectl get nodes` → 所有節點都是 `NotReady`,
`netlab` 中的 Pods 停在 `Pending`/`ContainerCreating`,CoreDNS 起不來。只要沒有
網路外掛 - 就沒有 Pod 網路。

連線到節點:`ssh k8s1_controlPlane_1`、`ssh k8s1_node_node_1`。

## 任務 1。手動安裝 CNI

官方的 kubeadm 步驟是「Installing a Pod network add-on」
([kubeadm 文件](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network),
[附加元件清單](https://kubernetes.io/docs/concepts/cluster-administration/addons/))。
我們安裝 Calico([Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)):

```bash
# 請選擇與 k8s 1.35 相容的 manifest 版本(見 docs.tigera.io)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# 觀察網路如何起來
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # 節點會轉為 Ready
```

安裝 CNI 之後:
- 節點變成 `Ready`;
- CoreDNS 起來(`kubectl -n kube-system get deploy coredns`);
- `netlab` 中的 `netprobe` Pods 分散到兩個節點上,並轉為 `Running`。

> 如果你希望 Calico 的位址池與 `--pod-network-cidr=10.0.0.0/16` 一致,
> 請在 `apply` 之前於 manifest 中設定 `CALICO_IPV4POOL_CIDR=10.0.0.0/16`(這不影響
> 實驗的通過)。

## 任務 2-3(自動驗證)

只要 CNI 開始運作,CoreDNS 與 `netprobe`(2 個 Pods 分布在不同節點上)就會自己
起來 - 這正是 Pod 網路可以運作的證明,包含**跨節點**的情況。

## 任務 4。低階網路報告 → `net-lowlevel.txt`

在 control plane 節點上收集事實:

```bash
ssh k8s1_controlPlane_1

# 外掛放進來的 CNI 設定檔
sudo ls /etc/cni/net.d
# 例如:10-calico.conflist

# 預設路由的裝置
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

在工作機上:

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> 請用你自己從上面輸出中得到的值替換。

## 拆解 network namespaces 與路由(低階)

理解 CNI 如何把 Pod 連上節點網路是很有幫助的。在有 Pod 的節點上:

```bash
# 找出容器與它們的 network namespace
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # Pod 的 network namespace 路徑

# 列出 network namespace
ip netns list
# 進入 Pod 行程的 netns 並查看它的網路
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # Pod 的 eth0 介面與它的 IP
sudo nsenter -t $PID -n ip route       # Pod 的預設路由

# 主機上的 veth 對(一端在 Pod 內,另一端在節點上)
ip -o link | grep -E 'cali|veth'
# 通往 Pod 網路的路由(Calico 會加入通往其他節點的路由)
ip route | grep -E '10\.|192\.168'
```

概念是:CNI 為 Pod 建立一個獨立的 **network namespace**,用 veth 對把它與
主機相連,從位址池分配一個 IP,並寫入通往其他節點上 Pod 網路的**路由** -
Kubernetes 的「扁平網路」就是這樣運作的。

文件:[Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)。

## 檢查

```bash
check_result
```
