[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 124 - 參考解答(由 3 個節點組成的 HA control plane)

你會拿到一個只有單一 control plane `cp1` 的叢集,它已透過
`--control-plane-endpoint` 與 `--upload-certs` 初始化,並已安裝 CNI。你需要加入
**兩個** control-plane 節點 `cp2` 與 `cp3`(它們上面的 prerequisites 與套件都已裝好),
以取得奇數的 etcd quorum(3 個節點)。

官方文件:
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/),
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)。

## 步驟 1。取得 certificate-key 與 join 指令(在 `cp1` 上)

```bash
# 1. 把 control plane 的憑證上傳到 secret 並取得 certificate-key
sudo kubeadm init phase upload-certs --upload-certs
# ... 會印出:<certificate-key>

# 2. 取得基本的 join 指令(token + discovery-hash)
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

把 `--control-plane` 與 `--certificate-key` 加上去,組合出 control-plane 節點用的指令。

## 步驟 2。加入 cp2(任務 1)

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## 步驟 3。加入 cp3(任務 2)

用同樣的方式。如果從步驟 1 之後已經過了大約 2 小時以上,`certificate-key` 就過期了 -
請重新執行 `upload-certs`;如果 token 過期(約 24 小時)- 請重新執行 `kubeadm token create`。

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

在 `cp1` 上檢查:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 個節點
kubectl get nodes                                            # 全部 Ready
```

## 步驟 4。檢查 etcd 的 quorum(任務 3)

在 stacked 拓撲下,每個 control-plane 節點都會啟動自己的 static pod `etcd-*`:

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# 直接查看 etcd 的成員數量(使用憑證,第 37 章):
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 行 - etcd 叢集的三個成員
```

## 為什麼正好是 3

3 個 etcd 成員的 quorum 是 2,能承受**一個**節點故障。2 個成員能承受
**零**次故障(2 之中要 2 個 quorum)- 這比單一節點更糟。所以 HA 建立在奇數
上:3(標準做法)或 5(可承受兩個節點故障)。偶數並不划算(第 35A 章)。

## 檢查

```bash
check_result
```
