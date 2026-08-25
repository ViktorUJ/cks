[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 118 - 参考解答（証明書、CoreDNS、クラスタネットワーク）

レポートは作業マシンの `/home/ubuntu/answers/` ディレクトリに保存します。control plane へは
SSH で接続します：`ssh k8s1_controlPlane_1`。

## 課題 1. 証明書のヘルスチェック → `certs.txt`

クラスタの証明書は control plane の `/etc/kubernetes/pki/` にあります。`openssl` で読み取ります
（[公式ドキュメント：Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)）。

```bash
ssh k8s1_controlPlane_1

# API サーバー証明書の有効期限
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- "notAfter=" のあとの値

# クラスタの証明機関の CN
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# 有効期限をまとめて見るのに便利：
sudo kubeadm certs check-expiration
```

作業マシンでレポートを書きます（`notAfter` の値は `=` のあとの文字列そのまま）：

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> `openssl` の出力から得た自分の `notAfter` の値を入れてください。

## 課題 2. CoreDNS を修復する

CoreDNS は `kube-system` の Deployment です
（[公式ドキュメント：DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)、
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)）。

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 - レプリカがゼロにされている
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# 名前解決の確認：
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## 課題 3. クラスタネットワークに関する事実 → `net.txt`

```bash
# クラスタの Pod CIDR（kube-controller-manager の --cluster-cidr）
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI：kube-system にあるネットワークエージェントの DaemonSet
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

ドキュメント：[Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)、
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)。

作業マシンでレポートを書きます：

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## 課題 4. Pod の ndots を下げる（dnsConfig）

kubelet は Pod の `/etc/resolv.conf` に `options ndots:5` を書き込みます：ドットが 5 個より
少ない名前は、まず search サフィックスを付けて順に試されます。外部名（`api.github.com` は
ドット 2 個）では、これは余分な NXDOMAIN クエリになります。Pod ごとにしきい値を下げるには `dnsConfig` を使います
（[公式ドキュメント：DNS for Services and Pods - Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)）。

まずデフォルトの DNS を使う Pod：

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# その resolv.conf を見る：そこには "options ndots:5" が入っている
kubectl exec dns-default -- cat /etc/resolv.conf
```

次に `ndots` を下げた Pod（宣言的に。`--dry-run` は dnsConfig を扱えないため）：

```yaml
# dns-tuned.yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-tuned
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
  containers:
  - name: c
    image: viktoruj/ping_pong:alpine
```

```bash
kubectl apply -f dns-tuned.yaml
kubectl get po dns-tuned -o jsonpath='{.spec.dnsConfig.options}'; echo
```

> トレードオフ：`ndots:2` は外部名を速くしますが、**別の** namespace のサービスへ
> 短い `backend.prod`（ドット 2 個 → もう絶対名扱い）でアクセスする場合、search による
> 補完が効かなくなります。外部名には末尾にドットを付けた FQDN のほうが確実です：`api.github.com.`。

## 課題 5. ndots のレポート → `dns.txt`

```bash
# デフォルトの Pod から ndots の値を取る
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## チェック

```bash
check_result
```

## 課題 6. Pod の DNS 名を見つける

各 Pod は次の式で A レコードを得ます：
`<ハイフンにした-pod-ip>.<namespace>.pod.cluster.local`
（[公式ドキュメント：DNS for Services and Pods - Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods)）。

```bash
# Pod dns-test の IP を調べる
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# DNS 名を組み立てる：IP のドットをハイフンに置き換える
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# 名前解決を確認する（nslookup/dig が使える任意の Pod から）
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# 答えを書き込む
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> 実際の Pod の IP を入れてください。
