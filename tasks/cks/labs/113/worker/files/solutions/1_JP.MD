[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 113 - 参考解答：kubeadm の minor upgrade

> 試験と同じように作業します：`kubectl` は作業マシンで実行し、ノードに対する操作 (apt、kubeadm、
> kubelet) はノード自体で行います：`ssh <ノード>` で入り、root になり (`sudo -i`)、
> コマンドを実行して抜けます (`exit`、`exit`)。クラスターの開始バージョンは `1.35.x`、目的のバージョンは
> `1.36.x` です。ノード名 (`<cp-ノード名>`、`<worker-ノード名>`) は `kubectl get no` から取得します；試験では異なりますが、この実習での ssh エイリアスは `k8s113_controlPlane_1` と `k8s113_node_worker1` です。

## ドキュメントでコマンドを見つける場所

| 必要なもの | ページとセクション |
| :--- | :--- |
| apt リポジトリを次の minor に切り替える (ファイル `/etc/apt/sources.list.d/kubernetes.list` の URL 内のバージョンだけを修正し、keyring は以前のままです) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| バージョンを選ぶ (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| 最初の control-plane で `kubeadm` を更新し、`kubeadm upgrade plan`、`kubeadm upgrade apply v1.xx.x` を実行する | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| `kubelet` と `kubectl` を更新し、`systemctl daemon-reload` と `restart kubelet` を実行する | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Worker ノード：`kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

Ubuntu のノードでは、`needrestart` が「一覧のみ」のモード (OK/Cancel のダイアログなし) に設定されているため、
`apt-get install` は質問で止まりません。

コマンド内の `1.36.x` の代わりに、`apt-cache madison kubeadm` と
`kubeadm upgrade plan` の出力から、実際の patch を入力してください。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

`kubectl get no` で、ノード名 (`ip-10-...`) を覚えておいてください：`drain` と `uncordon` に必要です。以下で
`<cp-ノード名>` は control-plane の名前、`<worker-ノード名>` は worker ノードの名前です。

## ステップ 0. 並行して availability のポーリングを起動する (課題 4)

upgrade の前に、作業マシンで別のセッション (`tmux`) を開き、Deployment `canary` の問い合わせのループを
以降のステップの全期間動かしたままにします：

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

## 1. control-plane の upgrade

```bash
ssh <cp-ノード名>
sudo -i
```

```bash
# control-plane で (root): 現在のバージョン
kubeadm version -o short; kubelet --version

# リポジトリを次の minor に切り替える: ファイル内で v1.35 を v1.36 に置き換える
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

kubeadm を更新します (`x` の代わりに実際の patch を入力します)。**このコマンドは単独で実行してください：** `apt-get` は
ターミナルの入力バッファを破棄するため、その直後に貼り付けた行は失われます。

```bash
# control-plane で (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# control-plane で (root)
kubeadm version -o short
kubeadm upgrade plan
```

`plan` の出力から具体的なバージョンを取り、**完全な**出力を保存しながら upgrade を実行します：

```bash
# control-plane で (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # root から
exit   # control-plane から
```

```bash
# 作業マシンで: 確認用に出力を取得する
scp <cp-ノード名>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

ここで初めて、`kubeadm upgrade apply` が成功した後に、ノードの drain と kubelet/kubectl の更新を行います：

```bash
# 作業マシンで
kubectl drain <cp-ノード名> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <cp-ノード名>
sudo -i
```

```bash
# control-plane で (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# control-plane で (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # root から
exit   # control-plane から
```

```bash
# 作業マシンで
kubectl uncordon <cp-ノード名>
kubectl get nodes
```

## 2. worker ノードの upgrade

control-plane が `1.36.x` で `Ready` になった後にのみ始めてください (version skew policy：
worker ノードの kubelet は control-plane より新しくてはなりません)。`canary` が再び `2/2` になるまで待ちます：

```bash
# 作業マシンで: AVAILABLE が 2 になるまで繰り返す
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <worker-ノード名>
sudo -i
```

```bash
# worker で (root): control-plane と同じリポジトリ
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# worker で (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# worker で (root)
# worker ノード (と追加の control-plane) では、apply の代わりに upgrade node を実行します
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # root から
exit   # worker から
```

```bash
# 作業マシンで
scp <worker-ノード名>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <worker-ノード名> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <worker-ノード名>
sudo -i
```

```bash
# worker で (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# worker で (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # root から
exit   # worker から
```

```bash
# 作業マシンで
kubectl uncordon <worker-ノード名>
kubectl get nodes
```

## 3. upgrade の順序の確認

課題 3 には個別のコマンドは不要です：順序は、checker-owned の monitor
(作業マシンの `/var/lib/cks-lab113-checker/upgrade-monitor.log`) が証明します。これは bootstrap から
ずっと書き込まれています。手順を順番どおりに (まずセクション 1 を完全に、次にセクション 2 を) 行ったなら、
ログには、control-plane がすでに `v1.36.x` で、`Ready` で schedulable であり、worker はまだ
`v1.35.x` である行があります。

## 4. downtime がないことの確認

> 唯一の control-plane での `kubeadm upgrade apply` の間、API server は数秒間
> 再起動し、問い合わせのループ内の `kubectl` は応答しません。そのような行は
> `available=api-unreachable` として記録され、最小値の集計には含まれません：API が利用できないことは、`canary` の
> 停止ではありません。downtime の有無を判定するのは、checker の独立した monitor (Pod Ready と `crictl` によるコンテナ) です。

ステップ 0 の問い合わせのループを停止し (そのセッションで `Ctrl+C`)、実行全体での `available` の最小値が
0 まで下がらなかったことを確認します：

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

`canary` の両方の replica は異なるノードに分散されており (required `podAntiAffinity`)、
`minAvailable: 1` の `PodDisruptionBudget` で保護されているため、正しい連続した drain (まず
1 つのノード、次に uncordon の後でもう 1 つのノード) は、`available` を `1` 未満にしません。

## 最終確認

```bash
kubectl get nodes
check_result
```

両方のノードが `v1.36.x` で `Ready` であり、どちらも `SchedulingDisabled` でない必要があります。
