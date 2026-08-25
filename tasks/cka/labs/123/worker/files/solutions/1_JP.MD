[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 123 - 参考解答（CNI をゼロから導入 + 低レベルのネットワーク）

クラスタは **CNI なし**で立ち上がっています：`kubectl get nodes` → すべてのノードが `NotReady`、
`netlab` の Pod は `Pending`/`ContainerCreating` のまま、CoreDNS も立ち上がりません。
ネットワークプラグインがない間は、Pod のネットワークも存在しません。

ノードへの接続：`ssh k8s1_controlPlane_1`、`ssh k8s1_node_node_1`。

## 課題 1。CNI を手作業で導入する

kubeadm の公式手順「Installing a Pod network add-on」です
（[kubeadm のドキュメント](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network)、
[アドオンの一覧](https://kubernetes.io/docs/concepts/cluster-administration/addons/)）。
ここでは Calico を導入します（[Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)）：

```bash
# マニフェストのバージョンは k8s 1.35 と互換のあるものを選んでください（docs.tigera.io 参照）
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# ネットワークが立ち上がる様子を観察する
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # ノードが Ready に移っていく
```

CNI の導入後：
- ノードが `Ready` になる；
- CoreDNS が立ち上がる（`kubectl -n kube-system get deploy coredns`）；
- `netlab` の `netprobe` の Pod が 2 つのノードへ分散し、`Running` に移る。

> Calico のアドレスプールを `--pod-network-cidr=10.0.0.0/16` に合わせたい場合は、
> `apply` の前にマニフェストで `CALICO_IPV4POOL_CIDR=10.0.0.0/16` を指定してください
> （実習の合否には影響しません）。

## 課題 2-3（自動でチェックされます）

CNI が動き出すと、CoreDNS と `netprobe`（異なるノード上の 2 つの Pod）はひとりでに
立ち上がります - これが、**ノードをまたぐ**ものも含めて Pod のネットワークが動いている裏付けです。

## 課題 4。低レベルネットワークのレポート → `net-lowlevel.txt`

control plane ノードで事実を集めます：

```bash
ssh k8s1_controlPlane_1

# プラグインが置いた CNI の設定ファイル
sudo ls /etc/cni/net.d
# 例：10-calico.conflist

# デフォルトルートのデバイス
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

作業マシンで：

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> 上の出力から得た自分の値を入れてください。

## network namespaces とルートの解析（低レベル）

CNI が Pod をノードのネットワークへどう結び付けるのかを理解しておくと役に立ちます。Pod が動いているノードで：

```bash
# コンテナとそのネットワーク namespace を探す
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # Pod のネットワーク namespace へのパス

# ネットワーク namespace の一覧
ip netns list
# Pod のプロセスの netns に入って、そのネットワークを見る
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # Pod の eth0 インターフェースとその IP
sudo nsenter -t $PID -n ip route       # Pod のデフォルトルート

# ホスト側の veth ペア（片方は Pod の中、もう片方はノード側）
ip -o link | grep -E 'cali|veth'
# Pod のネットワークへのルート（Calico が他のノードへのルートを追加する）
ip route | grep -E '10\.|192\.168'
```

考え方：CNI は Pod ごとに独立した **network namespace** を作り、それを veth ペアでホストと
つなぎ、プールから IP を割り当て、他のノード上の Pod ネットワークへの**ルート**を書き込みます -
こうして Kubernetes の「フラットなネットワーク」が動きます。

ドキュメント：[Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)、
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)。

## チェック

```bash
check_result
```
