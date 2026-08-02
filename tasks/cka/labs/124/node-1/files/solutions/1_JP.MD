[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 124 - 参考解答（3 ノード構成の HA control plane）

与えられるのは、`--control-plane-endpoint` と `--upload-certs` で初期化され、CNI が
導入済みの単一 control plane `cp1` を持つクラスタです。ここに control-plane ノード
`cp2` と `cp3` を**2 台**join し（prerequisites とパッケージは両ノードに導入済み）、
etcd の奇数クォーラム（3 ノード）を得る必要があります。

公式ドキュメント：
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)、
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)。

## ステップ 1. certificate-key と join コマンドを取得する（`cp1` で）

```bash
# 1. control plane の証明書を secret にアップロードし、certificate-key を取得する
sudo kubeadm init phase upload-certs --upload-certs
# ... 出力される：<certificate-key>

# 2. 基本の join コマンドを取得する（トークン + discovery-hash）
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

`--control-plane` と `--certificate-key` を追加して、control-plane ノード用のコマンドを組み立てます。

## ステップ 2. cp2 を join する（課題 1）

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## ステップ 3. cp3 を join する（課題 2）

同じ方法で行います。ステップ 1 から約 2 時間以上経っている場合、`certificate-key` は
期限切れです - `upload-certs` をやり直してください；トークンが期限切れ（約 24 時間）なら `kubeadm token create` を再実行します。

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

`cp1` での確認：

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 ノード
kubectl get nodes                                            # すべて Ready
```

## ステップ 4. etcd のクォーラムを確認する（課題 3）

stacked トポロジーでは、各 control-plane ノードでそれぞれの static pod `etcd-*` が起動します：

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# etcd のメンバー数を直接見る（証明書を使用、第 37 章）：
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 行 - etcd クラスタの 3 メンバー
```

## なぜ 3 なのか

3 つの etcd メンバーのクォーラムは 2 で、**1 台**のノード障害に耐えられます。2 メンバーは
**ゼロ**回の障害しか耐えられません（2 のうち 2 がクォーラム） - 単一ノードより悪い状態です。
だから HA は奇数で組みます：3（標準）か 5（2 台の障害に耐える）。偶数は不利です（第 35A 章）。

## チェック

```bash
check_result
```
