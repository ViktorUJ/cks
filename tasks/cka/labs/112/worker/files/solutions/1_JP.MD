[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 112 - 参考解答（etcd：スナップショットとリストア）

etcd に対する操作はすべて control plane ノード上で行います（`ssh k8s1_controlPlane_1`、`sudo -i`）。
`etcdctl` は導入済みです；証明書は `/etc/kubernetes/pki/etcd/` にあります。

etcd への接続パラメータは一度まとめて設定しておくと便利です：

```bash
# control plane 上、root で
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## 課題 1. スナップショット S1（基準状態）を取得し worker にコピーする

```bash
# control plane 上
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

スナップショットを作業マシンにコピーします（チェック用）：

```bash
# worker PC から
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

（`scp` が `/root` からファイルを取得できない場合は、control plane 上で `/tmp` にコピーして
権限を付与し（`cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`）、
そのうえで `/tmp` から `scp` してください。）

## 課題 2. クラスタに変更を加える

「マーカーとなるリソース」を作成します - 後でこれらを使って 2 つのスナップショットの違いを
確認します。コマンドは作業マシン上で実行します（`kubectl` はそこに設定されています）。

```bash
# worker PC 上
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## 課題 3. スナップショット S2（変更後）を取得する

```bash
# control plane 上
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# worker PC から
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

違い：`etcd-snapshot-1.db` は `snapshot-demo` の作成**前**に取得され、`etcd-snapshot-2.db`
は**後**に取得されています。つまり S2 には namespace `snapshot-demo` とそのリソースが含まれ、S1 には含まれません。

## 課題 4. S1 をリストアし、余分なリソースがないことを確認する

一番最初のスナップショットをリストアします - クラスタは `snapshot-demo` を作成する**前**の
状態に戻るはずです。

リストアの手順（「静的 Pod を停止する → `/var/lib/etcd` にリストアする
→ 静的 Pod を起動する」という方法）：

```bash
# control plane 上、root で
# 1. 現在の etcd マニフェストからノード名とアドレスを確認する - restore で必要になる
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# 出力例:
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. control plane のすべての静的 Pod を停止する（kubelet がコンテナを落とす）
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# etcd/apiserver のコンテナが消えるまで待つ
crictl ps

# 3. 現在のデータを退避し、スナップショット S1 を /var/lib/etcd にリストアする
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. マニフェストを戻す - kubelet がリストア済みデータで control plane を起動する
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **`--name` に関する注意（etcd 3.6+）。** restore の際には `--name`、
> `--initial-cluster`、`--initial-advertise-peer-urls` を etcd のマニフェストと**まったく同じ**
> 値で指定する必要があります。そうしないと、リストアされた member が静的 Pod の起動時の member と
> 一致せず、etcd は `member unknown` のパニックで落ちます。値はステップ 1 から取得します。

クラスタが起動し、`snapshot-demo` が**消えている**ことを確認します：

```bash
# worker PC から（API が起動するまで 1 分ほど待つ）
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound - 余分なリソースはない
kubectl get pods -n kube-system
```

## 課題 5. S2 からクラスタをリストアする

次に 2 つ目のスナップショットをリストアします - `snapshot-demo` とそのリソースが戻るはずです。
手順は同じで、スナップショットは `/root/etcd-snapshot-2.db` です。

```bash
# control plane 上、root で
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # コンテナが停止するまで待つ

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

クラスタが健全で、`snapshot-demo` が**戻った**ことを確認します：

```bash
# worker PC から
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config と demo-web が所定の場所にある
kubectl get pods -n kube-system
```

まとめ：スナップショットとは、取得した時点のクラスタ状態の完全なコピーです。S1 からの
リストアはクラスタを「空の」状態に巻き戻し、S2 からのリストアは作成したリソースを戻します。
