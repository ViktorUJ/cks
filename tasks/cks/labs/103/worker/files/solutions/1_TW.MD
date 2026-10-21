[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 103 - 參考解答

> 除非明確指出 `control-plane`，否則指令都在 worker 上執行。修改
> static Pod manifests 之前請先保存副本。Kubelet 會自己注意到檔案的變更，並重新建立
> 對應的 static Pods；不要透過 Kubernetes API 刪除它們。
>
> 在考試中，`k`(`alias k=kubectl`)與它的 bash-completion 已經在 SSH 主機上設定好 -
> 不要花時間去設定它們，直接使用 `k` 即可(參見第 33.6 章)。

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## 任務 1。kube-bench 報告

`kube-bench` `0.16.0` 已經安裝在 `control-plane` 上(就像真正的考試中，
節點上已經有 CIS Benchmark 工具一樣)- 不需要從 worker 複製過去。Kubernetes
`1.36` 目前還不在 kube-bench 官方的 support table 中；這個版本內建的 version mapping
以 `"1.34": "cis-1.12"` 這筆記錄結束 - `0.16.0` 中完全沒有更新的 profile(包括
任何 1.35/1.36 的 profile)，因此我們使用 `cis-1.12`,
作為最接近的現有 profile。我們強制把它當作 approximate
hardening signal 來執行，而不是 authoritative CIS compliance assessment。

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

請親眼確認五個 `== Summary <target> ==` 全部都存在 - 沒有明確的
`--targets`，其中一部分(`etcd`、`policies`)不會出現在報告中。

## 任務 2。Hardening kubelet

不要憑記憶回想欄位名稱 - 在考試中，直接從已經取得的
kube-bench 報告(任務 1)中取出會更快。報告中每個 check 都有 `== Remediations <target> ==` 區段，
裡面有現成的修正文字 - 用 `grep -A1` 依 check 編號搜尋，就能直接得到需要的欄位：

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

在 control-plane 上，kubelet 讀取 `/var/lib/kubelet/config.yaml`。YAML 中必須恰好有
以下欄位(不要把同名的鍵加入第二次):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

在考試中，不要在每個指令前加 `sudo` - 一次切換成 root(`sudo -i`),
這樣更快：

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # 離開 root shell
exit   # 離開 control-plane
```

我們檢查的不是檔案的靜態文字，而是 kubelet
實際套用的生效設定 - 透過 `configz` API(對 YAML 做文字解析很容易被像 `webhook.enabled` 這樣
類似的欄位騙過，而 `configz` 反映的是 kubelet 自己認定的
設定):

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## 任務 3。停用 kube-apiserver 的 profiling

與任務 2 相同的做法 - 把任務 1 的 kube-bench 報告當作真相來源，
不要憑記憶回想旗標：

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

把參數加入 `kube-apiserver` 容器的 `command` 清單。

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 在 command 陣列中加入一行,縮排與其他參數相同:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS 必須變成 Running - 如果還沒有,請等幾秒鐘再重試
```

## 任務 4。TLS Secret 與 Ingress

建立最小的應用程式與 Service，為確切的 DNS 名稱產生自簽憑證，
然後建立 TLS Secret 與 Ingress。`ingress-nginx` controller 在本實驗中已經
安裝並處於 Ready(lab-owned fixture，版本在 bootstrap 中固定)- 在建立 Ingress 之前，
我們先確認這一點。

簡短的資源名稱(`ns` = namespace,`deploy` = deployment,`svc` = service,
`ing` = ingress,`po` = pod)能在時間壓力下節省打字。

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

不要停在 `k get ... -o yaml` - 要確認 TLS Ingress 確實
透過真正的 controller 在運作。`secure.cks.local` 已經解析為真實的節點 IP
(bootstrap 在 `/etc/hosts` 中加入了該記錄)，而 `ingress-nginx-controller` 是類型為
`NodePort` 的 Service，在每個節點上都開放，因此 curl 直接在這台機器上執行，不需要 SSH
到叢集：

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200,內容包含 "Server Name: secure-app"

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

這個 HTTP→HTTPS 的 redirect 是考試中的真實題目，不是本實驗人為設置的要求
(參見 mock 考試 `tasks/cks/mock/04`，任務 4)。

## 任務 5。TLS hardening kube-apiserver 與 etcd

不要到文件中去找確切的旗標名稱 - 從已經執行中的 Pod 內部直接詢問二進位檔本身更快
(control plane 的任何元件都有 `--help`)，然後 grep 出需要的部分：

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

在兩個 static Pod manifests 中，把參數加入 `command`。對 kube-apiserver，任務要求
「兩個」旗標，儘管在 `VersionTLS13` 下真正提供防護的是 `--tls-min-version`
(Go 會自己選擇 TLS 1.3 cipher suites,`--tls-cipher-suites` 不會影響它們 - 參見「開始前先自我檢查」一節中的問題
2)。`--tls-cipher-suites` 仍然需要明確設定 - 這是
defense-in-depth：如果之後最低版本被放寬到 1.2，弱的加密套件組合
不會自己啟用。對 etcd(那裡允許 TLS 1.2),`--cipher-suites` 現在就實際
限制了套件組合，而不是為了將來。

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 在 command 中加入:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# 在 command 中加入:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS 必須變成 Running - 如果還沒有,請等幾秒鐘再重試
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - 連線成功

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - handshake 必須失敗,這正是需要的結果

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

預期會看到形如 `Protocol version: TLSv1.3` 或 `Protocol : TLSv1.3` 的行，而
`openssl s_client -tls1_2` 以 handshake 錯誤/non-zero exit 結束，必須記錄為
`TLS 1.2 correctly rejected`。

## 任務 6。驗證 kubelet 與 kubectl 的 SHA-256

基準不是從本機檔案計算出來的。請下載 Kubernetes `v1.36.0` 官方公布的 checksum,
產生 `sha256sum -c` 格式的檔案，並儲存結果。

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

兩行都必須以 `: OK` 結尾。如果二進位檔的路徑不是 `/usr/bin`,
`command -v` 仍然會為 `sha256sum -c` 產生正確的輸入。

## 任務 7。Remediation cycle：從具體的 kube-bench FAIL 到 PASS

與任務 1(整份報告的快照)不同，這裡需要把一個具體的 check
與它的修正連結起來。`kube-bench` 支援透過 `--check` 做針對性的執行，因此
不需要手動重新閱讀整份報告：

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

檢查節點上實際的存取權限，並把它修正為 `600` - 這是 file-only
的變更，kubelet 不會因為權限變更而重新建立 static Pod，只會因為
manifest 內容的變更而重新建立：

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

對同一個 check 重新做針對性的執行，應該會顯示 `PASS`:

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

確認 kube-apiserver 仍然健康：修改檔案權限不會改變它的
內容，因此 kubelet 不應該重新建立 static Pod。

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## 任務 8。Remediation cycle:kube-controller-manager

與任務 7 相同的做法，針對另一個元件與另一個 check ID(`1.1.3` -
kube-controller-manager pod specification file permissions):

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## 任務 9。Remediation cycle:kube-controller-manager 與 kube-scheduler 上的 profiling

與任務 7-8 相同的做法(透過 kube-bench 找出具體的 `[FAIL]`，修正，
確認 `[PASS]`)，針對 checks `1.3.2`(kube-controller-manager profiling)與 `1.4.1`
(kube-scheduler profiling)。兩者和整個 `1.x` 區段一樣，在
`cis-1.12` 中屬於 target `master`，因此不需要明確的 `--targets` - 與任務 7-8 完全相同。任務 3
只在 kube-apiserver 上停用了 profiling;kubeadm 預設「完全不會」在 kube-controller-manager/kube-scheduler 的
manifests 中加入 `--profiling=false`。

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

修正兩個 static Pod manifests - 與任務 3 相同的做法，只是針對另外兩個
元件：

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# 在 command 陣列中加入一行,縮排與其他參數相同:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

我們檢查的不是檔案的文字，而是實際執行中的 Pod(kubelet 在 manifest 變更之後
並不會立刻重新建立 static Pod)，而對同一個 check 重新做針對性的執行，應該會
顯示 `PASS`:

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` 必須對兩個元件都輸出 `true`，而上面兩個 `k get pods` 指令
必須顯示 `Running`。

## 任務 10。Remediation cycle:worker 節點上的 protect-kernel-defaults

與任務 7-9 相同的做法，這次是在「真正的」worker 節點上(不是 control-plane)，但針對
「另一個」profile。固定的 `kube-bench 0.16.0`/`cis-1.12`(本實驗所有其他
任務都使用它)完全不包含 protect-kernel-defaults 的 check - CIS 從這個版本的 profile 開始
把它移除/重新編號了；`cis-1.12` 中自己的 `4.2.6` 是
「另一個」check(`--make-iptables-util-chains`，預設為 `PASS`，與 protect-kernel-defaults
無關)。具有相同 ID `4.2.6` 的所需 check 存在於同一個二進位檔較舊的 profile
`cis-1.24` 中 - 請明確使用 `--benchmark cis-1.24` 來使用它，只用於
這一個任務。

與 control-plane 不同，worker 節點上「沒有」預先安裝 `kube-bench` - 請在
這裡自己安裝(真正的安裝，不是從 control-plane 或 worker PC 複製)：從 GitHub 下載同一個
固定的 release，把 `binary` 與 `cfg` 解壓縮到預設的 `--config-dir`
(`/etc/kube-bench/cfg`)，這樣就不必在每個指令中明確指定這個旗標：

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# 與任務 6 相同的做法:與獨立公布的 checksum 比對,而不是與
# 從檔案本身計算出的 checksum 比對。
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` 完全不在 kubeadm 產生的 `KubeletConfiguration` 中 -
這個欄位實際上就是不存在(等同於不安全的預設值 `false`)，因此直接
把它加進去，不要去找現有的行來取代：

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

透過 `/configz`(實際套用的設定，而不是檔案的文字)以及
對 check 重新做針對性的執行來確認：

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
