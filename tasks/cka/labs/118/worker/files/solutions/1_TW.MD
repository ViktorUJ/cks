[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 118 - 參考解答(憑證、CoreDNS、叢集網路)

報告儲存在工作機的 `/home/ubuntu/answers/` 目錄。連上 control plane
使用 SSH:`ssh k8s1_controlPlane_1`。

## 任務 1。憑證健康檢查 → `certs.txt`

叢集憑證放在 control plane 的 `/etc/kubernetes/pki/`。我們用
`openssl` 讀取它們([官方文件:Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/))。

```bash
ssh k8s1_controlPlane_1

# API 伺服器憑證的有效期限
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
# notAfter=Jul 20 10:00:00 2026 GMT   <- "notAfter=" 之後的值

# 叢集憑證授權中心的 CN
sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject
# subject=CN = kubernetes   <- CN = kubernetes

# 方便的期限總覽:
sudo kubeadm certs check-expiration
```

在工作機上寫入報告(`notAfter` 的值 - 就是 `=` 符號之後那整串字串):

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/certs.txt <<EOF
apiserver_notafter=Jul 20 10:00:00 2026 GMT
ca_cn=kubernetes
EOF
```

> 請填入你自己從 `openssl` 輸出得到的 `notAfter` 值。

## 任務 2。修復 CoreDNS

CoreDNS 是 `kube-system` 中的一個 Deployment
([官方文件:DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/),
[Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/))。

```bash
kubectl -n kube-system get deploy coredns          # READY 0/0 - 副本數被歸零
kubectl -n kube-system scale deployment coredns --replicas=2
kubectl -n kube-system rollout status deploy coredns

# 驗證解析:
kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup kubernetes.default
```

## 任務 3。叢集網路相關事實 → `net.txt`

```bash
# 叢集的 Pod CIDR(kube-controller-manager 的 --cluster-cidr)
ssh k8s1_controlPlane_1 \
  "sudo grep -o 'cluster-cidr=[^ ]*' /etc/kubernetes/manifests/kube-controller-manager.yaml"
# cluster-cidr=10.0.0.0/16

# CNI:kube-system 中網路代理程式的 DaemonSet
kubectl -n kube-system get ds | grep calico
# calico-node ...
```

文件:[Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[kubeadm: pod-network-cidr](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)。

在工作機上寫入報告:

```bash
cat > /home/ubuntu/answers/net.txt <<EOF
pod_cidr=10.0.0.0/16
cni_daemonset=calico-node
EOF
```

## 任務 4。為 Pod 降低 ndots(dnsConfig)

kubelet 會給 Pod 寫入帶有 `options ndots:5` 的 `/etc/resolv.conf`:點數少於 5 個
的名稱會先逐一搭配 search 後綴嘗試。對外部名稱來說(`api.github.com` - 2 個
點),這些都是多餘的 NXDOMAIN 查詢。要為 Pod 降低這個門檻,可以透過 `dnsConfig`
([官方文件:DNS for Services and Pods - Pod DNS Config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config))。

先建立一個使用預設 DNS 的 Pod:

```bash
kubectl run dns-default --image=viktoruj/ping_pong:alpine --restart=Never

# 看看它的 resolv.conf:裡面會有 "options ndots:5"
kubectl exec dns-default -- cat /etc/resolv.conf
```

接著建立一個 `ndots` 較低的 Pod(用宣告式方式,因為 `--dry-run` 不支援 dnsConfig):

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

> 取捨:`ndots:2` 會加快外部名稱的解析,但用簡短的 `backend.prod`(2 個點 → 已算絕對名稱)
> 去存取**其他** namespace 中的服務時,就不會再透過 search 補全了。對外部名稱來說,
> 帶結尾點的 FQDN 更可靠:`api.github.com.`。

## 任務 5。ndots 報告 → `dns.txt`

```bash
# 從預設的 Pod 取得 ndots 的值
kubectl exec dns-default -- cat /etc/resolv.conf | grep -oE 'ndots:[0-9]+'
# ndots:5

cat > /home/ubuntu/answers/dns.txt <<EOF
default_ndots=5
tuned_ndots=2
EOF
```

## 檢查

```bash
check_result
```

## 任務 6。找出 Pod 的 DNS 名稱

每個 Pod 都會依下列公式取得一筆 A 記錄:
`<帶連字號的-pod-ip>.<namespace>.pod.cluster.local`
([官方文件:DNS for Services and Pods - Pod's A/AAAA record](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pods))。

```bash
# 取得 Pod dns-test 的 IP
kubectl get pod dns-test -n dns-lab -o wide
# NAME       READY   STATUS    IP           ...
# dns-test   1/1     Running   10.0.1.23    ...

# 組出 DNS 名稱:把 IP 中的點換成連字號
# 10.0.1.23 → 10-0-1-23.dns-lab.pod.cluster.local

# 驗證解析(從任一個有 nslookup/dig 的 Pod)
kubectl exec dns-default -- nslookup 10-0-1-23.dns-lab.pod.cluster.local

# 寫入答案
echo "10-0-1-23.dns-lab.pod.cluster.local" > /home/ubuntu/answers/pod-dns-name.txt
```

> 請填入你自己 Pod 的實際 IP。
