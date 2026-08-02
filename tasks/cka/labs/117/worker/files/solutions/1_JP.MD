[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 117 - 参考解答（control plane とノードの troubleshooting）

作業マシンからノードへ接続する方法：

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (名前は /etc/hosts を参照)
```

## 課題 1。kube-apiserver を直す（crictl によるデバッグ）

`kubectl` が動きません（`connection refused`）- API サーバーが落ちています。状況を把握する
唯一の手段は、`crictl` によるコンテナランタイムレベルのデバッグです。

```bash
ssh k8s1_controlPlane_1
sudo -i

# コンテナを見る - Exited 状態の kube-apiserver を探す
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# 落ちたコンテナのログを読む
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# マニフェストを修正 - 壊れたフラグの行を削除する
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# 次の行を削除:    - --invalid-nonexistent-flag=true
```

> **代替手段：**`grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> で該当行を見つけ、そのあと `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`。

マニフェストの修正後、kubelet が static pod を再作成します。約 30 秒待ちます：

```bash
# control plane 上で
crictl ps | grep kube-apiserver    # Running になっているはず
exit
```

```bash
# worker PC 上で - 確認する
kubectl get --raw='/healthz'       # ok
```

## 課題 2。kube-scheduler を直す

```bash
# 症状: 新しい Pod がスケジュールされない
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# 原因を見る
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# control plane ノード上で static pod を修正する
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (バージョン = クラスタのバージョン)
```

マニフェストの修正後、kubelet が自分で static pod を再作成します。
約 30-60 秒でスケジューラーが立ち上がり、`sched-check` が Running に移行します。

> イメージの正確なバージョンは、動作しているコンポーネントから取得できます：
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## 課題 3。worker ノードを直す（NotReady）

```bash
kubectl get nodes                     # worker が NotReady
kubectl describe node <worker>        # kubelet がステータスを報告していない

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# 壊れた drop-in を削除する (設定ファイルのパスを置き換えていた)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

約 30 秒でノードは Ready に戻ります。

## 課題 4。control plane 上の壊れた static pod を直す

```bash
kubectl get pods -n default           # staticweb-<cp> が ImagePullBackOff
kubectl describe pod staticweb-<cp> -n default   # イメージ viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet が static pod を再作成し、mirror Pod `staticweb-<cp>` が Running に移行します。

## チェック

```bash
check_result
```
